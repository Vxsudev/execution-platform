#!/usr/bin/env bash
# run-full-regression.sh — Dynamic full regression over the canonical active index.
#
# Scans `scripts/verification/*.sh` at the top level only. Skips itself,
# `_legacy/` (never recursed), `_quarantine/` (never recursed). Reports
# aggregate PASS / FAIL counts. Exits 0 iff every active script PASSes.
#
# This wrapper is the ONLY entrypoint permitted to invoke multiple
# verification scripts. Individual scripts do NOT chain.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

TOTAL=0
PASSED=0
FAILED=0
FAILED_LIST=""

echo "=================================================="
echo "  FULL REGRESSION — canonical active index"
echo "  Source: scripts/verification/*.sh (top level only)"
echo "=================================================="
echo ""

for script in $(ls scripts/verification/*.sh 2>/dev/null | sort); do
    name="$(basename "$script")"
    [ "$name" = "run-full-regression.sh" ] && continue

    TOTAL=$((TOTAL + 1))
    if bash "$script" > /dev/null 2>&1; then
        PASSED=$((PASSED + 1))
        printf "  [PASS]  %s\n" "$name"
    else
        FAILED=$((FAILED + 1))
        FAILED_LIST="$FAILED_LIST $name"
        printf "  [FAIL]  %s\n" "$name"
    fi
done

echo ""
echo "=================================================="
echo "  Total:  $TOTAL"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
if [ -n "$FAILED_LIST" ]; then
    echo ""
    echo "  Failed scripts:"
    for f in $FAILED_LIST; do
        echo "    - $f"
    done
fi
echo "=================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
