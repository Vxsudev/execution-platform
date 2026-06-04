# Spec → Task Decomposition Playbook

## Step 1 — Read the Spec

Before generating any tasks, extract the following from the spec:

**System capability**
What new behavior does the system gain? What problem does it solve?

**Data model changes**
Which tables are created, altered, or dropped? Are there new constraints, indexes, or triggers?

**API surfaces**
Which routes are added or modified? What are the HTTP methods, paths, auth requirements,
and request/response shapes?

**Frontend surfaces**
Which pages, dialogs, or workflows are introduced? Which API clients are needed?

**Operational workflows**
Are there multi-step user flows, background jobs, rate limits, or event-driven side effects?

Do not proceed to task generation until all five dimensions are understood.

---

## Step 2 — Identify Work Categories

Tasks are numbered sequentially beginning at 001. The number of tasks depends on the
complexity of the feature.

Common work categories (in typical dependency order):

| Category | Contents |
|----------|----------|
| Database | Migrations, model definitions, constraints, triggers, indexes |
| Backend API | Route handlers, service logic, guards, schemas, tests |
| Frontend | Pages, dialogs, API clients, state, role guards |
| Verification | Smoke tests, curl sequences, SQL assertions, end-to-end checks |

Not every feature requires all categories. A simple backend-only change may produce
two tasks (database + backend). A feature with multiple complex layers may produce
more than four. Generate only the tasks required by the spec.

---

## Step 3 — Generate Task Graph

Tasks must be produced in dependency order. Each task declares which tasks block it.

Example dependency chain:

```
Task 001 (Database)
  └── Task 002 (Backend) — blocked by 001
        └── Task 003 (Frontend) — blocked by 002
              └── Task 004 (Verification) — blocked by 003
```

The number of tasks and their categories vary per feature.

Each task must be:

- **Independent within its layer** — a single task does not span multiple layers
- **Testable** — has concrete acceptance criteria that can be verified without human judgment
- **Bounded** — lists the specific files expected to change
- **Linked** — references the parent spec and its blockedBy task

---

## Step 4 — Task File Generation

For a spec at `specs/<feature>.md`, generate sequentially numbered task files:

```
tasks/<feature>-001.md
tasks/<feature>-002.md
tasks/<feature>-003.md
...
tasks/<feature>-NNN.md
```

### Task file format

```markdown
# Task: <imperative title>

## Parent Spec
specs/<feature>.md

## Status
pending | in-progress | blocked | done

## Layer
database | backend | frontend | verification

## Description
Precise description of what must be done. Enough detail for another agent to execute
this task without reading the spec or the other tasks.

## Acceptance Criteria
- [ ] Concrete, verifiable condition 1
- [ ] Concrete, verifiable condition 2
- [ ] ...

## Files Likely Affected
- path/to/file.py
- path/to/migration.py
- ...

## Blocked By
- tasks/<feature>-00N.md  (or "none" for task 001)
```

### Example — `specs/device-management.md`

```
tasks/device-management-001.md   Database: devices, device_types, history tables, API keys
tasks/device-management-002.md   Backend: route handlers, guards, schemas, service logic
tasks/device-management-003.md   Frontend: DevicesPage, RegisterDeviceDialog, AssignDeviceDialog
tasks/device-management-004.md   Verification: smoke test device registration, assignment, firmware update
```

---

## Step 5 — Execution Rule

**Implementation must never start directly from a spec.**

The required sequence is:

```
spec (approved)
  ↓
task graph generated (tasks/*.md created)
  ↓
task 001 moves to in-progress → implementation begins
  ↓
task 001 done → task 002 unblocked → in-progress
  ↓
...continue until all tasks done...
  ↓
last task done → spec status updated to implemented
```

An agent or developer picking up a task must:
1. Read the task file fully before writing any code
2. Confirm all blockedBy tasks are `done`
3. Set task status to `in-progress`
4. Implement only what the task describes — no scope creep into adjacent tasks
5. Verify all acceptance criteria before setting status to `done`

---

## Step 6 — Completion

A spec transitions from `approved` → `implemented` only when:

- All generated task files exist
- All task statuses are `done`
- Verification task acceptance criteria are fully met

Update the spec file's `## Status` field to `implemented` as the final step.

If a task is abandoned or superseded, set its status to `done` with a note in the
description explaining the disposition. Do not delete task files.

---

## Reference — Layer Responsibility Matrix

| Layer | Owns | Must NOT |
|-------|------|----------|
| Database (001) | migration artifact, data model additions/changes | Contain route logic or UI concerns |
| Backend (002) | Route handlers, request/response schemas, service functions, RBAC guards | Run migrations or touch frontend files |
| Frontend (003) | frontend surface components, dialogs, API client functions, access guard wrappers | Contain backend logic or DB queries |
| Verification (004) | Smoke test scripts, curl sequences, SQL assertions, CI checks | Modify application code |
