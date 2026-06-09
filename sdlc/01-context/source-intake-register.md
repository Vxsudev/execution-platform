# L0 Source Intake Register

## Status
approved (L0 review 2026-06-05)

## Layer
L0 Context

## Version
0.4.0 (SRC-006 registered — L1 track placement confirmation; OQ-01 resolved — 2026-06-09)

### Prior versions
- 0.3.0 (SRC-005 registered — L1 v1 scope-narrowing stakeholder capture; GAP-002 partially addressed re escalation — 2026-06-09)
- 0.2.0 (CON-001/CON-002 registered; GAP-007 resolved per RES-001 F-25 — 2026-06-05)

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md`
- `sdlc/01-context/context-operating-model.md`

## Downstream Consumers
- L0 Research
- L0 Context Synthesis
- L1 Intent artifacts

---

## 1. Purpose

This register is the L0 artifact of record for **what evidence exists** in
`source-materials/`, where it came from, how reliable it is, how fresh it is, and how it
may be used downstream. It records intake metadata only. It contains no product
conclusions, no requirements, no intent, no domain concepts, and no design content
(Context Operating Model §2.1 prohibited-content rule).

Classification terms used here are those defined by the Context Operating Model §3
(source quality) and §4 (freshness). Each source's quality grade was determined from
provenance and surface inspection at intake, not from deep content analysis.

---

## 2. Source Inventory

| Field | SRC-001 | SRC-002 | SRC-003 |
|---|---|---|---|
| **File path** | `source-materials/transcripts/call-with-vijay-chilakapati-2026-06-04.docx` | `source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx` | `source-materials/prior-analysis/claude-analysis.pdf` |
| **Source type** | Transcript / stakeholder discussion | Workbook / execution-tracking artifact | Prior AI-generated analysis (candidate conceptual architecture) |
| **Classification (COM §3)** | **Primary, internal** | **Primary, internal** | **Internal, inferred** — non-authoritative |
| **Provenance** | Recorded call with Vijay Chilakapati; exported to .docx; captured from `~/Downloads/Call with Vijay Chilakapati (1).docx` | astraX experiment-tracking workbook (June–Nov period); captured from `~/Downloads/astraX_JuneToNov_Experiment_All_Tracking.xlsx` | PDF export of a Claude-generated analysis ("execution-platform — Candidate Conceptual Architecture", marked `draft`, astraX); PDF metadata: Creator "Claude", Author "Vasudeva Rao", created 2026-06-05; captured from `~/Downloads/Claude.pdf` |
| **Capturer** | Vasu (vasu@astraanalytical.com), via repository intake session | Same | Same |
| **Capture date** | 2026-06-05 | 2026-06-05 | 2026-06-05 |
| **Date / as-of date** | Call date 2026-06-04 | Covers June–November tracking period; exact as-of date of last update **not yet determined** (see §4 uncertainty) | Authored 2026-06-05 (per PDF metadata); synthesizes pre-capture discussions |
| **Fidelity** | Verbatim export (assumed; not yet verified against recording) | Original artifact, byte-identical copy (md5-verified at intake) | Original artifact, byte-identical copy (md5-verified at intake) |
| **Freshness class (COM §4)** | Time-sensitive | Time-sensitive | Time-sensitive |
| **Authority level** | Highest available — evidence of record for stakeholder statements | Highest available — evidence of record for the tracking artifact itself | **Lowest** — inferred; may not be sole ground of any load-bearing assertion (weakest-link rule, COM §3) |
| **Allowed usage** | Ground stakeholder-intent claims; ground claims about what was said on 2026-06-04 (accountability app framing, dashboard vision, tracks, discovery workflow, approval posture) | Ground claims about the current tracking artifact and workflow as practiced (experiment structure, task-vs-experiment leakage, track taxonomy, ownership, status, cadence) | Hypothesis source and research input only; question lists and candidate framings may seed Research lines of inquiry |
| **Prohibited usage** | May not be treated as evidence that stated intentions are facts about the world (internal rule, COM §3: opinion is evidence of the opinion) | May not ground claims about intended future state — it evidences current practice only | **May not be cited as upstream authority by any artifact.** May not ground any Context assertion alone. Every claim in it must be re-validated against SRC-001/SRC-002 before use. The document itself declares: "NON-AUTHORITATIVE … May not be cited as upstream authority by any L0–L5 artifact." |
| **Sensitivity** | Internal — named individuals; do not redistribute | Internal business data | Internal |
| **Notes** | Primary named stakeholder: Vijay Chilakapati (founder / top acceptance authority per SRC-003's framing — to be validated against this transcript itself) | The workbook is the [W] source referenced by SRC-003's basis tags | Uses basis tags [W]=SRC-002, [T]=SRC-001, [A]=prior superseded analysis passes (not captured) |

> **ID note:** SRC-004 is intentionally unassigned at this time (no source occupies that
> ID). The current intake skips to SRC-005 per the capture directive; IDs are never
> reused, so SRC-004 remains permanently reserved-empty.

### 2.1 SRC-005 — L1 v1 scope-narrowing stakeholder capture

| Field | SRC-005 |
|---|---|
| **File path** | `source-materials/product-discussions/l1-product-intent-scope-narrowing-2026-06-07.md` |
| **Source type** | Stakeholder discussion / v1 scope-narrowing direction (text exchange) + labeled operator capture context |
| **Classification (COM §3)** | **Primary, internal** (verbatim stakeholder evidence); operator correction section labeled separately as authoritative project direction |
| **Provenance** | Text exchange with Vijay Chilakapati on 2026-06-07; verbatim quotes and a follow-up clarification preserved; captured into repository 2026-06-09 |
| **Capturer** | Vasu (vasu@astraanalytical.com) |
| **Capture date** | 2026-06-09 |
| **Date / as-of date** | 2026-06-07 (communication date) |
| **Fidelity** | Verbatim quotes preserved exactly; capture context and operator correction delineated as non-stakeholder content |
| **Freshness class (COM §4)** | Time-sensitive |
| **Authority level** | Highest available for v1 scope intent — most recent founder direction; supersedes nothing but **narrows** prior intent framing |
| **Allowed usage** | Narrow Product Intent to a v1 simple controlled table editor; ground create/edit of experiment/work-item/task rows as v1 intent; ground removal of escalation-to-Vijay from product scope; ground treating access control as a simple separate-app **pattern** constraint (not NDT-SaaS reuse) |
| **Prohibited usage** | May **not** define UI layout, database schema, API endpoints, or exact auth/access-control implementation; may **not** import or assume NDT-SaaS architecture; may **not** introduce an escalation workflow; may **not** define dashboard or operations-agent functionality for v1 |
| **Sensitivity** | Internal — named individual; do not redistribute |
| **Notes** | The follow-up "Yes" answers an either/or question and is **ambiguous on its face**; the operator correction in the source file (§2) is the disambiguating authority — "access control like we already have" means *similar simple pattern*, **not** NDT-SaaS reuse. `execution-platform` is a **separate application** from NDT-SaaS. |

### 2.2 SRC-006 — L1 track placement confirmation

| Field | SRC-006 |
|---|---|
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
| **Prohibited usage** | May **not** imply NDT-SaaS reuse or architectural coupling; may **not** define implementation architecture, access-control implementation, deployment, or technology; may **not** override ADR-000 separate-app boundary (CTX-11) |
| **Sensitivity** | Internal |
| **Notes** | Track classification is a product-organization concern, not an architectural decision. "OPS Cloud track" is a *business classification* only; it does not change the separate-app boundary established by CTX-11 and ADR-000. |

---

## 3. Source Quality Classification

Per Context Operating Model §3:

- **SRC-001 — primary internal.** Firsthand record of a stakeholder discussion,
  originating inside the organization. May directly ground Context assertions about what
  stakeholders said and intend, with the internal-source caveat that statements evidence
  the statement, not the asserted fact.
- **SRC-002 — primary internal.** The authoritative tracking artifact itself, not a
  report about it. May directly ground Context assertions about the artifact's structure
  and the workflow it embodies.
- **SRC-003 — inferred analysis, internal, non-authoritative.** Derived by AI reasoning
  over SRC-001, SRC-002, and uncaptured discussions. Self-declares non-authoritative
  status. Under the weakest-link rule it may inform but never solely ground a
  load-bearing assertion. Functionally closer to pre-existing Research than to a Source
  Material; it is registered as a Source Material only to preserve it as evidence of the
  prior analysis pass.
- **SRC-005 — primary internal.** Firsthand founder direction narrowing v1 product
  intent, captured verbatim. May directly ground v1 scope-intent assertions, with the
  internal-source caveat (statements evidence stated intent, not validated demand). The
  follow-up "Yes" is ambiguous on its face and is disambiguated by the operator
  correction recorded in the source file (separate-app pattern, **not** NDT-SaaS reuse).
- **SRC-006 — primary internal.** Operator confirmation of execution-platform's track
  placement within astraX's track taxonomy. May directly ground the product
  classification assertion (CTX-14) and resolve OQ-01. Classification is a
  product-organization concern only; it does not imply NDT-SaaS reuse or override the
  separate-app boundary (CTX-11, ADR-000).

---

## 4. Freshness Assessment

Per Context Operating Model §4, all four registered sources are **time-sensitive**; none
is timeless, none is yet obsolete.

| Source | As-of date | Validity horizon (review-by) | Uncertainty |
|---|---|---|---|
| SRC-001 | 2026-06-04 (call date) | 2026-09-04 (proposed: 3 months — stakeholder intent and approval posture can shift) | Low — call date is in the filename and consistent with file timestamps. |
| SRC-002 | **Resolved (was uncertain).** Internal target end dates (2026-06-14 … 2026-10-15) and "Jun–Nov roadmap" guidance confirm the tracking window is **June–November 2026** — a live tracker. As-of date: **no earlier than 2026-06-04** (file modification date). Resolution evidence: RES-001 F-25 (GAP-007 closed). | 2026-07-04 (proposed: 1 month — live tracker; contents decay continuously and should be re-captured before L1 handoff if stale) | Resolved 2026-06-05. Residual: the file is a snapshot of a living document; later edits are not captured. |
| SRC-003 | 2026-06-05 (PDF creation date) | Until superseding Research/Context exists, or 2026-09-05, whichever is sooner | Low on date; high on content reliability (inferred class, not freshness). |
| SRC-005 | 2026-06-07 (communication date); captured 2026-06-09 | 2026-09-07 (proposed: 3 months — v1 scope intent can shift) | Low on date. Residual: the follow-up "Yes" is ambiguous; disambiguated by operator correction, not by the stakeholder. |
| SRC-006 | 2026-06-09 (confirmation date) | 2026-09-09 (proposed: 3 months — product classification can shift) | Low. Residual: single operator confirmation; no corroborating stakeholder source. |

Proposed horizons are intake defaults; the Context Synthesis step may revise them with
rationale.

---

## 5. Usage Rules

1. **SRC-001 (transcript)** may support stakeholder-intent claims: what Vijay/the team
   said about the accountability app, dashboard vision, tracks, discovery workflow, and
   approval posture. Claims must cite SRC-001 with the 2026-06-04 as-of date.
2. **SRC-002 (workbook)** may support current-artifact and current-workflow claims:
   how experiments are actually structured, tracked, owned, statused, and reviewed.
   Claims must cite SRC-002 and carry its as-of date once resolved (§4).
3. **SRC-003 (prior analysis)** may be used **only** as hypothesis and research input —
   e.g., its candidate concepts and twelve open questions may shape Research lines of
   inquiry. It must never be cited as authority, and no Context assertion may rest on it
   alone. Any SRC-003 claim adopted into Context must first be validated against
   SRC-001, SRC-002, or future primary captures, and the citation must point at the
   validating primary source.
4. **Weakest-link enforcement:** any Context assertion whose citation chain includes
   SRC-003 inherits inferred-grade weight unless independently grounded in SRC-001 or
   SRC-002.
5. Mixed grounding is encouraged: corroboration of SRC-001 statements by SRC-002
   artifact structure (or vice versa) strengthens assertions toward load-bearing grade.
6. **SRC-005 (v1 scope narrowing)** may ground v1 product-intent claims: that v1 is a
   simple controlled table editor for create/edit of experiment/work-item/task rows;
   that escalation-to-Vijay is out of v1 scope; that access control is a simple
   separate-app **pattern** (exact design unresolved). It may **not** ground UI, schema,
   API, exact auth, NDT-SaaS reuse, escalation-workflow, or dashboard/agent claims
   (§2.1 prohibited usage). The follow-up "Yes" must not be cited as resolving the
   OPS-Cloud-reuse-vs-pattern question — the operator correction resolves it.
7. **SRC-006 (track placement confirmation)** may ground the product classification
   claim that execution-platform belongs under the OPS Cloud track (CTX-14). It may
   **not** imply NDT-SaaS reuse, architectural coupling, implementation architecture,
   deployment, technology choices, or override of the separate-app boundary (CTX-11,
   ADR-000). Classification is a product-organization concern only (§2.2 prohibited
   usage).

---

## 6. Missing Evidence

Source materials not yet captured, needed before full L0 Context can be approved.
(Listed as gaps only; contents are not assumed.)

| Gap ID | Missing material | Why needed | Target folder |
|---|---|---|---|
| GAP-001 | Raw chat notes on **task vs experiment** | SRC-003 flags this as unresolved (its §9 Q1–Q2) but the underlying discussion is uncaptured; only primary capture can ground it | `source-materials/product-discussions/` |
| GAP-002 | Raw chat notes on **approval authority** | Approval posture appears in SRC-001/SRC-003 framing, but the dedicated thread is uncaptured. **PARTIALLY ADDRESSED 2026-06-09:** SRC-005 directs that escalation-to-Vijay is not modeled in v1, removing escalation from v1 product scope; however, the broader acceptance/approval-authority question (OQ-02 / CON-002) remains **uncaptured and open** for any future approval feature | `source-materials/product-discussions/` |
| GAP-003 | Raw chat notes on **commitment vs experiment** | SRC-003 cites an earlier "commitment as the atom" framing from an uncaptured discussion | `source-materials/product-discussions/` |
| GAP-004 | Raw chat notes on **review cadence** (Friday-update / Monday-leads ritual) — **DOWNGRADED 2026-06-05:** substantially closed by SRC-002 primary evidence (How To Use: Friday updates, weekly standups, Monday leads meeting; RES-001 F-18). No longer blocking; capture would enrich but is deferable | ~~Cadence referenced only in SRC-003~~ Now primary-evidenced in SRC-002 | `source-materials/product-discussions/` (optional) |
| GAP-005 | Screenshots or emails related to the **accountability app / workbook** usage | Would corroborate SRC-002's workflow-as-practiced and SRC-001's framing | `source-materials/reference/` |
| GAP-006 | Prior (superseded) architecture passes tagged [A] in SRC-003 | SRC-003 cites them; without capture, [A]-based claims are unverifiable | `source-materials/prior-analysis/` |
| GAP-007 | ~~Resolution of SRC-002's as-of date / tracking-window year~~ **RESOLVED 2026-06-05:** window confirmed as June–November 2026 via internal dates and "Jun–Nov roadmap" guidance (RES-001 F-25); as-of ≥ 2026-06-04; freshness table (§4) updated | Closed | n/a |

---

## 7. Contradiction Register

Initialized empty at intake (no contradictions visible from filenames/metadata alone).
Entries CON-001 and CON-002 added 2026-06-05 from L0 Research Pass 1 (RES-001 §3), per
Context Operating Model §5.

| CON ID | Sources in conflict | Nature of conflict | Quality/freshness of each side | Status | Disposition / rationale |
|---|---|---|---|---|---|
| CON-001 | SRC-002 vs SRC-001 | Fixed track dropdown ("T1 Device through T6 Sales") in the workbook vs evolving taxonomy in the transcript one day later: T7 "internal tooling" floated without recorded adoption, sub-tracks agreed ("2 inside 2 and two inside 3"), accountability app has no home track | Both primary internal; SRC-001 fresher by one day (2026-06-04 call vs workbook as-of ≤ 2026-06-04) | **Held open** | COM §5.2(2): carried forward as explicit open question (RES-001 OQ-01, OQ-07; CTX-SYN-001 §6). Downstream rule: track set must be treated as unstable/configurable data; no artifact may assume a fixed taxonomy |
| CON-002 | SRC-003 vs SRC-001 + SRC-002 | SRC-003 posits an owner/lead acceptance architecture (submit → approve/reject/revise; lead ≠ owner; no self-acceptance) implying transcript support; primary sources contain **no acceptance lifecycle** — workbook statuses are execution-only, transcript evidences only informal deliverable review by Vijay | SRC-003 inferred internal (lowest authority) vs two primary internal sources; all current (2026-06-04/05) | **Held open** | COM §5.2(2): carried as open question (RES-001 OQ-02; CTX-SYN-001 §6), pending GAP-002 capture of raw approval-authority discussions. Downstream rule: no acceptance-lifecycle claim may be asserted as fact; SRC-003's model remains uncorroborated hypothesis |

---

## 8. Acceptance Criteria (draft → approved)

This register may move from `draft` to `approved` when all of the following hold:

- [ ] Every file present under `source-materials/` has a register entry with a stable
      Source ID, and every register entry points at an existing file (bidirectional
      completeness).
- [ ] Each entry carries the full metadata set required by Context Operating Model §2.1:
      provenance, capture date, capturer, source type, fidelity, location, sensitivity,
      and freshness class.
- [ ] Each source's quality classification (§3) has been confirmed against COM §3
      definitions by a reviewer, including SRC-003's non-authoritative standing.
- [ ] The SRC-002 as-of-date uncertainty (GAP-007) is resolved and a validity horizon is
      recorded; SRC-001 fidelity (verbatim vs edited export) is confirmed.
- [ ] Each missing-evidence gap (§6) is either captured (and registered with a new
      Source ID), or explicitly waived with recorded rationale and carried forward as a
      known gap.
- [ ] The Contradiction Register section exists and any contradictions surfaced during
      intake review are entered, not smoothed over (COM §5).
- [ ] The register contains no product conclusions, requirements, intent, domain
      concepts, architecture, or technology choices.
- [ ] Source files remain byte-identical to their captured originals (checksums match;
      no source file was modified by intake).
- [ ] Review is logged per COM §6 (`draft` → `review` → `approved`); no bootstrap
      exception is claimed.
