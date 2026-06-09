# L0 Context Synthesis v0 — Execution-Platform

## Status
approved (L0 review 2026-06-05; revised and re-approved 2026-06-09 — CTX-09…CTX-13 added per SRC-005 promotion; revised and re-approved 2026-06-09 — CTX-14 added per SRC-006 OQ-01 resolution)

## Layer
L0 Context

## Version
0.3.0 (CTX-14 added per SRC-006 OQ-01 resolution — 2026-06-09)

### Prior versions
- 0.2.0 (CTX-09…CTX-13 added per SRC-005 promotion — 2026-06-09)
- 0.1.0 (CTX-01…CTX-08; initial synthesis — 2026-06-05)

## Context ID
CTX-SYN-001

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md` (Process Constitution)
- `sdlc/01-context/context-operating-model.md` (Context Operating Model)
- `sdlc/01-context/source-intake-register.md` (Source Intake Register v0.4.0)
- `sdlc/01-context/research/l0-research-pass-1.md` (L0 Research Pass 1, RES-001)

## Downstream Consumers
- L1 Intent
- Product Requirements (L1)
- Actor / Role Catalog (L1)
- Future Domain Model (L2)
- Future Workflow Specification (L2)

## Contributing Evidence
- SRC-001 — Vijay Chilakapati call transcript (primary, internal; as-of 2026-06-04)
- SRC-002 — astraX Jun–Nov 2026 experiment tracking workbook (primary, internal;
  as-of ≥ 2026-06-04, live tracker)
- SRC-003 — prior Claude analysis (inferred, internal, non-authoritative; used only to
  source hypotheses and open questions, never as grounding)
- RES-001 — findings F-01…F-25, contradictions CON-001/CON-002, open questions
  OQ-01…OQ-10
- SRC-005 — v1 scope-narrowing stakeholder capture (primary, internal; as-of
  2026-06-07; captured 2026-06-09). Grounds CTX-09…CTX-13.
- SRC-006 — L1 track placement confirmation (primary, internal; as-of 2026-06-09;
  captured 2026-06-09). Grounds CTX-14.

Synthesis date: 2026-06-05. Revised: 2026-06-09 (CTX-09…CTX-13 added). Revised: 2026-06-09 (CTX-14 added).

---

## 1. Context Summary

What the captured evidence establishes, in brief:

astraX (a company building an XRF device, a customer cloud, and related operations)
runs its execution through a shared Excel workbook that organizes work as
**experiments**: hypothesis-framed, success-criteria-first, owner-assigned units of
work grouped into business **tracks** and reviewed on a **weekly cadence** (owners
update by Friday; standups read the filtered summary; a Monday leads meeting reviews
and prioritizes) [SRC-002; RES-001 F-01, F-03, F-18, F-19].

The workbook embodies a deliberate discipline — "experiments without hypotheses are
just tasks" — and that discipline demonstrably leaks: the log contains task-shaped rows
with no hypothesis, no owner, and no status [SRC-002; SRC-001; F-05, F-12].

The founder (Vijay Chilakapati) describes the workbook as a cumbersome stopgap to be
replaced by a UI with a dashboard whose purpose is **management execution** — reading
rolled-up execution state across the organization — and which should eventually sit on
top of future operations agents (sales, manufacturing, service) as the durable read
surface [SRC-001; F-01, F-04, F-06]. The working name for this product idea in the
evidence is the **accountability app** [SRC-001; F-07].

The track taxonomy (currently T1 Device through T6 Sales partner) is real but unstable
at the edges: sub-tracks are emerging, and the accountability app itself has no home
track [SRC-001; SRC-002; F-09–F-11, CON-001]. Learning is captured as an outcome
attribute that must trigger a recorded next action; no decision concept or
acceptance/approval machinery exists in the artifact of record [SRC-002; F-20–F-22].

This Context covers what is reliably known as of 2026-06-05. It asserts nothing about
what should be built; that is L1's work.

---

## 2. Evidence-Backed Context Assertions

Candidate assertions CCA-01…CCA-10 from RES-001 are dispositioned below. Promoted
assertions receive stable CTX IDs. Per COM §3, strength is bounded by the weakest
source in the chain; all promoted assertions rest on primary internal sources.

### CTX-01 — Weekly experiment-based execution process
- **Promoted from:** CCA-01
- **Source basis:** SRC-002 (How To Use: Friday status updates, "Update XL before the
  standup", "Monday (Leads meeting) — Review weekly progress and challenges,
  prioritize"); corroborated by F-01. As-of 2026-06-04.
- **Strength:** Strong (primary, explicit).
- **Allowed downstream usage:** May ground L1 assertions about the existing process the
  product must serve, including cadence-aware features.
- **Limitations:** Evidences the *designed* ritual; degree of actual adherence is
  unmeasured.

### CTX-02 — The experiment is the unit of tracked work
- **Promoted from:** CCA-02
- **Source basis:** SRC-002 (column set; hypothesis format; "WRITE THIS BEFORE YOU
  START"; ≤2-week atomicity; single Owner column); SRC-001 6:35 (hypothesis rule
  restated to Vijay's satisfaction). As-of 2026-06-04.
- **Strength:** Strong (two primary sources corroborate).
- **Allowed downstream usage:** May ground L1 intent about what a unit of work carries
  (hypothesis, design, success criteria, dependencies, target date, owner, status,
  outcome, next action) — as *evidence of current practice*, not as a domain model.
- **Limitations:** Whether "experiment" is the final atom of the future system is
  explicitly open (see §4 and OQ list); this assertion describes the workbook's
  practice only.

### CTX-03 — Hypothesis presence distinguishes experiment from task; leakage is real
- **Promoted from:** CCA-03
- **Source basis:** SRC-002 ("'Experiments' without hypotheses are just tasks");
  SRC-001 6:35; observable leakage rows in SRC-002 (8 rows without owner/hypothesis/
  status); SRC-001 10:32 (Vijay flags missing owners). As-of 2026-06-04.
- **Strength:** Strong.
- **Allowed downstream usage:** May ground L1 problem statements about discipline
  enforcement and the existence of non-experiment work in the log.
- **Limitations:** Whether Task should be a first-class concept is NOT established —
  only that hypothesis-less entries exist and are regarded as "just tasks."

### CTX-04 — Work is organized into business tracks; the taxonomy is unstable
- **Promoted from:** CCA-04 (+ CCA-10 merged as the instability evidence)
- **Source basis:** SRC-002 (dropdown "T1 Device through T6 Sales"; track values
  T1–T6); SRC-001 7:36–10:19 (tracks = projects; sub-tracks "2 inside 2 and two
  inside 3" agreed; accountability app has no track; T7 floated, adoption not
  recorded). As-of 2026-06-04. Carries CON-001 (held open).
- **Strength:** Strong on existence of tracks; moderate on structure (sub-tracks
  verbal only).
- **Allowed downstream usage:** May ground L1 intent that tracks exist and must be
  treated as configurable data, not a fixed enumeration.
- **Limitations:** The current T1–T6 list must not be hard-coded as final (CON-001).
  Sub-track depth and the T7 question are open (OQ-01, OQ-07).

### CTX-05 — Execution status vocabulary (current practice)
- **Promoted from:** CCA-05
- **Source basis:** SRC-002 ("Not Started → In Progress → Complete or Blocked or
  Inconclusive"; conditional formatting green/red; STATUS SUMMARY counts). As-of
  2026-06-04.
- **Strength:** Strong.
- **Allowed downstream usage:** May ground L1 descriptions of the execution lifecycle
  as practiced. The *absence* of acceptance states is itself evidence (see §4).
- **Limitations:** Describes the workbook's vocabulary; does not establish that this is
  the complete or intended future lifecycle (OQ-09: nothing evidenced after Complete).

### CTX-06 — Learning is an outcome attribute; outcomes trigger next actions
- **Promoted from:** CCA-06
- **Source basis:** SRC-002 (Outcome/Finding "fill in AFTER… note what it means"; Next
  Action "What does this result trigger? Must be actionable", examples include
  follow-on experiment, artifact update, "Escalate to Vijay"); SRC-001 6:50–7:09
  (no separate learnings register; Vijay redirects to experiments). As-of 2026-06-04.
- **Strength:** Strong.
- **Allowed downstream usage:** May ground L1 intent about capturing outcomes and
  result-triggered follow-ups as existing practice.
- **Limitations:** Whether learning must become cross-portfolio queryable is open
  (OQ-08); "make learning fun" (SRC-001 6:35) evidences an aspiration, not a
  requirement.

### CTX-07 — Intended direction: UI + dashboard for management execution, over agents
- **Promoted from:** CCA-07
- **Source basis:** SRC-001 0:39 (dashboard "sits on top of all these operations
  agents… pulls from everywhere"), 1:02–1:18 (Excel "cumbersome… Instead, we do that
  using a user interface"), 10:32 ("we will use this to. Management execution");
  SRC-002 T3 row ("Implement sales agent"). As-of 2026-06-04.
- **Strength:** Strong on direction; this is stakeholder intent, internally sourced —
  it evidences what Vijay *wants*, which is exactly what L1 Intent needs.
- **Allowed downstream usage:** May ground L1 vision/intent statements, with the
  internal-source caveat: it is evidence of stated intent, not of validated demand.
- **Limitations:** No scope, no readership beyond Vijay evidenced (OQ-10), no
  committed timeline, no technology choice (hosting explicitly open, F-08).

### CTX-08 — Discovery precedes experimentation in customer-facing work
- **Promoted from:** CCA-08
- **Source basis:** SRC-001 8:36 (discovery thread "will lead to the technical
  experiments"), 11:46–12:36 ("let's listen before we… give them an account"; onboard
  only when "our solution is close to what they are willing"; verticals: scrapyard,
  manufacturing QC). As-of 2026-06-04.
- **Strength:** Strong (explicit, repeated).
- **Allowed downstream usage:** May ground L1 context about how customer-facing tracks
  generate work; relevant to any track/workflow framing.
- **Limitations:** Specific to the current outreach phase; may evolve.

### Not promoted

- **CCA-09 (approval posture) — NOT promoted.** Evidence: informal review-by-Vijay of
  deliverables (SRC-001 4:49, 5:08) and "Escalate to Vijay" as a Next Action example
  (SRC-002). This is too thin to ground any assertion about approval architecture, and
  the only articulated acceptance model (SRC-003) is inferred-only and uncorroborated
  (CON-002). Carried instead as open question OQ-02/OQ-03 and as §4 "not established."
- **CCA-10 — merged into CTX-04** as the taxonomy-instability evidence rather than
  promoted standalone.

**Promoted (v0.1.0): 8 assertions (CTX-01…CTX-08). Added (v0.2.0): 5 assertions (CTX-09…CTX-13). Added (v0.3.0): 1 assertion (CTX-14). Total: 14.**

---

### CTX-09 — v1 scope: simple controlled table editor for experiment/work-item/task rows

- **Source basis:** SRC-005 §1, §2.3 (Vijay verbatim: "Keep it simple, ability to create
  and edit experiment… Just a nicer table editor"; operator capture: experiments,
  work-items, and tasks share the same columns). As-of 2026-06-07.
- **Strength:** Moderate (single primary source; most recent founder direction; no
  corroborating source yet).
- **Allowed downstream usage:** May ground L1 and PRD statements that v1 is a simple
  table editor supporting create/edit of experiment/work-item/task rows with a shared
  column set.
- **Limitations:** The mandatory-field policy (which columns, if any, are required) is
  **unresolved** (see §4 item 9). The distinction between experiment, work-item, and
  task beyond sharing columns is **unresolved** and deferred to L2/Domain Model. This
  assertion establishes the v1 *scope*, not the full product vision (CTX-07 remains the
  direction; CTX-09 narrows v1).

### CTX-10 — Escalation-to-Vijay is not a modeled v1 product pathway

- **Source basis:** SRC-005 §2.3 (operator capture context; as-of 2026-06-07).
  The verbatim v1 framing makes no mention of escalation; the operator additionally
  directs it not be built as a product pathway.
- **Strength:** Moderate (operator capture authority; not a direct stakeholder quote).
- **Allowed downstream usage:** May ground L1 and PRD statements that no
  escalation-to-Vijay feature or workflow is in v1 scope. Resolves OQ-03 for v1
  (see §5 update).
- **Limitations:** Applies to v1 only. If escalation re-enters scope in a future version,
  a fresh primary capture is required. Does not foreclose an escalation feature in
  future releases.

### CTX-11 — execution-platform is a separate application from NDT-SaaS

- **Source basis:** SRC-005 §2.1 (operator capture context; as-of 2026-06-07).
  "execution-platform is a completely separate application from the existing NDT-SaaS
  cloud platform. It has absolutely nothing to do with NDT-SaaS unless explicitly
  stated otherwise."
- **Strength:** Moderate (authoritative operator correction; no NDT-SaaS reuse was ever
  in the verbatim stakeholder framing; the correction guards against a misinterpretation
  of "access control like we already have").
- **Allowed downstream usage:** May ground all downstream artifact statements that
  execution-platform is a separate, standalone application with no NDT-SaaS dependency
  unless later explicitly directed otherwise.
- **Limitations:** If a later direction explicitly authorizes an NDT-SaaS dependency,
  this assertion must be revised via ADR. Does not specify what the application's
  architecture, hosting, or stack is.

### CTX-12 — Access control means a simple separate-app pattern; exact design unresolved

- **Source basis:** SRC-005 §1, §2.1–§2.2 (as-of 2026-06-07). Vijay's phrase "access
  control like we already have" is interpreted as *follow a similar simple pattern*,
  not as reuse of NDT-SaaS auth/access-control. The follow-up "Yes" to an either/or
  question was **ambiguous on its face**; the operator correction is the disambiguating
  authority.
- **Strength:** Moderate (inference from ambiguous stakeholder utterance + operator
  correction; the interpretation is conservative and guards against over-engineering).
- **Allowed downstream usage:** May ground L1 NFR and PRD statements that v1 requires
  *some* access-control pattern for a standalone application; the exact design is an
  open item for PRD/L3.
- **Limitations:** The exact access-control design (roles, permissions, auth mechanism)
  is **unresolved** (see §4 item 10). This assertion establishes the intent constraint
  only, not the implementation. The ambiguity of the stakeholder response is preserved
  and noted.

### CTX-13 — Experiments/work-items/tasks share columns in v1; mandatory-field policy unresolved

- **Source basis:** SRC-005 §2.3 (operator capture; as-of 2026-06-07). "Experiments,
  work-items, and tasks share the same columns in v1." "Mandatory-field policy is
  unresolved — which columns (if any) are required is not yet decided."
- **Strength:** Moderate (single primary source; operator capture interpretation of
  Vijay's "ability to create and edit experiment" + "nicer table editor").
- **Allowed downstream usage:** May ground PRD and L2 statements that the shared-column
  approach is the v1 data model intent. May also ground statements that mandatory-field
  discipline is deferred to the PRD.
- **Limitations:** The mandatory-field policy is **explicitly unresolved** and must not be
  asserted by this brief or the PRD without further stakeholder capture. The
  *relationship* between experiment, work-item, and task (beyond sharing columns) is
  deferred to L2 Behavior / Domain Model.

### CTX-14 — execution-platform is classified under the OPS Cloud track

- **Source basis:** SRC-006 (operator product classification confirmation; as-of
  2026-06-09). "execution-platform belongs under the OPS Cloud track."
- **Strength:** Moderate (primary internal; single operator confirmation; no
  corroborating stakeholder source).
- **Allowed downstream usage:** May ground L1 statements that execution-platform's home
  track within the astraX track taxonomy is the OPS Cloud track for product-intent
  purposes. Resolves OQ-01 for Product Intent Brief.
- **Limitations:** This is a **product-organization classification**, not an architectural
  coupling. It does not override ADR-000's separate-app boundary (CTX-11) or imply any
  NDT-SaaS reuse, shared architecture, shared deployment, or shared access-control
  implementation. The exact access-control design (CTX-12) and mandatory-field policy
  (CTX-13) are unaffected. CON-001 (track taxonomy instability) remains held open —
  this assertion resolves the home-track question only, not the broader taxonomy
  structure.

---

## 3. What IS Established

Claims sufficiently supported by primary evidence (citations above):

1. **Management-execution purpose.** The workbook-and-future-dashboard exists so
   leadership can read rolled-up execution state and run the organization with it
   [CTX-07; F-01, F-02].
2. **Spreadsheet as stopgap.** The Excel workbook is explicitly cumbersome and is
   intended to be replaced by a UI [CTX-07; F-04].
3. **Experiment discipline.** Hypothesis-first, success-criteria-before-start,
   ≤2-week atomic experiments with single owners, designs, dependencies, and target
   dates [CTX-02; F-03, F-13, F-14].
4. **Task leakage.** Hypothesis-less, owner-less, status-less rows exist in the live
   log; leadership notices and cares [CTX-03; F-05].
5. **Weekly cadence.** Friday updates → standups off the filtered summary → Monday
   leads review/prioritization [CTX-01; F-18, F-19].
6. **Unstable track taxonomy.** Tracks are real business projects (T1–T6 today) but
   the set and structure are in motion [CTX-04; F-09–F-11; CON-001].
7. **Dashboard-over-agents direction.** The dashboard is intended to remain the
   durable read surface above future sales/manufacturing/service agents [CTX-07;
   F-06, F-24].
8. **Discovery-before-experiment** in customer-facing tracks, targeting scrapyard and
   manufacturing-QC verticals [CTX-08; F-23].
9. **Learning-as-attribute + next-action triggering** as current practice [CTX-06;
   F-20, F-21].
10. **Execution-only status vocabulary** in the artifact of record [CTX-05; F-15].
11. **v1 = simple controlled table editor** for create/edit of experiment/work-item/task
    rows [CTX-09; SRC-005].
12. **execution-platform is a separate application** from NDT-SaaS; no NDT-SaaS
    dependency or reuse [CTX-11; SRC-005].
13. **"Access control like we already have" = similar simple pattern** for the separate
    app; not NDT-SaaS reuse [CTX-12; SRC-005].
14. **Experiments/work-items/tasks share columns** in v1 [CTX-13; SRC-005].
15. **Escalation-to-Vijay is not a modeled v1 pathway** [CTX-10; SRC-005].
16. **execution-platform is classified under the OPS Cloud track** within astraX's
    track taxonomy for product-intent purposes [CTX-14; SRC-006]. Classification does
    not override the separate-app boundary (CTX-11).

---

## 4. What is NOT Established

The following must not be treated as fact by any downstream artifact. Citing this
section is the only valid way to reference these notions until new evidence arrives.

1. **Formal approval architecture.** No approval/acceptance mechanism is evidenced
   beyond informal review of deliverables by Vijay [F-15, F-16; CON-002].
2. **Owner/lead acceptance lifecycle** (submit → approve/reject/revise; lead ≠ owner;
   "no self-acceptance"). Inferred-only, from SRC-003; uncorroborated [F-17; CON-002].
3. **Decision as an entity.** No decision concept exists in any primary source
   [F-22]. SRC-003's Decision concept is hypothesis only.
4. **Commitment as the atom.** Appears only in SRC-003's account of uncaptured
   discussions (GAP-003). No primary trace.
5. **Future agent ownership model.** Agents are evidenced as a direction [F-24], but
   nothing establishes how agent-produced work would be owned, attributed, or
   reviewed (SRC-003 §9 Q12 is a question, not evidence).
6. **Final track taxonomy.** T1–T6 is today's list, not a commitment; T7 and
   sub-track structure are unresolved [CON-001; OQ-01, OQ-07].
7. *(Additional)* **Post-Complete lifecycle** (closure, archival, reopening) — no
   evidence exists either way [OQ-09].
8. *(Additional)* **Dashboard readership beyond Vijay** — team-wide entry is
   evidenced; consumption beyond the founder is not [OQ-10].
9. *(Added v0.2.0)* **Mandatory-field policy** — which columns in the shared v1 column
   set (if any) are required is not yet decided [CTX-13; SRC-005 §2.3]. Deferred to PRD.
10. *(Added v0.2.0)* **Exact access-control design** — the specific roles, permissions,
    and auth mechanism for the separate application are unresolved [CTX-12; SRC-005 §2.2].
    Deferred to PRD/L3.
11. *(Added v0.2.0)* **Experiment vs work-item vs task distinction** beyond sharing
    columns — the semantic relationship and any behavioral differences are unresolved
    [CTX-09, CTX-13; SRC-005 §4]. Deferred to L2 Behavior / Domain Model.

---

## 5. Open Questions Carried Forward

From RES-001 §5, classified for L1 planning. None is answered here.

| OQ | Question (abbreviated) | Classification |
|---|---|---|
| OQ-01 | Was T7 (internal tooling) adopted, or do sub-tracks absorb the accountability app? | **RESOLVED (v0.3.0, 2026-06-09)** — execution-platform is classified under the OPS Cloud track (CTX-14; SRC-006). No longer a blocker. |
| OQ-02 | Does any acceptance/approval step exist beyond informal review by Vijay? Who holds it, over what? | **Blocking L1 Intent** — for any intent statement about approval/acceptance; non-blocking for the rest of L1 |
| OQ-03 | What does "Escalate to Vijay" mean procedurally? | **RESOLVED (v0.2.0, 2026-06-09)** — escalation is not a modeled v1 product pathway (CTX-10; SRC-005 §2.3). No longer a blocker. |
| OQ-04 | What else does Vijay's (uncaptured) email define besides the hypothesis rule? | **Useful for L1** — capture would strengthen CTX-02/CTX-03 grounding |
| OQ-05 | What is in the Teams "story" document? | **Deferable to L2** — outreach/strategy material, peripheral to execution-platform intent |
| OQ-06 | Are the unstatused workbook rows to become experiments, tasks, or be removed? | **RESOLVED (v0.2.0, 2026-06-09)** — v1 supports tasks as first-class rows sharing columns with experiments (CTX-09, CTX-13; SRC-005 §2.3). Mandatory-field policy (depth of discipline enforcement) deferred to PRD. |
| OQ-07 | Is `Parent Item` the intended carrier of sub-track structure? | **Deferable to L2** — structural detail beneath intent level |
| OQ-08 | Must learning be cross-portfolio queryable, or is per-row Outcome sufficient? | **Useful for L1** — distinguishes aspiration from requirement before L1 commits |
| OQ-09 | What happens after Complete (closure/review/archival)? | **Useful for L1** — lifecycle completeness; currently unevidenced either way |
| OQ-10 | Who consumes the dashboard besides Vijay? | **Blocking L1 Intent** — for actor/role-catalog work specifically (readership is half the actor model); non-blocking for problem framing |

**Status (v0.3.0):** OQ-01, OQ-03, and OQ-06 RESOLVED. Remaining open: 7 (OQ-02, OQ-04, OQ-05, OQ-07, OQ-08, OQ-09, OQ-10). **Blocking (scoped): OQ-02, OQ-10.**

---

## 6. Contradiction Register Carry-Forward

Per COM §5, both entries remain **held open**; neither is resolved here, silently or
otherwise.

- **CON-001 — Track taxonomy: fixed dropdown vs evolving structure.** SRC-002
  hard-codes T1–T6; SRC-001 (one day fresher) shows T7 floated, sub-tracks agreed, and
  an artifact with no home track. Both sides primary internal. **Disposition: held
  open.** Downstream rule: treat the track set as unstable data (CTX-04); any L1
  statement assuming a fixed taxonomy is invalid.
- **CON-002 — Acceptance architecture: SRC-003's model vs absent primary evidence.**
  SRC-003 (inferred) posits an owner/lead acceptance plane; primary sources show
  execution-only statuses and informal founder review. **Disposition: held open**,
  pending GAP-002 capture (raw approval-authority discussions). Downstream rule: no
  acceptance-lifecycle claim may be asserted by L1 (§4 item 2); the topic enters L1
  only as an explicit open question (OQ-02).

---

## 7. L1 Readiness Assessment

**L1 Intent may begin, with constraints.** Against COM §8 conditions:

1. *Approved Context exists* — *not yet*: this synthesis is `draft`. **L1 may be
   drafted in parallel but may not enter `review` until this artifact is `approved`**
   (COM §8 gate).
2. *Load-bearing assertions well-grounded* — yes for CTX-01…CTX-08 (all primary-based).
3. *Freshness current* — yes; all evidence as-of 2026-06-04/05, within proposed
   horizons.
4. *Contradictions accounted for* — yes; CON-001/CON-002 held open and visible.
5. *Glossary seed* — **not yet created**; terms are available in the evidence
   (experiment, task, track, owner, hypothesis, success criteria, outcome/finding,
   next action, status vocabulary, standup, leads meeting, accountability app,
   management execution). A glossary-seed artifact is required before L1 handoff.
6. *Handoff recorded* — pending approval.

**What L1 may assert** (citing CTX IDs): the existing process (CTX-01, CTX-02, CTX-05,
CTX-06), the problems (CTX-03 leakage; CTX-07 cumbersome stopgap), the stated direction
(CTX-07 dashboard for management execution over future agents), the organizing
structures as unstable data (CTX-04), and the discovery posture (CTX-08).

**What L1 must leave open:** everything in §4 — approval architecture, acceptance
lifecycle, Decision/Commitment concepts, agent ownership, final taxonomy,
post-Complete lifecycle, dashboard readership — plus hosting/deployment (an explicit
open question in the evidence, F-08).

**What L1 must explicitly validate** (with stakeholders, generating new Source
Materials): OQ-02 and OQ-10 before any approval-related or actor-catalog intent enters
`review`; OQ-06 and OQ-08 before committing problem statements that depend on them.

---

## 8. Acceptance Criteria (draft → approved)

This Context Synthesis may move to `approved` when:

- [ ] Every assertion (CTX-01…CTX-08) cites ≥1 primary Source ID with as-of date and
      quality class, traceable through RES-001 to SRC-001/SRC-002 (COM §7 backward
      closure; no uncited assertions).
- [ ] No assertion rests solely on SRC-003 (weakest-link rule, COM §3).
- [ ] §4 (not established) and §6 (contradictions) are confirmed complete by a
      reviewer against RES-001 — no contradiction dropped or silently resolved.
- [ ] Open questions OQ-01…OQ-10 are carried with classifications, and the two
      blocking-scope questions (OQ-02, OQ-10) are acknowledged by the L1 owner.
- [ ] The artifact contains no requirements, intent, domain model, architecture,
      technology choices, or invented concepts — all terminology traces to the cited
      evidence (COM §7 no-invention).
- [ ] The glossary seed (COM §8.5) is created as a separate L0 artifact, seeded only
      from terms present in SRC-001/SRC-002.
- [ ] The Source Intake Register is updated to record CON-001/CON-002 in its
      Contradiction Register and GAP-007's resolution (window = Jun–Nov 2026).
- [ ] Review is logged per COM §6 (`draft` → `review` → `approved`); no bootstrap
      exception claimed.
