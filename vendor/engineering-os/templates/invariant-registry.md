# Invariant Registry — TEMPLATE

## Purpose

Catalogue of all invariants extracted from project doctrine.
Each invariant is classified as RATIFIED (programmatically enforceable) or
CANDIDATE (requires runtime/human judgment).

RATIFIED invariants are enforced by `vendor/engineering-os/scripts/invariant-engine.sh`.
CANDIDATE invariants are recorded here but NOT enforced.

Source files:
- `<project doctrine paths — e.g. ai/product-invariants.md>`

---

## RATIFIED Invariants

Enforced by the invariant engine on every supervisor run.

| ID | Name | Source | Enforcement Level | Rule File |
|----|------|--------|-------------------|-----------|
| INV-001 | __short name__ | __doctrine ref__ | CHECK | `.engineering-os/invariants/INV-001-__name__.sh` |
| INV-002 | __short name__ | __doctrine ref__ | CHECK | `.engineering-os/invariants/INV-002-__name__.sh` |

### INV-001 Detail

**Invariant:** __precise statement__

**Check:** __concrete, programmatic check__

**Source citation:** "__quoted phrase from doctrine__" — `__source path__`

---

## Candidate Invariants

Ratified in doctrine but NOT yet programmatically enforceable without runtime
infrastructure. Captured here for future enforcement when detection becomes feasible.

| ID | Name | Source | Reason Not Enforced |
|----|------|--------|---------------------|
| CAND-001 | __short name__ | __source__ | __why runtime is required__ |
