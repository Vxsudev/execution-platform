# Task Generator

## Purpose

This document defines the deterministic procedure for converting an approved
specification into a complete, executable task graph.

The task generator operates at Step 7 of the spec compiler pipeline
(`ai/spec-compiler.md`). It reads spec contents and dynamically produces
task files whose count, layers, and dependencies are determined entirely by
the spec — no fixed task structure is assumed.

---

## Position in the Pipeline

```
spec (approved)
  ↓
task-generator.md  ←── THIS DOCUMENT
  ↓
tasks/<feature>-001.md
tasks/<feature>-002.md
...
tasks/<feature>-NNN.md
  ↓
execution-orchestrator.md
```

---

## Step 1 — Validate Spec Pre-Conditions

Before generating any tasks, confirm:

1. The spec file exists at `specs/<feature>.md`
2. The spec `## Status` field is `approved`
3. The spec contains a valid `## Phase` field

If any pre-condition fails:

**STOP** — tasks may not be generated from a spec that is not approved.
Report the failing condition.

**Invocation constraint:** Task generation is initiated via `scripts/compile-spec.sh`,
which writes the OS execution token (`/tmp/.os-compile-token`) and then invokes
`scripts/generate-tasks.sh`. Do NOT invoke `generate-tasks.sh` directly — it
requires the token and will exit 1 without it. The token is single-use and
session-bound.

---

## Step 2 — Extract Phase Tag

Read the spec header and extract the phase tag:

```markdown
## Phase
phase-<identifier>
```

The phase tag must correspond to an existing phase specification file in
`specs/phases/`. Validate by scanning that directory for a file containing:

```
Phase: phase-<identifier>
```

If the phase tag is absent or does not match any existing phase specification:

**STOP** — do not generate tasks. The spec must be corrected to declare
a valid phase before task generation can proceed.

The extracted phase tag propagates to every generated task file.
No task may be created with a phase tag that differs from the parent spec.

---

## Step 3 — Identify Required Layers

Read the spec and evaluate which layers are needed. Layers are determined
dynamically from spec section contents — never assumed.

Evaluation rules:

| Spec Section | Non-empty when... | Layer Required |
|---|---|---|
| `## Data Model Changes` | Tables, columns, indexes, constraints, or triggers are introduced | `database` |
| `## API Surface` | New or modified endpoints are listed | `backend` |
| `## Frontend Surface` | New pages, dialogs, navigation changes, or API clients are described | `frontend` |
| `## Operational Workflow` | Multi-step flows, background jobs, or event-driven side effects span backend or frontend | add to `backend` or `frontend` as appropriate |
| Always | Every feature requires a final verification check | `verification` |

If a section explicitly states `none`, the corresponding layer is skipped.

The `verification` layer is never optional. Every feature must have a
verification task as its final node.

### Layer detection example

A spec with:
- `## Data Model Changes` containing a new table → database task required
- `## API Surface` containing two new endpoints → backend task required
- `## Frontend Surface` containing a new page → frontend task required

Produces four tasks: database, backend, frontend, verification.

A spec with:
- `## Data Model Changes: none`
- `## API Surface: none`
- `## Frontend Surface` containing navigation changes only

Produces two tasks: frontend, verification.

---

## Step 4 — Assign Task Numbers

Tasks are numbered sequentially starting at 001 in layer dependency order:

```
database  → assigned first
backend   → assigned after database
frontend  → assigned after backend
verification → always last
```

Skipped layers do not consume a number slot.

The total number of tasks equals the number of required layers.

Number format: zero-padded three-digit integer (`001`, `002`, ..., `NNN`).

No maximum is defined. The number of tasks grows with spec complexity.

---

## Step 5 — Build Dependency Graph

Assign `Blocked By` declarations following the rules in `ai/task-graph.md`.

Default dependency chain:

```
database-task
  └── backend-task (blocked by: database-task)
        └── frontend-task (blocked by: backend-task)
              └── verification-task (blocked by: frontend-task)
```

For abbreviated graphs, chain tasks in the order they appear.
The root task always declares `Blocked By: none`.
Each subsequent task declares its immediate predecessor.

Validate the resulting graph before writing files:

- No circular dependencies
- All `Blocked By` references point to tasks in the current graph
- Verification task is the terminal node

If validation fails:

**STOP** — redesign the task decomposition before writing files.

---

## Step 6 — Generate Task Files

For each required layer, create one task file at:

```
tasks/<feature>-NNN.md
```

Where `<feature>` is derived from the spec filename (without `.md` extension),
and `NNN` is the assigned task number from Step 4.

Each task file must contain all required fields:

```markdown
# Task: <imperative title>

## Parent Spec
specs/<feature>.md

## Phase
<phase-tag>

## Status
pending

## Layer
database | backend | frontend | verification

## Description
<precise description — sufficient for another agent to execute without
reading the spec or other tasks>

## Acceptance Criteria
- [ ] <concrete, verifiable condition>
- [ ] <concrete, verifiable condition>
- [ ] ...

## Files Likely Affected
- <path/to/file>
- ...

## Blocked By
- tasks/<feature>-00N.md  (or "none" for the root task)
```

### Phase Tag Propagation Rule

The `## Phase` field in every task file must match exactly the `## Phase`
field from the parent spec.

```
spec:  ## Phase\nphase-2
task:  ## Phase\nphase-2   ← must be identical
```

A task with a phase tag that does not match its parent spec is invalid
and must not be created.

### Status at Generation

All tasks are created with:

```markdown
## Status
pending
```

Status must not be set to `in-progress` or `done` during generation.

---

## Step 7 — Emit Task Graph Summary

After all task files are written, emit a task graph summary:

```
Task Graph: <feature>
Phase: <phase-tag>
Tasks generated: N

001  [database]     <title>  →  blocked by: none
002  [backend]      <title>  →  blocked by: 001
003  [frontend]     <title>  →  blocked by: 002
004  [verification] <title>  →  blocked by: 003
```

This summary is for confirmation only. It does not modify any files.

---

## Layer Content Reference

When writing task descriptions, each layer owns specific concerns:

| Layer | Description must cover | Must NOT include |
|-------|------------------------|-----------------|
| `database` | migration artifact, data model changes, new columns, indexes, constraints, triggers | Route logic, UI concerns |
| `backend` | Route handlers, request/response schemas, guards, service functions, tenant filtering, audit logging | Migration commands, frontend files |
| `frontend` | frontend surface components, API client functions, route config changes, access guard wiring | Backend logic, DB queries |
| `scripts` | Shell scripts in `scripts/`, verification gate scripts, OS pipeline scripts, hooks | Application code changes, migrations |
| `verification` | Spec acceptance criteria checks, contract verification, system verification scripts | Application code changes |

---

## Halting Rules

| Condition | Action |
|-----------|--------|
| Spec status is not `approved` | STOP — do not generate tasks |
| Phase tag absent from spec | STOP — do not generate tasks |
| Phase tag has no matching phase file in `specs/phases/` | STOP — do not generate tasks |
| Circular dependency detected in proposed graph | STOP — redesign decomposition |
| Required layer has no content to describe | Skip the layer — do not generate an empty task |
| Spec sections are ambiguous | Read `ai/spec-to-task-playbook.md` for decomposition guidance |

---

## Document References

| Document | Role in Task Generation |
|----------|------------------------|
| `ai/spec-compiler.md` | Invokes the task generator at Step 7 |
| `ai/spec-to-task-playbook.md` | Layer responsibility matrix and decomposition guidance |
| `ai/task-graph.md` | DAG rules, dependency declaration format, ordering enforcement |
| `ai/execution-loop-controller.md` | Phase validation — confirms phase tag is a valid registered phase |
| `ai/execution-orchestrator.md` | Consumes generated tasks during execution |
