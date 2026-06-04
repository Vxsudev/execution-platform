# PROJECT_BOOTSTRAP.md

## Purpose

This file initializes the **Engineering Operating System** for this repository.

Any AI agent, developer, or automation entering this repository must read this file first and load the Engineering OS context before performing any work.

The Engineering OS defines the deterministic engineering pipeline used by this repository.

Agents must not begin implementation without loading this context.

---

# Boot Sequence

Upon entering the repository, perform the following initialization sequence.

---

## Step 1 — Load Engineering OS

Read:

```
ENGINEERING_OS.md
```

This document explains the full engineering protocol used by the repository.

It describes:

* the capability → spec → tasks pipeline
* the control layer architecture
* the verification gate
* the engineering journal

Agents must understand this system before continuing.

---

## Step 2 — Load Control Layer

Read the following documents in order:

```
ai/product-invariants.md
ai/runtime-contracts.md
ai/service-boundaries.md
ai/coding-patterns.md
ai/spec-compiler.md
ai/spec-generation.md
ai/spec-to-task-playbook.md
ai/task-generator.md
ai/task-graph.md
ai/execution-loop-controller.md
ai/execution-orchestrator.md
ai/verification-playbook.md
ai/debug-playbook.md
ai/architecture-index.md
ai/system-map.md
ai/invariant-registry.md
```

These documents define the system's architecture, engineering protocol, and operational safeguards.

Enforcement files (read if performing engineering work):

```
scripts/state-manager.sh      — state machine CLI
scripts/invariant-check.sh    — automated invariant gate
ai/state_registry.json        — live feature state registry
.git/hooks/pre-commit         — artifact trail gate
```

---

## Step 2.5 — Validate Enforcement Layer

Before loading the repository map, verify the enforcement layer is intact.

Check each of the following:

```bash
# Pre-commit gate
ls .git/hooks/pre-commit && test -x .git/hooks/pre-commit

# State machine
ls scripts/state-manager.sh && test -x scripts/state-manager.sh

# Invariant engine
bash scripts/invariant-check.sh
```

If any check fails:

**STATUS: BLOCKED** — do not proceed with engineering work until the enforcement
layer is restored.

- Missing `.git/hooks/pre-commit`: artifact trail is broken — commits may bypass spec gates
- Missing `scripts/state-manager.sh`: state machine is offline — pipeline order is unenforced
- `scripts/invariant-check.sh` exits 2: active invariant violation — system is in an invalid state

All three must pass before beginning implementation.

---

## Step 3 — Load Repository Map

Read:

```
ai/repo-index.md
```

This provides a compact map of the repository structure.

---

## Step 4 — Determine Current Engineering State

Read:

```
product/capability-backlog.md
ai/engineering-journal.md
```

These documents describe:

* pending capabilities
* active work
* completed features

---

# Engineering Rule

Agents must not implement features directly.

All work must follow the deterministic pipeline:

```
capability
↓
spec compiler
↓
specification
↓
tasks
↓
execution controller
↓
verification
↓
engineering journal
```

Agents must not bypass this pipeline.

---

# Verification Requirement

After implementation tasks complete, verification must run before the capability can be marked complete.

Verification scripts are located in:

```
scripts/verification/
```

Execution mode is **DELTA-ONLY** (declared in `ai/verification-playbook.md`):

- If the capability's spec declares `## Verification Scripts`, the supervisor runs only those scripts.
- Otherwise, the supervisor runs the full active corpus (top-level `*.sh`), excluding `_legacy/`, `_quarantine/`, and `run-full-regression.sh`.

Permanent control-layer gates:

```
scripts/verification/279-os-enforcement-layer-v1.sh
scripts/verification/280-os-state-machine-v1.sh
scripts/verification/281-invariant-engine-v1.sh
scripts/verification/995-control-layer-consolidation.sh
scripts/verification/996-rbac-contract-reconciliation.sh
scripts/verification/997-canonical-surface-resolution.sh
scripts/verification/998-repo-index-authority.sh
scripts/verification/999-canonicalization-lock.sh
```

Full regression entrypoint:

```
scripts/verification/run-full-regression.sh
```

Every active script must pass. Retired scripts live under `_legacy/` and are never executed. Known regression candidates live under `_quarantine/` and are excluded from the PASS gate (see `ai/incidents/` for triage).

---

# Incident Protocol

If verification fails or system errors occur, an incident record must be created in:

```
ai/incidents/
```

The incident must document:

* failure
* root cause
* remediation
* prevention strategy

---

# Engineering Memory

All completed capabilities must be recorded in:

```
ai/engineering-journal.md
```

The journal preserves system history and architectural decisions.

Entries must include:

* feature
* phase
* spec
* spec version
* tasks executed
* implementation notes
* incidents

---

# System Philosophy

This repository does not use ad-hoc feature development.

Instead it uses a deterministic engineering pipeline that ensures:

* architectural integrity
* pattern consistency
* safe AI-assisted development
* traceable system evolution

All agents and developers must follow this system.
