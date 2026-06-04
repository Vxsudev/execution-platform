# Invariant Registry — execution-platform

## Purpose

Catalogue of invariants enforced by the vendored Engineering OS invariant
engine (`vendor/engineering-os/scripts/invariant-engine.sh`) against the
project overlay (`.engineering-os/invariants/*.sh`).

At control-plane bootstrap (pre-Context), only **process** invariants exist.
**Domain** invariants are forbidden until L2 Behavior is approved
(Process Constitution §8, enforced by INV-005).

Source doctrine:
- `sdlc/00-process-constitution/sdlc-architecture-directive.md`
- `sdlc/01-context/context-operating-model.md`

---

## RATIFIED Invariants

Enforced by the invariant engine on every supervisor run (pre-execution and
pre-verification) and via `os-boot-check`.

| ID | Name | Source | Enforcement | Rule File |
|----|------|--------|-------------|-----------|
| INV-001 | Vendored OS snapshot is immutable | Integration recon; Constitution §9 | CHECK | `.engineering-os/invariants/INV-001-source-os-immutable.sh` |
| INV-002 | No application code before L5 Build | Constitution §10 | CHECK | `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh` |
| INV-003 | Every SDLC artifact declares Layer + Status | Constitution §3, §6 | CHECK | `.engineering-os/invariants/INV-003-artifact-declares-layer-status.sh` |
| INV-004 | ADRs append-only and well-formed | Constitution §11 | CHECK (structural) | `.engineering-os/invariants/INV-004-adr-append-only.sh` |
| INV-005 | Domain Constitution forbidden pre-L2 | Constitution §8 | CHECK | `.engineering-os/invariants/INV-005-domain-constitution-derived.sh` |
| INV-006 | Every SDLC artifact declares traceability | Constitution §7 | CHECK | `.engineering-os/invariants/INV-006-artifact-declares-traceability.sh` |

---

## Candidate Invariants

Ratified in doctrine but requiring runtime/history infrastructure beyond a
static check.

| ID | Name | Source | Reason Not Fully Enforced |
|----|------|--------|---------------------------|
| CAND-001 | ADR temporal append-only (no edits to accepted ADRs) | Constitution §11 | Requires git-history diffing; partially covered by INV-004 (structural) + pre-commit hook |
| CAND-002 | Traceability closes end-to-end before L5 | Constitution §7 | Requires a populated corpus (L1–L4) to validate forward/backward closure |
