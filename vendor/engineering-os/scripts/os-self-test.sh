#!/usr/bin/env bash
# os-self-test.sh — Engineering OS context-safe self-test runner
#
# Detects execution context and routes to the appropriate test entrypoint.
#
# Context detection (first match wins):
#   adapter project: vendor/engineering-os/tests/run-self-tests.sh exists
#   OS core repo:    tests/run-self-tests.sh exists
#
# Exit code propagated unchanged from the selected test runner.

set -e

echo "Engineering OS Self-Test"
echo "══════════════════════════════════════"

# ── Context detection ─────────────────────────────────────────────────────

if [ -f "vendor/engineering-os/tests/run-self-tests.sh" ]; then
  CONTEXT="adapter"
  TEST_RUNNER="vendor/engineering-os/tests/run-self-tests.sh"
elif [ -f "tests/run-self-tests.sh" ]; then
  CONTEXT="os-core"
  TEST_RUNNER="tests/run-self-tests.sh"
else
  echo ""
  echo "ERROR: cannot locate test runner."
  echo "  Searched: vendor/engineering-os/tests/run-self-tests.sh (adapter context)"
  echo "  Searched: tests/run-self-tests.sh (OS core context)"
  echo ""
  echo "Run from adapter project root or OS core repo root."
  exit 1
fi

echo ""
echo "Context: $CONTEXT"
echo "Runner:  $TEST_RUNNER"
echo ""

exec bash "$TEST_RUNNER"
