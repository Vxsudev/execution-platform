# ADR-000 — Product v1 Scope and Boundaries

## Status
accepted (2026-06-09 — CTX-09…CTX-13 promoted into approved Context; acceptance rationale in §Acceptance)

## Date
2026-06-09

## Layer
L1 Intent (cross-cutting scope/boundary decision)

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md` (Process Constitution §11 ADR policy)
- `sdlc/01-context/context-synthesis-v0.md` (CTX-SYN-001 v0.2.0, approved 2026-06-09;
  specifically CTX-09, CTX-10, CTX-11, CTX-12, CTX-13)
- `sdlc/02-intent/product-intent-brief.md` (v0.3.0 §10 v1 scope)

## Downstream Consumers
- Product Requirements Document (L1)
- Actor / Role Catalog (L1)
- Non-Functional Requirements (L1)
- All L2+ artifacts and any future v1 build work

---

## Context

`execution-platform` has, through L0 Context and the draft L1 Product Intent Brief,
been framed expansively: a UI + management-execution dashboard intended to sit atop
future operations agents. On 2026-06-07 the founder (Vijay) issued a v1 scope narrowing
(captured as SRC-005): *"Keep it simple, ability to create and edit experiment. Use
access control like we already have. Just a nicer table editor."*

A prior architectural assumption — that "access control like we already have" / "OPS
Cloud" implied reuse of the existing **NDT-SaaS** platform — has been **corrected by the
operator**: `execution-platform` is a **completely separate application** from NDT-SaaS.
This ADR records the resulting v1 scope and the hard boundaries, so that implementation
does not begin under the wrong assumptions.

This ADR is recorded under Constitution §11 (a cross-cutting decision constraining
downstream artifacts that is not already fixed by an approved upstream artifact). It is
**proposed**, not accepted: it leans on SRC-005, which is newly captured primary evidence
not yet promoted into approved Context, and on an operator correction; both should be
ratified through review before this ADR is `accepted`.

## Decision

`execution-platform` **v1** is a **separate application** whose initial product scope is a
**simple controlled table editor** for **experiment / work-item / task** rows.

### Recorded boundaries

1. **Separate from NDT-SaaS.** `execution-platform` is a completely separate application
   from NDT-SaaS, with no dependency on it, unless a later recorded direction states
   otherwise.
2. **"OPS Cloud" / "access control like we already have" does not imply NDT-SaaS reuse.**
   It denotes a *similar, simple access-control pattern* for the separate application.
   The stakeholder follow-up "Yes" to an either/or question was ambiguous; the operator
   correction is the disambiguating authority.
3. **No escalation-to-Vijay modeled pathway.** Escalation is not built as a product
   pathway in v1.
4. **No dashboard and no operations agents in v1.** These remain future direction, not v1
   build scope.
5. **Access control pattern required; exact design unresolved.** v1 needs *some* simple
   access-control pattern, but its exact design is deferred to a later layer.
6. **Mandatory-field policy unresolved.** Experiments/work-items/tasks share the same
   columns in v1; which columns (if any) are mandatory is not yet decided.
7. **The SDLC corpus governs product definition but is not product scope.** The
   governance artifacts (Constitution, L0 Context, L1 Intent) define *how* the product is
   specified; they are not themselves features to be built.

## Consequences

- The draft Product Intent Brief is narrowed to the v1 table editor (its §10); the
  broader vision is retained as direction, not v1 build scope.
- Downstream artifacts must **not** import or assume NDT-SaaS architecture, auth, data
  model, or access-control implementation.
- Downstream artifacts must **not** model escalation, approval/acceptance, dashboards, or
  operations agents as v1 scope.
- Frontend/backend technology stack remains **unchosen**; this ADR makes no technology
  decision.
- Unresolved items (mandatory-field policy, exact access-control design, the
  experiment/work-item/task distinction, OQ-01 track placement) are carried forward to
  the PRD / L2 / L3 layers as appropriate.

## Acceptance

Per Constitution §11, this ADR enters `accepted` after review confirms no conflict with
the Constitution or approved upstream artifacts. That review is complete as of 2026-06-09.

**Acceptance rationale:**
- The separate-app boundary is now **approved Context** (CTX-11, CTX-SYN-001 v0.2.0).
  No conflict with the Process Constitution — the Constitution makes no NDT-SaaS
  assumption; CTX-11 corrects a prior misinterpretation, not the Constitution itself.
- The v1 table-editor scope is now **approved Context** (CTX-09, CTX-13).
- No escalation pathway is now **approved Context** (CTX-10).
- The access-control-as-pattern constraint is now **approved Context** (CTX-12).
- All unresolved items (mandatory-field policy, exact access-control design, OQ-01 track
  placement, experiment/work-item/task distinction) are **explicitly deferred** in both
  the ADR Consequences section and the approved Context §4.
- No conflict with the Process Constitution or any approved upstream artifact was found.
- The operator correction grounding CTX-11 has been reviewed and recorded into approved
  Context; it is no longer a "raw" correction awaiting ratification.

This ADR is **append-only** per Constitution §11; the above section replaces the
"Why proposed" section as the acceptance record. It is not edited; it is superseded
only by a new ADR.

## Alternatives considered

- **Reuse NDT-SaaS access control / treat execution-platform as part of NDT-SaaS** —
  **rejected** by operator correction: the two are separate applications.
- **Build the full dashboard/agents vision as v1** — **deferred**: SRC-005 narrows v1 to
  a simple table editor; the broader vision is future direction.
