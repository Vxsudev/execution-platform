#!/usr/bin/env bash
# 002-os-state-machine.sh — Vendored OS Self-Test
#
# Mirrors scripts/verification/280-os-state-machine-v1.sh, exercising the
# vendored state-manager.sh against a synthetic feature.
#
# IMPORTANT (Phase A limitation):
#   The vendored state-manager.sh resolves its registry path relative to
#   its own location: $(cd "$(dirname "$0")/.." && pwd)/ai/state_registry.json
#   When invoked from vendor/engineering-os/scripts/, that resolves to
#   vendor/engineering-os/ai/state_registry.json — a *separate* registry
#   from the live ai/state_registry.json.
#
#   For Phase A, this test exercises the vendored copy against its own
#   isolated registry (created on first write). The test feature name is
#   prefixed with __test_ and is reset on cleanup. The live registry is
#   never touched.
#
#   Full parameterization of registry path via adapter config is deferred
#   to the swap capability.

# Note: do NOT `set -e` — several sub-tests assert non-zero exits from
# state-manager.sh, which would abort the test script.

PASS=0
FAIL=0
TEST_FEATURE="__test_sm_$$"
VENDOR_REGISTRY_DIR="vendor/engineering-os/ai"
VENDOR_REGISTRY="$VENDOR_REGISTRY_DIR/state_registry.json"

# Ensure parent dir exists for the vendored registry — script's
# ensure_registry() only creates the file, not the dir.
mkdir -p "$VENDOR_REGISTRY_DIR"

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

cleanup() {
  bash vendor/engineering-os/scripts/state-manager.sh reset "$TEST_FEATURE" > /dev/null 2>&1 || true
  if [ -f "$VENDOR_REGISTRY" ]; then
    python3 -c "
import json
try:
    with open('$VENDOR_REGISTRY', 'r') as f:
        d = json.load(f)
    if '$TEST_FEATURE' in d:
        del d['$TEST_FEATURE']
    with open('$VENDOR_REGISTRY', 'w') as f:
        json.dump(d, f, indent=2)
        f.write('\n')
except Exception:
    pass
" 2>/dev/null || true
  fi
}
trap cleanup EXIT

echo "002 — Vendored OS State Machine Self-Test"
echo "══════════════════════════════════════════════════════════════"

# V1: registry-create-on-first-use works (file may not exist initially)
echo ""
echo "V1. Vendored state-manager.sh exists and is executable"
if [ -f vendor/engineering-os/scripts/state-manager.sh ] && [ -x vendor/engineering-os/scripts/state-manager.sh ]; then
  pass "V1: vendored state-manager.sh exists and executable"
else
  fail "V1: vendored state-manager.sh missing or not executable"
  exit 1
fi

# V2: get unknown feature returns RECON_READY
echo ""
echo "V2. get unknown feature returns RECON_READY"
RESULT=$(bash vendor/engineering-os/scripts/state-manager.sh get "$TEST_FEATURE" 2>&1)
if [ "$RESULT" = "RECON_READY" ]; then
  pass "V2: get unknown feature returns RECON_READY"
else
  fail "V2: expected RECON_READY, got '$RESULT'"
fi

# V3: advance valid transition succeeds
echo ""
echo "V3. advance RECON_READY → SPEC_LOCKED succeeds"
if bash vendor/engineering-os/scripts/state-manager.sh advance "$TEST_FEATURE" SPEC_LOCKED > /dev/null 2>&1; then
  pass "V3: advance to SPEC_LOCKED succeeded"
else
  fail "V3: advance to SPEC_LOCKED failed"
fi

# V4: state is now SPEC_LOCKED
echo ""
echo "V4. state is now SPEC_LOCKED after advance"
RESULT=$(bash vendor/engineering-os/scripts/state-manager.sh get "$TEST_FEATURE" 2>&1)
if [ "$RESULT" = "SPEC_LOCKED" ]; then
  pass "V4: state correctly persisted as SPEC_LOCKED"
else
  fail "V4: expected SPEC_LOCKED, got '$RESULT'"
fi

# V5: advance invalid transition (skip states) exits 2
echo ""
echo "V5. advance SPEC_LOCKED → EXECUTION_ACTIVE (skip TASK_GRAPH_LOCKED) exits 2"
RC=0
bash vendor/engineering-os/scripts/state-manager.sh advance "$TEST_FEATURE" EXECUTION_ACTIVE > /dev/null 2>&1 || RC=$?
if [ "$RC" = "2" ]; then
  pass "V5: skip-state advance exits 2 as expected"
else
  fail "V5: expected exit 2, got $RC"
fi

# V6: require correct state passes
echo ""
echo "V6. require SPEC_LOCKED on a feature in SPEC_LOCKED passes"
if bash vendor/engineering-os/scripts/state-manager.sh require "$TEST_FEATURE" SPEC_LOCKED > /dev/null 2>&1; then
  pass "V6: require correct state passes"
else
  fail "V6: require SPEC_LOCKED failed"
fi

# V7: require wrong state exits 2
echo ""
echo "V7. require EXECUTION_ACTIVE on a feature in SPEC_LOCKED exits 2"
RC=0
bash vendor/engineering-os/scripts/state-manager.sh require "$TEST_FEATURE" EXECUTION_ACTIVE > /dev/null 2>&1 || RC=$?
if [ "$RC" = "2" ]; then
  pass "V7: require-wrong-state exits 2"
else
  fail "V7: expected exit 2, got $RC"
fi

# V8: state_registry.json is valid JSON after writes
echo ""
echo "V8. vendored state_registry.json is valid JSON"
if [ -f "$VENDOR_REGISTRY" ] && python3 -c "import json; json.load(open('$VENDOR_REGISTRY'))" 2>/dev/null; then
  pass "V8: vendored registry is valid JSON"
else
  fail "V8: vendored registry malformed or missing"
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
