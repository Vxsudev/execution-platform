# Directive Template — Engineering OS

This document is the standard scaffold for capability directives issued to agents
in this repository. Sections marked `[FILL: ...]` vary per capability and must be
completed by the operator issuing the directive. Prescriptive sections describe
enforcement structure; operator intent always takes precedence over scaffold structure.

---

# DIRECTIVE AUTHORITY

Directives are issued by the **operator** (the human or authorized automation
that initiates a capability). This template provides structure — it is not a
source of authority.

Rules:

- **Operator defines the capability.** The repo provides enforcement structure only.
- **No agent may originate a directive independently.** An agent that has not received
  a directive from the operator must not self-issue one using this template.
- **Operator intent overrides scaffold structure.** If the operator's directive
  omits or modifies a section, the agent follows the operator's version, not
  the template's default.
- **Template must not be cited as authority over the operator.** The enforcement
  layer, state machine, and invariant engine are the authorities — not this document.

---

# ENGINEERING OS BOOT

Before accepting this directive, the agent MUST complete the full OS boot sequence:

1. Run `/os-boot` and wait for STATUS: READY.
2. If STATUS: BLOCKED, resolve the blocking condition before proceeding.
3. Do not begin implementation while BLOCKED.

Reference: `ENGINEERING_OS.md`, `PROJECT_BOOTSTRAP.md`, `.claude/skills/os-boot/SKILL.md`

---

# ENFORCEMENT LAYER

Three enforcement layers are active in this repository. All three must pass before
any execution stage may proceed.

## Layer 1 — Artifact Trail

**Gate:** `.git/hooks/pre-commit` + OS execution token `/tmp/.os-compile-token`

Before proceeding, verify:
- `.git/hooks/pre-commit` exists and is executable
- The OS token will be written by `scripts/compile-spec.sh` before `scripts/generate-tasks.sh` is invoked
- Do NOT invoke `generate-tasks.sh` directly

If the pre-commit hook is missing: **STOP** and report.

## Layer 2 — State Machine

**Gate:** `scripts/state-manager.sh` + `ai/state_registry.json`

Before proceeding, verify:
- `ai/state_registry.json` exists
- `scripts/state-manager.sh` is executable

The state machine enforces this chain:

```
RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE →
VERIFICATION_REQUIRED → RELEASE_APPROVED
```

Each pipeline script (`compile-spec.sh`, `generate-tasks.sh`, `execution-supervisor.sh`)
requires the prior state and advances to the next. An invalid transition exits 2
and BLOCKS the pipeline.

## Layer 3 — Invariant Engine

**Gate:** `scripts/invariant-check.sh` exits 0

Before proceeding, run:

```bash
bash scripts/invariant-check.sh
```

If exit code is 2: **BLOCKED** — invariant violation detected. Do not proceed.
If the script is missing: report MISSING and halt.

The invariant engine runs twice during execution-supervisor.sh: before task
execution (pre-execution gate) and before verification (pre-verification gate).

---

# STATE MACHINE

Before execution begins, check the feature's current state:

```bash
bash scripts/state-manager.sh get [FILL: feature-slug]
```

Expected state at execution start: `TASK_GRAPH_LOCKED`

If state is not `TASK_GRAPH_LOCKED`:
- `RECON_READY`: compile-spec.sh has not been run — run it first
- `SPEC_LOCKED`: generate-tasks.sh has not been run — run it first
- `EXECUTION_ACTIVE` or later: execution already in progress or completed

Do not advance state manually. State is advanced by the pipeline scripts.

Live registry: `ai/state_registry.json`

---

# INVARIANT ENGINE

Before execution begins, verify all ratified invariants pass:

```bash
bash scripts/invariant-check.sh
```

Exit 0: all invariants pass — proceed.
Exit 2: invariant violation — **BLOCKED**. Do not proceed. Fix the violation first.

Ratified invariants are documented in `ai/invariant-registry.md`.
Adding new invariants requires updating both `ai/invariant-registry.md` and
`scripts/invariant-check.sh`.

---

# PRE-COMMIT / GIT GATE

The pre-commit hook at `.git/hooks/pre-commit` enforces:

1. **Artifact trail**: any commit touching `tasks/` must have a corresponding spec in `specs/`
2. **State gate**: if the feature being committed is registered in `ai/state_registry.json`
   with state `RECON_READY`, the commit is **blocked** (no task files before spec is locked)
3. **INV-003 lightweight check**: `infra/env/*.env.example` files must all exist

The hook does NOT block on missing spec for features not yet in the registry
(graceful degradation for legacy features — a warning is printed instead).

If a commit is blocked by the hook: resolve the underlying condition. Do NOT
bypass hooks with `--no-verify`.

---

# CAPABILITY

**Feature name:** `[FILL: SCREAMING_SNAKE_CASE slug, e.g. DEVICE_CALIBRATION_TRACKING]`

**Feature slug:** `[FILL: kebab-case slug, e.g. device-calibration-tracking]`

**Phase:** `[FILL: phase-N]`

**Objective:**

[FILL: 2-4 sentence description of what the capability delivers and why it is
being built. Include the user-facing outcome and the architectural motivation.]

**Spec:** `specs/[FILL: feature-slug].md`

---

# IMPLEMENTATION PLAN

[FILL: Task groups in execution order. Example structure below — replace entirely
with the actual task breakdown for this capability.]

```
Task Group 1 — [FILL: Layer name, e.g. Database]
  Task 001: [FILL: title]
  Layer: database | backend | frontend | scripts | verification

Task Group 2 — [FILL: Layer name]
  Task 002: [FILL: title]
  Layer: ...

Task Group N — Verification
  Task NNN: Create verification gate NNN-[FILL: feature-slug].sh
  Layer: verification
```

Execute in dependency order. Mark each task `in-progress` before starting,
`done` when all acceptance criteria are verified.

---

# VERIFICATION

After all tasks complete, verification MUST pass before the journal entry is written.

Enforcement gates that MUST pass (run these explicitly):

```bash
bash scripts/verification/279-os-enforcement-layer-v1.sh
bash scripts/verification/280-os-state-machine-v1.sh
bash scripts/verification/281-invariant-engine-v1.sh
bash scripts/verification/[FILL: NNN-feature-slug].sh
```

Full regression (when the directive includes FULL REGRESSION REQUIRED):

```bash
bash scripts/verification/run-full-regression.sh
```

No behavioral regression is permitted in gates 279, 280, or 281.

Reference: `ai/verification-playbook.md`

---

# STOP CONDITION

Stop ONLY when ALL of the following are true:

- [ ] All tasks in the implementation plan are marked `done`
- [ ] `bash scripts/invariant-check.sh` exits 0
- [ ] `bash scripts/state-manager.sh get [FILL: feature-slug]` returns `RELEASE_APPROVED`
- [ ] Verification gate `[FILL: NNN-feature-slug].sh` passes
- [ ] Gates 279, 280, 281 show no regression (still PASS)
- [ ] Engineering journal entry appended to `ai/engineering-journal.md`

Do NOT stop if any condition above is not met. Do NOT partially complete.

---

# ENGINEERING JOURNAL

After verification passes and state is `RELEASE_APPROVED`, append an entry to
`ai/engineering-journal.md` with the following fields:

```
### [FILL: YYYY-MM-DD] — [FILL: Feature Name]

**Phase:** [FILL: phase-N]
**Spec:** specs/[FILL: feature-slug].md
**Spec Version:** 1
**Tasks:** [FILL: tasks/feature-slug-001.md, ..., tasks/feature-slug-NNN.md]

**Implementation Notes:**
[FILL: 3-6 bullet points describing what was built, key decisions made,
and any non-obvious implementation choices.]

**Verification:**
Gate [FILL: NNN]: [FILL: X/Y] PASS

**Incidents:** None
```

The journal is append-only. Never modify existing entries.
