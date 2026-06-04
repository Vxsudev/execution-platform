#!/usr/bin/env bash
# execution-supervisor.sh
#
# Execution Supervisor for the Engineering OS.
#
# This script turns the engineering OS into a self-running system.
# It detects the next pending task, validates dependencies, transitions
# task status, and advances the task lifecycle.
#
# This script is runtime infrastructure only. It does NOT define architecture
# rules. All rules are sourced from:
#
#   Task lifecycle:     ai/execution-orchestrator.md
#   Dependency model:   ai/task-graph.md
#   Verification:       ai/verification-playbook.md
#   Outer loop:         ai/execution-loop-controller.md
#
# Usage:
#   scripts/execution-supervisor.sh <feature>
#
# Example:
#   scripts/execution-supervisor.sh pipeline-test-fixture
#
# The supervisor locates all tasks matching tasks/<feature>-*.md
# and executes them in lifecycle order.

set -e

FEATURE=$1

if [ -z "$FEATURE" ]; then
  echo "Usage: execution-supervisor.sh <feature>"
  echo "Example: execution-supervisor.sh my-feature"
  exit 1
fi

# ── Locate task files ──────────────────────────────────────────────────────
# Implements ai/execution-orchestrator.md Step 1 — scan task graph

TASK_FILES=$(ls tasks/${FEATURE}-*.md 2>/dev/null | sort)

if [ -z "$TASK_FILES" ]; then
  echo "ERROR: No task files found matching: tasks/${FEATURE}-*.md"
  exit 1
fi

TASK_COUNT=$(echo "$TASK_FILES" | wc -l | tr -d ' ')
echo "Execution Supervisor"
echo "══════════════════════════════════════"
echo "  Feature:  $FEATURE"
echo "  Tasks:    $TASK_COUNT"
echo ""

# ── Helper: read a field from a task file ──────────────────────────────────
# Extracts the first non-empty line after a ## heading.

read_field() {
  local file="$1"
  local field="$2"
  grep -A1 "^## $field" "$file" | tail -1 | tr -d '[:space:]'
}

# ── Helper: read Blocked By entries from a task file ───────────────────────
# Returns one task path per line, or "none".

read_blocked_by() {
  local file="$1"
  awk '/^## Blocked By/{found=1; next} found && /^## /{exit} found && /^- /{print}' "$file" \
    | sed 's/^- //' | tr -d '[:space:]'
}

# ── Helper: update Status field in a task file ─────────────────────────────
# Implements ai/execution-orchestrator.md Steps 3 and 6.

update_status() {
  local file="$1"
  local old_status="$2"
  local new_status="$3"

  if [ "$(uname)" = "Darwin" ]; then
    sed -i '' "s/^## Status\n${old_status}/## Status\n${new_status}/" "$file" 2>/dev/null || true
    # sed multiline is unreliable — use awk for robustness
    awk -v old="$old_status" -v new="$new_status" '
      /^## Status$/ { print; getline; if ($0 == old) print new; else print; next }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  else
    awk -v old="$old_status" -v new="$new_status" '
      /^## Status$/ { print; getline; if ($0 == old) print new; else print; next }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
}

# ── Helper: check if all blockers are done ─────────────────────────────────
# Implements ai/execution-orchestrator.md Step 2 — verify dependencies.

blockers_satisfied() {
  local file="$1"
  local blocked_by
  blocked_by=$(read_blocked_by "$file")

  # "none" means no blockers
  if [ "$blocked_by" = "none" ]; then
    return 0
  fi

  # Check each blocker
  echo "$blocked_by" | while IFS= read -r blocker; do
    [ -z "$blocker" ] && continue
    if [ ! -f "$blocker" ]; then
      echo "  ERROR: Blocker file not found: $blocker"
      return 1
    fi
    local blocker_status
    blocker_status=$(read_field "$blocker" "Status")
    if [ "$blocker_status" != "done" ]; then
      return 1
    fi
  done
}

# ── Helper: detect circular dependencies ───────────────────────────────────
# Implements ai/task-graph.md — circular dependency detection.

check_circular_deps() {
  local visited=""
  for task_file in $TASK_FILES; do
    local current="$task_file"
    local chain="$current"
    while true; do
      local blocked_by
      blocked_by=$(read_blocked_by "$current")
      [ "$blocked_by" = "none" ] && break
      [ -z "$blocked_by" ] && break

      # Check if we've seen this in the current chain
      if echo "$chain" | grep -qF "$blocked_by"; then
        echo "  ERROR: Circular dependency detected!"
        echo "  Chain: $chain → $blocked_by"
        return 1
      fi
      chain="$chain → $blocked_by"
      current="$blocked_by"
    done
  done
  return 0
}

# ── Helper: hash control-plane files ──────────────────────────────────────
# Returns a composite checksum of lifecycle-sensitive files.
# Used to detect unauthorised mutations by the worker.
#
# Control plane scope:
#   tasks/*.md              — task graph and lifecycle state
#   ai/engineering-journal.md — append-only execution record
#
# scripts/ is intentionally excluded: verification scripts may write
# logs and would cause false-positive guard triggers.

snapshot_control_plane() {
  if command -v md5sum >/dev/null 2>&1; then
    HASH="md5sum"
  else
    HASH="md5 -r"
  fi
  find tasks/*.md ai/engineering-journal.md -type f 2>/dev/null \
    | sort | xargs $HASH 2>/dev/null
}

# ── Helper: execute a task via Claude ─────────────────────────────────────
# Implements ai/execution-orchestrator.md Step 4 — Implement Task.
#
# Claude is a pure execution worker. It may only write to application source.
# Control-plane files (tasks/, ai/, scripts/) are off-limits.
#
# Guard:
#   1. Snapshot control plane hashes before execution.
#   2. Invoke Claude with worker-restricted prompt.
#   3. Re-snapshot control plane after execution.
#   4. If any control-plane file changed: abort, revert status, exit 1.

execute_task() {
  local task_file="$1"
  echo "  Invoking Claude to execute task..."
  echo "  Task: $task_file"
  echo ""

  # ── Control-plane snapshot (pre-execution) ────────────────────────────
  local snapshot_before
  snapshot_before=$(snapshot_control_plane)

  # ── Permission isolation: lock lifecycle files read-only ─────────────
  # Scope: only lifecycle files — tasks/*.md and engineering-journal.md.
  # Prevents accidental writes by the worker even if the prompt is ignored.
  # Permissions are restored AFTER integrity check, not before.
  chmod -w tasks/*.md                  2>/dev/null || true
  chmod -w ai/engineering-journal.md   2>/dev/null || true

  # ── Claude worker invocation ─────────────────────────────────────────
  # Prompt enforces worker-only scope. Supervisor retains exclusive
  # ownership of task lifecycle transitions and journal writes.

  claude --dangerously-skip-permissions -p "$(cat << EOF
You are a task execution worker for the Engineering OS.

You may modify application source code only.

You MUST NOT modify:

  tasks/
  scripts/
  ai/
  task status fields
  task graph files
  verification scripts
  engineering journal

Your job is to implement the task described in:

  $task_file

Follow:
  ai/execution-orchestrator.md
  ai/coding-patterns.md
  ai/runtime-contracts.md

When implementation is complete, exit.
EOF
)"
  local claude_exit=$?

  # ── Control-plane integrity check (post-execution) ────────────────────
  # Snapshot taken while files are still read-only.
  # Permissions restored ONLY after the check passes.
  local snapshot_after
  snapshot_after=$(snapshot_control_plane)

  if [ "$snapshot_before" != "$snapshot_after" ]; then
    # Violation: restore permissions so supervisor can revert state, then abort.
    chmod +w tasks/*.md                  2>/dev/null || true
    chmod +w ai/engineering-journal.md   2>/dev/null || true
    echo ""
    echo "  ERROR: Worker attempted to mutate control plane."
    echo "  Control-plane files changed during execution."
    echo ""
    diff <(echo "$snapshot_before") <(echo "$snapshot_after") \
      | grep '^[<>]' | sed 's/^< /  REMOVED: /;s/^> /  ADDED\/MODIFIED: /' || true
    echo ""
    return 2
  fi

  # ── Restore permissions ───────────────────────────────────────────────
  # Guard passed. Supervisor needs write access to advance lifecycle.
  chmod +w tasks/*.md                  2>/dev/null || true
  chmod +w ai/engineering-journal.md   2>/dev/null || true

  return $claude_exit
}

# ── Helper: read ## Verification Scripts from a spec file ─────────────────
# Implements ai/verification-playbook.md DELTA-ONLY mode.
#
# Reads the spec's "## Verification Scripts" block. Each entry is either a
# bare script filename (e.g. "155-verification-system-hardening.sh") or a
# full path under scripts/verification/. Returns one full path per line.
# Lines starting with "#" and blank lines are ignored.

read_spec_verification_scripts() {
  local spec_file="$1"
  [ -f "$spec_file" ] || { echo ""; return; }

  awk '
    /^## Verification Scripts/ { found=1; next }
    found && /^## / { exit }
    found { print }
  ' "$spec_file" \
    | sed 's/^- //' \
    | sed 's/`//g' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | grep -v '^#' \
    | grep -v '^$' \
    | grep -v '^(' \
    | awk '{
        s=$1
        if (s ~ /^scripts\//) print s
        else if (s ~ /\.sh$/)  print "scripts/verification/" s
      }'
}

# ── Helper: resolve delta-scoped verification scripts for a task ──────────
#
# Reads the task file's ## Parent Spec, then extracts ## Verification Scripts
# from that spec. If the spec does not declare a list, returns empty and the
# caller falls back to full-corpus mode.

resolve_delta_scripts() {
  local task_file="$1"
  local spec
  spec=$(grep -A1 "^## Parent Spec" "$task_file" 2>/dev/null | tail -1 \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$spec" ] || [ ! -f "$spec" ] && { echo ""; return; }

  local raw
  raw=$(read_spec_verification_scripts "$spec")
  [ -z "$raw" ] && { echo ""; return; }

  # Fail-closed: any declared path inside _legacy/ or _quarantine/ invalidates
  # the whole list (caller must see an empty result and surface the error).
  if echo "$raw" | grep -qE '/(_legacy|_quarantine)/'; then
    echo "  ERROR: spec-declared path resolves under _legacy/ or _quarantine/ — refusing" >&2
    echo "$raw" | grep -E '/(_legacy|_quarantine)/' | sed 's/^/    /' >&2
    echo ""
    return
  fi
  echo "$raw"
}

# ── Helper: list the full verification corpus (fallback) ──────────────────
#
# Excludes any script under scripts/verification/_legacy/ or
# scripts/verification/_quarantine/. Retired scripts (legacy) and isolated
# regression signals (quarantine) never participate in the gate.
# Also excludes run-full-regression.sh — invoked explicitly, not as a leaf.

list_full_corpus() {
  ls scripts/verification/*.sh 2>/dev/null \
    | grep -v '/_legacy/' \
    | grep -v '/_quarantine/' \
    | grep -v '/run-full-regression\.sh$' \
    | sort
}

# ── Helper: run per-task verification scripts ──────────────────────────────
# Implements ai/execution-orchestrator.md Step 5 — Verify Acceptance Criteria.
# Implements ai/verification-playbook.md DELTA-ONLY mode.
#
# Selection rule:
#   1. If parent spec declares ## Verification Scripts → DELTA MODE: explicit
#   2. Else → DELTA MODE: fallback (full corpus, minus _legacy/).
# Returns 0 if all selected scripts pass, 1 if any fail.

run_task_verification() {
  local task_file="$1"

  if [ ! -d "scripts/verification" ]; then
    echo "  Verification: no scripts/verification/ directory — skipping"
    return 0
  fi

  local vscripts mode
  vscripts=$(resolve_delta_scripts "$task_file")
  if [ -n "$vscripts" ]; then
    mode="explicit"
  else
    mode="fallback"
    vscripts=$(list_full_corpus)
  fi

  if [ -z "$vscripts" ]; then
    echo "  Verification: no scripts selected — skipping"
    return 0
  fi

  local script_count
  script_count=$(echo "$vscripts" | wc -l | tr -d ' ')
  echo "  DELTA MODE: $mode ($script_count script(s))"

  local all_pass=true
  while IFS= read -r vscript; do
    [ -z "$vscript" ] && continue
    if [ ! -f "$vscript" ]; then
      echo "    ✗ MISSING $vscript"
      all_pass=false
      continue
    fi
    echo "  Running: $vscript"
    if bash "$vscript" > /dev/null 2>&1; then
      echo "    ✓ PASS"
    else
      echo "    ✗ FAIL"
      all_pass=false
    fi
  done <<< "$vscripts"

  [ "$all_pass" = true ] && return 0 || return 1
}

# ── State Machine: require TASK_GRAPH_LOCKED ────────────────────────────────
if [ -f "scripts/state-manager.sh" ]; then
  bash scripts/state-manager.sh require "$FEATURE" TASK_GRAPH_LOCKED || exit 2
fi

# ── Invariant Gate: check before execution ──────────────────────────────────
if [ -f "scripts/invariant-check.sh" ]; then
  echo "Invariant Gate (pre-execution)..."
  if ! bash scripts/invariant-check.sh > /tmp/.invariant-pre-out 2>&1; then
    cat /tmp/.invariant-pre-out
    echo "FATAL: Invariant violation detected — cannot proceed with execution."
    echo "  Fix the invariant violations above and re-run."
    exit 1
  fi
  cat /tmp/.invariant-pre-out
  echo ""
fi

# ── Pre-flight: circular dependency check ──────────────────────────────────

echo "Pre-flight checks..."
if ! check_circular_deps; then
  echo "FATAL: Circular dependency detected. Cannot proceed."
  echo "Refer to: ai/task-graph.md — Circular Dependency Detection"
  exit 1
fi
echo "  ✓ No circular dependencies"

# Check for tasks stuck in in-progress
for task_file in $TASK_FILES; do
  status=$(read_field "$task_file" "Status")
  if [ "$status" = "in-progress" ]; then
    echo ""
    echo "  WARNING: Task stuck in in-progress: $task_file"
    echo "  Reverting to pending for re-execution."
    update_status "$task_file" "in-progress" "pending"
  fi
done

echo "  ✓ Pre-flight complete"

# ── State Machine: advance to EXECUTION_ACTIVE ──────────────────────────────
if [ -f "scripts/state-manager.sh" ]; then
  bash scripts/state-manager.sh advance "$FEATURE" EXECUTION_ACTIVE
fi

echo ""

# ── Execution Loop ─────────────────────────────────────────────────────────
# Implements ai/execution-orchestrator.md — Execution Lifecycle (Steps 1-7).
#
# Loop:
#   1. Find next eligible pending task
#   2. Verify dependencies
#   3. Set status → in-progress
#   4. Invoke Claude to execute task
#   5. Run verification scripts — revert to pending on failure
#   6. Set status → done (only after execution + verification pass)
#   7. Repeat until no pending tasks remain

EXECUTED=0
ITERATION=0
MAX_ITERATIONS=$((TASK_COUNT * 2))  # safety limit

while true; do
  ITERATION=$((ITERATION + 1))
  if [ "$ITERATION" -gt "$MAX_ITERATIONS" ]; then
    echo "FATAL: Max iterations reached ($MAX_ITERATIONS). Possible deadlock."
    exit 1
  fi

  # Count remaining pending tasks
  PENDING=0
  NEXT_TASK=""

  for task_file in $TASK_FILES; do
    status=$(read_field "$task_file" "Status")
    if [ "$status" = "pending" ]; then
      PENDING=$((PENDING + 1))
      # Check if this task is eligible (blockers satisfied)
      if [ -z "$NEXT_TASK" ] && blockers_satisfied "$task_file"; then
        NEXT_TASK="$task_file"
      fi
    fi
  done

  # Exit condition: no pending tasks remain
  if [ "$PENDING" -eq 0 ]; then
    echo "════════════════════════════════════════"
    echo "All tasks complete."
    break
  fi

  # Deadlock: pending tasks exist but none are eligible
  if [ -z "$NEXT_TASK" ]; then
    echo "FATAL: $PENDING task(s) remain pending but none are eligible."
    echo "Possible causes: unsatisfied dependencies or missing blocker files."
    echo ""
    for task_file in $TASK_FILES; do
      status=$(read_field "$task_file" "Status")
      if [ "$status" = "pending" ]; then
        blocked_by=$(read_blocked_by "$task_file")
        echo "  BLOCKED: $task_file (blocked by: $blocked_by)"
      fi
    done
    exit 1
  fi

  # ── Execute the selected task ────────────────────────────────────────────

  TASK_NUM=$(basename "$NEXT_TASK" .md | grep -o '[0-9]*$')
  TASK_LAYER=$(read_field "$NEXT_TASK" "Layer")
  EXECUTED=$((EXECUTED + 1))

  echo "────────────────────────────────────────"
  echo "Executing task $TASK_NUM [$TASK_LAYER]: $NEXT_TASK"
  echo "────────────────────────────────────────"

  # Step 3: Set status → in-progress
  # Implements ai/execution-orchestrator.md Step 3
  update_status "$NEXT_TASK" "pending" "in-progress"
  echo "  Status: pending → in-progress"

  # Step 4: Execute task via Claude
  # Implements ai/execution-orchestrator.md Step 4 — Implement Task
  execute_task "$NEXT_TASK" && EXEC_EXIT=0 || EXEC_EXIT=$?

  if [ "$EXEC_EXIT" -eq 2 ]; then
    echo "  ABORT: Control-plane mutation detected."
    echo "  Reverting status: in-progress → pending"
    update_status "$NEXT_TASK" "in-progress" "pending"
    echo "  Supervisor retains exclusive lifecycle ownership."
    exit 2
  fi

  if [ "$EXEC_EXIT" -ne 0 ]; then
    echo "  FAIL: Claude execution failed for $NEXT_TASK"
    echo "  Reverting status: in-progress → pending"
    update_status "$NEXT_TASK" "in-progress" "pending"
    echo "  Refer to: ai/execution-orchestrator.md Error Conditions"
    exit 1
  fi
  echo "  Execution: complete"
  echo ""

  # Step 5: Per-task verification
  # Implements ai/execution-orchestrator.md Step 5 — Verify Acceptance Criteria
  # Implements ai/verification-playbook.md — System Verification
  echo "  Running verification..."
  if ! run_task_verification "$NEXT_TASK"; then
    echo "  FAIL: Verification failed for $NEXT_TASK"
    echo "  Reverting status: in-progress → pending"
    update_status "$NEXT_TASK" "in-progress" "pending"
    echo "  Refer to: ai/verification-playbook.md Failure Handling"
    exit 1
  fi
  echo "  Verification: pass"
  echo ""

  # Step 6: Set status → done
  # Implements ai/execution-orchestrator.md Step 6
  # Only reached after successful execution AND verification.
  update_status "$NEXT_TASK" "in-progress" "done"
  echo "  Status: in-progress → done"

  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "  Completed: $TIMESTAMP"
  echo ""

done

# ── Invariant Gate: check before verification ────────────────────────────────
if [ -f "scripts/invariant-check.sh" ]; then
  echo "Invariant Gate (pre-verification)..."
  if ! bash scripts/invariant-check.sh > /tmp/.invariant-prev-out 2>&1; then
    cat /tmp/.invariant-prev-out
    echo "FATAL: Invariant violation detected — cannot proceed with verification."
    echo "  Fix the invariant violations above and re-run."
    exit 1
  fi
  cat /tmp/.invariant-prev-out
  echo ""
fi

# ── Post-loop: Verification Gate ───────────────────────────────────────────
# Implements ai/execution-loop-controller.md Stage 5 — Verification Gate
# Implements ai/verification-playbook.md — System Verification

echo ""
echo "Verification Gate"
echo "══════════════════════════════════════"
echo ""

VERIFICATION_PASS=true

# DELTA-ONLY selection per ai/verification-playbook.md:
#   1. If the capability's first task declares a parent spec with a
#      ## Verification Scripts block, run only those scripts (explicit mode).
#   2. Else, fall back to the full corpus (excluding scripts/verification/_legacy/).

if [ -d "scripts/verification" ]; then
  GATE_FIRST_TASK=$(echo "$TASK_FILES" | head -1)
  VSCRIPTS=$(resolve_delta_scripts "$GATE_FIRST_TASK")
  if [ -n "$VSCRIPTS" ]; then
    GATE_MODE="explicit"
  else
    GATE_MODE="fallback"
    VSCRIPTS=$(list_full_corpus)
  fi

  if [ -n "$VSCRIPTS" ]; then
    GATE_COUNT=$(echo "$VSCRIPTS" | wc -l | tr -d ' ')
    echo "DELTA MODE: $GATE_MODE ($GATE_COUNT script(s))"
    echo "Running verification scripts..."
    while IFS= read -r vscript; do
      [ -z "$vscript" ] && continue
      if [ ! -f "$vscript" ]; then
        echo "  Running: $vscript"
        echo "    ✗ MISSING"
        VERIFICATION_PASS=false
        continue
      fi
      echo "  Running: $vscript"
      if bash "$vscript" > /dev/null 2>&1; then
        echo "    ✓ PASS"
      else
        echo "    ✗ FAIL"
        VERIFICATION_PASS=false
      fi
    done <<< "$VSCRIPTS"
    echo ""
  else
    echo "  No verification scripts selected."
    echo ""
  fi
else
  echo "  scripts/verification/ directory not found — skipping system verification"
  echo ""
fi

# ── State Machine: advance to VERIFICATION_REQUIRED ─────────────────────────
if [ -f "scripts/state-manager.sh" ]; then
  bash scripts/state-manager.sh advance "$FEATURE" VERIFICATION_REQUIRED
fi

# ── Post-loop: Journal Entry ──────────────────────────────────────────────
# Implements ai/execution-loop-controller.md Stage 6 — Engineering Journal Entry

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATESTAMP=$(date -u +"%Y-%m-%d")

if [ "$VERIFICATION_PASS" = true ]; then
  echo "Verification: PASS"
  # ── State Machine: advance to RELEASE_APPROVED ────────────────────────────
  if [ -f "scripts/state-manager.sh" ]; then
    bash scripts/state-manager.sh advance "$FEATURE" RELEASE_APPROVED
  fi
  echo ""

  # Determine parent spec
  FIRST_TASK=$(echo "$TASK_FILES" | head -1)
  PARENT_SPEC=$(grep -A1 "^## Parent Spec" "$FIRST_TASK" 2>/dev/null | tail -1 | tr -d '[:space:]')
  PHASE=$(read_field "$FIRST_TASK" "Phase")

  # Build task list
  TASK_LIST=""
  for task_file in $TASK_FILES; do
    layer=$(read_field "$task_file" "Layer")
    TASK_LIST="${TASK_LIST}\n- ${task_file} [${layer}]"
  done

  echo "Journal Entry"
  echo "──────────────────────────────────────"
  echo "  Date:     $DATESTAMP"
  echo "  Feature:  $FEATURE"
  echo "  Phase:    $PHASE"
  echo "  Spec:     $PARENT_SPEC"
  echo "  Tasks:    $TASK_COUNT executed"
  echo "  Result:   verification passed"
  echo ""

  # Append to engineering journal
  {
    echo ""
    echo "---"
    echo ""
    echo "### $DATESTAMP"
    echo ""
    echo "### Feature"
    echo ""
    echo "$FEATURE"
    echo ""
    echo "### Phase"
    echo ""
    echo "$PHASE"
    echo ""
    echo "### Spec"
    echo ""
    echo "$PARENT_SPEC"
    echo ""
    echo "### Tasks"
    echo ""
    echo -e "$TASK_LIST"
    echo ""
    echo "### Implementation Notes"
    echo ""
    echo "Executed by execution-supervisor.sh at $TIMESTAMP."
    echo "All $TASK_COUNT tasks completed. Verification passed."
    echo ""
    echo "### Pattern Updates"
    echo ""
    echo "None."
    echo ""
    echo "### Incidents"
    echo ""
    echo "None."
  } >> ai/engineering-journal.md

  echo "  ✓ Journal entry appended to ai/engineering-journal.md"

else
  echo "Verification: FAIL"
  echo ""
  echo "  Verification failed. Tasks remain marked done but feature"
  echo "  is not complete until verification passes."
  echo ""
  echo "  Required actions (per ai/verification-playbook.md):"
  echo "    1. Record failure in ai/incidents/"
  echo "    2. Identify root cause"
  echo "    3. Implement fix"
  echo "    4. Re-run verification"
  exit 1
fi

echo ""
echo "Execution complete."
echo ""
echo "  Feature:  $FEATURE"
echo "  Tasks:    $EXECUTED executed"
echo "  Status:   all done"
echo "  Verified: $VERIFICATION_PASS"
echo "  Journal:  updated"
