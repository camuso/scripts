#!/bin/bash
#
# test-fd-leak.sh - Test for CVE in rdtset (RHEL-214298)
#
# Verifies whether rdtset leaks privileged file descriptors
# (e.g. /dev/cpu/*/msr) to sub-commands after privilege drop.
#
# Must be run as root on a system with MSR support (x86_64).
#
# Usage:
#   sudo ./test-fd-leak.sh [path-to-rdtset]
#
# Exit codes:
#   0 - PASS (no MSR fds leaked)
#   1 - FAIL (MSR fds leaked to child — vulnerability present)
#   2 - SKIP (cannot run test — missing prerequisites)
#

set -euo pipefail

RDTSET="${1:-$(command -v rdtset 2>/dev/null || echo "")}"
RESULT_FILE=$(mktemp /tmp/fd-leak-test.XXXXXX)

OFF=$'\033[0m'
PASS=$'\033[1;32m'
FAIL=$'\033[1;31m'
INFO=$'\033[0;36m'
WARN=$'\033[0;33m'

cleanup() {
    rm -f "$RESULT_FILE"
}
trap cleanup EXIT

echo -e "${INFO}=== rdtset FD leak test (RHEL-214298) ===${OFF}"
echo ""

# --- Prerequisite checks ---

if [[ $(id -u) -ne 0 ]]; then
    echo -e "${WARN}SKIP:${OFF} Must be run as root (rdtset requires MSR access)"
    exit 2
fi

if [[ -z "$RDTSET" || ! -x "$RDTSET" ]]; then
    echo -e "${WARN}SKIP:${OFF} rdtset not found. Provide path as argument."
    echo "  Usage: sudo $0 /path/to/rdtset"
    exit 2
fi

if [[ ! -e /dev/cpu/0/msr ]]; then
    modprobe msr 2>/dev/null || true
    if [[ ! -e /dev/cpu/0/msr ]]; then
        echo -e "${WARN}SKIP:${OFF} /dev/cpu/0/msr not available (no MSR support)"
        exit 2
    fi
fi

echo -e "${INFO}rdtset:${OFF} $RDTSET"
echo -e "${INFO}rdtset version:${OFF}"
"$RDTSET" -w 2>&1 || true
echo ""

# --- The test ---
#
# Run rdtset in MSR mode with a Python sub-command that inspects its own
# inherited file descriptors. If any /dev/cpu/*/msr descriptors are
# present in the child, the vulnerability exists.

echo -e "${INFO}Running rdtset with FD inspection sub-command...${OFF}"
echo ""

"$RDTSET" -F msr -t 'l3=0xf;cpu=0' -c 0 -- \
    python3 -c "
import os, sys

result_file = '$RESULT_FILE'
uid, gid = os.getuid(), os.getgid()

msr_fds = []
other_fds = []

for entry in os.listdir('/proc/self/fd'):
    try:
        fd_num = int(entry)
        if fd_num <= 2:
            continue
        target = os.readlink(f'/proc/self/fd/{entry}')
        if '/dev/cpu/' in target and target.endswith('/msr'):
            msr_fds.append((fd_num, target))
        else:
            other_fds.append((fd_num, target))
    except (ValueError, OSError):
        pass

# Write results to file (stdout may not survive rdtset cleanup)
with open(result_file, 'w') as f:
    f.write(f'uid={uid} gid={gid}\n')
    f.write(f'msr_fds={len(msr_fds)}\n')
    f.write(f'other_fds={len(other_fds)}\n')
    for fd_num, target in msr_fds:
        # Try a harmless read to confirm descriptor is usable
        try:
            data = os.pread(fd_num, 8, 0x10)  # IA32_TIME_STAMP_COUNTER
            f.write(f'LEAKED fd={fd_num} target={target} readable=yes ({len(data)} bytes)\n')
        except OSError as e:
            f.write(f'LEAKED fd={fd_num} target={target} readable=no ({e})\n')
    for fd_num, target in other_fds:
        f.write(f'INHERITED fd={fd_num} target={target}\n')
" 2>&1 || true

echo ""

# --- Parse results ---

if [[ ! -s "$RESULT_FILE" ]]; then
    echo -e "${WARN}SKIP:${OFF} No output from sub-command (rdtset may have failed to initialize)"
    echo "  This can happen if the CPU doesn't support L3 CAT."
    echo "  Check that RDT/CAT is supported: rdtset -F msr -w"
    exit 2
fi

echo -e "${INFO}Sub-command results:${OFF}"
cat "$RESULT_FILE"
echo ""

MSR_COUNT=$(grep -c '^LEAKED' "$RESULT_FILE" 2>/dev/null) || MSR_COUNT=0

if [[ "$MSR_COUNT" -gt 0 ]]; then
    echo -e "${FAIL}FAIL:${OFF} $MSR_COUNT MSR file descriptor(s) leaked to child process!"
    echo ""
    echo "  The child process inherited open /dev/cpu/*/msr descriptors"
    echo "  after rdtset dropped privileges. This confirms the vulnerability"
    echo "  described in RHEL-214298."
    echo ""
    grep '^LEAKED' "$RESULT_FILE" | while read -r line; do
        echo -e "  ${FAIL}•${OFF} $line"
    done
    exit 1
else
    echo -e "${PASS}PASS:${OFF} No MSR file descriptors leaked to child process."
    echo ""
    echo "  The child process did not inherit any /dev/cpu/*/msr descriptors."
    echo "  The fix is working correctly."
    exit 0
fi
