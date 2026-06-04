# SYSTEM SPINE PLAYBOOK

## Purpose

Define a repeatable capability sequence to transform a fragmented or partially-built system into a controlled, self-validating, self-constraining system spine.

This playbook is executed when:
- system correctness is uncertain
- verification is unreliable
- control-layer artifacts are stale or contradictory
- multiple surfaces exist with unclear authority
- RBAC and constraints are implicit

---

## Outcome

After executing this playbook, the system must be:

- Deterministic in behavior
- Verifiable via authoritative gates
- Non-ambiguous in structure and routing
- Explicit in access control
- Impossible to misuse (invalid states prevented)
- Self-explaining via control-layer artifacts

---

## Capability Sequence (Canonical)

Execute in strict order:

### 1. CONTROL_SURFACE_FREEZE

**Goal:**
Capture a stable, immutable snapshot of system state.

**Output:**
- recon artifact
- baseline commit reference
- known anomalies (no fixes)

**Rule:**
No mutations. Only state capture.

---

### 2. VERIFICATION_SYSTEM_RECOVERY

**Goal:**
Restore verification as a trusted control gate.

**Actions:**
- enforce DELTA-ONLY execution
- classify all failures
- eliminate duplicate verification streams

**Outcome:**
Verification becomes meaningful again.

---

### 3. VERIFICATION_SYSTEM_CANONICALIZATION_LOCK

**Goal:**
Make verification deterministic and binary.

**Actions:**
- canonicalize script index
- move obsolete → `_legacy/`
- isolate real regressions → `_quarantine/`
- repair drifted assertions

**Outcome:**
PASS = truth, FAIL = block

---

### 4. REPO_INDEX_REWRITE

**Goal:**
Align control-layer map with actual repository state.

**Actions:**
- rebuild `ai/repo-index.md` from filesystem truth
- correct counts, routes, modules
- label canonical vs legacy surfaces

**Outcome:**
System is accurately described.

---

### 5. CANONICAL_SURFACE_RESOLUTION

**Goal:**
Eliminate structural ambiguity.

**Actions:**
- classify every route/page:
  - canonical
  - legacy-retained
  - redirect-only
  - deep-link-only
  - orphan
- remove orphans
- enforce single canonical path per surface

**Outcome:**
One way to do everything.

---

### 6. RBAC_CONTRACT_RECONCILIATION

**Goal:**
Make access control explicit and enforced.

**Actions:**
- build role × surface matrix
- align backend guards + frontend gating
- remove hidden privilege paths

**Outcome:**
Who can do what is deterministic.

---

### 7. CONTROL_LAYER_CONSOLIDATION

**Goal:**
Unify all control-layer artifacts.

**Actions:**
- align:
  - repo-index
  - system-map
  - service-boundaries
  - architecture-index
  - MEMORY
- remove naming and semantic drift

**Outcome:**
System is self-explaining and non-contradictory.

---

### 8. SYSTEM_CONSTRAINTS_LOCK

**Goal:**
Prevent invalid states at runtime.

**Actions:**
- define invariants across:
  - datasets
  - reports
  - templates
  - workflows
  - RBAC mutations
- enforce in:
  - backend (authoritative)
  - frontend (preventive)
- add invariant verification gate

**Outcome:**
System cannot be misused.

---

## Final State Definition

A system spine is complete when:

- All verification gates PASS
- No duplicate or ambiguous surfaces exist
- All control-layer artifacts agree
- RBAC is explicit and enforced
- All invariants are enforced at runtime
- No invalid state can be produced

---

## Gate Stack (Reference)

Typical final gate chain:

- 999 — verification canonicalization
- 998 — repo index authority
- 997 — canonical surface resolution
- 996 — RBAC contract
- 995 — control layer consolidation
- 994 — system constraints

Each gate must assert a distinct slice of the system contract.

---

## Anti-Patterns

Do NOT:

- skip CONTROL_SURFACE_FREEZE
- attempt fixes before verification recovery
- leave multiple canonical paths active
- rely on frontend-only enforcement
- allow expected failures in verification
- let control-layer docs drift from code

---

## Usage Guidance

Use this playbook when:

- inheriting a messy codebase
- preparing a system for scale
- converting a prototype into a production system
- before monetization or external distribution

---

## Strategic Value

This playbook produces:

- Positioning → system defines correctness
- Control Points → ingestion, routing, validation
- Integration → system sits between inputs and outputs
- Decision Rights → system enforces behavior

---

## Key Principle

Build systems that cannot be used incorrectly.
