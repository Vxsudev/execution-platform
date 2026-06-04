# Task Graph

## Purpose

This document defines the DAG (directed acyclic graph) model used to declare,
validate, and execute task dependencies in this repository.

All task graphs derived from specs must conform to the rules in this document.

---

## DAG Model

Each feature produces a set of tasks. Tasks are nodes in a directed acyclic
graph. Edges represent blocking dependencies.

```
Task A → Task B means: Task B cannot begin until Task A is done.
```

A task with no inbound edges is a root task — it has no blockers and may
begin immediately once the spec is approved.

---

## Dependency Declaration Format

Dependencies are declared in task files using the `Blocked By` field:

```markdown
## Blocked By
- tasks/<feature>-00N.md
```

For root tasks (no dependencies):

```markdown
## Blocked By
- none
```

Multiple dependencies are listed one per line:

```markdown
## Blocked By
- tasks/<feature>-001.md
- tasks/<feature>-002.md
```

---

## Standard Layer Ordering

The canonical execution order enforces layer isolation:

```
database (001)
  ↓
backend (002)
  ↓
frontend (003)
  ↓
verification (004)
```

This ordering is mandatory unless a layer is absent from the feature.

**Rationale:**
- Backend routes depend on the schema being present — database must precede backend.
- Frontend API clients depend on the routes existing — backend must precede frontend.
- Verification must run after all implementation is complete.

### Abbreviated Graphs

Not every feature uses all four layers.

A frontend-only feature with no API changes uses:

```
frontend (001)
  ↓
verification (002)
```

A backend-only feature with schema changes uses:

```
database (001)
  ↓
backend (002)
  ↓
verification (003)
```

Generate only the tasks required by the spec. Never generate empty tasks.

---

## Execution Ordering Rules

1. **Strict layer order** — database tasks always precede backend tasks;
   backend tasks always precede frontend tasks; verification is always last.

2. **Blocked tasks may not begin** — a task in `pending` or `blocked` status
   whose `Blocked By` tasks are not all `done` must not be set to `in-progress`.

3. **Single active task** — only one task may be `in-progress` at a time within
   a feature's execution cycle. Parallel execution across features is permitted.

4. **Status transitions** are strictly ordered:
   ```
   pending → in-progress → done
   ```
   A task may not skip states or move backwards.

---

## Circular Dependency Detection

Circular dependencies are invalid and must be rejected at task generation time.

A circular dependency exists when following `Blocked By` chains from any task
eventually returns to that same task.

Example of invalid graph (rejected):

```
001 blocked by 002
002 blocked by 001   ← circular — INVALID
```

If a circular dependency is detected during compilation:

**STOP** — the task graph cannot be generated. Redesign the task decomposition
before proceeding.

---

## Graph Validation Checklist

Before execution begins, verify the task graph:

- [ ] Each task declares a valid `Blocked By` field
- [ ] No circular dependencies exist
- [ ] Layer ordering follows: database → backend → frontend → verification
- [ ] The verification task is always the final node
- [ ] All `Blocked By` references point to tasks that exist in the graph

---

## Reference

Task file format is defined in `ai/spec-to-task-playbook.md`.

Execution lifecycle is defined in `ai/execution-orchestrator.md`.
