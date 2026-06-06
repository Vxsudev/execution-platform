# Product Intent Brief — Execution-Platform

## Status
draft

## Layer
L1 Intent

## Version
0.1.0

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md` (Process Constitution v1.0.0)
- `sdlc/01-context/context-synthesis-v0.md` (CTX-SYN-001, approved 2026-06-05)
- `sdlc/01-context/glossary-seed.md` (approved 2026-06-05)
- `sdlc/02-intent/l1-intent-recon.md` (approved 2026-06-06)

## Downstream Consumers
- Actor / Role Catalog (L1)
- Product Requirements Document (L1)
- Non-Functional Requirements (L1)

---

## 1. Artifact Header

| Field | Value |
|---|---|
| Status | draft |
| Layer | L1 Intent |
| Version | 0.1.0 |
| Created | 2026-06-06 |

---

## 2. Product Intent Summary

`execution-platform` is the intended replacement for the astraX experiment tracking workbook. The workbook is explicitly acknowledged as cumbersome [CTX-07]; it requires direct Excel editing and does not serve as a durable surface for reading and acting on organizational execution state.

The intended product is a **UI and dashboard** whose purpose is **management execution** — enabling leadership to read rolled-up execution state across the organization and use it to run the business [CTX-07]. The dashboard is intended to remain the durable read surface as the organization eventually runs operations through AI agents (sales, manufacturing, service) [CTX-07].

The product must preserve and enforce the experiment discipline already established in the workbook: hypothesis-framed units of work with pre-written measurable success criteria, single ownership, and a weekly update cadence [CTX-02, CTX-01]. The current workbook demonstrates that this discipline leaks without enforcement: hypothesis-less, owner-less rows enter the experiment log and are noticed as a defect [CTX-03].

Work is organized by business tracks [CTX-04]. The track set is real but unstable at the edges; the product must treat it as configurable data [CTX-04]. Customer-facing tracks follow a discovery-before-experiment workflow, gathering intelligence from prospects before committing to experimentation [CTX-08].

The working name for this product in the evidence is the **accountability app** [Glossary Seed: accountability app].

---

## 3. Problem Statement

The following problems are established by approved L0 Context. No problem is stated here that is not grounded in approved CTX assertions.

### P-01 — The spreadsheet is cumbersome [CTX-07]

The founder explicitly describes the Excel workbook as cumbersome and states the intent to replace it: "I know you don't have to edit the Excel sheet. It's cumbersome. … Instead, we do that using a user interface." Direct spreadsheet editing is the wrong interaction model for the team's execution rhythm.

### P-02 — Experiment discipline demonstrably leaks [CTX-03]

The workbook's log contains hypothesis-less, owner-less, status-less rows — task-shaped entries that have entered the experiment log without conforming to the experiment format. The founder notices and treats missing ownership as a defect. The discipline of "experiments without hypotheses are just tasks" is stated but not enforced by the current artifact.

### P-03 — Execution state is not a durable management surface [CTX-07]

The workbook was designed for management execution, but it does not serve as a persistent read surface that leadership can use to track organizational state without direct editing. The intended future state is a dashboard that "pulls from everywhere" and remains the control surface above operations agents.

### P-04 — The track taxonomy is unstable and unresolved [CTX-04]

The track set (T1 Device through T6 Sales partner) is real but in motion: a T7 internal tooling track was floated without recorded adoption, sub-tracks are verbally agreed but structurally absent, and the accountability app itself has no home track. Any product that hard-codes the taxonomy will be immediately out of date.

### P-05 — The post-experiment lifecycle is absent [CTX-05]

The execution status vocabulary ends at Complete, Blocked, or Inconclusive. What happens after Complete — closure, archival, learning consolidation — is unevidenced. This leaves the execution record incomplete as a management tool.

---

## 4. Product Direction

The following directional statements are grounded in approved CTX assertions. None constitutes a design decision, implementation choice, or architectural commitment.

### D-01 — Replace spreadsheet interaction with a UI and dashboard [CTX-07]

The product replaces direct Excel editing with a purpose-built interface. The dashboard replaces the manual filtered-summary view that currently drives standups and the Monday leads meeting.

### D-02 — Support management execution as the primary purpose [CTX-07, CTX-01]

The dashboard's job is to make rolled-up execution state legible to leadership. This maps to the existing cadence: Friday updates → standup off filtered summary → Monday leads review. The product must make this workflow fluent without requiring spreadsheet access.

### D-03 — Preserve and enforce experiment discipline [CTX-02, CTX-03]

The product must preserve the hypothesis format, success-criteria-before-start requirement, single-owner requirement, ≤2-week atomicity bound, and the status vocabulary. It must actively prevent or flag entries that do not conform — addressing the leakage problem visible in P-02.

### D-04 — Make the track taxonomy configurable [CTX-04]

Tracks are an organizing structure, not a fixed enumeration. The product must support a configurable track set rather than hard-coding T1–T6. Sub-track structure is emerging and must be accommodated as configurable data.

### D-05 — Capture outcomes and trigger next actions [CTX-06]

The product must support post-experiment recording: the outcome/finding, its interpretation, and the actionable next step the result triggers. This preserves the learning-as-attribute model already established in the workbook.

### D-06 — Support the discovery-before-experiment workflow for customer-facing tracks [CTX-08]

Customer-facing work follows a distinct two-phase structure: a discovery/outreach thread followed by technical experiments. The product must accommodate this workflow rather than forcing all work into the experiment format from the start.

### D-07 — Provide a durable read surface above future operations agents [CTX-07]

The dashboard is intended to remain the management read surface as the organization's operations are progressively backed by AI agents (sales, manufacturing, service). The product must be designed as a durable interface, not a one-cycle tool.

---

## 5. Goals

Goals are derived from approved CTX assertions. Each goal cites its grounding.

| Goal ID | Goal Statement | CTX Basis |
|---|---|---|
| G-01 | Enable management execution: provide leadership with a legible, up-to-date view of rolled-up execution state across all tracks and experiments. | CTX-07, CTX-01 |
| G-02 | Enforce experiment discipline: ensure that every tracked work item conforms to the hypothesis format, carries pre-written success criteria, has a single named owner, and respects the ≤2-week atomicity bound. | CTX-02, CTX-03 |
| G-03 | Support the weekly cadence: make the Friday-update → standup → Monday-leads-review workflow fluent without requiring direct spreadsheet editing. | CTX-01 |
| G-04 | Surface outcomes and next actions: after an experiment reaches a terminal status, capture the outcome/finding and the actionable next step it triggers. | CTX-06 |
| G-05 | Organize work by configurable tracks: maintain the track-based organizing structure while treating the track set and sub-track structure as configurable data, not a fixed enumeration. | CTX-04 |
| G-06 | Accommodate the discovery-before-experiment workflow: support customer-facing tracks where discovery outreach precedes and feeds technical experimentation. | CTX-08 |
| G-07 | Serve as the durable management surface above future operations agents: remain the read interface as sales, manufacturing, and service agents come online and produce execution data. | CTX-07 |

---

## 6. Non-Goals

The following are explicitly out of scope for this Product Intent Brief. They are not part of this intent and may not be introduced by downstream artifacts without new primary evidence or stakeholder validation as specified.

| Non-Goal | Authority |
|---|---|
| **Formal approval architecture** — no submit/approve/reject/revise lifecycle is established or intended at this stage. | CTX-SYN-001 §4 item 1; CON-002 held open; l1-intent-recon.md §6.2 item 1 |
| **Acceptance lifecycle** — no acceptance states (submitted, approved, rejected, revise) may be asserted or modeled. | CTX-SYN-001 §4 item 2; CON-002 |
| **Decision as an entity** — no Decision concept exists in any primary source and must not be introduced. | CTX-SYN-001 §4 item 3 |
| **Commitment as an atom** — no Commitment concept is evidenced and must not be introduced. | CTX-SYN-001 §4 item 4 |
| **Fixed track taxonomy** — T1–T6 is today's list; this product does not commit to a final enumeration. | CTX-04; CON-001 held open |
| **Dashboard readership beyond Vijay** — who else consumes the dashboard is an unresolved open question (OQ-10). No reader class beyond the founder may be asserted without new primary evidence. | CTX-SYN-001 §4 item 8; OQ-10 |
| **Agent ownership or attribution model** — how agent-produced work will be owned, attributed, or reviewed is not established. | CTX-SYN-001 §4 item 5 |
| **Technology choices** — no hosting platform, framework, language, or deployment topology is selected or implied. | F-08 explicitly open |
| **Implementation design** — no UI layout, API shape, database schema, or system architecture is defined at this layer. | Process Constitution §3 (L1 may not determine L3 concerns) |
| **Post-Complete lifecycle** — what happens after an experiment reaches Complete is unevidenced and remains an open question (OQ-09). | CTX-SYN-001 §4 item 7 |

---

## 7. Open Questions Blocking Approval

This Product Intent Brief may be drafted but **may not enter review** until the following open questions are resolved via new primary source capture. Resolving them requires a stakeholder session that generates new Source Materials (new SRC IDs in the Source Intake Register). Inference and assertion are not sufficient.

### OQ-01 — Track placement of the accountability app

**Question:** Was T7 (internal tooling track) formally adopted, or does the accountability app live inside a sub-track of T2 or T3, or is it considered organizational infrastructure outside the track system altogether?

**Why this blocks approval:** The Product Intent Brief cannot state the product's own place in the execution system without knowing whether it belongs to a track, a sub-track, or exists outside that structure. Any directional statement that implies a placement would assert beyond approved evidence.

**What this requires:** A new primary stakeholder capture (new SRC ID) recording Vijay's decision on track placement.

### OQ-03 — Meaning of "Escalate to Vijay" as a next action

**Question:** Does "Escalate to Vijay" describe a general escalation protocol — Vijay as the universal escalation terminal for any blocked or unresolved next action — or was it specific to the cited example? Who else, if anyone, is a valid escalation target?

**Why this blocks approval:** The Product Intent Brief describes the product as a management-execution tool. The escalation model is part of the accountability framing — knowing whether Vijay is the universal authority or one of several escalation targets shapes what the product must support. Asserting either without evidence would originate a concept absent from approved sources.

**What this requires:** A new primary stakeholder capture recording the escalation model.

### OQ-06 — Task support: first-class concept vs. leakage prevention

**Question:** Should execution-platform support tasks (hypothesis-less work items) as a distinct, intentional first-class concept — or is the product's intent to permit only framed experiments and prevent task-shaped entries entirely?

**Why this blocks approval:** This is a load-bearing intent decision. G-02 (enforce experiment discipline) and the entire framing of P-02 (leakage as a problem) depend on whether the product's stance is permissive (tasks are valid, tracked separately) or restrictive (tasks are forbidden in this system). The two positions produce fundamentally different product intents, and neither can be asserted from approved L0 evidence alone.

**What this requires:** A new primary stakeholder capture recording Vijay's position on task support.

---

## 8. Stakeholder Validation Questions

The following questions must be asked in a stakeholder session and captured as a new primary Source Material (new SRC ID). They are stated as questions only — they are not answered here.

1. **Track placement:** Should execution-platform / the accountability app live as a T7 internal tooling track, inside a sub-track of an existing track (e.g., T2 or T3), or does it exist outside the track system as organizational infrastructure? [Resolves OQ-01]

2. **Task support:** Should the product support tracking of tasks (hypothesis-less work items) as a distinct, first-class work type — or should the system enforce that only framed experiments may be entered, treating task-shaped entries as leakage to be prevented? [Resolves OQ-06]

3. **Escalation procedure:** When the workbook example says "Escalate to Vijay," does this describe a general escalation protocol — Vijay as the universal escalation terminal — or was it specific to that example? Who else, if anyone, can be an escalation target in the intended product? [Resolves OQ-03]

---

## 9. Acceptance Criteria

This Product Intent Brief may move from `draft` to `approved` when all of the following hold:

- [ ] All nine required sections are present and non-empty.
- [ ] Every claim in Sections 2–6 cites at least one CTX ID from CTX-SYN-001; no claim is made without traceable grounding.
- [ ] OQ-01, OQ-03, and OQ-06 are resolved via new primary Source Materials (new SRC IDs registered in the Source Intake Register); new captures are cited by source ID in the relevant sections.
- [ ] The goals (Section 5) are updated if stakeholder validation changes, adds, or removes a goal — with citation to the new source.
- [ ] The non-goals (Section 6) are confirmed or updated based on stakeholder validation — specifically that task support, escalation architecture, and track placement are reconciled against the validated position.
- [ ] No approval architecture, acceptance lifecycle, Decision or Commitment entity, fixed track taxonomy, or technology choice appears anywhere in the artifact.
- [ ] Dashboard readership beyond Vijay (OQ-10) is not asserted — either it remains open (if OQ-10 is still unresolved at approval time) or it is grounded in a newly captured source.
- [ ] The Glossary Seed terms are used as defined; no new terminology is introduced without evidence.
- [ ] All upstream authority artifacts (Process Constitution, CTX-SYN-001, Glossary Seed, L1 Intent Recon) are `approved` at review time.
- [ ] The artifact declares `Status`, `Layer`, `Version`, `Upstream Authority`, and `Downstream Consumers` in conformance with Constitution §7.
- [ ] Review is logged per Constitution §6 (`draft` → `review` → `approved`); no bootstrap exception is claimed.
