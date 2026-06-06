# L0 Glossary Seed

## Status
approved (L0 review 2026-06-05)

## Layer
L0 Context

## Version
0.1.0

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md`
- `sdlc/01-context/context-operating-model.md`
- `sdlc/01-context/source-intake-register.md`
- `sdlc/01-context/research/l0-research-pass-1.md`

## Downstream Consumers
- L0 Context Synthesis (CTX-SYN-001)
- L1 Intent (ubiquitous-language foundation per COM §8.5)

---

## Purpose and Rules

This glossary seeds ubiquitous language **only from terms present in the primary
sources** SRC-001 (Vijay call transcript, as-of 2026-06-04) and SRC-002 (astraX
experiment workbook, as-of ≥ 2026-06-04), per COM §7 no-invention. Definitions
paraphrase the evidence; quotes are verbatim. No term is coined here; no SRC-003
terminology is seeded (its concepts — e.g. "acceptance authority", "commitment",
"unit of accountable work" — are inferred-only and excluded). Definitions describe
**current usage**, not future-system semantics; L1 may refine meanings only with
evidence or stakeholder validation.

---

## Terms

### experiment
- **Source basis:** Workbook structure and guidance; transcript discussion of what to
  list per track.
- **Source IDs:** SRC-002; SRC-001 (6:35–9:27)
- **Definition from evidence:** A unit of tracked work defined by a hypothesis ("If we
  do X, then Y will happen, because Z"), pre-written measurable success criteria, an
  experiment design, dependencies, a target end date, a single owner, and a status.
  Atomicity bound: "Any atomic experiment is NOT bigger than 2 weeks" (SRC-002).
- **Ambiguity / notes:** Whether "experiment" is the atom of any future system is open
  (CTX-SYN-001 §4); rows in the live log do not all conform (task leakage, RES-001
  F-05).
- **Downstream usage allowed:** Describe current practice; ground problem statements.
  Not yet a domain-model commitment.

### task
- **Source basis:** Workbook hypothesis tip; transcript restatement of Vijay's email.
- **Source IDs:** SRC-002 ("'Experiments' without hypotheses are just tasks"); SRC-001
  (6:35: "If we don't have the hypothesis, it's just a task")
- **Definition from evidence:** Work lacking a hypothesis. Used pejoratively in the
  evidence — a degraded experiment, not a celebrated category.
- **Ambiguity / notes:** Whether Task is a first-class concept, a type, or an absence
  is explicitly unresolved (RES-001 OQ-06; SRC-003 raises but cannot settle it).
- **Downstream usage allowed:** Name the leakage phenomenon. Must not be modeled as an
  entity without further evidence.

### hypothesis
- **Source basis:** Workbook column guidance; transcript.
- **Source IDs:** SRC-002; SRC-001 (6:35)
- **Definition from evidence:** The predictive statement defining an experiment, in the
  form "If we do X, then Y will happen, because Z." Specificity is demanded: "Bad:
  'Test the quant model.' Good: 'If we reduce GEOMINFO_ts by 20%, Mo overcall on 316
  SS will drop below 5% delta.'" (SRC-002).
- **Ambiguity / notes:** None observed; the two sources agree.
- **Downstream usage allowed:** Ground discipline-related intent.

### success criteria
- **Source basis:** Workbook column guidance.
- **Source IDs:** SRC-002
- **Definition from evidence:** The measurable pass condition, written before the
  experiment starts: "WRITE THIS BEFORE YOU START. What specifically does 'pass' look
  like? Must be measurable… Prevents moving goalposts after the fact."
- **Ambiguity / notes:** None observed.
- **Downstream usage allowed:** Ground discipline-related intent.

### experiment design
- **Source basis:** Workbook column guidance.
- **Source IDs:** SRC-002
- **Definition from evidence:** How the experiment will be run — "materials/samples
  needed, steps, number of runs, measurement method. Enough detail that someone else
  could run it in your absence."
- **Ambiguity / notes:** None observed.
- **Downstream usage allowed:** Describe current practice.

### owner
- **Source basis:** Workbook column; transcript reaction to ownerless rows.
- **Source IDs:** SRC-002 (Owner column; values Vijay, Sreekar, Gopinath, Ravi,
  Aditya); SRC-001 (10:32: "Who are the owners for these?")
- **Definition from evidence:** The single named person responsible for an experiment
  row. Missing ownership is treated as a defect by the founder.
- **Ambiguity / notes:** Evidence shows one owner per row as practice; no evidence on
  transfer, sharing, or owner-vs-reviewer distinctions.
- **Downstream usage allowed:** Ground single-ownership-as-practiced claims. Authority
  semantics beyond ownership (approval, acceptance) are NOT established (CON-002).

### track
- **Source basis:** Workbook dropdown and rows; transcript track walkthrough.
- **Source IDs:** SRC-002 ("Select from dropdown: T1 Device through T6 Sales. Links
  your experiment to the Jun–Nov roadmap"); SRC-001 (7:36–8:28: "the streams
  themselves are these right? These are projects… that's one track")
- **Definition from evidence:** A business project/line of work that experiments belong
  to. Current set: T1 AstraX Device, T2 AstraX Customer Cloud, T3 AstraX Ops Cloud,
  T4 Manufacturing partners, T5 Business, T6 Sales partner.
- **Ambiguity / notes:** "Track", "stream", "project", and "thread" are used
  near-interchangeably in SRC-001. The set is unstable (CON-001): T7 floated, sub-tracks
  agreed verbally, accountability app homeless.
- **Downstream usage allowed:** Treat as configurable data; never as a fixed
  enumeration.

### parent item
- **Source basis:** Workbook column (summary sheet).
- **Source IDs:** SRC-002 (`Parent Item` column header)
- **Definition from evidence:** A column on the team summary sheet; unpopulated in all
  inspected rows. No usage guidance exists in the How To Use sheet.
- **Ambiguity / notes:** Intended semantics unknown — possibly the carrier of
  sub-track/hierarchy structure (RES-001 OQ-07). Definition cannot be stated beyond
  the column's existence.
- **Downstream usage allowed:** Evidence that some hierarchy notion was anticipated;
  nothing more.

### function
- **Source basis:** Workbook column (summary sheet).
- **Source IDs:** SRC-002 (`Function` column; observed value "Mechanical")
- **Definition from evidence:** A discipline/department label on experiment rows
  (e.g. Mechanical).
- **Ambiguity / notes:** Only "Mechanical" observed; full value set and purpose
  (filtering? reporting?) unevidenced.
- **Downstream usage allowed:** Evidence that work is also sliced by discipline.

### status
- **Source basis:** Workbook column guidance and STATUS SUMMARY block.
- **Source IDs:** SRC-002 ("Select from Drop Down (Not Started → In Progress →
  Complete or Blocked or Inconclusive). Update every Friday. Row turns green on
  Complete, red on Blocked automatically.")
- **Definition from evidence:** The execution state of an experiment row, from a fixed
  five-value vocabulary, updated weekly, with visual encoding and aggregate counts.
- **Ambiguity / notes:** Execution-only vocabulary; nothing after Complete is
  evidenced (OQ-09). No acceptance states exist (CON-002).
- **Downstream usage allowed:** Describe the current lifecycle as practiced.

### outcome / finding
- **Source basis:** Workbook column guidance.
- **Source IDs:** SRC-002 ("Fill in AFTER the experiment. State the actual result in
  one sentence. Then note what it means: 'Pass — confirms hypothesis' or 'Fail — Mo
  delta was 9%, not <5%…'")
- **Definition from evidence:** The post-experiment record of the actual result and its
  interpretation, judged against the success criteria.
- **Ambiguity / notes:** This is where learning lives in current practice — as an
  attribute, not a separate register (RES-001 F-20; cross-portfolio queryability is
  open, OQ-08).
- **Downstream usage allowed:** Ground learning-capture-as-practiced claims.

### next action
- **Source basis:** Workbook column guidance.
- **Source IDs:** SRC-002 ("What does this result trigger? Must be actionable.
  Examples: 'Run experiment #2 with adjusted detector angle' or 'Update CalcEngine
  GEOMINFO_ts to 0.8x and retest' or 'Escalate to Vijay — blocked on DPP gain
  setting.'")
- **Definition from evidence:** The actionable consequence an outcome must trigger —
  a follow-on experiment, an artifact update, or an escalation.
- **Ambiguity / notes:** "Escalate to Vijay" appears as an example; the escalation
  procedure is otherwise unevidenced (OQ-03).
- **Downstream usage allowed:** Ground result-triggered-follow-up-as-practiced claims.

### standup
- **Source basis:** Workbook How To Use (weekly ritual section and header).
- **Source IDs:** SRC-002 ("weekly standup calls — Update XL before the standup"; "Can
  Filter by Track or Status to run standup")
- **Definition from evidence:** A recurring team call run off the summary sheet,
  filtered by Track or Status, with the workbook updated beforehand.
- **Ambiguity / notes:** Frequency stated as weekly; day not specified (Friday is the
  update deadline; the standup/update relationship is "before").
- **Downstream usage allowed:** Ground cadence claims.

### Monday leads meeting
- **Source basis:** Workbook weekly ritual.
- **Source IDs:** SRC-002 ("Monday (Leads meeting) — Review weekly progress and
  challenges, prioritize")
- **Definition from evidence:** A Monday meeting of leads that reviews weekly progress
  and challenges and sets priorities.
- **Ambiguity / notes:** Who counts as a "lead" is unevidenced — relevant to the open
  acceptance/authority question (OQ-02) but not answered by this term.
- **Downstream usage allowed:** Ground cadence claims; "leads" as a role must not be
  given authority semantics from this term alone.

### accountability app
- **Source basis:** Transcript naming exchange.
- **Source IDs:** SRC-001 (5:29–5:49: Vasu "the accountability app"; Vijay "the
  accountability app is the one that I just explained to you, right?"; tied to "the
  sheets that you sent in the email")
- **Definition from evidence:** The working name for the envisioned internal tool that
  replaces the experiment workbook with a UI and dashboard.
- **Ambiguity / notes:** Name introduced by Vasu and loosely confirmed by Vijay; not an
  official product name. The app has no home track (9:34).
- **Downstream usage allowed:** Refer to the product idea by this name with the naming
  caveat.

### management execution
- **Source basis:** Transcript.
- **Source IDs:** SRC-001 (10:32: "I want each one of us to do this and then we will
  use this to. Management execution.")
- **Definition from evidence:** The founder's stated purpose for the workbook/dashboard:
  using rolled-up execution records to run the organization.
- **Ambiguity / notes:** The phrase is fragmentary in the transcript; its precise scope
  is interpreted minimally here. Related ambition: "How do you use AI to run your
  organization?" (0:31).
- **Downstream usage allowed:** Ground purpose/vision statements, with the
  internal-source caveat (evidence of stated intent).

### dashboard
- **Source basis:** Transcript.
- **Source IDs:** SRC-001 (0:39, 1:02: "as you do the Excel sheet, I'm pretty sure you
  will start to see a dashboard… we do that using a user interface")
- **Definition from evidence:** The envisioned read surface that emerges from the
  workbook's content, replaces direct Excel editing, "pulls from everywhere", and
  remains on top of future operations agents.
- **Ambiguity / notes:** Readership beyond Vijay unevidenced (OQ-10); no design or
  technology is implied.
- **Downstream usage allowed:** Ground direction/vision statements.

### operations agents
- **Source basis:** Transcript; workbook T3 row.
- **Source IDs:** SRC-001 (0:39: "all these operations agents that we are discussing,
  which is the sales agent, manufacturing agent, service agent"); SRC-002 (T3 row:
  "Implement sales agent — Create a Agent to support astraX sales workflows online,
  Amazon like experience")
- **Definition from evidence:** Envisioned AI agents for sales, manufacturing, and
  service operations that would sit behind the dashboard and feed it.
- **Ambiguity / notes:** Future-tense in both sources; one (sales agent) exists as a
  Not Started/unstatused experiment. Ownership/attribution model for agent-produced
  work is NOT established (CTX-SYN-001 §4).
- **Downstream usage allowed:** Ground future-direction statements only.

### discovery
- **Source basis:** Transcript.
- **Source IDs:** SRC-001 (8:36: "the basically discovery part, which is what the email
  and all that is 1 thread"; 12:19: "let's be more trying to learn discovery… see
  what's that unique workflow that's happening in scrapyard or happening in
  manufacturing QC"; 12:07: "let's listen before we… give them an account")
- **Definition from evidence:** The listen-and-learn phase of customer-facing work —
  outreach, emails, information-gathering meetings — that precedes and feeds technical
  experiments. Onboarding waits until "our solution is close to what they are willing"
  (11:46).
- **Ambiguity / notes:** Specific to the current outreach phase (scrapyard and
  manufacturing-QC verticals).
- **Downstream usage allowed:** Ground workflow-as-practiced claims for customer-facing
  tracks.

### technical experiment
- **Source basis:** Transcript.
- **Source IDs:** SRC-001 (8:36–8:55: discovery "will lead to the technical
  experiments. The experiment… both those threads, the marketing and the engineering,
  both go here")
- **Definition from evidence:** The engineering-side experiments that discovery
  findings lead into, within the same track as the discovery thread (both "go into
  T2").
- **Ambiguity / notes:** Contrasted with discovery/marketing threads, not formally
  defined; relationship to the workbook's "experiment" appears to be specialization by
  subject, not a different concept.
- **Downstream usage allowed:** Describe the discovery→experiment flow.

---

## Exclusions (recorded for transparency)

Terms deliberately NOT seeded because they appear only in SRC-003 (inferred,
non-authoritative) or in no source: *acceptance authority, execution authority,
commitment, unit of accountable work, decision (as entity), lead (as authority role),
review cycle (as concept), submit/approve/reject/revise (as lifecycle)*. These may
enter the glossary only via new primary evidence or stakeholder validation (GAP-002,
OQ-02).

---

## Acceptance Criteria (draft → approved)

- [ ] Every term cites ≥1 primary Source ID; every quote verifiable verbatim.
- [ ] No term is coined; no SRC-003-only terminology is seeded (COM §7 no-invention).
- [ ] Ambiguities and open-question links are confirmed against RES-001/CTX-SYN-001.
- [ ] Reviewer confirms the exclusions list is complete.
- [ ] Review logged per COM §6.
