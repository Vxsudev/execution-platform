#!/usr/bin/env bash
# 004-os-cli-backing-surfaces.sh — CLI Backing Surfaces Self-Test
#
# Asserts that all CLI V0 commands have real backing scripts, that
# boot/check/self-test exit only 0 or 1, that self-test routes correctly,
# and that os-cli-v0 spec maps every command to a real script.
#
# Runs correctly from OS core repo root or adapter project root.
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks fail

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "004 — CLI Backing Surfaces Self-Test"
echo "══════════════════════════════════════════════════════════════"

# ── Context detection ─────────────────────────────────────────────────────

if [ -f "scripts/os-boot-check.sh" ]; then
  SCRIPT_DIR="scripts"
  CONTEXT="os-core"
elif [ -f "vendor/engineering-os/scripts/os-boot-check.sh" ]; then
  SCRIPT_DIR="vendor/engineering-os/scripts"
  CONTEXT="adapter"
else
  echo ""
  echo "  FAIL  Cannot locate OS scripts."
  echo "        Run from OS core root or adapter project root."
  exit 1
fi

echo ""
echo "Context: $CONTEXT ($SCRIPT_DIR/)"

# ── V1: All CLI backing scripts exist and are executable ──────────────────

echo ""
echo "V1. CLI backing scripts present and executable"

CLI_BACKING_SCRIPTS="os-boot-check.sh os-adapter-check.sh os-self-test.sh invariant-engine.sh state-manager.sh compile-spec.sh execution-supervisor.sh run-full-regression.sh"

for script in $CLI_BACKING_SCRIPTS; do
  if [ -f "$SCRIPT_DIR/$script" ] && [ -x "$SCRIPT_DIR/$script" ]; then
    pass "V1: $SCRIPT_DIR/$script"
  else
    fail "V1: $SCRIPT_DIR/$script — missing or not executable"
  fi
done

# ── V2: os-boot-check exits only 0 or 1 ──────────────────────────────────

echo ""
echo "V2. os-boot-check.sh exits 0 or 1 (deterministic range)"

set +e
bash "$SCRIPT_DIR/os-boot-check.sh" > /tmp/.004-boot-out 2>&1
BOOT_EXIT=$?
set -e

if [ "$BOOT_EXIT" -eq 0 ] || [ "$BOOT_EXIT" -eq 1 ]; then
  pass "V2: os-boot-check exits $BOOT_EXIT (valid)"
else
  fail "V2: os-boot-check exits $BOOT_EXIT (expected 0 or 1 only)"
fi

# ── V3: os-adapter-check exits only 0 or 1 ───────────────────────────────

echo ""
echo "V3. os-adapter-check.sh exits 0 or 1 (deterministic range)"

set +e
bash "$SCRIPT_DIR/os-adapter-check.sh" > /tmp/.004-check-out 2>&1
CHECK_EXIT=$?
set -e

if [ "$CHECK_EXIT" -eq 0 ] || [ "$CHECK_EXIT" -eq 1 ]; then
  pass "V3: os-adapter-check exits $CHECK_EXIT (valid)"
else
  fail "V3: os-adapter-check exits $CHECK_EXIT (expected 0 or 1 only)"
fi

# ── V4: os-self-test routes to correct runner for detected context ─────────

echo ""
echo "V4. os-self-test.sh routes to correct runner"

if [ "$CONTEXT" = "adapter" ]; then
  EXPECTED_RUNNER="vendor/engineering-os/tests/run-self-tests.sh"
  EXPECTED_CONTEXT_LABEL="adapter"
else
  EXPECTED_RUNNER="tests/run-self-tests.sh"
  EXPECTED_CONTEXT_LABEL="os-core"
fi

if [ -f "$EXPECTED_RUNNER" ]; then
  set +e
  SELF_TEST_HEADER=$(bash "$SCRIPT_DIR/os-self-test.sh" 2>&1 | head -5)
  SELF_TEST_ROUTE_EXIT=$?
  set -e

  if echo "$SELF_TEST_HEADER" | grep -q "Context: $EXPECTED_CONTEXT_LABEL"; then
    pass "V4: os-self-test routes to $EXPECTED_CONTEXT_LABEL context"
  else
    fail "V4: os-self-test did not route to expected context ($EXPECTED_CONTEXT_LABEL)"
    echo "      Output header:"
    echo "$SELF_TEST_HEADER" | sed 's/^/        /'
  fi

  if echo "$SELF_TEST_HEADER" | grep -q "Runner:  $EXPECTED_RUNNER"; then
    pass "V4: os-self-test runner path correct ($EXPECTED_RUNNER)"
  else
    fail "V4: os-self-test runner path not as expected ($EXPECTED_RUNNER)"
  fi
else
  fail "V4: expected test runner not found: $EXPECTED_RUNNER"
fi

# ── V5: os-cli-v0 spec status is approved ────────────────────────────────

echo ""
echo "V5. os-cli-v0 spec is approved with real script mappings"

SPEC_PATH=""
if [ -f "ai/specs/os-cli-v0.md" ]; then
  SPEC_PATH="ai/specs/os-cli-v0.md"
elif [ -f "vendor/engineering-os/ai/specs/os-cli-v0.md" ]; then
  SPEC_PATH="vendor/engineering-os/ai/specs/os-cli-v0.md"
fi

if [ -z "$SPEC_PATH" ]; then
  fail "V5: ai/specs/os-cli-v0.md not found"
else
  pass "V5: spec found at $SPEC_PATH"

  STATUS=$(grep -A1 "^## Status" "$SPEC_PATH" | tail -1 | tr -d '[:space:]')
  if [ "$STATUS" = "approved" ]; then
    pass "V5: spec status is approved"
  else
    fail "V5: spec status is '$STATUS' (expected approved)"
  fi

  # V5b: Every CLI command maps to a real script (no prose-only mappings)
  for script in os-boot-check.sh os-adapter-check.sh os-self-test.sh \
                invariant-engine.sh state-manager.sh compile-spec.sh \
                execution-supervisor.sh run-full-regression.sh; do
    if grep -q "$script" "$SPEC_PATH"; then
      pass "V5: spec references real script: $script"
    else
      fail "V5: spec does not reference $script"
    fi
  done

  # V5c: No command maps to prose-only ("no backing script") in routing table
  if grep -q "no backing script" "$SPEC_PATH"; then
    fail "V5: spec routing table still contains prose-only mapping ('no backing script')"
  else
    pass "V5: routing table has no prose-only mappings"
  fi
fi

# ── V6: Adapter context simulation — no OS core checks, boot exits 0 ──────
#
# Creates a minimal .engineering-os/adapter.config.sh and EOS_INVARIANTS_DIR
# with a trivial passing invariant. Verifies:
#   - boot reports Context: adapter (not os-core)
#   - boot exits 0 (READY)
#   - OS core check patterns are absent from boot output

echo ""
echo "V6. Adapter context simulation — correct classification and no cross-context leakage"

SIM_ADAPTER_DIR="/tmp/.004-adapter-sim-$$"
SIM_CONFIG_DIR="$SIM_ADAPTER_DIR/.engineering-os"
SIM_INV_DIR="$SIM_ADAPTER_DIR/invariants"
SIM_LINK=".engineering-os"
SIM_CLEANUP=0

# Build simulation workspace
mkdir -p "$SIM_CONFIG_DIR" "$SIM_INV_DIR"

# Minimal invariant that always passes
cat > "$SIM_INV_DIR/INV-SIM.sh" <<'INVSIM'
EOS_INV_ID="INV-SIM"
EOS_INV_NAME="simulation pass"
check() { return 0; }
INVSIM
chmod +x "$SIM_INV_DIR/INV-SIM.sh"

# Adapter config exporting EOS_INVARIANTS_DIR
cat > "$SIM_CONFIG_DIR/adapter.config.sh" <<ADPCFG
export EOS_INVARIANTS_DIR="$SIM_INV_DIR"
export EOS_PROJECT_NAME="simulation"
ADPCFG

# Symlink .engineering-os into cwd so boot detects adapter context
if ln -sf "$SIM_CONFIG_DIR" "$SIM_LINK" 2>/dev/null; then
  SIM_CLEANUP=1

  set +e
  V6_BOOT_OUT=$(bash "$SCRIPT_DIR/os-boot-check.sh" 2>&1)
  V6_BOOT_EXIT=$?
  set -e

  # Context must be adapter
  if echo "$V6_BOOT_OUT" | grep -q "Context: adapter"; then
    pass "V6: boot reports Context: adapter"
  else
    fail "V6: boot did not report adapter context"
    echo "$V6_BOOT_OUT" | head -6 | sed 's/^/      /'
  fi

  # Must exit 0 (all adapter checks pass)
  if [ "$V6_BOOT_EXIT" -eq 0 ]; then
    pass "V6: boot exits 0 (READY) in adapter simulation"
  else
    fail "V6: boot exits $V6_BOOT_EXIT in adapter simulation (expected 0)"
    echo "$V6_BOOT_OUT" | grep "FAIL" | sed 's/^/      /'
  fi

  # OS core check patterns must be absent
  if echo "$V6_BOOT_OUT" | grep -qE "Required OS scripts|Core directory structure|V1: all required scripts"; then
    fail "V6: OS core check patterns found in adapter mode output"
  else
    pass "V6: no OS core check patterns in adapter mode output"
  fi

  # Cleanup
  rm -f "$SIM_LINK"
else
  echo "  SKIP  V6: cannot create symlink in cwd (skip, not fail)"
fi

rm -rf "$SIM_ADAPTER_DIR"

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
