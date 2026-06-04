#!/usr/bin/env bash
# os-boot-check.sh — Engineering OS boot validation
#
# Context detection (control-plane based, not filesystem-shape based):
#   Adapter:  .engineering-os/adapter.config.sh present (takes priority)
#   OS core:  core-docs/ directory present
#   Unknown:  neither — exits 1
#
# Exit codes:
#   0 — READY: all checks passed
#   1 — BLOCKED: one or more checks failed

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

# Invariant engine is co-located with this script regardless of deployment
# (OS core: scripts/  |  adapter: vendor/engineering-os/scripts/)
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Engineering OS Boot Check"
echo "══════════════════════════════════════"

# ── Context detection ─────────────────────────────────────────────────────
# Adapter config takes absolute priority — an adapter project that also has
# a scripts/ dir must not be misclassified as OS core.

if [ -f ".engineering-os/adapter.config.sh" ]; then
  CONTEXT="adapter"
elif [ -d "core-docs" ]; then
  CONTEXT="os-core"
else
  echo ""
  echo "  FAIL  Invalid OS context — no adapter config or OS core detected"
  echo ""
  echo "Status: BLOCKED"
  exit 1
fi

echo ""
echo "Context: $CONTEXT"
echo ""

# ── Adapter context validation ────────────────────────────────────────────

if [ "$CONTEXT" = "adapter" ]; then

  ADAPTER_CONFIG=".engineering-os/adapter.config.sh"
  ADAPTER_CONFIG_SOURCED=false

  echo "V1. Adapter config"
  # shellcheck disable=SC1090
  if . "$ADAPTER_CONFIG" 2>/tmp/.os-boot-src-err; then
    pass "V1: $ADAPTER_CONFIG sources successfully"
    ADAPTER_CONFIG_SOURCED=true
  else
    fail "V1: $ADAPTER_CONFIG failed to source — $(cat /tmp/.os-boot-src-err)"
  fi

  echo ""
  echo "V2. EOS_INVARIANTS_DIR"
  EOS_INV_DIR_VALID=false
  if [ "$ADAPTER_CONFIG_SOURCED" = true ]; then
    if [ -n "${EOS_INVARIANTS_DIR:-}" ]; then
      pass "V2: EOS_INVARIANTS_DIR exported ($EOS_INVARIANTS_DIR)"
      if [ -d "$EOS_INVARIANTS_DIR" ]; then
        pass "V2: EOS_INVARIANTS_DIR path exists"
        EOS_INV_DIR_VALID=true
      else
        fail "V2: EOS_INVARIANTS_DIR path does not exist: $EOS_INVARIANTS_DIR"
      fi
    else
      fail "V2: EOS_INVARIANTS_DIR not exported by adapter config"
    fi
  else
    fail "V2: EOS_INVARIANTS_DIR check skipped — adapter config failed to source"
  fi

  echo ""
  echo "V3. Invariant engine"
  INV_ENGINE="$SELF_DIR/invariant-engine.sh"
  if [ ! -f "$INV_ENGINE" ]; then
    fail "V3: invariant-engine.sh not found at $INV_ENGINE"
  elif [ "$ADAPTER_CONFIG_SOURCED" = true ] && [ "$EOS_INV_DIR_VALID" = true ]; then
    if bash "$INV_ENGINE" --config "$ADAPTER_CONFIG" > /tmp/.os-boot-inv-out 2>&1; then
      pass "V3: invariant engine — all invariants pass"
    else
      INV_EXIT=$?
      if [ "$INV_EXIT" -eq 2 ]; then
        fail "V3: invariant engine exits 2 — violation(s) detected"
      else
        fail "V3: invariant engine exits $INV_EXIT — config or execution error"
      fi
      grep -E "FAIL|ERROR" /tmp/.os-boot-inv-out | sed 's/^/      /' || true
    fi
  else
    pass "V3: invariant engine check skipped — adapter config or EOS_INVARIANTS_DIR invalid"
  fi

# ── OS core context validation ────────────────────────────────────────────

elif [ "$CONTEXT" = "os-core" ]; then

  echo "V1. Required OS scripts"
  REQUIRED_SCRIPTS="state-manager.sh invariant-engine.sh compile-spec.sh generate-tasks.sh execution-supervisor.sh"

  V1_OK=true
  for script in $REQUIRED_SCRIPTS; do
    if [ ! -f "scripts/$script" ]; then
      fail "V1: scripts/$script — not found"
      V1_OK=false
    elif [ ! -x "scripts/$script" ]; then
      fail "V1: scripts/$script — not executable"
      V1_OK=false
    fi
  done
  [ "$V1_OK" = true ] && pass "V1: all required scripts present and executable"

  echo ""
  echo "V2. Core directory structure"
  for dir in core-docs ai; do
    if [ -d "$dir" ]; then
      pass "V2: $dir/"
    else
      fail "V2: $dir/ — not found"
    fi
  done

fi

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Status: BLOCKED"
  exit 1
fi

echo "Status: READY"
exit 0
