#!/usr/bin/env bash
# invariant-engine.sh — Engineering OS Generic Invariant Runner
#
# Discover-and-dispatch invariant engine. Reads project-specific invariant
# rules from $EOS_INVARIANTS_DIR (declared in adapter.config.sh) and runs
# each rule's check() function.
#
# Usage:
#   bash invariant-engine.sh                       # run all invariants
#   bash invariant-engine.sh --only INV-003        # run a single invariant
#   bash invariant-engine.sh --config <path>       # explicit adapter config
#
# Configuration resolution (first match wins):
#   1. $EOS_CONFIG environment variable
#   2. --config <path> argument
#   3. ./.engineering-os/adapter.config.sh
#
# Adapter config must export:
#   EOS_INVARIANTS_DIR   path to dir containing invariant rule files (*.sh)
#
# Each rule file must define:
#   EOS_INV_ID        e.g. "INV-001"
#   EOS_INV_NAME      short human-readable name
#   check()           function returning 0 (pass) or non-zero (fail)
#
# Exit codes:
#   0 — all checks pass
#   1 — configuration error (no config / invariants dir missing)
#   2 — one or more invariant violations detected

set -e

# ── Argument parsing ─────────────────────────────────────────────────────────

ONLY_ID=""
CONFIG_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --only)
      shift
      ONLY_ID="${1:-}"
      [ -z "$ONLY_ID" ] && { echo "ERROR: --only requires an invariant ID" >&2; exit 1; }
      shift
      ;;
    --config)
      shift
      CONFIG_PATH="${1:-}"
      [ -z "$CONFIG_PATH" ] && { echo "ERROR: --config requires a path" >&2; exit 1; }
      shift
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      echo "Usage: invariant-engine.sh [--only <ID>] [--config <path>]" >&2
      exit 1
      ;;
  esac
done

# ── Adapter config resolution ────────────────────────────────────────────────

if [ -n "$EOS_CONFIG" ]; then
  RESOLVED_CONFIG="$EOS_CONFIG"
elif [ -n "$CONFIG_PATH" ]; then
  RESOLVED_CONFIG="$CONFIG_PATH"
elif [ -f ".engineering-os/adapter.config.sh" ]; then
  RESOLVED_CONFIG=".engineering-os/adapter.config.sh"
else
  echo "ERROR: no adapter config found." >&2
  echo "  Set EOS_CONFIG, pass --config <path>, or create ./.engineering-os/adapter.config.sh" >&2
  exit 1
fi

if [ ! -f "$RESOLVED_CONFIG" ]; then
  echo "ERROR: adapter config not found at: $RESOLVED_CONFIG" >&2
  exit 1
fi

# shellcheck disable=SC1090
. "$RESOLVED_CONFIG"

if [ -z "${EOS_INVARIANTS_DIR:-}" ]; then
  echo "ERROR: adapter config did not export EOS_INVARIANTS_DIR" >&2
  echo "  Config: $RESOLVED_CONFIG" >&2
  exit 1
fi

if [ ! -d "$EOS_INVARIANTS_DIR" ]; then
  echo "ERROR: invariants directory does not exist: $EOS_INVARIANTS_DIR" >&2
  exit 1
fi

# ── Discover rule files ──────────────────────────────────────────────────────

RULE_FILES=$(ls "$EOS_INVARIANTS_DIR"/*.sh 2>/dev/null | sort)

if [ -z "$RULE_FILES" ]; then
  echo "ERROR: no *.sh rule files found in $EOS_INVARIANTS_DIR" >&2
  exit 1
fi

# ── Run rules ────────────────────────────────────────────────────────────────

echo "Invariant Check Engine"
echo "══════════════════════════════════════"
[ -n "$ONLY_ID" ] && echo "(single-invariant mode: $ONLY_ID)" && echo ""

PASS=0
FAIL=0
TOTAL_RUN=0

for rule_file in $RULE_FILES; do
  # Subshell isolates variables and check() function across rule files.
  RESULT_LINE=$(
    # shellcheck disable=SC1090
    . "$rule_file"

    if [ -z "${EOS_INV_ID:-}" ] || [ -z "${EOS_INV_NAME:-}" ]; then
      echo "FAIL_META|UNKNOWN|rule file missing EOS_INV_ID or EOS_INV_NAME: $rule_file"
      exit 0
    fi

    if ! type check > /dev/null 2>&1; then
      echo "FAIL_META|$EOS_INV_ID|rule file missing check() function: $rule_file"
      exit 0
    fi

    if [ -n "$ONLY_ID" ] && [ "$EOS_INV_ID" != "$ONLY_ID" ]; then
      echo "SKIP|$EOS_INV_ID|"
      exit 0
    fi

    if check > /dev/null 2>&1; then
      echo "PASS|$EOS_INV_ID|$EOS_INV_NAME"
    else
      FAIL_REASON="${EOS_INV_FAIL_MSG:-$EOS_INV_NAME}"
      echo "FAIL|$EOS_INV_ID|$FAIL_REASON"
    fi
  )

  STATUS=$(echo "$RESULT_LINE" | cut -d'|' -f1)
  RID=$(echo    "$RESULT_LINE" | cut -d'|' -f2)
  RMSG=$(echo   "$RESULT_LINE" | cut -d'|' -f3-)

  case "$STATUS" in
    PASS)
      echo "  $RID: PASS — $RMSG"
      PASS=$((PASS + 1))
      TOTAL_RUN=$((TOTAL_RUN + 1))
      ;;
    FAIL)
      echo "  $RID: FAIL — $RMSG"
      FAIL=$((FAIL + 1))
      TOTAL_RUN=$((TOTAL_RUN + 1))
      ;;
    FAIL_META)
      echo "  $RID: FAIL — $RMSG"
      FAIL=$((FAIL + 1))
      TOTAL_RUN=$((TOTAL_RUN + 1))
      ;;
    SKIP)
      :  # skipped by --only filter
      ;;
    *)
      echo "  ?: ERROR — unparseable result for $rule_file: $RESULT_LINE" >&2
      FAIL=$((FAIL + 1))
      TOTAL_RUN=$((TOTAL_RUN + 1))
      ;;
  esac
done

# ── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "══════════════════════════════════════"
if [ -n "$ONLY_ID" ]; then
  echo "Result: $PASS/$TOTAL_RUN PASS ($ONLY_ID)"
else
  TOTAL_RULES=$(echo "$RULE_FILES" | wc -l | tr -d ' ')
  echo "Result: $PASS/$TOTAL_RULES PASS"
fi

if [ "$FAIL" -gt 0 ]; then
  exit 2
fi
exit 0
