#!/usr/bin/env bash
# state-manager.sh — Engineering OS State Machine
#
# Governs per-feature lifecycle state for the Engineering OS pipeline.
# States: RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED →
#         EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED
#
# Commands:
#   get     <feature>         — print current state
#   require <feature> <state> — exit 2 if in registry and state ≠ expected
#   advance <feature> <state> — validate transition, write new state
#   reset   <feature>         — return feature to RECON_READY
#
# Features NOT in registry: require passes with warning (legacy features).
# advance auto-registers the feature starting from RECON_READY.

# Registry: prefer EOS_STATE_REGISTRY if set (from adapter config), else resolve relative to package root
if [ -n "$EOS_STATE_REGISTRY" ]; then
  case "$EOS_STATE_REGISTRY" in
    /*) REGISTRY="$EOS_STATE_REGISTRY" ;;
    *)  REGISTRY="$(pwd)/$EOS_STATE_REGISTRY" ;;
  esac
else
  REGISTRY="$(cd "$(dirname "$0")/.." && pwd)/ai/state_registry.json"
fi

# ── State transition table (bash 3 compatible, no associative arrays) ────────

next_state() {
  case "$1" in
    RECON_READY)             echo "SPEC_LOCKED" ;;
    SPEC_LOCKED)             echo "TASK_GRAPH_LOCKED" ;;
    TASK_GRAPH_LOCKED)       echo "EXECUTION_ACTIVE" ;;
    EXECUTION_ACTIVE)        echo "VERIFICATION_REQUIRED" ;;
    VERIFICATION_REQUIRED)   echo "RELEASE_APPROVED" ;;
    RELEASE_APPROVED)        echo "NONE" ;;
    *)                       echo "NONE" ;;
  esac
}

is_valid_state() {
  case "$1" in
    RECON_READY|SPEC_LOCKED|TASK_GRAPH_LOCKED|EXECUTION_ACTIVE|VERIFICATION_REQUIRED|RELEASE_APPROVED)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

# ── Registry helpers ─────────────────────────────────────────────────────────

ensure_registry() {
  if [ ! -f "$REGISTRY" ]; then
    echo "{}" > "$REGISTRY"
  fi
}

feature_in_registry() {
  local feature="$1"
  ensure_registry
  python3 -c "
import json, sys
d = json.load(open('$REGISTRY'))
sys.exit(0 if '$feature' in d else 1)
" 2>/dev/null
}

get_state() {
  local feature="$1"
  ensure_registry
  if ! feature_in_registry "$feature"; then
    echo "RECON_READY"
    return 0
  fi
  python3 -c "
import json
d = json.load(open('$REGISTRY'))
print(d.get('$feature', {}).get('state', 'RECON_READY'))
" 2>/dev/null || echo "RECON_READY"
}

write_state() {
  local feature="$1"
  local new_state="$2"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  ensure_registry
  python3 -c "
import json
with open('$REGISTRY', 'r') as f:
    d = json.load(f)
d['$feature'] = {'state': '$new_state', 'updated_at': '$timestamp'}
with open('$REGISTRY', 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
" 2>/dev/null
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_get() {
  local feature="$1"
  if [ -z "$feature" ]; then
    echo "Usage: state-manager.sh get <feature>" >&2
    exit 1
  fi
  get_state "$feature"
}

cmd_require() {
  local feature="$1"
  local expected="$2"
  if [ -z "$feature" ] || [ -z "$expected" ]; then
    echo "Usage: state-manager.sh require <feature> <state>" >&2
    exit 1
  fi
  if ! is_valid_state "$expected"; then
    echo "STATE ERROR: '$expected' is not a valid state." >&2
    exit 1
  fi
  if ! feature_in_registry "$feature"; then
    echo "STATE WARNING: '$feature' not in registry — legacy feature, require skipped" >&2
    return 0
  fi
  local current
  current=$(get_state "$feature")
  if [ "$current" != "$expected" ]; then
    echo "STATE ERROR: '$feature' is '$current', expected '$expected'" >&2
    echo "  Valid pipeline order: RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED" >&2
    exit 2
  fi
}

cmd_advance() {
  local feature="$1"
  local to_state="$2"
  if [ -z "$feature" ] || [ -z "$to_state" ]; then
    echo "Usage: state-manager.sh advance <feature> <state>" >&2
    exit 1
  fi
  if ! is_valid_state "$to_state"; then
    echo "STATE ERROR: '$to_state' is not a valid state." >&2
    exit 1
  fi
  # Auto-register at RECON_READY if not in registry
  if ! feature_in_registry "$feature"; then
    write_state "$feature" "RECON_READY"
  fi
  local current
  current=$(get_state "$feature")
  local valid_next
  valid_next=$(next_state "$current")
  if [ "$valid_next" != "$to_state" ]; then
    echo "STATE ERROR: Invalid transition for '$feature': $current → $to_state" >&2
    echo "  Expected next state: $valid_next" >&2
    echo "  Valid pipeline: RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED" >&2
    exit 2
  fi
  write_state "$feature" "$to_state"
  echo "State: $feature → $to_state"
}

cmd_reset() {
  local feature="$1"
  if [ -z "$feature" ]; then
    echo "Usage: state-manager.sh reset <feature>" >&2
    exit 1
  fi
  write_state "$feature" "RECON_READY"
  echo "State reset: $feature → RECON_READY"
}

# ── Dispatch ─────────────────────────────────────────────────────────────────

CMD="${1:-}"
shift 2>/dev/null || true

case "$CMD" in
  get)     cmd_get "$@" ;;
  require) cmd_require "$@" ;;
  advance) cmd_advance "$@" ;;
  reset)   cmd_reset "$@" ;;
  *)
    echo "Usage: state-manager.sh <get|require|advance|reset> <feature> [state]" >&2
    echo ""
    echo "States: RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED" >&2
    exit 1 ;;
esac
