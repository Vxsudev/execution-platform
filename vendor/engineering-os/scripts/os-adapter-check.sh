#!/usr/bin/env bash
# os-adapter-check.sh — Engineering OS adapter contract validation
#
# Validates that the adapter configuration satisfies the Engineering OS contract.
#
# Usage:
#   bash scripts/os-adapter-check.sh
#   bash scripts/os-adapter-check.sh --config <path>
#
# Default config path: .engineering-os/adapter.config.sh
#
# Exit codes:
#   0 — adapter config is valid
#   1 — invalid adapter: one or more contract requirements not met

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

# ── Argument parsing ──────────────────────────────────────────────────────

CONFIG_PATH=".engineering-os/adapter.config.sh"

while [ $# -gt 0 ]; do
  case "$1" in
    --config)
      shift
      CONFIG_PATH="${1:-}"
      [ -z "$CONFIG_PATH" ] && { echo "ERROR: --config requires a path" >&2; exit 1; }
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: os-adapter-check.sh [--config <path>]" >&2
      exit 1
      ;;
  esac
done

echo "Engineering OS Adapter Check"
echo "══════════════════════════════════════"
echo ""
echo "Config: $CONFIG_PATH"
echo ""

# ── V1: Config file exists ────────────────────────────────────────────────

echo "V1. Adapter config file exists"
if [ -f "$CONFIG_PATH" ]; then
  pass "V1: $CONFIG_PATH"
else
  fail "V1: $CONFIG_PATH — not found"
  echo ""
  echo "══════════════════════════════════════"
  echo "Result: $PASS PASS / $FAIL FAIL"
  echo "Status: invalid adapter"
  exit 1
fi

# ── V2: Config sources without error ─────────────────────────────────────

echo ""
echo "V2. Config sources cleanly"
# shellcheck disable=SC1090
if . "$CONFIG_PATH" 2>/tmp/.os-adapter-src-err; then
  pass "V2: config sources without error"
else
  fail "V2: config failed to source — $(cat /tmp/.os-adapter-src-err)"
  echo ""
  echo "══════════════════════════════════════"
  echo "Result: $PASS PASS / $FAIL FAIL"
  echo "Status: invalid adapter"
  exit 1
fi

# ── V3: EOS_INVARIANTS_DIR (hard required by invariant-engine.sh) ─────────

echo ""
echo "V3. EOS_INVARIANTS_DIR (required)"
if [ -n "${EOS_INVARIANTS_DIR:-}" ]; then
  pass "V3: EOS_INVARIANTS_DIR exported: $EOS_INVARIANTS_DIR"
  if [ -d "$EOS_INVARIANTS_DIR" ]; then
    pass "V3: EOS_INVARIANTS_DIR path exists"
    INV_COUNT=$(ls "$EOS_INVARIANTS_DIR"/*.sh 2>/dev/null | wc -l | tr -d ' ')
    if [ "$INV_COUNT" -gt 0 ]; then
      pass "V3: $INV_COUNT invariant rule file(s) found"
    else
      fail "V3: no *.sh rule files in $EOS_INVARIANTS_DIR"
    fi
  else
    fail "V3: EOS_INVARIANTS_DIR path does not exist: $EOS_INVARIANTS_DIR"
  fi
else
  fail "V3: EOS_INVARIANTS_DIR not exported — invariant-engine.sh will exit 1 without it"
fi

# ── V4: EOS_STATE_REGISTRY resolvable ────────────────────────────────────

echo ""
echo "V4. EOS_STATE_REGISTRY"
if [ -n "${EOS_STATE_REGISTRY:-}" ]; then
  pass "V4: EOS_STATE_REGISTRY declared: $EOS_STATE_REGISTRY"
  REGISTRY_DIR=$(dirname "$EOS_STATE_REGISTRY")
  if [ -d "$REGISTRY_DIR" ]; then
    pass "V4: registry parent directory exists: $REGISTRY_DIR"
  else
    fail "V4: registry parent directory does not exist: $REGISTRY_DIR"
  fi
else
  pass "V4: EOS_STATE_REGISTRY not declared — state-manager.sh uses package default"
fi

# ── V5: Optional directory declarations ──────────────────────────────────

echo ""
echo "V5. Optional EOS directory declarations"

for var in EOS_SPEC_DIR EOS_TASK_DIR EOS_VERIFICATION_DIR EOS_PHASE_DIR; do
  val=$(eval "echo \"\${${var}:-}\"")
  if [ -n "$val" ]; then
    if [ -d "$val" ]; then
      pass "V5: $var=$val (exists)"
    else
      pass "V5: $var=$val (declared — directory not yet created)"
    fi
  else
    pass "V5: $var not declared — OS scripts use defaults"
  fi
done

# ── V6: EOS_PROJECT_NAME ─────────────────────────────────────────────────

echo ""
echo "V6. EOS_PROJECT_NAME"
if [ -n "${EOS_PROJECT_NAME:-}" ]; then
  pass "V6: EOS_PROJECT_NAME: $EOS_PROJECT_NAME"
else
  fail "V6: EOS_PROJECT_NAME not declared — required for journal and pre-commit gate"
fi

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Status: invalid adapter"
  exit 1
fi

echo "Status: adapter valid"
exit 0
