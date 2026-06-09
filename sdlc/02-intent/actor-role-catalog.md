# Actor / Role Catalog — Execution-Platform

## Status
draft

## Layer
L1 Intent

## Version
0.1.0

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md` (Process Constitution v1.0.0)
- `sdlc/01-context/context-synthesis-v0.md` (CTX-SYN-001 v0.3.0, approved 2026-06-09)
- `sdlc/01-context/glossary-seed.md` (approved 2026-06-05)
- `sdlc/02-intent/l1-intent-recon.md` (approved 2026-06-06)
- `sdlc/02-intent/product-intent-brief.md` (approved 2026-06-09)
- `architecture/decisions/ADR-000-product-v1-scope-and-boundaries.md` (accepted 2026-06-09)

## Downstream Consumers
- Product Requirements Document (L1)
- Non-Functional Requirements (L1)
- Future Authorization Specification (L2)
- Future Workflow Specification (L2)
- Future UI Specification (L3)

---

> **v1 scope notice.** This catalog is scoped to the v1 execution-platform — a simple
> controlled table editor for experiment/work-item/task rows, as a **separate
> application** from NDT-SaaS (CTX-11; ADR-000). Two actors are firmly evidenced.
> Several candidate actors exist but cannot be confirmed without new primary source
> capture. This artifact **may not enter `review`** until OQ-02 and OQ-10 are resolved.

---

## 1. Artifact Header

| Field | Value |
|---|---|
| Status | draft |
| Layer | L1 Intent |
| Version | 0.1.0 |
| Created | 2026-06-09 |

---

## 2. Actor Catalog Scope

### 2.1 What This Catalog May Identify

This catalog identifies **principals** who interact with execution-platform, for the
purpose of informing downstream L1 artifacts (PRD, NFRs) and downstream L2/L3 artifacts
(Authorization Specification, Workflow Specification, UI Specification).

At L1, actors are classified by:

- **Evidenced actors** — principals directly supported by approved Context assertions
  (CTX IDs), grounded in primary internal sources. These may be cited by downstream
  artifacts.
- **Candidate / unresolved actors** — principals whose existence is plausible from
  partial evidence but whose specific role, authority, or scope cannot be confirmed
  without new primary source capture. Downstream artifacts must not assert these as
  facts.
- **Future-direction actors** — entities mentioned as future product direction only;
  not v1 actors and not eligible for downstream v1 assertions.
- **Reader / writer distinctions** — where evidence supports distinguishing who reads
  execution state from who creates or edits it.

### 2.2 What This Catalog May Not Define

This catalog may not define at this layer:

- **Permission assignments** — which actor may access which route, resource, or data
  set. This is an L2 Authorization Specification concern.
- **Approval or acceptance workflow** — no acceptance lifecycle is established in any
  primary source (CON-002; OQ-02; CTX-SYN-001 §4 items 1–2). The catalog must not
  model it.
- **UI screens, interaction flows, or navigation paths** — L3 Structure concern.
- **API contracts, endpoint access rules, or field-level access** — L3 Structure concern.
- **Database schemas, data model, or persistence design** — L3 Structure concern.
- **Technology or authentication mechanism** — the exact access-control design is
  explicitly unresolved (CTX-12; CTX-SYN-001 §4 item 10). This catalog does not
  resolve it.
- **NDT-SaaS actor model, roles, or permissions** — execution-platform is a completely
  separate application (CTX-11; ADR-000 §1); no NDT-SaaS actor definition, role
  hierarchy, or permission model is inherited or assumed.

---

## 3. Evidence-Grounded Actors

The following actors are grounded in approved Context assertions (CTX-SYN-001 v0.3.0)
from primary internal sources. Each entry cites its CTX IDs and states the evidence
limits precisely.

### ACT-01 — Vijay Chilakapati (Founder / Management Execution Reader)

| Field | Value |
|---|---|
| **Actor ID** | ACT-01 |
| **Name / Role Label** | Vijay Chilakapati — Founder / Management Execution Reader |
| **CTX IDs** | CTX-07, CTX-01, CTX-02 |
| **Primary evidence** | SRC-001 (named individual; articulates dashboard direction; states management-execution purpose); SRC-002 (Owner column value: Vijay — named row owner) |

**Current role in v1 intent:**

Vijay is the **primary named user** and the product's stated authority for direction.
Two distinct roles are evidenced for the same individual:

1. **Management Execution Reader.** Vijay articulates the dashboard / accountability
   app as a tool for *management execution* — reading rolled-up execution state across
   the organization to run the business [CTX-07]. He is the **only explicitly evidenced
   consumer** of the management-execution read surface.

2. **Row Owner / Creator (also).** Vijay appears as an Owner in SRC-002 (experiment
   rows assigned to him). He uses the current workbook as a data-entry actor as well as
   a reader.

In v1, both roles apply: Vijay may create and edit experiment/work-item/task rows as a
named owner, and is the primary intended reader of any execution-state summary.

**Allowed downstream usage:**
- May ground PRD statements that the product must surface execution state to a
  management-level reader.
- May ground a "management reader" persona in PRD and workflow specifications.
- Vijay is a named individual; "Vijay" is evidence citation, not a system role name.

**Limitations:**
- Dashboard readership **beyond** Vijay is **unresolved** (OQ-10; CTX-SYN-001 §4
  item 8). No other reader class is evidenced; no reader class may be asserted.
- "Escalate to Vijay" appears in SRC-002 as a next-action example [CTX-06]; it is
  **not modeled** as a product pathway in v1 (CTX-10). This evidence does not ground
  any escalation feature.
- Whether Vijay holds any **formal approval or acceptance authority** over experiment
  rows is not established (CON-002; OQ-02). This catalog does not assert such authority.

---

### ACT-02 — Row Owner / Creator (Experiment / Work-Item / Task Owner)

| Field | Value |
|---|---|
| **Actor ID** | ACT-02 |
| **Name / Role Label** | Row Owner / Creator — the named individual responsible for creating and editing a work row |
| **CTX IDs** | CTX-02, CTX-03, CTX-09, CTX-13 |
| **Primary evidence** | SRC-002 (Owner column; named values: Vijay, Sreekar, Gopinath, Ravi, Aditya; single-owner-per-row convention; status update obligation); SRC-001 (10:32: "Who are the owners for these?"; hypothesis rule; missing ownership treated as defect) |

**Current role in v1 intent:**

The **Row Owner / Creator** is the actor who creates and edits experiment,
work-item, and task rows in the v1 table editor. This actor:

- Has a single named identity per row (single owner per row is evidenced practice
  [CTX-02]).
- Is responsible for keeping rows current: status, outcome/finding, and next action,
  updated by Friday for the weekly standup [CTX-01, CTX-06].
- Rows without an owner are treated as defective by the founder [CTX-03].
- In v1, creates and edits rows sharing a common column set [CTX-09, CTX-13].

Named individuals evidenced in SRC-002 as owners: Vijay, Sreekar, Gopinath, Ravi,
Aditya. The actor class extends to any future team member who creates or edits a work
row.

"Owner" is defined in the Glossary Seed and must be used per that definition:
*the single named person responsible for a work row.*

**Allowed downstream usage:**
- May ground PRD statements about who creates and edits work rows.
- May ground the single-owner-per-row constraint.
- May ground the discipline-leakage problem statement (rows without owners are
  defective) [CTX-03].

**Limitations:**
- Whether "owner" implies any **approval, acceptance, or review authority** over other
  rows is NOT established [CON-002; OQ-02]. The catalog does not assert such authority.
- The **mandatory-field policy** (which columns, if any, a row owner must populate) is
  unresolved [CTX-13; CTX-SYN-001 §4 item 9]. Downstream artifacts must not assert it
  without new primary evidence.
- Whether experiment owners, work-item owners, and task owners form distinct sub-roles
  is unresolved — in v1 all share the same columns [CTX-13]; row-type behavioral
  distinctions are deferred to L2 Behavior / Domain Model.

---

### Not a v1 Actor — AFD-01: Future Operations Agent

| Field | Value |
|---|---|
| **Actor ID** | AFD-01 |
| **Name / Role Label** | Future Operations Agent (Sales / Manufacturing / Service) |
| **CTX IDs** | CTX-07 |
| **Status** | **Future direction only — not a v1 actor** |

Operations agents (sales, manufacturing, service) are evidenced as the **future
direction** Vijay articulates for the platform [CTX-07]: the dashboard is intended to
remain the durable read surface above these agents as they come online. They are NOT
v1 actors and must not be included in v1 PRD requirements, authorization design, or
workflow specifications. Future releases may introduce them, requiring a new primary
capture at that time.

---

## 4. Candidate / Unresolved Actors

The following actors are plausible from partial evidence but cannot be confirmed as
approved actors without new primary source capture. Downstream artifacts must not assert
these as facts until the blocking OQs are resolved.

### CACT-01 — Dashboard Reader (beyond Vijay)

| Field | Value |
|---|---|
| **Candidate ID** | CACT-01 |
| **Name / Role Label** | Dashboard Reader — a principal who consumes execution-state summaries but may not necessarily be a row creator |
| **OQ blocking** | OQ-10 — *Who consumes the dashboard besides Vijay?* |

**Why unresolved:**
The product intent establishes a management-execution read surface [CTX-07], but
readership beyond Vijay is explicitly not established [CTX-SYN-001 §4 item 8].
Whether "leads" (Monday leads meeting attendees), all experiment owners, or the whole
team are also intended readers is unevidenced. Any assertion of a reader class beyond
the founder would violate the no-invention rule (Constitution §5.1).

**Source evidence needed:**
A new primary stakeholder capture (new SRC ID) recording who besides Vijay is an
intended reader of the management-execution surface. Must distinguish, if applicable,
between read-only consumers and principals who also create/edit rows.

**May not be asserted until resolved:**
- Any PRD requirement specifying a reader class beyond Vijay.
- Any access-control statement implying a read-only role for anyone other than Vijay.
- Any actor catalog entry for team-wide, leads-level, or owner-level readership of
  the summary surface.

---

### CACT-02 — Lead (as a Distinct Role beyond Row Owner)

| Field | Value |
|---|---|
| **Candidate ID** | CACT-02 |
| **Name / Role Label** | Lead — a principal who chairs the Monday leads meeting and may hold a distinct authority within a track |
| **OQ blocking** | OQ-02 — *Does any acceptance/approval step exist, and who holds it?* |

**Why unresolved:**
The term "leads" appears in evidence as the attendees of the Monday leads meeting
[CTX-01; Glossary Seed: *Monday leads meeting*], which "reviews weekly progress and
challenges and sets priorities." This evidences that some principals have a leads-level
responsibility. However:

- The Glossary Seed explicitly notes: "who counts as a 'lead' is unevidenced — relevant
  to the open acceptance/authority question (OQ-02) but not answered by this term."
- Whether a "lead" holds any authority over experiment rows *beyond* meeting attendance
  (e.g., ability to reprioritize, gate, or approve rows) is NOT established.
- Constitution §5.1 prohibits asserting authority semantics for "lead" beyond the
  Glossary Seed definition.

**Source evidence needed:**
A new primary stakeholder capture resolving OQ-02: does a lead hold any formal
prioritization, acceptance, or approval authority over rows in their track? Is there a
meaningful distinction between a track lead's product role and a row owner's role beyond
meeting participation?

**May not be asserted until resolved:**
- Any lead actor with approval or acceptance authority over experiment rows.
- Any workflow step distinguishing lead-level review from owner-level data entry.

---

### CACT-03 — Approver / Acceptor

| Field | Value |
|---|---|
| **Candidate ID** | CACT-03 |
| **Name / Role Label** | Approver / Acceptor — a principal who formally accepts or validates a row or experiment result |
| **OQ blocking** | OQ-02; CON-002 (held open) |

**Why unresolved:**
SRC-003 (inferred, non-authoritative) posited an owner/lead acceptance architecture
(submit → approve/reject/revise; lead ≠ owner; no self-acceptance). Primary sources
(SRC-001, SRC-002) contain **no acceptance lifecycle** — workbook statuses are
execution-only; the transcript evidences only informal deliverable review by Vijay
[CON-002; CTX-SYN-001 §4 items 1–2]. The SRC-003 model is uncorroborated and must
not be asserted as fact. The Approver / Acceptor actor remains a candidate only.

**Source evidence needed:**
A new primary stakeholder capture (GAP-002) of the raw approval-authority discussions.
Must answer: is there any formal acceptance step, who holds it, and over what scope?

**May not be asserted until resolved:**
- Any approval or acceptance lifecycle role in PRD, authorization spec, or workflow spec.
- Any "lead approves owner's experiment" or "Vijay accepts on escalation" workflow.
- Any acceptance state (submitted, approved, rejected, revised) on any work row.

---

### CACT-04 — Access-Control Administrator / System Operator

| Field | Value |
|---|---|
| **Candidate ID** | CACT-04 |
| **Name / Role Label** | Access-Control Administrator — a principal who configures or manages access control for the separate execution-platform application |
| **OQ blocking** | CTX-12 exact access-control design open (CTX-SYN-001 §4 item 10) |

**Why unresolved:**
v1 requires *some* simple access-control pattern for the separate application [CTX-12;
ADR-000 §Recorded boundaries item 5], but the exact design — including whether a
distinct administrator role is needed, and what its scope would be — is deferred to
PRD/L3. Vasu (vasu@astraanalytical.com) is the product builder and will likely hold
deployment-level administrative access, but this has not been defined as a product
role in any primary evidence.

execution-platform is a **completely separate application** from NDT-SaaS [CTX-11;
ADR-000]. No NDT-SaaS administrator role, permission model, or auth mechanism is
inherited or assumed.

**Source evidence needed:**
The PRD or L3 Structure must define the access-control mechanism before a system
administrator or operator actor can be authoritatively specified.

**May not be asserted until resolved:**
- Any admin role with specific permission-assignment capabilities.
- Any role implying NDT-SaaS auth integration or shared user base.
- Any specific authentication mechanism (tokens, sessions, SSO).

---

## 5. Role / Authority Boundaries

This section states the authority-model constraints governing all downstream consumers
of this catalog. These are evidence-derived constraints, not implementation decisions.

### 5.1 Ownership is evidenced; approval authority is not

**Single-row ownership** — one named owner per experiment/work-item/task row — is
established by primary evidence [CTX-02; SRC-002 Owner column]. Downstream artifacts
may assert:
- A row carries exactly one named owner.
- Rows without owners are treated as defective in current practice [CTX-03].

**Approval authority** — any authority by which a principal formally accepts, approves,
or validates a row or experiment result — is **not established** by any primary source
[CON-002; OQ-02]. Downstream artifacts must not assert any approval or validation
authority for any actor until OQ-02 is resolved via new primary evidence.

### 5.2 Acceptance lifecycle is not established

No acceptance states (submitted, approved, rejected, revised) exist in any
primary-evidenced artifact. The workbook status vocabulary is execution-only: Not
Started → In Progress → {Complete, Blocked, Inconclusive} [CTX-05]. Downstream
artifacts must not model any acceptance state beyond this vocabulary until OQ-02 is
resolved.

### 5.3 Access-control design is unresolved

v1 requires a simple access-control pattern [CTX-12]; the exact design — roles,
permissions, authentication mechanism — is deferred to PRD/L3 [CTX-SYN-001 §4 item 10;
ADR-000 §Recorded boundaries item 5]. Downstream artifacts must not specify permission
assignments, role-permission matrices, or auth implementation until that design is
approved through the appropriate layer.

### 5.4 Separate-application boundary is intact

execution-platform is a **completely separate application** from NDT-SaaS [CTX-11;
ADR-000 §Recorded boundaries item 1]. No actor, role, permission, or auth mechanism
from NDT-SaaS is inherited, reused, or assumed. Any actor model for the separate
application must be defined independently of NDT-SaaS.

### 5.5 No NDT-SaaS reuse assumed

"Access control like we already have" / "OPS Cloud" means a *similar simple pattern*
for the separate app — not reuse of NDT-SaaS actor definitions, role hierarchies, or
permission model [CTX-12; ADR-000 §Recorded boundaries item 2]. Downstream artifacts
must not import NDT-SaaS roles or permission structures.

---

## 6. Actor Interaction Summary

At L1 only. No workflow states, permission matrices, UI flows, or implementation
decisions.

| Actor | Interaction with v1 | Authority | Evidence |
|---|---|---|---|
| **ACT-01 Vijay** | Reads rolled-up execution state for management purposes; also creates/edits rows as a named owner | Named reader + named owner — no approval authority established | CTX-07, CTX-01, CTX-02 |
| **ACT-02 Row Owner / Creator** | Creates and edits experiment/work-item/task rows in the table editor; keeps status, outcome, and next-action current | Owns their rows; no approval authority over others established | CTX-02, CTX-03, CTX-09, CTX-13 |
| **CACT-01 Dashboard Reader** | Reads execution state — scope and membership **unresolved** | Read-only — scope unresolved (OQ-10) | CTX-07 (partial) |
| **CACT-02 Lead** | Attends Monday leads meeting; additional product authority **unresolved** | Meeting participation evidenced; product authority not established (OQ-02) | CTX-01, Glossary Seed |
| **CACT-04 Access-Control Admin** | Manages system access — design **unresolved** | Administration scope deferred to PRD/L3 (CTX-12) | CTX-12 |

**Interactions NOT modeled in v1 (explicitly out of scope per approved PIB §10.3):**
- Escalation-to-Vijay workflow (CTX-10) — not a modeled pathway.
- Approval / acceptance workflow (CON-002; OQ-02) — not established.
- Operations agent interaction (AFD-01) — future direction only.
- Any NDT-SaaS actor interaction — separate application (CTX-11; ADR-000).

---

## 7. Open Questions Blocking Review

This Actor / Role Catalog may be drafted but **may not enter `review`** until both of
the following open questions are resolved via new primary source capture. Resolution
requires new SRC IDs registered in the Source Intake Register.

### OQ-02 — Approval / Acceptance Authority

**Question:** Does any acceptance or approval step exist in the current or intended
process — at which a row or experiment result moves from "in progress" to a formally
reviewed or accepted state? If so, who holds that authority, over what scope, and can
it be held by someone other than Vijay (e.g. a track lead, an experiment owner)?

**Why this blocks review:** If an acceptance actor exists, this catalog is incomplete
without it — and downstream Authorization Specification and Workflow Specification
would be materially different with or without it. If no such actor exists, the catalog
must explicitly confirm that. Either answer changes the actor model.

**Status:** CON-002 held open. No primary evidence. GAP-002 not yet captured.
SRC-003's acceptance model is inferred-only and must not be assumed.

**Required:** New primary stakeholder capture. Resolving this opens CACT-02 and CACT-03
for final disposition.

---

### OQ-10 — Dashboard Readership Beyond Vijay

**Question:** Who, beyond Vijay, is an intended consumer of the dashboard / management-
execution view? Is it all track leads? All experiment owners? The whole team? Is there
a distinction between who can read execution state and who can create/edit rows?

**Why this blocks review:** The management-execution read surface is a first-class
product capability [CTX-07]. Without knowing who reads it, this catalog cannot define
the full actor set, and the PRD cannot specify requirements for a reader class beyond
the founder. The dashboard reader is CACT-01 — it may not be promoted to an evidenced
actor until this question is resolved.

**Status:** Open. Vijay is the only evidenced reader. OQ-10 unresolved.

**Required:** New primary stakeholder capture. Resolving this promotes or retires
CACT-01.

---

## 8. Stakeholder Validation Questions

The following questions must be asked in a stakeholder session and captured as new
primary Source Materials (new SRC IDs in the Source Intake Register). They are stated
as questions only — they are not answered here.

1. **Approval / acceptance authority (resolves OQ-02 / closes CON-002):**
   Does any step exist in the current or intended product at which an experiment row
   moves from "in progress" or "complete" to a formally reviewed or accepted state?
   If so: who has the authority to accept it? Is it always Vijay, or can a track lead
   accept within their track? Can a row owner self-accept? Is there a submit-and-review
   cycle, or is completion self-declared?

2. **Dashboard readership (resolves OQ-10):**
   Beyond Vijay, who is an intended consumer of the management-execution view or summary?
   Is it all experiment owners, track leads only, or the whole team? Is there a
   distinction between who can read the execution-state dashboard and who can create
   or edit rows?

3. **Lead as a distinct product role (informs CACT-02):**
   Do track leads hold any distinct authority in the product beyond attending the Monday
   leads meeting — such as the ability to prioritize, reprioritize, or gate experiment
   rows within their track? Is "lead" a product role, or is it purely an organizational
   meeting label?

4. **Access-control structure (informs CACT-04):**
   Who is responsible for adding and removing principals from the system? Is there an
   administrator role distinct from row owners and readers? Should the system enforce
   track-scoped access (an owner sees only their track's rows) or is access flat
   across all rows?

---

## 9. Acceptance Criteria

This Actor / Role Catalog may move from `draft` to `approved` when all of the
following hold:

- [ ] All nine required sections are present and non-empty.
- [ ] Every evidenced actor in §3 cites ≥1 CTX ID from CTX-SYN-001 v0.3.0; no actor
      is asserted without traceable grounding in approved Context.
- [ ] OQ-02 is resolved via a new primary Source Material (new SRC ID registered in
      the Source Intake Register); the resolution either promotes CACT-03 (if an
      acceptance actor exists) or explicitly confirms that only execution-only statuses
      apply (if it does not).
- [ ] OQ-10 is resolved via a new primary Source Material (new SRC ID); CACT-01 is
      promoted to an evidenced actor with defined membership, or explicitly retired if
      readership is Vijay-only.
- [ ] CACT-02 (Lead) and CACT-04 (Access-Control Admin) are either promoted to
      evidenced actors with CTX grounding, or formally retired with recorded rationale.
- [ ] No actor carries an approval, acceptance, or validation authority assertion without
      primary evidence.
- [ ] No permission assignments, role-permission matrices, or authentication
      implementation details appear anywhere in the artifact.
- [ ] No NDT-SaaS actor, role, permission, or auth model is referenced or assumed; the
      separate-application boundary (CTX-11; ADR-000) is intact.
- [ ] No acceptance lifecycle states (submitted / approved / rejected / revised) appear
      for any actor.
- [ ] The artifact contains no UI layouts, API contracts, database schema, or technology
      choices (Constitution §4 must-not-contain rules for Actor / Role Catalog class).
- [ ] All upstream authority artifacts (Process Constitution, CTX-SYN-001 v0.3.0,
      Glossary Seed, L1 Intent Recon, Product Intent Brief) are `approved` at review
      time.
- [ ] The artifact declares `Status`, `Layer`, `Version`, `Upstream Authority`, and
      `Downstream Consumers` in conformance with Constitution §7.
- [ ] Review is logged per Constitution §6 (`draft` → `review` → `approved`); no
      bootstrap exception is claimed.
