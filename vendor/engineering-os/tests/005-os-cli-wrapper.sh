#!/usr/bin/env bash
# 005-os-cli-wrapper.sh — CLI Wrapper Self-Test
#
# Asserts that scripts/raystrat-os routes all commands to their backing scripts,
# propagates exit codes, fails fast on invalid usage, and works in OS core
# context without an adapter config.
#
# Runs from OS core repo root or adapter project root.
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks fail

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "005 — CLI Wrapper Self-Test"
echo "══════════════════════════════════════════════════════════════"

# ── Context detection ─────────────────────────────────────────────────────

if [ -f "scripts/raystrat-os" ]; then
  CLI="scripts/raystrat-os"
  CONTEXT="os-core"
elif [ -f "vendor/engineering-os/scripts/raystrat-os" ]; then
  CLI="vendor/engineering-os/scripts/raystrat-os"
  CONTEXT="adapter"
else
  echo ""
  echo "  FAIL  Cannot locate raystrat-os"
  echo "        Searched: scripts/raystrat-os"
  echo "        Searched: vendor/engineering-os/scripts/raystrat-os"
  exit 1
fi

echo ""
echo "Context: $CONTEXT ($CLI)"

# ── V1: CLI file exists and is executable ────────────────────────────────

echo ""
echo "V1. CLI exists and is executable"

if [ -f "$CLI" ] && [ -x "$CLI" ]; then
  pass "V1: $CLI"
else
  fail "V1: $CLI — missing or not executable"
fi

# ── V2: Unknown command fails with exit 1 ────────────────────────────────

echo ""
echo "V2. Unknown command exits 1 with error message"

set +e
bash "$CLI" _unknown_xyz_ > /tmp/.005-unknown 2>&1
V2_EXIT=$?
set -e

if [ "$V2_EXIT" -eq 1 ]; then
  pass "V2: unknown command exits 1"
else
  fail "V2: unknown command exits $V2_EXIT (expected 1)"
fi

if grep -q "unknown command" /tmp/.005-unknown 2>/dev/null; then
  pass "V2: error message contains 'unknown command'"
else
  fail "V2: error message missing 'unknown command'"
fi

# ── V3: No-arg invocation exits 1 with usage text ────────────────────────

echo ""
echo "V3. No-arg invocation exits 1 with usage"

set +e
bash "$CLI" > /tmp/.005-noarg 2>&1
V3_EXIT=$?
set -e

if [ "$V3_EXIT" -eq 1 ]; then
  pass "V3: no-arg exits 1"
else
  fail "V3: no-arg exits $V3_EXIT (expected 1)"
fi

if grep -q "Usage:" /tmp/.005-noarg 2>/dev/null; then
  pass "V3: usage text printed"
else
  fail "V3: usage text not printed"
fi

# ── V4: Missing required args fail fast ──────────────────────────────────

echo ""
echo "V4. Missing required args fail fast (exit 1)"

for cmd in status compile exec intent; do
  set +e
  bash "$CLI" "$cmd" > /tmp/.005-req-"$cmd" 2>&1
  V4_EXIT=$?
  set -e

  if [ "$V4_EXIT" -eq 1 ]; then
    pass "V4: '$cmd' (no arg) exits 1"
  else
    fail "V4: '$cmd' (no arg) exits $V4_EXIT (expected 1)"
  fi
done

# ── V5: boot routes to os-boot-check.sh ──────────────────────────────────

echo ""
echo "V5. boot → scripts/os-boot-check.sh"

set +e
BOOT_OUT=$(bash "$CLI" boot 2>&1)
BOOT_EXIT=$?
set -e

if echo "$BOOT_OUT" | grep -q "Engineering OS Boot Check"; then
  pass "V5: boot output matches os-boot-check.sh header"
else
  fail "V5: boot output missing os-boot-check.sh header"
  echo "      got: $(echo "$BOOT_OUT" | head -2)"
fi

if [ "$BOOT_EXIT" -eq 0 ] || [ "$BOOT_EXIT" -eq 1 ]; then
  pass "V5: boot exits $BOOT_EXIT (valid range 0|1)"
else
  fail "V5: boot exits $BOOT_EXIT (expected 0 or 1)"
fi

# ── V6: check routes to os-adapter-check.sh ──────────────────────────────

echo ""
echo "V6. check → scripts/os-adapter-check.sh"

set +e
CHECK_OUT=$(bash "$CLI" check 2>&1)
CHECK_EXIT=$?
set -e

if echo "$CHECK_OUT" | grep -q "Engineering OS Adapter Check"; then
  pass "V6: check output matches os-adapter-check.sh header"
else
  fail "V6: check output missing os-adapter-check.sh header"
  echo "      got: $(echo "$CHECK_OUT" | head -2)"
fi

if [ "$CHECK_EXIT" -eq 0 ] || [ "$CHECK_EXIT" -eq 1 ]; then
  pass "V6: check exits $CHECK_EXIT (valid range 0|1)"
else
  fail "V6: check exits $CHECK_EXIT (expected 0 or 1)"
fi

# ── V7: verify routes to invariant-engine.sh ─────────────────────────────

echo ""
echo "V7. verify → scripts/invariant-engine.sh"

set +e
VERIFY_OUT=$(bash "$CLI" verify 2>&1)
VERIFY_EXIT=$?
set -e

if echo "$VERIFY_OUT" | grep -qE "Invariant Check Engine|no adapter config found"; then
  pass "V7: verify output matches invariant-engine.sh"
else
  fail "V7: verify output does not match invariant-engine.sh"
  echo "      got: $(echo "$VERIFY_OUT" | head -2)"
fi

if [ "$VERIFY_EXIT" -ge 0 ] && [ "$VERIFY_EXIT" -le 2 ]; then
  pass "V7: verify exits $VERIFY_EXIT (valid invariant-engine range 0|1|2)"
else
  fail "V7: verify exits $VERIFY_EXIT (expected 0, 1, or 2)"
fi

# ── V8: status routes to state-manager.sh get ────────────────────────────

echo ""
echo "V8. status → scripts/state-manager.sh get"

set +e
STATUS_OUT=$(bash "$CLI" status os-cli-v0 2>&1)
STATUS_EXIT=$?
set -e

if echo "$STATUS_OUT" | grep -qE "^(RECON_READY|SPEC_LOCKED|TASK_GRAPH_LOCKED|EXECUTION_ACTIVE|VERIFICATION_REQUIRED|RELEASE_APPROVED)$"; then
  pass "V8: status output is a valid OS state"
else
  fail "V8: status output is not a valid OS state: '$STATUS_OUT'"
fi

if [ "$STATUS_EXIT" -eq 0 ]; then
  pass "V8: status exits 0"
else
  fail "V8: status exits $STATUS_EXIT (expected 0)"
fi

# ── V9: state passes all args to state-manager.sh ────────────────────────

echo ""
echo "V9. state → scripts/state-manager.sh (full passthrough)"

set +e
STATE_OUT=$(bash "$CLI" state get os-cli-v0 2>&1)
STATE_EXIT=$?
set -e

if echo "$STATE_OUT" | grep -qE "^(RECON_READY|SPEC_LOCKED|TASK_GRAPH_LOCKED|EXECUTION_ACTIVE|VERIFICATION_REQUIRED|RELEASE_APPROVED)$"; then
  pass "V9: state get output is a valid OS state"
else
  fail "V9: state get output is not a valid OS state: '$STATE_OUT'"
fi

if [ "$STATE_EXIT" -eq 0 ]; then
  pass "V9: state exits 0"
else
  fail "V9: state exits $STATE_EXIT (expected 0)"
fi

# ── V10: Routing table completeness via source inspection ─────────────────

echo ""
echo "V10. All 9 backing scripts referenced in CLI source"

for target in os-boot-check.sh os-adapter-check.sh invariant-engine.sh \
              state-manager.sh compile-spec.sh execution-supervisor.sh \
              run-full-regression.sh os-self-test.sh os-intent-entry.sh; do
  if grep -q "$target" "$CLI"; then
    pass "V10: CLI routes to $target"
  else
    fail "V10: CLI does not reference $target"
  fi
done

# ── V11: No adapter config in OS core does not break boot or status ────────

echo ""
echo "V11. OS core context (no adapter config) does not break boot/status"

# boot must succeed (READY) in OS core when scripts are intact
set +e
BOOT_CORE=$(bash "$CLI" boot 2>&1)
BOOT_CORE_EXIT=$?
set -e

if [ "$BOOT_CORE_EXIT" -eq 0 ]; then
  pass "V11: boot exits 0 in OS core (no adapter config)"
else
  fail "V11: boot exits $BOOT_CORE_EXIT in OS core (expected 0)"
fi

# status must succeed for any registered feature
set +e
STATUS_CORE=$(bash "$CLI" status os-cli-v0 2>&1)
STATUS_CORE_EXIT=$?
set -e

if [ "$STATUS_CORE_EXIT" -eq 0 ]; then
  pass "V11: status exits 0 without adapter config"
else
  fail "V11: status exits $STATUS_CORE_EXIT without adapter config (expected 0)"
fi

# ── V12: Symlink invocation resolves to OS repo, not symlink dir ──────────

echo ""
echo "V12. Symlink invocation: ~/bin/raystrat-os → scripts/raystrat-os"

SYMLINK_TARGET="$HOME/bin/raystrat-os"
SYMLINK_CREATED=0

# Resolve absolute path to CLI for symlinking
CLI_ABS="$(cd "$(dirname "$CLI")" && pwd)/$(basename "$CLI")"

# Create ~/bin if needed; skip V12 if we can't write there
if mkdir -p "$HOME/bin" 2>/dev/null; then
  ln -sf "$CLI_ABS" "$SYMLINK_TARGET" 2>/dev/null && SYMLINK_CREATED=1
fi

if [ "$SYMLINK_CREATED" -eq 1 ]; then
  # Boot via symlink — must find OS scripts in OS repo, not ~/bin
  set +e
  SYM_BOOT=$(bash "$SYMLINK_TARGET" boot 2>&1)
  SYM_BOOT_EXIT=$?
  set -e

  if echo "$SYM_BOOT" | grep -q "Engineering OS Boot Check"; then
    pass "V12: boot via symlink produces boot-check header"
  else
    fail "V12: boot via symlink missing boot-check header"
    echo "      got: $(echo "$SYM_BOOT" | head -2)"
  fi

  if [ "$SYM_BOOT_EXIT" -eq 0 ] || [ "$SYM_BOOT_EXIT" -eq 1 ]; then
    pass "V12: boot via symlink exits $SYM_BOOT_EXIT (valid range 0|1)"
  else
    fail "V12: boot via symlink exits $SYM_BOOT_EXIT (expected 0 or 1)"
  fi

  # Status via symlink — must reach state-manager.sh in OS repo
  set +e
  SYM_STATUS=$(bash "$SYMLINK_TARGET" status os-cli-v0 2>&1)
  SYM_STATUS_EXIT=$?
  set -e

  if echo "$SYM_STATUS" | grep -qE "^(RECON_READY|SPEC_LOCKED|TASK_GRAPH_LOCKED|EXECUTION_ACTIVE|VERIFICATION_REQUIRED|RELEASE_APPROVED)$"; then
    pass "V12: status via symlink returns valid OS state"
  else
    fail "V12: status via symlink returned: '$SYM_STATUS'"
  fi

  if [ "$SYM_STATUS_EXIT" -eq 0 ]; then
    pass "V12: status via symlink exits 0"
  else
    fail "V12: status via symlink exits $SYM_STATUS_EXIT (expected 0)"
  fi

  # Cleanup
  rm -f "$SYMLINK_TARGET"
else
  echo "  SKIP  V12: cannot create symlink at $SYMLINK_TARGET (skip, not fail)"
fi

# ── V13: intent creates spec + generates tasks (no exec assertion) ─────────
#
# Verifies the intent entry path up to and including task generation.
# Execution-supervisor (which requires claude) is allowed to fail —
# spec and task files are asserted to exist before that point.

echo ""
echo "V13. intent → spec created + tasks generated"

V13_INTENT="pipeline test"
V13_SLUG="pipeline-test"
V13_SPEC="specs/${V13_SLUG}.md"
V13_TASKS_PATTERN="tasks/${V13_SLUG}-*.md"

# Pre-clean any leftover from a prior run
rm -f "$V13_SPEC" $V13_TASKS_PATTERN 2>/dev/null || true
bash "scripts/state-manager.sh" reset "$V13_SLUG" > /dev/null 2>&1 || true

set +e
bash "$CLI" intent "$V13_INTENT" > /tmp/.005-intent 2>&1
V13_EXIT=$?
set -e

# Spec file must have been created (created before compile/exec)
if [ -f "$V13_SPEC" ]; then
  pass "V13: spec file created at $V13_SPEC"
else
  fail "V13: spec file not created at $V13_SPEC"
  echo "      intent output:"
  cat /tmp/.005-intent | head -10 | sed 's/^/        /'
fi

# Spec must contain approved status (created by intent handler)
if [ -f "$V13_SPEC" ] && grep -q "^approved$" "$V13_SPEC"; then
  pass "V13: spec status is approved"
else
  fail "V13: spec status not approved"
fi

# Task files must exist — proves compile + generate-tasks ran successfully
if ls $V13_TASKS_PATTERN > /dev/null 2>&1; then
  TASK_COUNT=$(ls $V13_TASKS_PATTERN 2>/dev/null | wc -l | tr -d ' ')
  pass "V13: $TASK_COUNT task file(s) generated"
else
  fail "V13: no task files generated — compile or generate-tasks failed"
  echo "      intent output:"
  cat /tmp/.005-intent | sed 's/^/        /'
fi

# Cleanup — reset state so registry doesn't accumulate test entries
rm -f "$V13_SPEC" $V13_TASKS_PATTERN 2>/dev/null || true
bash "scripts/state-manager.sh" reset "$V13_SLUG" > /dev/null 2>&1 || true

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
