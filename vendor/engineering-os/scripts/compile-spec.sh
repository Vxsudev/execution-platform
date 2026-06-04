#!/usr/bin/env bash
# compile-spec.sh
#
# Enforcement entry point for the Engineering OS spec pipeline.
#
# This script enforces the spec compilation gate. It:
#   1. Validates the spec exists and is in approved status
#   2. Validates the phase tag against specs/phases/
#   3. Enforces state machine: requires RECON_READY, advances to SPEC_LOCKED
#   4. Writes the OS execution token (/tmp/.os-compile-token) — proof that
#      the approval gate was traversed; generate-tasks.sh requires this token
#   5. Delegates to scripts/generate-tasks.sh (which advances to TASK_GRAPH_LOCKED)
#
# Architecture rules:  ai/spec-compiler.md
# Task generation:     ai/task-generator.md
# DAG rules:           ai/task-graph.md
# Phase validation:    ai/execution-loop-controller.md
# State machine:       scripts/state-manager.sh + ai/state_registry.json

set -e

SPEC=$1

# ── Step 1: Validate spec argument ─────────────────────────────────────────

if [ -z "$SPEC" ]; then
  echo "Usage: compile-spec <spec-file>"
  echo "Example: compile-spec specs/my-feature.md"
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "ERROR: Spec file not found: $SPEC"
  exit 1
fi

echo "Compiling spec: $SPEC"
echo ""

# ── State Machine: require RECON_READY ─────────────────────────────────────
FEATURE=$(basename "$SPEC" .md)
if [ -f "scripts/state-manager.sh" ]; then
  bash scripts/state-manager.sh require "$FEATURE" RECON_READY || exit 2
fi

# ── Step 2: Validate spec status ───────────────────────────────────────────

STATUS=$(grep -A1 "^## Status" "$SPEC" | tail -1 | tr -d '[:space:]')

if [ "$STATUS" != "approved" ]; then
  echo "ERROR: Spec status is '$STATUS' — must be 'approved' before tasks can be generated."
  echo "Refer to: ai/spec-compiler.md (Step 6 — Spec Approval)"
  exit 1
fi

echo "[1/3] Spec status: approved"

# ── Step 3: Validate phase tag ─────────────────────────────────────────────

PHASE=$(grep -A1 "^## Phase" "$SPEC" | tail -1 | tr -d '[:space:]')

if [ -z "$PHASE" ]; then
  echo "ERROR: Spec does not contain a ## Phase field."
  echo "Refer to: ai/task-generator.md (Step 2 — Extract Phase Tag)"
  exit 1
fi

PHASE_FILE=$(grep -rl "^Phase: $PHASE" specs/phases/ 2>/dev/null | head -1)

if [ -z "$PHASE_FILE" ]; then
  echo "ERROR: Phase '$PHASE' has no matching phase specification in specs/phases/."
  echo "Refer to: ai/execution-loop-controller.md (Phase Validation)"
  exit 1
fi

echo "[2/3] Phase tag: $PHASE (validated against $PHASE_FILE)"

# ── State Machine: advance to SPEC_LOCKED ──────────────────────────────────
if [ -f "scripts/state-manager.sh" ]; then
  bash scripts/state-manager.sh advance "$FEATURE" SPEC_LOCKED
fi

# ── OS Execution Token ──────────────────────────────────────────────────────
# Proof that compile-spec approval gate was traversed.
# generate-tasks.sh requires this token; direct invocation without it fails.
echo "${SPEC}:$(date +%s)" > /tmp/.os-compile-token

# ── Step 4: Delegate to task generator ─────────────────────────────────────

echo "[3/3] Delegating to task generator..."
echo ""

bash scripts/generate-tasks.sh "$SPEC"
