#!/bin/bash
#
# test-symlink-race.sh - Test for symlink-following truncation in pqos
#                        safe_fopen (RHEL-214424)
#
# The vulnerability is in the original safe_fopen() implementation:
#
#   1. lstat(path) — collects symlink metadata
#   2. fopen(path, "w+") — follows the symlink, truncating the TARGET
#   3. fstat(fd) vs lstat comparison detects the mismatch, aborts
#
# Steps 1-3 correctly detect the symlink, but the damage happens at
# step 2: fopen("w+") truncates the symlink target to zero bytes
# before the check at step 3 can prevent it.  No race is required —
# a pre-existing symlink is enough.
#
# The fix replaces fopen() with open(O_NOFOLLOW) + fdopen().  The
# kernel rejects the symlink atomically at open time with ELOOP,
# so the target is never opened or truncated.
#
# On unpatched code: FAIL — the target file is truncated to zero.
# On patched code:   PASS — the target file is untouched.
#
# Must be run as root on a system with RDT/CAT support (x86_64).
#
# Usage:
#   sudo ./test-symlink-race.sh [path-to-pqos]
#
# Exit codes:
#   0 - PASS (target file intact — symlink was rejected before open)
#   1 - FAIL (target file truncated — vulnerability confirmed)
#   2 - SKIP (cannot run test — missing prerequisites)
#

PQOS="${1:-$(command -v pqos 2>/dev/null || echo "")}"
TESTDIR=$(mktemp -d /tmp/symlink-race-test.XXXXXX)

OFF=$'\033[0m'
BOLD=$'\033[1m'
GREEN=$'\033[1;32m'
RED=$'\033[1;31m'
INFO=$'\033[0;36m'
WARN=$'\033[0;33m'

pass_result() {
    echo -e "${GREEN}${BOLD}***********${OFF}"
    echo -e "${GREEN}${BOLD}*  PASS!  *${OFF}"
    echo -e "${GREEN}${BOLD}***********${OFF}"
}

fail_result() {
    echo -e "${RED}${BOLD}***********${OFF}"
    echo -e "${RED}${BOLD}*  FAIL!  *${OFF}"
    echo -e "${RED}${BOLD}***********${OFF}"
}

cleanup() {
    rm -rf "$TESTDIR"
}
trap cleanup EXIT

echo -e "${INFO}=== pqos symlink truncation test (RHEL-214424) ===${OFF}"
echo ""
echo -e "${INFO}NOTE:${OFF} This test checks whether pqos safe_fopen() truncates a"
echo "  symlink target before detecting the symlink.  The original code"
echo "  calls fopen(\"w+\") which follows symlinks and truncates the"
echo "  target, then detects the mismatch and aborts — but the damage"
echo "  is already done.  No race condition is needed; a pre-existing"
echo "  symlink is sufficient."
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
echo ""

# --- Set up files ---

TARGET="$TESTDIR/sensitive-file.txt"
SYMLINK="$TESTDIR/pqos-output.csv"
SENTINEL="THIS_DATA_MUST_SURVIVE"

echo "$SENTINEL" > "$TARGET"
ln -sf "$TARGET" "$SYMLINK"

echo -e "${INFO}Target file:${OFF}  $TARGET"
echo -e "${INFO}Symlink:${OFF}      $SYMLINK -> $TARGET"
echo -e "${INFO}Content:${OFF}      $SENTINEL"
echo ""

# Verify setup
if [[ ! -L "$SYMLINK" ]]; then
    echo -e "${RED}Error:${OFF} Failed to create symlink"
    exit 2
fi

# --- Trigger the vulnerability ---

echo -e "${INFO}Running pqos with symlink as output path...${OFF}"
echo ""

# pqos will attempt safe_fopen(SYMLINK, "w+").
# On unpatched code: fopen truncates the target, then lstat/fstat
#   catches the mismatch and prints "File is a symlink".
# On patched code: open(O_NOFOLLOW) fails with ELOOP immediately.
"$PQOS" --iface=os -o "$SYMLINK" -u csv -T 2>&1 | while IFS= read -r line; do
    echo "  pqos: $line"
done
echo ""

# --- Check the target ---

if [[ ! -f "$TARGET" ]]; then
    fail_result
    echo ""
    echo -e "${RED}${BOLD}FAIL:${OFF} Target file was deleted!"
    echo ""
    echo "  pqos followed the symlink and removed the target file."
    echo "  This confirms the vulnerability described in RHEL-214424."
    exit 1
fi

contents=$(cat "$TARGET")
if [[ -z "$contents" ]]; then
    fail_result
    echo ""
    echo -e "${RED}${BOLD}FAIL:${OFF} Target file was truncated to zero bytes!"
    echo ""
    echo "  pqos safe_fopen() called fopen(\"w+\") which followed the"
    echo "  symlink and truncated the target before the post-open"
    echo "  lstat/fstat check could prevent it."
    echo ""
    echo "  This confirms the vulnerability described in RHEL-214424."
    exit 1
fi

if [[ "$contents" != "$SENTINEL" ]]; then
    fail_result
    echo ""
    echo -e "${RED}${BOLD}FAIL:${OFF} Target file content was modified!"
    echo ""
    echo "  Expected: $SENTINEL"
    echo "  Got:      $contents"
    echo ""
    echo "  pqos followed the symlink and overwrote the target."
    echo "  This confirms the vulnerability described in RHEL-214424."
    exit 1
fi

pass_result
echo ""
echo -e "${GREEN}${BOLD}PASS:${OFF} Target file is intact."
echo ""
echo "  Content: $contents"
echo ""
echo "  The symlink was rejected at open time (O_NOFOLLOW → ELOOP)"
echo "  before any truncation could occur.  The fix is working."
exit 0
