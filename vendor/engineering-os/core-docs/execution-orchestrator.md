# Execution Orchestrator

## Purpose

This document defines the per-task execution lifecycle that agents follow when
implementing features in this repository.

The execution orchestrator governs the inner loop — how a single task moves from
`pending` to `done`. It operates inside the broader execution pipeline defined by
`ai/execution-loop-controller.md`.

---

## Relationship to Other Documents

| Document | Role |
|----------|------|
| `ai/execution-loop-controller.md` | Outer loop — phase validation, spec lifecycle, journal entry |
| `ai/execution-orchestrator.md` | Inner loop — per-task execution lifecycle (this document) |
| `ai/task-graph.md` | DAG model — dependency ordering and validation |
| `ai/verification-playbook.md` | Verification gate — how to verify after implementation |
| `scripts/execution-supervisor.sh` | Runtime — executes the lifecycle described in this document; runs invariant gates and advances state machine |

The orchestrator operates inside Stage 4 of the execution loop controller
(Task Execution). It is not a replacement for the loop controller.

---

## Execution Lifecycle

For each task in the feature's task graph, the orchestrator executes the
following sequence:

```
[pre-execution invariant gate]  (scripts/invariant-check.sh — state: EXECUTION_ACTIVE)
      ↓
1. select next pending task
      ↓
2. verify dependencies
      ↓
3. set task status → in-progress
      ↓
4. implement task
      ↓
5. verify acceptance criteria
      ↓
6. set task status → done
      ↓
7. continue loop
      ↓
[pre-verification invariant gate]  (scripts/invariant-check.sh — state: VERIFICATION_REQUIRED)
```

Each step is mandatory. Steps may not be skipped or reordered.

The two invariant gates are run by `scripts/execution-supervisor.sh`. If either
gate exits non-zero, the pipeline is blocked (exit 1) and must not proceed.

---

## State Machine Precondition

Before selecting the first task, confirm the feature state is `TASK_GRAPH_LOCKED`:

```bash
bash scripts/state-manager.sh get <feature-slug>
```

If state is not `TASK_GRAPH_LOCKED`:

**STOP** — do not execute tasks. Report the blocking condition:

| State observed | Blocking condition |
|---|---|
| `RECON_READY` | `compile-spec.sh` has not been run — spec is not locked |
| `SPEC_LOCKED` | `generate-tasks.sh` has not completed — task graph not locked |
| `EXECUTION_ACTIVE` | Execution already in progress — do not re-enter |
| `VERIFICATION_REQUIRED` or later | Execution already complete |

Task execution may only begin from `TASK_GRAPH_LOCKED`. State is advanced to
`EXECUTION_ACTIVE` by `scripts/execution-supervisor.sh` after the pre-execution
invariant gate passes.

---

## Step 1 — Select Next Pending Task

Scan the task graph for the next eligible task.

A task is eligible when:
- Its status is `pending`
- All tasks listed in its `Blocked By` field have status `done`

Tasks are selected in numeric order (`001` before `002`, etc.).

If no eligible task exists and tasks remain in `pending` status:
- check for circular dependencies (see `ai/task-graph.md`)
- report the blocking condition

If all tasks are `done`, the feature is complete — proceed to the verification
gate defined in `ai/execution-loop-controller.md`.

---

## Step 2 — Verify Dependencies

Before beginning a task, confirm:

1. All `Blocked By` tasks have status `done`
2. The parent spec is in `approved` or `implemented` status
3. No higher-priority task is currently `in-progress`

If any dependency check fails:

**STOP** — do not begin the task. Report the blocking condition and wait for
resolution.

---

## Step 3 — Set Task Status → in-progress

Update the task file:

```markdown
## Status
in-progress
```

This must happen before any code is written. It signals that the task is
actively being executed and prevents duplicate execution.

---

## Step 4 — Implement Task

Read the task file fully. Implement only what the task describes.

Rules during implementation:

- **Scope containment** — modify only the files listed in `Files Likely Affected`.
  If additional files must change, document the reason in the task before modifying them.
- **Pattern compliance** — all code must follow patterns in `ai/coding-patterns.md`.
- **Contract compliance** — implementation must not violate `ai/runtime-contracts.md`.
- **Boundary compliance** — implementation must respect `ai/service-boundaries.md`.
- **No scope bleed** — do not implement work belonging to a different task.

---

## Step 5 — Verify Acceptance Criteria

After implementation, check every acceptance criterion in the task file.

Each criterion must be verifiable without human judgment — it describes
observable system behavior.

A criterion is satisfied when the described behavior can be confirmed by:
- reading the modified source files, or
- running the system and observing the behavior, or
- running a verification script

If any criterion is not met:

**Do not advance to step 6.** Fix the implementation and re-verify.

---

## Step 6 — Set Task Status → done

Once all acceptance criteria are verified, update the task file:

```markdown
## Status
done
```

Do not mark a task `done` if any criterion remains unverified.

---

## Step 7 — Continue Loop

Return to Step 1 and select the next eligible task.

When the final task (verification task) is marked `done`, the inner loop
is complete. Hand off to the outer loop controller:

```
verification task done
  ↓
run ai/verification-playbook.md
  ↓
append ai/engineering-journal.md entry
  ↓
set spec status → implemented
  ↓
update capability backlog
```

---

## Error Conditions

| Condition | Action |
|-----------|--------|
| Dependency not met | Stop. Report blocker. Do not begin task. |
| Acceptance criterion fails after implementation | Fix and re-verify. Do not mark done. |
| File outside `Files Likely Affected` must change | Document reason in task. Then modify. |
| Pattern not found in `ai/coding-patterns.md` | Stop. Propose pattern amendment. |
| Contract violation detected | Stop. Create incident record. Fix before continuing. |

---

## Task Status Reference

| Status | Meaning |
|--------|---------|
| `pending` | Task exists but is not yet ready to begin (blockers remain) |
| `in-progress` | Task is actively being executed |
| `done` | All acceptance criteria verified; task complete |
| `blocked` | Explicit block — a dependency issue prevents progress |
