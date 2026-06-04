# ENGINEERING_OS.md

## Purpose

This document describes the **Engineering Operating System (Engineering OS)** used by this repository.

The Engineering OS defines how capabilities move from product ideas to verified production code through a deterministic engineering pipeline enforced by the repository's AI control layer.

This document exists so that **AI agents, developers, and future sessions can immediately understand the system architecture** without reconstructing it from scattered documents.

This repository uses a **spec-driven engineering protocol** rather than ad-hoc feature implementation.

All engineering work must follow this system.

---

# Core Principle

Engineering work is treated as a **deterministic pipeline**, not an open-ended development process.

The pipeline converts:

```
capability
↓
specification
↓
tasks
↓
implementation
↓
verification
↓
journal
```

Each stage is enforced by a control layer document.

Agents must not bypass this pipeline.

---

# Engineering Pipeline

The full pipeline is:

```
capability backlog
↓
SPEC COMPILER           (state → SPEC_LOCKED)
↓
specification
↓
task graph              (state → TASK_GRAPH_LOCKED)
↓
EXECUTION LOOP CONTROLLER
↓
[invariant gate]        (state → EXECUTION_ACTIVE)
↓
task execution
↓
[invariant gate]        (state → VERIFICATION_REQUIRED)
↓
verification gate       (state → RELEASE_APPROVED)
↓
engineering journal
↓
capability completed
```

Each stage is defined by the AI control layer.

Enforcement checkpoints are active at every state transition. A feature cannot
advance past a stage unless the enforcement layer at that boundary passes.

---

# Control Layer Overview

The Engineering OS is implemented through documents located in:

```
ai/
```

Each document defines a specific control surface.

The control layer is organized into **three domains**:

Architecture Authority
Engineering Protocol
Operational Safety

---

# Architecture Authority

These documents define **what the system is allowed to do**.

They are the highest authority.

## product-invariants

```
ai/product-invariants.md
```

Defines non-negotiable system properties.

Examples include:

* strict tenant isolation
* membership-derived RBAC authority
* immutable audit logging
* append-only ingest pipeline
* UUID identity membrane

No capability may violate these invariants.

If a capability conflicts with an invariant, it must be redesigned.

---

## runtime-contracts

```
ai/runtime-contracts.md
```

Defines runtime interaction rules between services.

Examples:

* backend owns database access
* frontend communicates only via API
* environment variables come from the adapter-configured environment path
* services are orchestrated through Docker Compose

Capabilities must respect these contracts.

---

## service-boundaries

```
ai/service-boundaries.md
```

Defines ownership of system components.

Examples:

backend owns:

* database models
* migrations
* API routes

frontend owns:

* UI
* API client
* user interaction logic

No service may directly modify another service's data.

---

# Engineering Protocol

These documents define **how work is produced**.

---

## spec-compiler

```
ai/spec-compiler.md
```

The spec compiler converts capabilities into specifications and task graphs.

Pipeline:

```
capability
↓
invariant validation
↓
architecture boundary check
↓
pattern selection
↓
spec generation
↓
spec approval
↓
task generation
↓
execution handoff
```

Compilation halts if:

* invariants are violated
* runtime contracts are violated
* service boundaries are violated
* required patterns do not exist
* spec duplicates an existing feature

---

## spec-generation

```
ai/spec-generation.md
```

Defines the structure of a valid engineering specification.

Every spec must include:

* Status
* Phase
* Capability description
* Data model changes
* API surface
* frontend surface
* operational workflow
* dependencies
* acceptance criteria
* out-of-scope definitions

Specs begin in status:

```
draft
```

Only approved specs may produce tasks.

---

## spec-to-task-playbook

```
ai/spec-to-task-playbook.md
```

Defines how specs are decomposed into tasks.

Tasks are numbered sequentially:

```
tasks/<feature>-001.md
tasks/<feature>-002.md
...
tasks/<feature>-NNN.md
```

The number of tasks depends on feature complexity.

Tasks must:

* target a single engineering layer
* declare dependencies
* define acceptance criteria
* identify files likely to be modified

---

## execution-loop-controller

```
ai/execution-loop-controller.md
```

Defines the deterministic task execution pipeline.

Execution sequence:

```
tasks
↓
implementation
↓
verification
↓
engineering journal
↓
completion
```

The controller also enforces **phase boundaries**.

---

# Product Phases

Product architecture evolves through defined phases.

Phase specifications live in:

```
specs/phases/
```

Example:

```
specs/phases/phase-1.md
specs/phases/phase-2.md
```

Each phase file declares its identity:

```
Phase: phase-x
```

Capabilities must declare a phase tag.

Example:

```
phase: phase-2
```

The execution controller validates phase consistency across:

* capability backlog
* spec
* journal entry

---

# Capability Backlog

Capabilities originate in:

```
product/capability-backlog.md
```

Lifecycle states are defined by level-2 headings in that document.

Example:

```
## Pending
## In Spec
## In Development
## Completed
```

The execution controller reads these headings to determine capability state.

States must not be hardcoded.

---

# Coding Patterns

Implementation must follow repository coding patterns defined in:

```
ai/coding-patterns.md
```

Patterns include:

Backend patterns
Frontend patterns
Audit logging patterns
Tenant filtering patterns

Agents must not invent new patterns.

If a feature requires a pattern that does not exist, the agent must stop and propose a pattern amendment.

---

# Operational Safety

These documents define **how the system detects and responds to failure**.

---

## verification-playbook

```
ai/verification-playbook.md
```

Defines the verification gate executed after implementation.

Verification scripts are located in:

```
scripts/verification/
```

Scripts follow numeric ordering:

```
001-system.sh
002-<name>.sh
003-<name>.sh
```

Verification executes scripts in lexical order.

If any script fails, verification fails.

The feature must be fixed before continuing.

---

## debug-playbook

```
ai/debug-playbook.md
```

Defines a deterministic debugging procedure.

Used when system failures occur.

---

## incidents

```
ai/incidents/
```

Root-cause documentation for system failures.

Incidents record:

* failure description
* root cause
* fix
* prevention strategy

---

## engineering-journal

```
ai/engineering-journal.md
```

Append-only history of feature implementations.

Each entry records:

* date
* feature
* phase
* spec
* spec version
* tasks
* implementation notes
* incidents

The journal preserves system evolution.

---

## pre-commit-gate

```
.git/hooks/pre-commit
```

Artifact trail enforcement. Blocks commits that touch task files without a
corresponding spec. Checks that the OS execution token exists before allowing
task generation. Runs a lightweight invariant scan (INV-003) on every commit.

---

## state-manager

```
scripts/state-manager.sh
ai/state_registry.json
```

State machine enforcement. Tracks feature lifecycle state in
`ai/state_registry.json`. Every pipeline stage transition is validated against
the expected prior state. Invalid transitions exit with status 2, blocking
the pipeline.

State chain:

```
RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE →
VERIFICATION_REQUIRED → RELEASE_APPROVED
```

---

## invariant-engine

```
scripts/invariant-check.sh
ai/invariant-registry.md
```

Invariant engine enforcement. Runs automated checks against ratified product
invariants before task execution begins and again before verification runs.
Exits 2 if any ratified invariant is violated.

Ratified invariants are programmatically detectable. Candidate invariants are
recorded in `ai/invariant-registry.md` but not yet enforced.

---

# Repository Navigation

The repository map is documented in:

```
ai/repo-index.md
```

This document provides a compact navigation reference for the entire system.

---

# Development Philosophy

This repository does not implement features through ad-hoc coding.

Instead it uses:

```
capability
↓
specification
↓
tasks
↓
implementation
↓
verification
↓
journal
```

This ensures:

* architectural integrity
* deterministic engineering workflows
* traceable system evolution
* safe AI-assisted development

---

# Enforcement Architecture

**Process correctness is enforced by machine gates, not documentation.**

Documentation describes what the system does. Machine gates prevent it from doing
anything else. The three enforcement layers below are the actual authority.

Three independent layers guard the pipeline.

Each layer is sufficient to block execution independently.
All three must pass for a capability to advance.

---

## Layer 1 — Artifact Trail

The pre-commit hook blocks commits that violate the artifact trail invariant.
The OS execution token (`/tmp/.os-compile-token`) is written by
`scripts/compile-spec.sh` and consumed (single-use, deleted) by
`scripts/generate-tasks.sh`. Task generation cannot proceed without this token.

Relevant files:

```
.git/hooks/pre-commit
scripts/compile-spec.sh
scripts/generate-tasks.sh
```

---

## Layer 2 — State Machine

Feature lifecycle state is tracked in `ai/state_registry.json` managed by
`scripts/state-manager.sh`. Pipeline scripts require a specific state before
advancing and reject invalid transitions (exit 2).

Relevant files:

```
scripts/state-manager.sh
ai/state_registry.json
```

---

## Layer 3 — Invariant Engine

`scripts/invariant-check.sh` runs before task execution begins and before
verification runs. It checks all ratified invariants from `ai/invariant-registry.md`.
Exit 2 blocks the pipeline.

Relevant files:

```
scripts/invariant-check.sh
ai/invariant-registry.md
```

---

# Summary

The Engineering OS provides:

Deterministic engineering
Architecture enforcement
Pattern consistency
Verification gating
Incident traceability
Engineering memory

The result is a controlled development environment where capabilities are compiled into production features through a structured pipeline.

All agents and developers working in this repository must follow this system.
