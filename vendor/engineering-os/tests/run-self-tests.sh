#!/usr/bin/env bash
# run-self-tests.sh — Vendored OS Self-Test Orchestrator
#
# Runs the five vendored package self-tests in numeric order.
# Each sub-test asserts a portion of the package's contract:
#   001 — enforcement layer (pre-commit + script presence + token gate)
#   002 — state machine (transitions + require + isolated registry)
#   003 — invariant engine (generic runner + adapter overlay + parity with live)
#   004 — CLI backing surfaces (boot/check/self-test scripts + spec approval)
#   005 — CLI wrapper (raystrat-os routing, exit codes, usage guard)
#
# Run from repository root:
#   bash vendor/engineering-os/tests/run-self-tests.sh
#
# Exit codes:
#   0 — all four sub-tests pass
#   1 — one or more sub-tests fail

set -e

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

PASS=0
FAIL=0
FAILED_TESTS=""

run_test() {
  local script="$1"
  local label="$2"
  echo ""
  echo "──────────────────────────────────────────────────────────────"
  echo "Running: $label"
  echo "──────────────────────────────────────────────────────────────"
  if bash "$TESTS_DIR/$script"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_TESTS="$FAILED_TESTS $script"
  fi
}

echo "Engineering OS — Vendored Package Self-Test Suite"
echo "══════════════════════════════════════════════════════════════"

run_test "001-os-enforcement-layer.sh"    "Enforcement Layer"
run_test "002-os-state-machine.sh"        "State Machine"
run_test "003-os-invariant-engine.sh"     "Invariant Engine"
run_test "004-os-cli-backing-surfaces.sh" "CLI Backing Surfaces"
run_test "005-os-cli-wrapper.sh"          "CLI Wrapper"

TOTAL=$((PASS + FAIL))

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Self-Test Suite Result"
echo "══════════════════════════════════════════════════════════════"
echo "  Passed: $PASS / $TOTAL"
echo "  Failed: $FAIL / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
  echo "  Failed tests:$FAILED_TESTS"
  exit 1
fi
echo ""
echo "All vendored OS self-tests PASS."
exit 0
