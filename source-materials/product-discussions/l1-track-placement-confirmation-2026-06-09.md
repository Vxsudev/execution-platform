# SRC-006 — L1 Track Placement Confirmation

## Source Metadata

| Field | Value |
|---|---|
| **Source ID** | SRC-006 |
| **File path** | `source-materials/product-discussions/l1-track-placement-confirmation-2026-06-09.md` |
| **Source type** | Operator product classification confirmation |
| **Classification (COM §3)** | **Primary, internal** |
| **Provenance** | Operator confirmation of execution-platform's track placement within astraX's track taxonomy, captured 2026-06-09 |
| **Capturer** | Vasu (vasu@astraanalytical.com) |
| **Capture date** | 2026-06-09 |
| **Date / as-of date** | 2026-06-09 (confirmation date) |
| **Fidelity** | Verbatim statement preserved exactly; interpretation boundary documented |
| **Freshness class (COM §4)** | Time-sensitive |
| **Authority level** | Primary internal — operator product classification; resolves OQ-01 for Product Intent Brief |
| **Allowed usage** | Resolves OQ-01 track placement for Product Intent Brief; grounds CTX-14 (execution-platform classified under OPS Cloud track for product-intent purposes) |
| **Prohibited usage** | May not imply NDT-SaaS reuse or architectural coupling; may not define implementation architecture, access-control implementation, deployment, or technology; may not override ADR-000 separate-app boundary (CTX-11) |
| **Sensitivity** | Internal |
| **Notes** | Track classification is a product-organization concern, not an architectural decision. "OPS Cloud track" is a business classification only; it does not change the separate-app boundary established by CTX-11 and ADR-000. |

---

## 1. Verbatim Statement

> "execution-platform belongs under the OPS Cloud track"

---

## 2. Interpretation Boundary

The above statement resolves the product classification question (OQ-01: was T7
adopted, or does the accountability app live inside an existing track, or outside
the track system?).

### 2.1 What this statement resolves

- execution-platform is classified under the **OPS Cloud track** within astraX's
  track taxonomy for product-intent purposes.
- The app is not a T7 "internal tooling" track, not a sub-track of T2 or T3, and
  not outside the track system — it has a home track.

### 2.2 What this statement does NOT establish or authorize

1. **This does not merge execution-platform into NDT-SaaS.** The OPS Cloud track is
   a business classification, not an architectural coupling. ADR-000's separate-app
   boundary (CTX-11) remains fully in force.
2. **This does not change the separate-application architecture.** execution-platform
   remains a completely separate application from NDT-SaaS regardless of track
   classification.
3. **This does not create implementation architecture.** No hosting, deployment, auth,
   or stack decision follows from this classification.
4. **This does not define repository structure.** Track classification is a
   product-organization concern, not a code-organization concern.
5. **This does not define access-control implementation.** CTX-12's unresolved
   access-control design is not affected by this classification.
6. **This does not resolve the track taxonomy itself.** This classification provides
   execution-platform's home track; it does not resolve CON-001 or finalize the
   broader track set and sub-track structure.

---

## 3. Open Items Not Addressed by This Source

- Mandatory-field policy (CTX-13) — unresolved; deferred to PRD.
- Exact access-control design (CTX-12) — unresolved; deferred to PRD/L3.
- Experiment vs work-item vs task distinction beyond shared columns (CTX-09,
  CTX-13) — deferred to L2 Behavior / Domain Model.
- OQ-02 (approval authority) — unresolved; not addressed by this source.
- OQ-10 (dashboard readership beyond Vijay) — unresolved; not addressed by
  this source.
