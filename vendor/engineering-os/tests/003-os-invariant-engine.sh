#!/usr/bin/env bash
# 003-os-invariant-engine.sh — Vendored OS Self-Test
#
# Mirrors scripts/verification/281-invariant-engine-v1.sh, exercising the
# vendored invariant-engine.sh against the NDT adapter overlay.

# Note: do NOT `set -e` — V8 asserts a non-zero exit from the engine
# which would abort the script.

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "003 — Vendored OS Invariant Engine Self-Test"
echo "══════════════════════════════════════════════════════════════"

# V1: invariant-engine.sh exists and is executable
echo ""
echo "V1. invariant-engine.sh exists and is executable"
if [ -f vendor/engineering-os/scripts/invariant-engine.sh ] && [ -x vendor/engineering-os/scripts/invariant-engine.sh ]; then
  pass "V1: invariant-engine.sh exists and is executable"
else
  fail "V1: invariant-engine.sh missing or not executable"
  exit 1
fi

# V2: adapter overlay exists
echo ""
echo "V2. adapter overlay exists with config + invariants/"
if [ -f .engineering-os/adapter.config.sh ] && [ -d .engineering-os/invariants ]; then
  pass "V2: adapter overlay present"
else
  fail "V2: adapter overlay incomplete"
  exit 1
fi

# V3: 6 rule files present
echo ""
echo "V3. 6 INV-NNN-*.sh rule files present in adapter overlay"
RULE_COUNT=$(ls .engineering-os/invariants/INV-*.sh 2>/dev/null | wc -l | tr -d ' ')
if [ "$RULE_COUNT" = "6" ]; then
  pass "V3: 6 rule files present"
else
  fail "V3: expected 6 rule files, found $RULE_COUNT"
fi

# V4: engine exits 0 on full run against NDT adapter
echo ""
echo "V4. engine exits 0 on full run (all 6 PASS)"
if bash vendor/engineering-os/scripts/invariant-engine.sh > /tmp/.eos-engine-out 2>&1; then
  pass "V4: engine exits 0 on full run"
else
  fail "V4: engine failed full run"
  cat /tmp/.eos-engine-out
fi

# V5: engine output reports 6/6 PASS
echo ""
echo "V5. engine output reports '6/6 PASS'"
if grep -q "Result: 6/6 PASS" /tmp/.eos-engine-out 2>/dev/null; then
  pass "V5: 6/6 PASS reported"
else
  fail "V5: 6/6 PASS not reported"
fi

# V6: --only filter mode works
echo ""
echo "V6. --only INV-003 runs single invariant and exits 0"
if bash vendor/engineering-os/scripts/invariant-engine.sh --only INV-003 > /tmp/.eos-engine-only 2>&1; then
  if grep -q "Result: 1/1 PASS (INV-003)" /tmp/.eos-engine-only; then
    pass "V6: --only filter works"
  else
    fail "V6: --only output incorrect"
    cat /tmp/.eos-engine-only
  fi
else
  fail "V6: --only INV-003 failed"
fi

# V7: engine source contains zero NDT identifiers
echo ""
echo "V7. engine source has no NDT identifiers"
NDT_HITS=$(grep -E "ndt|audit_logs|raw_events|infra/env|frontend/src|backend/alembic" \
  vendor/engineering-os/scripts/invariant-engine.sh 2>/dev/null || true)
if [ -z "$NDT_HITS" ]; then
  pass "V7: engine source is NDT-free"
else
  fail "V7: NDT identifiers leaked into engine source"
  echo "$NDT_HITS"
fi

# V8: engine errors out cleanly when no config found
echo ""
echo "V8. engine errors when invoked from a dir with no adapter config"
TEMP_DIR=$(mktemp -d)
ENGINE_ABS="$(pwd)/vendor/engineering-os/scripts/invariant-engine.sh"
RC=0
( cd "$TEMP_DIR" && bash "$ENGINE_ABS" > /dev/null 2>&1 ) || RC=$?
rm -rf "$TEMP_DIR"
if [ "$RC" = "1" ]; then
  pass "V8: engine exits 1 when no config resolvable"
else
  fail "V8: expected exit 1, got $RC"
fi

# V9: live invariant-check.sh and vendored engine produce equivalent results
echo ""
echo "V9. vendored engine output matches live invariant-check.sh (modulo dynamic content)"
LIVE_RESULT=$(bash scripts/invariant-check.sh 2>&1 | grep -E "^Result:" | tr -d ' ')
VEND_RESULT=$(bash vendor/engineering-os/scripts/invariant-engine.sh 2>&1 | grep -E "^Result:" | tr -d ' ')
if [ "$LIVE_RESULT" = "$VEND_RESULT" ]; then
  pass "V9: live + vendored agree on Result line ($LIVE_RESULT)"
else
  fail "V9: live='$LIVE_RESULT' vendored='$VEND_RESULT'"
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
