#!/usr/bin/env bash
# generate-tasks.sh
#
# Deterministic task generation for the Engineering OS.
#
# This script implements the algorithm defined in ai/task-generator.md.
# It does not define architecture rules — it executes them.
#
# Every step below is traceable to a named step in ai/task-generator.md.
# If a rule changes, update ai/task-generator.md first, then this script.
#
# Architecture source:  ai/task-generator.md
# DAG rules source:     ai/task-graph.md
# Phase rules source:   ai/execution-loop-controller.md

set -e

SPEC=$1

# ── OS Execution Token Check ────────────────────────────────────────────────
# generate-tasks.sh must be invoked via compile-spec.sh, not directly.
# compile-spec.sh writes /tmp/.os-compile-token after approval validation.
OS_TOKEN="/tmp/.os-compile-token"
if [ ! -f "$OS_TOKEN" ]; then
  echo "ERROR: OS execution token not found."
  echo "  generate-tasks.sh must be invoked via compile-spec.sh."
  echo "  Run: bash scripts/compile-spec.sh <spec-file>"
  echo "  See: ai/spec-compiler.md Step 7"
  exit 1
fi
rm "$OS_TOKEN"

# ── State Machine: require SPEC_LOCKED ──────────────────────────────────────
if [ -f "scripts/state-manager.sh" ]; then
  _GT_FEATURE=$(basename "${1:-}" .md)
  bash scripts/state-manager.sh require "$_GT_FEATURE" SPEC_LOCKED || exit 2
fi

mkdir -p tasks

# ── Implements ai/task-generator.md Step 1 — Validate Spec Pre-Conditions ──

if [ -z "$SPEC" ]; then
  echo "Usage: generate-tasks <spec-file>"
  echo "Example: generate-tasks specs/my-feature.md"
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "ERROR: Spec file not found: $SPEC"
  exit 1
fi

STATUS=$(grep -A1 "^## Status" "$SPEC" | tail -1 | tr -d '[:space:]')
if [ "$STATUS" != "approved" ]; then
  echo "ERROR: Spec status is '$STATUS' — must be 'approved'."
  echo "Refer to: ai/task-generator.md Step 1"
  exit 1
fi

# ── Implements ai/task-generator.md Step 2 — Extract Phase Tag ─────────────

FEATURE=$(basename "$SPEC" .md)
PHASE=$(grep -A1 "^## Phase" "$SPEC" | tail -1 | tr -d '[:space:]')

if [ -z "$PHASE" ]; then
  echo "ERROR: Spec does not contain a ## Phase field."
  echo "Refer to: ai/task-generator.md Step 2"
  exit 1
fi

PHASE_FILE=$(grep -rl "^Phase: $PHASE" specs/phases/ 2>/dev/null | head -1)
if [ -z "$PHASE_FILE" ]; then
  echo "ERROR: Phase '$PHASE' has no matching file in specs/phases/."
  echo "Refer to: ai/task-generator.md Step 2"
  exit 1
fi

# ── Implements ai/task-generator.md Step 3 — Identify Required Layers ───────
#
# Rule (ai/task-generator.md Step 3):
#   ## Data Model Changes  non-empty and not "none"  →  database layer required
#   ## API Surface         non-empty and not "none"  →  backend layer required
#   ## Frontend Surface    non-empty and not "none"  →  frontend layer required
#   verification                                     →  always required

HAS_DATABASE=false
HAS_BACKEND=false
HAS_FRONTEND=false

DATA_MODEL_RAW=$(awk '
  /^## Data Model Changes/ { found=1; next }
  found && /^##[[:space:]]/ { exit }
  found { print }
' "$SPEC")

if echo "$DATA_MODEL_RAW" | grep -iq '^none$'; then
  DATA_MODEL=""
else
  DATA_MODEL=$(echo "$DATA_MODEL_RAW" | grep -v '^[[:space:]]*$' || true)
fi

API_SURFACE_RAW=$(awk '
  /^## API Surface/ { found=1; next }
  found && /^##[[:space:]]/ { exit }
  found { print }
' "$SPEC")

if echo "$API_SURFACE_RAW" | grep -iq '^none$'; then
  API_SURFACE=""
else
  API_SURFACE=$(echo "$API_SURFACE_RAW" | grep -v '^[[:space:]]*$' || true)
fi

FRONTEND_SURFACE_RAW=$(awk '
  /^## Frontend Surface/ { found=1; next }
  found && /^##[[:space:]]/ { exit }
  found { print }
' "$SPEC")

if echo "$FRONTEND_SURFACE_RAW" | grep -iq '^none$'; then
  FRONTEND_SURFACE=""
else
  FRONTEND_SURFACE=$(echo "$FRONTEND_SURFACE_RAW" | grep -v '^[[:space:]]*$' || true)
fi

[ -n "$DATA_MODEL" ]       && HAS_DATABASE=true
[ -n "$API_SURFACE" ]      && HAS_BACKEND=true
[ -n "$FRONTEND_SURFACE" ] && HAS_FRONTEND=true

# ── Implements ai/task-generator.md Step 4 — Assign Task Numbers ────────────
#
# Rule (ai/task-generator.md Step 4):
#   Canonical order: database → backend → frontend → verification
#   Skipped layers do not consume a number slot.
#   verification is always last.

LAYERS=""
N=0

$HAS_DATABASE && { N=$((N + 1)); LAYERS="$LAYERS database"; }
$HAS_BACKEND  && { N=$((N + 1)); LAYERS="$LAYERS backend"; }
$HAS_FRONTEND && { N=$((N + 1)); LAYERS="$LAYERS frontend"; }
N=$((N + 1))
LAYERS="$LAYERS verification"
TASK_COUNT=$N

# ── Implements ai/task-generator.md Step 5 — Build Dependency Graph ─────────
#
# Rule (ai/task-graph.md + ai/task-generator.md Step 5):
#   Root task:          Blocked By: none
#   Each subsequent:    Blocked By: immediate predecessor
#   Linear chain is always acyclic — satisfies no-circular-dependency rule.
#   Verification is the terminal node by construction.

K=0
PREV_NUM=""
TASK_ENTRIES=""

for LAYER in $LAYERS; do
  K=$((K + 1))
  NUM=$(printf "%03d" $K)
  FILE="tasks/${FEATURE}-${NUM}.md"
  if [ -z "$PREV_NUM" ]; then
    BLOCKED="none"
  else
    BLOCKED="tasks/${FEATURE}-${PREV_NUM}.md"
  fi
  TASK_ENTRIES="${TASK_ENTRIES}${NUM}|${LAYER}|${FILE}|${BLOCKED} "
  PREV_NUM="$NUM"
done

# ── Implements ai/task-generator.md Step 6 — Generate Task Files ─────────────
#
# Rule (ai/task-generator.md Step 6):
#   One file per layer at tasks/<feature>-NNN.md
#   Phase propagation rule: task ## Phase must equal spec ## Phase exactly.
#   Status at generation: pending (never in-progress or done).
#   Content placeholders: description, acceptance criteria, files likely affected
#   require AI reasoning from the spec — agent fills these in per task-generator.md.

echo "Generating task files..."
echo ""

for ENTRY in $TASK_ENTRIES; do
  NUM=$(echo   "$ENTRY" | cut -d'|' -f1)
  LAYER=$(echo "$ENTRY" | cut -d'|' -f2)
  FILE=$(echo  "$ENTRY" | cut -d'|' -f3)
  BLOCKED=$(echo "$ENTRY" | cut -d'|' -f4)

  if [ -f "$FILE" ]; then
    echo "  SKIP  $FILE (already exists)"
    continue
  fi

  if [ "$BLOCKED" = "none" ]; then
    BLOCKED_FIELD="- none"
  else
    BLOCKED_FIELD="- $BLOCKED"
  fi

  cat > "$FILE" << TASKEOF
# Task: [FILL: imperative title for this $LAYER task]

## Parent Spec
$SPEC

## Phase
$PHASE

## Status
pending

## Layer
$LAYER

## Description
[FILL: precise description derived from $SPEC.
Read the spec section relevant to the $LAYER layer.
Follow ai/task-generator.md Layer Content Reference.
Pattern guide: ai/coding-patterns.md]

## Acceptance Criteria
- [ ] [FILL: concrete, verifiable condition]
- [ ] [FILL: concrete, verifiable condition]

## Files Likely Affected
- [FILL: paths derived from $SPEC and ai/coding-patterns.md]

## Blocked By
$BLOCKED_FIELD
TASKEOF

  echo "  WROTE $FILE"
done

# ── State Machine: advance to TASK_GRAPH_LOCKED ─────────────────────────────
if [ -f "scripts/state-manager.sh" ]; then
  bash scripts/state-manager.sh advance "$FEATURE" TASK_GRAPH_LOCKED
fi

echo ""

# ── Implements ai/task-generator.md Step 7 — Emit Task Graph Summary ─────────

echo "Task Graph: $FEATURE"
echo "Phase: $PHASE"
echo "Tasks generated: $TASK_COUNT"
echo ""

for ENTRY in $TASK_ENTRIES; do
  NUM=$(echo   "$ENTRY" | cut -d'|' -f1)
  LAYER=$(echo "$ENTRY" | cut -d'|' -f2)
  BLOCKED=$(echo "$ENTRY" | cut -d'|' -f4)
  printf "  %s  [%-12s]  blocked by: %s\n" "$NUM" "$LAYER" "$BLOCKED"
done

echo ""
echo "Phase propagation: task ## Phase = $PHASE (matches spec)"
echo "Graph validation:  linear chain — acyclic, verification is terminal"
echo ""
echo "Agent instruction: fill task content per ai/task-generator.md Steps 3-7."
echo "  Read $SPEC for each task layer. Apply ai/coding-patterns.md."
