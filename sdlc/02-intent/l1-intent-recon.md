# L1 Intent Recon — Execution-Platform

## Status
approved (L1 review 2026-06-06)

## Layer
L1 Intent

## Version
0.1.0

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md` (Process Constitution v1.0.0)
- `sdlc/01-context/context-synthesis-v0.md` (CTX-SYN-001, approved 2026-06-05)
- `sdlc/01-context/glossary-seed.md` (approved 2026-06-05)

## Downstream Consumers
- Actor / Role Catalog (L1)
- Product Intent Brief (L1)
- Product Requirements Document (L1)
- Non-Functional Requirements (L1)

---

## 1. Artifact Header

| Field | Value |
|---|---|
| Status | draft |
| Layer | L1 Intent |
| Version | 0.1.0 |
| Created | 2026-06-05 |

---

## 2. L0 Context Handoff Summary

What approved L0 established, cited by CTX ID only. No new claims are introduced here.

| CTX ID | Established Fact |
|---|---|
| CTX-01 | astraX runs a weekly experiment-based execution process: Friday status updates, standup off filtered summary, Monday leads review and prioritize. |
| CTX-02 | The experiment is the unit of tracked work in current practice — hypothesis-framed, success-criteria-first, single owner, ≤2-week atomicity, status, outcome, and next action. |
| CTX-03 | Hypothesis-less entries (tasks) demonstrably leak into the experiment log; leadership notices and treats this as a defect. |
| CTX-04 | Work is organized into business tracks (T1–T6 today); the track set and sub-track structure are unstable and must be treated as configurable data. |
| CTX-05 | The execution status vocabulary in the artifact of record is: Not Started → In Progress → {Complete, Blocked, Inconclusive}; no acceptance or approval states exist. |
| CTX-06 | Learning is captured as an outcome/finding attribute; each outcome is expected to trigger a recorded next action (follow-on experiment, artifact update, or escalation). |
| CTX-07 | Stated direction: replace the cumbersome spreadsheet with a UI and dashboard whose purpose is management execution, intended to sit on top of future operations agents as the durable read surface. |
| CTX-08 | Customer-facing work follows discovery-before-experiment: listen and gather intelligence from prospects before committing to experimentation or onboarding. |

Contradictions CON-001 (track taxonomy) and CON-002 (acceptance architecture) are both **held open** and flow into L1 as constraints (see Section 4 and Section 6).

Open questions OQ-01 through OQ-10 are **carried forward unresolved** (see Section 4).

---

## 3. L1 Scope

### 3.1 What L1 May Determine

L1 Intent is the layer that defines what is wanted, for whom, and under what constraints. Drawing on CTX-SYN-001, L1 may determine:

- **Product intent** — what problem the accountability app exists to solve, grounded in CTX-07 (management execution) and the established gap between the current spreadsheet practice and the stated direction.
- **Intended users / readers** — who consumes the product, grounded in primary-evidenced actors (e.g., Vijay Chilakapati as named user, owners as experiment-entry actors); extended actor set subject to stakeholder validation (OQ-10).
- **Actor classes** — broad groupings of principals that interact with the system (e.g., experiment owners, dashboard readers, leads), to the extent that approved L0 evidence and stakeholder validation support them.
- **High-level goals** — capabilities and outcomes L1 expects the product to enable, traceable to CTX-01 through CTX-08.
- **Non-goals** — what the product explicitly will not do in the scope of the current intent, derivable from the "not established" list (CTX-SYN-001 §4).
- **Constraints** — known constraints on the product visible from approved context (e.g., track taxonomy must be configurable not fixed; approval architecture must not be asserted ahead of evidence).
- **Unresolved stakeholder questions** — which open questions must be answered before L1 artifacts can be approved.

### 3.2 What L1 May Not Determine

L1 must not author, assert, or invent the following. These are L2 or later concerns, or are explicitly not established by approved L0.

| Forbidden at L1 | Reason |
|---|---|
| Domain model (entities, aggregates, relationships) | L2 Behavior concern |
| Final workflow specifications | L2 Behavior concern |
| UI layouts, screen designs, or interaction patterns | L3 Structure concern |
| API endpoints, field names, or payload shapes | L3 Structure concern |
| Database schema, data model, or persistence design | L3 Structure concern |
| Technology choices (hosting, framework, language) | Explicitly open (F-08); not an L1 concern |
| Acceptance/approval lifecycle | Not established (CTX-SYN-001 §4 item 1–2; CON-002) |
| Decision or Commitment as named entities | Not established (CTX-SYN-001 §4 items 3–4) |
| Agent ownership or attribution model | Not established (CTX-SYN-001 §4 item 5) |
| Final track taxonomy (hard-coded set) | CON-001 held open; CTX-04 requires configurable treatment |
| Post-Complete lifecycle | Not evidenced (CTX-SYN-001 §4 item 7) |

---

## 4. Open Questions Entering L1

All ten open questions from RES-001 §5, classified for L1 artifact gating. None is answered here.

| OQ | Question | L1 Classification |
|---|---|---|
| OQ-01 | Was T7 (internal tooling track) formally adopted, or do sub-tracks inside T2/T3 absorb the accountability app? | **Must resolve before Product Intent Brief approval** — affects whether the product's own track placement is stated or deferred. Non-blocking for drafting. |
| OQ-02 | Does any acceptance/approval step exist in current practice beyond informal review by Vijay — and if so, who holds it and over what? | **Must resolve before Actor / Role Catalog approval** — approval authority is core to any actor model. Non-blocking for drafting. See CON-002. |
| OQ-03 | What does "Escalate to Vijay" mean procedurally — is Vijay the universal escalation point, or only for the cited example's domain? | **Must resolve before Product Intent Brief approval** — affects how accountability and escalation are framed in intent. |
| OQ-04 | What else does Vijay's (uncaptured) email define besides the hypothesis rule? | **May defer to L2 Behavior** — the hypothesis rule is already grounded by CTX-02/CTX-03; any additional email content would enrich L1 but is not currently blocking. |
| OQ-05 | What is in the Teams "story" document Vijay shared on screen? | **May defer to L2 Behavior** — outreach/strategy material; peripheral to execution-platform product intent at L1 level. |
| OQ-06 | Are the unstatused workbook rows (task-shaped entries) intended to become experiments, tracked as tasks, or removed? | **Must resolve before Product Intent Brief approval** — the answer determines whether task-class support is a goal or an explicit non-goal, which is a load-bearing intent decision. |
| OQ-07 | Is the `Parent Item` column the intended carrier of sub-track structure, and why is it unpopulated? | **May defer to L2 Behavior** — structural/data-model detail beneath intent level; CTX-04 establishes that hierarchy exists conceptually. |
| OQ-08 | Must learning be cross-portfolio queryable, or is the per-row Outcome column considered sufficient? | **Must resolve before Product Requirements Document approval** — distinguishes an aspiration (cross-portfolio querying) from a requirement; load-bearing for PRD scope. |
| OQ-09 | What happens to an experiment after Complete — is there any closure, review, or archival step? | **Must resolve before Product Requirements Document approval** — lifecycle completeness is a PRD-scope question; currently unevidenced either way. |
| OQ-10 | Who are the consumers of the dashboard besides Vijay — leads? the whole team? | **Must resolve before Actor / Role Catalog approval** — dashboard readership is the primary actor-identification question; the actor catalog cannot be reviewed without it. See CTX-SYN-001 §5. |

### Special Attention: OQ-02 and OQ-10

**OQ-02** is the approval / acceptance authority question. CTX-SYN-001 §4 establishes that the formal acceptance lifecycle posited by SRC-003 is uncorroborated (CON-002) and must not be asserted as fact. Until new primary evidence is captured (GAP-002), any Actor / Role Catalog or Product Requirements Document assertion about approval roles or acceptance states is invalid. L1 must carry this visibly and enforce it as a drafting constraint.

**OQ-10** is the dashboard readership question. The Actor / Role Catalog cannot be reviewed without knowing who consumes the dashboard. The evidence establishes Vijay as a named user (CTX-07) and owners as experiment-entry actors (CTX-02), but the readership audience for the management-execution surface is explicitly unevidenced beyond the founder. Any actor catalog that asserts a specific reader class without new primary evidence would violate the no-invention rule (Constitution §5.1).

---

## 5. L1 Artifact Sequence Recommendation

### 5.1 Recommended Order

The expected baseline order (Actor / Role Catalog → Product Intent Brief → PRD → NFRs) is **modified** on the basis of CTX-SYN-001 §5, which explicitly classifies OQ-10 as blocking for Actor / Role Catalog approval but non-blocking for product intent framing. Because an approved Product Intent Brief provides richer upstream authority for the Actor / Role Catalog — and because the Product Intent Brief has no equivalent approval blocker — L0 evidence supports leading with intent before actors.

**Recommended sequence:**

```
A. Product Intent Brief
B. Actor / Role Catalog
C. Product Requirements Document
D. Non-Functional Requirements
```

### 5.2 Artifact Profiles

#### A. Product Intent Brief

| Field | Detail |
|---|---|
| **Purpose** | Define what problem the accountability app exists to solve, the product's high-level goals, its primary direction, and its explicit non-goals — grounded in approved CTX assertions. |
| **Upstream Authority** | CTX-SYN-001 (CTX-01 through CTX-08); Glossary Seed; this Recon (for open-question constraints). |
| **Downstream Consumers** | Actor / Role Catalog; Product Requirements Document; Non-Functional Requirements. |
| **Approval Blockers** | OQ-01 (track placement of the product itself) and OQ-06 (task-class as goal or non-goal) must be resolved before approval. OQ-03 (escalation framing) must also be resolved. |
| **Must NOT Contain** | UI layouts; API shapes; database design; technology choices; acceptance lifecycle assertions; domain model entities; any concept not present in approved CTX assertions or the Glossary Seed. |

#### B. Actor / Role Catalog

| Field | Detail |
|---|---|
| **Purpose** | Identify and classify the principals who interact with the product — who enters experiments, who reads the dashboard, who leads, who escalates — grounded in evidence and stakeholder-validated actor set. |
| **Upstream Authority** | CTX-SYN-001 (CTX-01, CTX-02, CTX-07); Glossary Seed (owner, track, standup, Monday leads meeting); Product Intent Brief (approved). |
| **Downstream Consumers** | Product Requirements Document; Future Authorization Specifications (L2); Future Workflow Specifications (L2); Future UI Specifications (L3). |
| **Approval Blockers** | OQ-10 (dashboard readership beyond Vijay) must be resolved via new primary evidence before this artifact may enter review. OQ-02 (approval/acceptance authority) must be resolved before any approval-related role is included. |
| **Must NOT Contain** | Permission assignments (that is L2 Authorization); acceptance lifecycle roles without primary evidence; any actor not grounded in CTX-SYN-001 or stakeholder-validated new source materials; invented authority semantics for "lead" or "owner" beyond what the Glossary Seed defines. |

#### C. Product Requirements Document

| Field | Detail |
|---|---|
| **Purpose** | State the set of product requirements — what the system must do, for whom, and under what observable conditions — with stable requirement IDs minted at this layer. |
| **Upstream Authority** | CTX-SYN-001; Glossary Seed; Product Intent Brief (approved); Actor / Role Catalog (approved). |
| **Downstream Consumers** | Non-Functional Requirements; Future Functional Requirements (L2); Future Acceptance Criteria (L4); Future Domain Model (L2). |
| **Approval Blockers** | Product Intent Brief must be approved. Actor / Role Catalog must be approved. OQ-08 (cross-portfolio learning queryability) and OQ-09 (post-Complete lifecycle) must be resolved before PRD approval. |
| **Must NOT Contain** | UI layouts; API endpoint signatures; database fields; technology selection; domain model (entities, aggregates); acceptance criteria (that is L4); any requirement not traceable to an approved CTX assertion or stakeholder-validated source. |

#### D. Non-Functional Requirements

| Field | Detail |
|---|---|
| **Purpose** | State the quality attributes, operational constraints, and non-behavioral requirements the system must satisfy — performance, availability, security posture, scale — grounded in product intent and actor scope. |
| **Upstream Authority** | CTX-SYN-001; Product Intent Brief (approved); Actor / Role Catalog (approved). PRD may be in parallel draft — NFRs should not depend on PRD for their primary grounding. |
| **Downstream Consumers** | Future Data Model (L3); Future API Contracts (L3); Future Test Strategy (L4); Future Build (L5). |
| **Approval Blockers** | Product Intent Brief must be approved. Actor / Role Catalog must be approved. NFRs must not assert implementation detail (no hosting choice, no specific technology) until technology is selected at the appropriate layer. Hosting open question (F-08) must remain open. |
| **Must NOT Contain** | Implementation detail (specific technologies, frameworks, libraries); UI specifications; API shapes; database schemas; technology selection; any requirement that assumes the acceptance-lifecycle model (CON-002). |

---

## 6. Evidence Constraints for L1

### 6.1 What L1 May Assert from Approved Context

L1 may assert, cite, and elaborate the following — each by CTX ID:

- The management-execution purpose and stopgap nature of the spreadsheet (CTX-07).
- The experiment discipline as current practice: hypothesis format, success criteria, single owner, ≤2-week atomicity, status lifecycle, outcome, next action (CTX-02, CTX-05, CTX-06).
- Task leakage as an observed and acknowledged problem (CTX-03).
- The weekly cadence as the operational rhythm: Friday updates, standup, Monday leads meeting (CTX-01).
- The track taxonomy as an organizing structure that is real but unstable and must be configurable (CTX-04).
- The dashboard-over-agents direction as Vijay's stated intent (CTX-07) — with the internal-source caveat (evidence of stated intent, not validated demand).
- Discovery-before-experiment as the workflow for customer-facing tracks (CTX-08).
- The defined glossary terms as approved ubiquitous language.

### 6.2 What Must Remain Open

The following are **not established** by approved L0 and must not enter any L1 artifact as assertions:

1. **Approval architecture not established.** No formal acceptance mechanism is evidenced. CON-002 is held open. Any L1 reference to approval roles or acceptance states requires new primary evidence from GAP-002 / OQ-02 stakeholder capture.
2. **Decision entity not established.** No "Decision" concept exists in any primary source (CTX-SYN-001 §4 item 3). SRC-003's Decision concept is hypothesis only and must not be introduced.
3. **Commitment atom not established.** Appears only in SRC-003's account of uncaptured discussions (CTX-SYN-001 §4 item 4; GAP-003). Must not be asserted or modeled.
4. **Final track taxonomy not established.** T1–T6 is today's list; T7 is floated and unadopted; sub-track structure is verbally agreed but structurally unresolved (CON-001). L1 must treat the track set as configurable data, never as a committed enumeration.
5. **Dashboard readership not established beyond Vijay.** Vijay is the only evidenced dashboard consumer. "Leads" as a readership class is not grounded beyond the Monday leads meeting cadence (CTX-01; Glossary Seed: monday leads meeting). Team-wide readership is unevidenced (OQ-10).

---

## 7. Stakeholder Validation Needs

The following questions must be put to stakeholders and captured as new primary Source Materials before the specified L1 artifacts may enter `review`. They are listed here as questions only — they are not answered.

These are the questions that must be asked, not the answers:

1. **Approval/acceptance authority (for Actor / Role Catalog and PRD approval):** Does any step exist in the current or intended process at which an experiment moves from "in progress" to "accepted" or "validated" — and if so, who has the authority to make that determination, and over what? Is it always Vijay, or can track leads or owners accept within their scope? [Required to resolve OQ-02; to close CON-002.]

2. **Dashboard readership (for Actor / Role Catalog approval):** Beyond Vijay, who is the intended audience for the dashboard? Is it all experiment owners? All track leads? The whole team? Is there a distinction between who can read vs who can write? [Required to resolve OQ-10.]

3. **Track placement of the accountability app (for Product Intent Brief approval):** Should the accountability app / execution-platform sit in an internal tooling track (T7 as floated), or inside a sub-track of an existing track, or be considered infrastructure rather than a tracked experiment? [Required to resolve OQ-01.]

4. **Task as first-class concept (for Product Intent Brief approval):** Should the product support tracking of tasks (hypothesis-less work items) as a distinct, intentional concept — or is the product explicitly for experiments only, with tasks treated as a known leakage problem to be prevented? [Required to resolve OQ-06.]

5. **Escalation procedure (for Product Intent Brief approval):** When the workbook says "Escalate to Vijay," does this describe a general escalation protocol — Vijay as the universal escalation terminal — or was it specific to that example? Who else, if anyone, can be an escalation target? [Required to resolve OQ-03.]

6. **Learning queryability (for PRD approval):** Is the requirement that learnings be cross-portfolio queryable (e.g., "search outcomes across all tracks and time periods"), or is the current per-row Outcome/Finding column considered sufficient for intended use? [Required to resolve OQ-08.]

7. **Post-Complete lifecycle (for PRD approval):** What happens to an experiment after it reaches Complete status? Is there any intended closure step, review, archival, or reactivation? [Required to resolve OQ-09.]

---

## 8. L1 Readiness Verdict

**L1 artifact drafting may begin, subject to the following constraints.**

### 8.1 Preconditions met

Per COM §8, as of the approved CTX-SYN-001 (approved 2026-06-05):

- Approved Context exists (CTX-SYN-001, 8 assertions CTX-01…CTX-08).
- Load-bearing assertions are grounded in primary internal sources.
- Freshness is current (all evidence as-of 2026-06-04/05, within proposed horizons).
- Contradictions CON-001 and CON-002 are carried as held-open visible constraints.
- Glossary Seed exists (approved 2026-06-05).
- Handoff is recorded (CTX-SYN-001 §7 and this Recon).

### 8.2 Drafting Constraints

1. **L1 artifacts may be drafted** — authoring may proceed for all four artifacts (Product Intent Brief, Actor / Role Catalog, PRD, NFRs).
2. **No L1 artifact may enter `review`** until its upstream authority artifacts are `approved` (Constitution §6 gate rule).
3. **Product Intent Brief** may not enter `review` until OQ-01, OQ-03, and OQ-06 are resolved via new primary source capture.
4. **Actor / Role Catalog** may not enter `review` until OQ-10 and OQ-02 are resolved via new primary source capture.
5. **PRD** may not enter `review` until the Product Intent Brief is approved, the Actor / Role Catalog is approved, and OQ-08 and OQ-09 are resolved.
6. **No L1 artifact may assert** approval architecture, acceptance lifecycle, Decision/Commitment entities, agent ownership model, or a fixed track taxonomy — these are not established (Section 6.2).
7. **No concept may be introduced** that is absent from CTX-SYN-001 or the approved Glossary Seed without new primary evidence (no-invention rule, Constitution §5.1).
8. **Stakeholder validation sessions** must generate new primary Source Materials (new SRC IDs in the Source Intake Register) to close the blocking open questions — they cannot be resolved by assertion or inference.

---

## 9. Acceptance Criteria

This Recon artifact may move from `draft` to `approved` when all of the following hold:

- [ ] All nine required sections are present and non-empty.
- [ ] The L0 Context Handoff Summary (Section 2) cites only approved CTX IDs and introduces no new claims beyond those in CTX-SYN-001.
- [ ] The L1 Scope (Section 3) correctly bounds what L1 may and may not determine, with the forbidden set consistent with CTX-SYN-001 §4 and the Process Constitution §3 and §4.
- [ ] OQ-01 through OQ-10 are all carried forward (Section 4) with classifications consistent with CTX-SYN-001 §5. No question is dropped or answered.
- [ ] OQ-02 and OQ-10 are explicitly called out as approval-blocking constraints, consistent with their classification in CTX-SYN-001 §5.
- [ ] The L1 Artifact Sequence (Section 5) defines purpose, upstream authority, downstream consumers, approval blockers, and must-not-contain for all four L1 artifacts.
- [ ] The sequence modification (Product Intent Brief leading rather than Actor / Role Catalog) is grounded in the CTX-SYN-001 §5 classification of OQ-10, not in invention.
- [ ] The Evidence Constraints (Section 6) correctly enumerate what may be asserted and explicitly state that approval architecture, decision entity, commitment atom, final track taxonomy, and dashboard readership beyond Vijay are not established.
- [ ] The Stakeholder Validation Needs (Section 7) are stated as questions only — no answer is introduced.
- [ ] The L1 Readiness Verdict (Section 8) is affirmative with stated constraints, and no constraint contradicts the Process Constitution or CTX-SYN-001.
- [ ] This artifact contains no PRD content, no domain model, no architecture, no technology choices, no implementation content, and no invented concepts.
- [ ] The artifact declares `Status`, `Layer`, `Version`, `Upstream Authority`, and `Downstream Consumers` in conformance with Constitution §7.
- [ ] Review is logged per Constitution §6 (`draft` → `review` → `approved`); no bootstrap exception is claimed.
