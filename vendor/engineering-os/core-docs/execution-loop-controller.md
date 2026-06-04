# Execution Loop Controller

## Purpose

This document defines the deterministic engineering execution controller
used by AI agents when developing capabilities in this repository.

The controller coordinates the engineering control layer and ensures that
development follows the spec-driven workflow.

It also enforces **product phase boundaries** so that capabilities cannot
violate earlier architectural phases.

Agents must follow this controller when performing engineering work.

---

## Product Phases

Product phases are defined by phase specification files located in:

```
specs/phases/*.md
```

Each phase specification describes the architectural scope of that phase.

Phases are discovered dynamically by scanning `specs/phases/*.md` and
reading the `Phase` declaration inside each file.

The controller must not infer phase identity from filenames. The
authoritative phase identifier is the `Phase:` field declared within
each phase specification file.

Only phases defined by these files are valid phases.

### Phase Declaration Rules

Phase specification files must declare their phase using the following syntax:

```
Phase: phase-<identifier>
```

Rules:

- The declaration must appear within the first 20 lines of the file.
- The declaration is case-sensitive and must begin with `Phase:`.
- Exactly one phase declaration must exist per phase file.
- The execution controller must read this declaration to determine the phase identity.

Example:

```
# Phase Specification

Phase: phase-3
```

Phase identity must never be inferred from filenames.

---

## Phase Tagging

Every capability must declare a phase tag.

Phase tag format:

```
phase: phase-<x>
```

Where `x` corresponds to an existing phase specification.

Example:

```
phase: phase-2
```

The phase tag must appear in:

- capability backlog entry
- spec header
- engineering journal entry

---

## Phase Validation

Phase tags must correspond to an existing architecture phase.

A phase tag is valid only if a phase specification file exists in
`specs/phases/` containing a matching `Phase:` declaration.

If the corresponding phase specification does not exist:

**STOP**

The capability cannot proceed until the correct phase is defined.

---

## Phase Propagation

The phase tag must propagate across the execution pipeline.

The following invariant must always hold:

```
capability phase = spec phase = journal phase
```

If a mismatch occurs:

**STOP**

Execution must halt until the phase mismatch is corrected.

---

## Execution Loop

All capabilities move through the following pipeline:

```
capability backlog
  ↓
spec generation
  ↓
task generation
  ↓
task execution
  ↓
verification gate
  ↓
engineering journal entry
  ↓
capability completed
```

Agents must not skip stages.

---

## Stage 1 — Capability Intake

Capabilities originate in:

```
product/capability-backlog.md
```

Each capability must include a phase tag.

Example:

```
Device calibration tracking
phase: phase-2
```

Capability lifecycle states are defined by `product/capability-backlog.md`.

The execution controller must respect the lifecycle defined in that document
rather than hardcoding states.

When a capability enters the spec-authoring stage, spec generation begins.

---

## Stage 2 — Spec Generation

Generate a spec in:

```
specs/<capability-name>.md
```

The spec must follow the template defined in:

```
ai/spec-generation.md
```

The spec header must include:

```
## Status
draft

## Phase
phase-<x>
```

The spec phase must match the capability phase.

If the phases differ:

**STOP**

The spec must be corrected before continuing.

---

## Stage 3 — Task Generation

Use:

```
ai/spec-to-task-playbook.md
```

The spec is decomposed into sequentially numbered task files:

```
tasks/<feature-name>-001.md
tasks/<feature-name>-002.md
tasks/<feature-name>-003.md
...
tasks/<feature-name>-NNN.md
```

The number of tasks depends on the complexity of the feature.

Tasks inherit the phase from the spec.

---

## Stage 4 — Task Execution

Before task execution begins, `scripts/execution-supervisor.sh` runs the
invariant gate (`scripts/invariant-check.sh`). Execution is blocked if the gate
exits non-zero. State advances from `TASK_GRAPH_LOCKED` to `EXECUTION_ACTIVE`
at this point.

Execute tasks sequentially in dependency order:

```
001 → 002 → ... → NNN
```

Agents must:

- modify only files required by the active task
- follow patterns defined in `ai/coding-patterns.md`
- respect runtime contracts defined in `ai/runtime-contracts.md`
- respect service boundaries defined in `ai/service-boundaries.md`
- preserve product invariants defined in `ai/product-invariants.md`

---

## Stage 5 — Verification Gate

Before verification scripts run, `scripts/execution-supervisor.sh` runs the
invariant gate a second time (`scripts/invariant-check.sh`). State advances to
`VERIFICATION_REQUIRED` at this point. `RELEASE_APPROVED` is only set when
verification passes (`VERIFICATION_PASS == true`).

After all tasks complete, run verification.

Follow:

```
ai/verification-playbook.md
```

System verification requires executing all scripts in:

```
scripts/verification/
```

Verification checks:

1. functional correctness
2. contract compliance
3. system health

If verification fails:

```
verification
  ↓
incident record
  ↓
fix
  ↓
verification again
```

Repeat until verification passes.

---

## Stage 6 — Engineering Journal Entry

State must be `RELEASE_APPROVED` before a journal entry is written.
`scripts/execution-supervisor.sh` sets this state only when
`VERIFICATION_PASS == true`. Do not write a journal entry if state has
not reached `RELEASE_APPROVED`.

After verification passes, append an entry to:

```
ai/engineering-journal.md
```

The entry must include:

- date
- feature
- phase
- spec
- spec version
- tasks
- implementation notes
- pattern updates
- incidents (if any)

---

## Stage 7 — Completion

After the journal entry:

1. Update the spec status to `implemented`
2. Update the capability backlog to reflect completion

---

## State Chain

The full state machine chain for a registered feature:

```
RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE →
VERIFICATION_REQUIRED → RELEASE_APPROVED
```

Managed by `scripts/state-manager.sh` with live state in `ai/state_registry.json`.
Features not in the registry pass with a warning (graceful degradation for legacy
features). New features must be registered before pipeline execution.

---

## Execution Guarantees

The execution controller guarantees:

- spec-driven development
- architectural phase containment
- contract compliance
- deterministic verification
- engineering traceability

Agents must not bypass this controller.
