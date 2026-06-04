# Verification Playbook

## Purpose

This document defines the deterministic verification procedure that must
be executed after feature implementation and before a feature is recorded
in the engineering journal.

Verification ensures that implemented work:

- satisfies the feature specification
- respects architectural constraints
- does not break system operation

A feature is not considered complete until verification passes.

---

## Verification Gate

Verification occurs immediately after implementation.

Workflow position:

```
implementation
  ↓
[invariant gate]  (scripts/invariant-check.sh — state: VERIFICATION_REQUIRED)
  ↓
verification
  ├── PASS → state: RELEASE_APPROVED → engineering journal entry
  └── FAIL → incident record → fix → verification
```

The invariant gate runs before verification scripts. `scripts/execution-supervisor.sh`
enforces this. If the invariant gate exits 2, verification is blocked.

Journal entries must only be written after verification passes AND state reaches
`RELEASE_APPROVED`.

---

## Verification Procedure

Verification must check three layers.

### 1. Functional Verification

Confirm the feature behaves according to the spec.

Use the acceptance criteria defined in the spec document.

Example checks:

- new API endpoints respond correctly
- UI behavior matches expected workflow
- database records reflect intended changes

---

### 2. Contract Verification

Confirm implementation does not violate control layer rules.

Check against:

- `ai/product-invariants.md`
- `ai/runtime-contracts.md`
- `ai/service-boundaries.md`
- `ai/coding-patterns.md`

Example checks:

- tenant isolation preserved
- UUID identity membrane preserved
- audit logging emitted for state changes
- frontend does not access database directly

---

### 3. System Verification

Confirm the system still runs correctly.

#### Verification Script Ordering

Verification scripts must be stored in:

```
scripts/verification/
```

Scripts must follow a numeric prefix convention:

```
scripts/verification/001-system.sh
scripts/verification/002-security.sh
scripts/verification/003-performance.sh
```

Scripts are executed in lexical order. This ensures deterministic execution
order when multiple verification scripts exist.

Each script must exit with status 0 on success. Verification fails if any
script exits with a non-zero status.

Agents must execute all verification scripts during system verification.
System verification must not be performed manually when scripts are available.

Run:

```bash
for script in scripts/verification/*.sh; do
  bash "$script"
done
```

System verification is considered successful if all scripts exit without error.

Current verification scripts:

- `scripts/verification/001-system.sh` — docker services, backend health, smoke tests, frontend reachability

---

## Failure Handling

If verification fails:

1. Record the failure in `ai/incidents/`.
2. Identify the root cause.
3. Implement a fix.
4. Run verification again.

Verification must pass before a journal entry is written.

---

## Verification Mode

Default mode: **DELTA ONLY**

A block verification script must verify only:

- files/surfaces touched by that block
- immediately dependent behavior
- TypeScript build sanity (once per script)

No verification script may invoke earlier block scripts. Each script is
self-contained.

### Full Regression

Full regression runs only when explicitly requested:

- Directive includes: `FULL REGRESSION REQUIRED`
- Or operator runs: `scripts/verification/run-full-regression.sh`

Full regression is the **only** place that invokes multiple verification
scripts. It runs them sequentially and reports aggregate results.

### Stale Assertion Policy

Verification scripts must assert the **current** product contract.

When a later block supersedes UI or behavior from an earlier block,
the earlier block's script must be updated to reflect the new contract.
Do not preserve assertions for removed features.

Example: when P8.7 replaced per-field Accept/Reject with ghost values,
scripts 149–152 were updated to assert the ghost-state contract instead
of the removed suggestion chip UI.

---

## Verification Completion

Verification is complete when:

- spec acceptance criteria are satisfied
- no architectural contracts are violated
- system health checks pass

Only then may the feature be recorded in `ai/engineering-journal.md`.
