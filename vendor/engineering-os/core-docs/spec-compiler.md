# Spec Compiler

## Purpose

This document defines the deterministic procedure that agents must follow
when compiling a capability into a specification and task graph.

The spec compiler is the single entry point for converting product
capabilities into engineering artifacts. It orchestrates the repository's
control layer documents in a fixed sequence, ensuring that every
capability passes through invariant validation, boundary checks, and
pattern selection before a spec or task is produced.

Agents must follow this procedure when compiling capabilities.

---

## Spec Compilation Pipeline

```
Input:
  capability description
  phase tag

Output:
  specification (specs/<feature-name>.md)
  task graph (tasks/<feature-name>-001.md ... NNN.md)
```

Pipeline:

```
1. capability intake          (read capability-backlog.md, extract phase tag)
2. invariant validation       (ai/product-invariants.md, ai/runtime-contracts.md)
3. architecture boundary check (ai/service-boundaries.md)
4. pattern selection          (ai/coding-patterns.md)
5. spec generation            (ai/spec-generation.md → specs/<feature>.md)
6. spec approval              (human or authorized agent sets status: approved)
7. task generation            (ai/task-generator.md → tasks/<feature>-NNN.md)
8. execution loop handoff     (ai/execution-loop-controller.md)
9. verification gate          (ai/verification-playbook.md)
10. engineering journal entry (ai/engineering-journal.md)
```

Each step is a gate. If a step fails, the pipeline halts.

**Approved specs MUST produce task files.** A spec that reaches `approved` status without
generating a corresponding task graph is incomplete. Task generation (Step 7) is not optional.

---

## Step 1 — Capability Intake

Read the capability from:

```
product/capability-backlog.md
```

Extract:

- capability name
- phase tag

The phase tag must be valid. Phase validation is performed by the
execution loop controller as defined in `ai/execution-loop-controller.md`.

Example:

```
Device calibration tracking
phase: phase-2
```

If the capability does not have a phase tag:

**STOP** — assign a phase tag before proceeding.

---

## Step 2 — Invariant Validation

Read:

```
ai/product-invariants.md
```

Verify the capability does not conflict with any product invariant:

- strict tenant isolation
- membership-derived RBAC authority
- immutable audit logging
- append-only ingest pipeline
- UUID-based external identity membrane

Also verify against the architectural constraints:

- no cross-tenant data access
- no external exposure of integer primary keys
- no audit bypass for state changes
- no device direct writes to operational tables

If an invariant conflict is detected:

**STOP** — the capability cannot be compiled. The capability must be
redesigned or rejected.

---

## Step 3 — Architecture Boundary Check

Read:

```
ai/runtime-contracts.md
ai/service-boundaries.md
```

Verify the capability respects:

- **service ownership** — database access belongs to backend only;
  frontend communicates via API only
- **data boundaries** — tenant-scoped data requires tenant filtering;
  no cross-service data access
- **API communication rules** — frontend uses the adapter-configured API base URL;
  external clients use API keys via the configured ingest endpoint
- **environment authority** — all config from the adapter-configured environment path
- **orchestration** — services managed via Docker Compose

If a boundary violation is detected:

**STOP** — the spec must be redesigned to respect service boundaries
and runtime contracts.

---

## Step 4 — Pattern Selection

Read:

```
ai/coding-patterns.md
```

Select existing implementation patterns for each layer the capability
will touch:

- **database changes** — migration artifacts, data model additions,
  tenant-scoped constraints
- **backend routes** — router declaration, dependency injection, role
  guards, tenant extraction, cross-tenant protection, atomic writes
- **frontend surfaces** — page structure, API client pattern, route
  guards, component organization
- **audit logging** — audit event emission with event type convention,
  emitted for all state-changing operations
- **tenant filtering** — mandatory `<project_scope_field>` filter on
  all tenant-scoped queries

New patterns must never be invented during compilation. If a required
pattern does not exist:

**STOP** — a pattern amendment must be proposed before the spec can
be compiled. The proposal must include:

- the problem the new pattern solves
- the proposed structure
- why existing patterns cannot accommodate the capability

Compilation may only resume after the pattern amendment is approved
and added to `ai/coding-patterns.md`.

---

## Step 5 — Spec Generation

Generate the specification according to:

```
ai/spec-generation.md
```

This includes:

1. Repository recon (repo-index, runtime-contracts, service-boundaries,
   product-invariants)
2. Duplication check against existing `specs/`
3. Spec authoring using the required template

Create the spec file:

```
specs/<feature-name>.md
```

The spec must include all required sections:

- Status (`draft`)
- Phase (matching the capability phase tag)
- Capability
- Data Model Changes
- API Surface
- Frontend Surface
- Operational Workflow
- Dependencies
- Acceptance Criteria
- Out of Scope

The spec filename must use lowercase kebab-case and must match the
feature slug used for task files.

Initial status: `draft`

---

## Step 6 — Spec Approval

The spec must transition from `draft` to `approved` before task
generation may begin.

Approval is an explicit decision — it is not automatic. A human or
authorized agent must change the status field after reviewing the
spec content.

A spec must not be approved unless:

- acceptance criteria are defined
- all spec quality checklist items pass (see `ai/spec-generation.md`)
- no invariant or boundary violations exist

Only approved specs may produce tasks.

---

## Step 7 — Task Graph Generation

**Invoke:**

```
ai/task-generator.md
```

The task generator defines the complete, deterministic procedure for converting an
approved spec into a task graph. Follow every step in `ai/task-generator.md`.

Generate sequentially numbered task files:

```
tasks/<feature-name>-001.md
tasks/<feature-name>-002.md
...
tasks/<feature-name>-NNN.md
```

Tasks must be produced in dependency order. Each task:

- covers a single layer (database, backend, frontend, or verification)
- declares its blocked-by dependencies per `ai/task-graph.md`
- includes concrete acceptance criteria
- lists files likely affected
- carries the phase tag from the parent spec (phase propagation is mandatory)

The number of tasks depends on the spec content. Layer detection rules are defined
exclusively in `ai/task-generator.md` Step 3.

**Tooling:** `scripts/generate-tasks.sh` is invoked automatically by
`scripts/compile-spec.sh` via the OS execution token (`/tmp/.os-compile-token`).
The token is written by `compile-spec.sh` and consumed (deleted) by
`generate-tasks.sh` — single-use, session-bound. Do not invoke
`generate-tasks.sh` directly; it requires the token to proceed.

When invoked, `generate-tasks.sh` validates the OS token, confirms the state
machine is in `SPEC_LOCKED`, emits task file scaffolds for each layer detected
in the spec, and advances state to `TASK_GRAPH_LOCKED`. Task file content is
then filled in by an agent following `ai/task-generator.md`.

Pipeline handoff:

```
compile-spec.sh  →  writes /tmp/.os-compile-token  →  state: SPEC_LOCKED
generate-tasks.sh → consumes token, generates scaffolds → state: TASK_GRAPH_LOCKED
```

---

## Step 8 — Execution Handoff

After task generation, the spec compiler's work is complete.

The feature now enters the execution loop controller pipeline
(`ai/execution-loop-controller.md`):

```
tasks
  ↓
implementation (task execution)
  ↓
verification gate
  ↓
engineering journal entry
  ↓
completion
```

The execution controller manages all subsequent stages.

---

## Capability → Layer Mapping

When a spec section is compiled into tasks, each section maps to a
specific layer category. This table is authoritative for task assignment.

| Spec Section | Layer | Task Category |
|---|---|---|
| Capability | — | Informs all layers; no dedicated task |
| Data Model Changes | `database` | migration artifact + data model update |
| API Surface | `backend` | Route handlers, schemas, guards, service logic |
| Frontend Surface | `frontend` | Pages, API clients, route config, access guard wiring |
| Verification | `verification` | Smoke checks, contract checks, system scripts |

### Mapping Rules

**Capability → tasks**
The capability description sets the overall goal. It does not produce a
task directly. It informs the scope of database, backend, and frontend tasks.

**Data Model → backend tasks**
Any new table, column, index, constraint, or trigger requires a `database`
layer task containing a migration artifact and data model change.

**API Surface → backend + frontend tasks**
Each new or modified endpoint requires:
- A `backend` task for the route handler, schema, and guard
- A `frontend` task for the corresponding API client function

**Frontend Surface → frontend tasks**
Each new page, dialog, or navigation change requires a `frontend` layer task.
The task covers: page component, API client call, access guard wiring, and
route registration.

**Verification → verification tasks**
Every feature requires a final `verification` task that checks:
- All spec acceptance criteria
- Contract compliance
- System verification scripts

---

## Compiler Halting Rules

The spec compiler halts at any step where a violation is detected.
The following table summarizes halt conditions:

| Step | Halt Condition |
|------|----------------|
| 1. Capability Intake | Missing phase tag |
| 2. Invariant Validation | Product invariant conflict |
| 3. Boundary Check | Runtime contract or service boundary violation |
| 4. Pattern Selection | Required pattern does not exist |
| 5. Spec Generation | Duplicate spec detected |
| 6. Spec Approval | Spec not approved |
| 7. Task Generation | Spec not in `approved` status; OS token missing; state not `SPEC_LOCKED` |

When halted, the compiler must report the halt condition. Compilation
may only resume after the condition is resolved.

---

## Document References

The spec compiler orchestrates the following control layer documents:

| Document | Used In |
|----------|---------|
| `product/capability-backlog.md` | Step 1 — capability source |
| `ai/product-invariants.md` | Step 2 — invariant validation |
| `ai/runtime-contracts.md` | Step 3 — contract compliance |
| `ai/service-boundaries.md` | Step 3 — boundary enforcement |
| `ai/coding-patterns.md` | Step 4 — pattern selection |
| `ai/spec-generation.md` | Step 5 — spec template and procedure |
| `ai/task-generator.md` | Step 7 — task generation procedure |
| `ai/task-graph.md` | Step 7 — DAG model and dependency rules |
| `ai/spec-to-task-playbook.md` | Step 7 — layer responsibility reference |
| `ai/execution-loop-controller.md` | Step 8 — execution handoff |
