# L0 Context Operating Model

## Status
approved

## Layer
L0 (Context) — governing artifact for the layer

## Version
1.0.0 (approved by L0 review 2026-06-05 per Process Constitution §6)

## Upstream Authority
- `sdlc/00-process-constitution/sdlc-architecture-directive.md` (Process Constitution v1.0.0)

## Downstream Consumers
- Every L0 artifact (Source Materials, Research, Context)
- L1 Intent (consumes approved Context as its upstream authority)

---

## 1. Purpose

### 1.1 Why L0 exists

L0 is the **evidentiary foundation** of the repository. It exists to guarantee that
every downstream commitment — every requirement, decision, model, or design — rests on
**captured, cited, quality-graded evidence** rather than on assertion, recollection, or
assumption.

This document is **repository governance**, not product design. It defines *how
evidence enters the repository and becomes approved Context*. It contains no product
content, no intent, no domain concepts, and no technology choices; it governs the
*making* of the artifacts that will eventually carry those things.

L0 produces a single authoritative output: an **approved Context corpus** that L1
Intent may cite. Everything L0 does is in service of making that corpus trustworthy,
traceable, and honest about its own limits.

### 1.2 Why Intent cannot be authored without approved Context

The Process Constitution establishes two binding rules that make L0 a hard precondition
for L1:

- **Authority flows downward (Constitution §5).** L1 Intent is a downstream consumer of
  L0 Context. An Intent artifact must trace to an approved upstream artifact; if no
  approved Context exists, Intent has nothing to derive from.
- **Concepts are discovered, not invented (Constitution §5.1, §8).** Requirements
  authored without an evidentiary basis would *originate* concepts rather than
  *elaborate* approved ones — the precise drift the Constitution forbids.

Therefore Intent authored ahead of approved Context is, by definition, **invention
ahead of evidence**. L0 is the mechanism that makes Intent *grounded* rather than
*asserted*. Until Context is approved, L1 may not begin (Section 8).

---

## 2. Evidence Taxonomy

L0 recognizes exactly three artifact classes, in increasing order of interpretation and
decreasing order of raw fidelity. Each artifact declares its class, its metadata, and
conforms to its prohibitions.

### 2.1 Source Materials
- **Purpose:** Raw, faithfully preserved evidence as it exists at the source.
- **Authority level:** Highest fidelity, lowest interpretation — the **evidence of
  record**. All other L0 artifacts derive from these. A Source Material is never
  outranked by analysis built on top of it.
- **Required metadata:** stable Source ID; provenance/origin; capture date; capturer;
  source type (primary / secondary / internal / inferred — Section 3); fidelity
  (verbatim / excerpt / faithful summary); location or access reference;
  sensitivity/handling classification; freshness class (Section 4).
- **Prohibited content:** conclusions, requirements, recommendations, interpretation,
  edits that alter meaning, invented entities or terminology. A Source Material that
  has been interpreted is no longer a Source Material — it is Research.

### 2.2 Research
- **Purpose:** Analysis, comparison, and interpretation **of Source Materials**.
- **Authority level:** Derived and subordinate — a Research finding never outranks the
  sources it cites, and its weight is bounded by them (Section 3).
- **Required metadata:** stable Research ID; cited Source IDs (≥1); analyst; date;
  method of analysis; stated confidence; any assumptions made.
- **Prohibited content:** solutions, commitments, requirements, intent, design,
  technology selection, uncited claims, and any new domain concept absent from the
  cited sources (Constitution §5.1).

### 2.3 Context
- **Purpose:** The **synthesized, decision-relevant framing** that L0 hands to L1 — the
  curated answer to "what do we reliably know, and how confident are we?"
- **Authority level:** The **approved output of L0**, and the *only* L0 artifact L1 may
  consume directly as upstream authority.
- **Required metadata:** stable Context ID; contributing Research and Source IDs;
  synthesis date; confidence per assertion; references into the Contradiction Register
  (Section 5); explicit open questions; freshness summary of underlying evidence.
- **Prohibited content:** requirements, intent, design, application architecture,
  technology choices, invented domain concepts, and **any silent resolution of
  contradictory evidence** (Section 5).

---

## 3. Source Quality Model

Every Source Material declares one of four types. The type governs how it may be used to
ground a Context assertion.

| Type | Definition | Permitted use |
|---|---|---|
| **Primary** | Firsthand, direct evidence — the original record, direct observation, or the authoritative artifact itself. | May **directly ground** a Context assertion. Highest weight. |
| **Secondary** | A third party's reporting or interpretation of primary evidence. | **Supporting** use; must be flagged as secondary. May ground a load-bearing assertion **only when corroborated** by a primary or independent source. |
| **Internal** | Evidence originating inside the organization or repository (prior artifacts, internal records, internal statements). | Valid, but **not self-authorizing** — provenance and authority must be explicit. An internal opinion is evidence of the opinion, not of the fact it asserts. |
| **Inferred** | Derived by reasoning rather than observed. | **Lowest authority.** Must be labeled inferred and state its inference chain and assumptions. May **inform** but must **not be the sole ground** of a load-bearing assertion. |

**Weakest-link rule:** the weight of a Context assertion is bounded by the **weakest
source in its citation chain.** A load-bearing assertion (one that downstream Intent
will depend on) requires at least one **primary** source, or a **secondary source
corroborated** by an independent source. Inferred-only grounding is never sufficient for
a load-bearing assertion.

---

## 4. Freshness Model

Every Source Material declares a freshness class. Freshness governs whether evidence may
still be used and what handling it requires.

| Class | Definition | Handling rules |
|---|---|---|
| **Timeless** | Validity is not date-dependent (definitions, historical facts, immutable records). | No expiry. Still must be cited. |
| **Time-sensitive** | Validity decays over time (states, conditions, structures, figures that change). | Must carry an **"as-of" date** and a **validity horizon** (review-by). Any Context using it records the as-of date. If the horizon has passed, it must be **re-validated before L1 handoff** (Section 8). |
| **Obsolete** | Superseded, or past its validity horizon. | **Never silently used.** Marked obsolete; either **refreshed** (a new capture supersedes it) or **explicitly excluded** with rationale. Any Context depending on it moves to `review` or `superseded`. Obsolete evidence is **retained, not deleted** (audit trail). |

Freshness is a property of the evidence, not of the Context. Approved Context inherits
risk from time-sensitive evidence and must surface it.

---

## 5. Contradiction Handling

**Context must never silently resolve contradictions.** Conflicting evidence is a signal
to be preserved, not a defect to be smoothed over.

### 5.1 The Contradiction Register
When two pieces of evidence conflict, a **Contradiction Register** entry is created
recording: the conflicting Source/Research IDs; the nature of the conflict; the source
quality (Section 3) and freshness (Section 4) of each side; and a status.

### 5.2 Permitted dispositions
A contradiction may be handled in exactly one of three ways, each requiring a recorded
rationale:
1. **Corroborated resolution** — one side is favored on the basis of stronger source
   quality, corroboration, or freshness. The rationale and the quality basis are
   recorded; the losing evidence is **retained and referenced**, not erased.
2. **Held open** — the contradiction is unresolved and is **carried forward as an
   explicit open question** into Context and on to L1 as a known unknown.
3. **Escalated** — referred for a decision outside L0's evidentiary authority.

### 5.3 Hard rules
- No contradiction may be **dropped, hidden, or resolved without recorded rationale.**
- Approved Context **may** contain unresolved contradictions, but only if they are
  **explicitly labeled** and visible to L1. A buried contradiction invalidates the
  Context.

---

## 6. Context Approval Gate

L0 artifacts move through the four statuses defined by Constitution §6. This is a
subordinate artifact set; **no bootstrap exception applies** — every L0 artifact enters
as `draft` and is approved only by review.

| Status | Meaning | Entry criteria | Exit criteria |
|---|---|---|---|
| `draft` | Captured or synthesized; not reviewed | Declares its taxonomy class, required metadata, and citations | Submitted for review |
| `review` | Under examination | All cited Source Materials exist (≥ `draft`); Research cites sources; metadata complete | Reviewer accepts or rejects |
| `approved` | Accepted; consumable by L1 | Every assertion traces to evidence (Section 7); source-quality and freshness rules satisfied; contradictions surfaced not hidden (Section 5); **no requirements/intent/design/technology/domain-invention present** | — (terminal until superseded) |
| `superseded` | Replaced by a newer L0 artifact | A replacement is `approved`; the replacement is referenced | — (terminal); artifact retained, not deleted |

**Gate dependency:** a Context artifact may not enter `review` until the Research and
Source Materials it cites are at least `draft`-captured and present; it may not be
`approved` while any cited evidence is `obsolete` without disposition.

---

## 7. Context Traceability

L0 specializes the Constitution §7 traceability standard for evidence.

- **Stable IDs.** Every Source Material, Research finding, and Context artifact carries a
  unique, stable ID. IDs are never reused or renumbered.
- **No uncited assertions.** Every **assertion** in an approved Context artifact — any
  statement of fact or state — must carry **≥1 citation** to a Research finding or
  Source Material by ID. An approved Context with an uncited assertion is invalid.
- **Citation contents.** A citation references the source ID and, for time-sensitive
  evidence, the **as-of date**, and surfaces the source's **quality class** so the
  reader can judge weight.
- **Backward closure.** Every Context assertion traces to evidence; every Research
  finding traces to Source Materials.
- **Forward declaration.** Context declares its downstream consumer (L1 Intent) per the
  standard `## Downstream Consumers` field.
- **No-invention conformance (Constitution §5.1).** Terminology and concepts appearing
  in Context must be **present in the cited evidence.** Context elaborates evidence; it
  does not originate concepts. New terms are *captured from sources into the glossary
  seed*, never coined in Context.

---

## 8. Context → Intent Handoff

L1 Intent may begin **only when all of the following objective conditions hold** for the
Context corpus relevant to the intended scope:

1. **Approved Context exists.** A Context-of-record covering the scope is `approved` and
   can be cited by L1 as upstream authority.
2. **Load-bearing assertions are well-grounded.** Every assertion L1 will depend on cites
   ≥1 **primary** source, or a **corroborated secondary** source (Section 3).
3. **Freshness is current.** All time-sensitive evidence underlying the Context is within
   its validity horizon, or has been **re-validated** (Section 4).
4. **Contradictions are accounted for.** Every Contradiction Register entry is either
   **resolved with recorded rationale** or **explicitly carried as an open question**.
   None is silently dropped (Section 5).
5. **Glossary seed exists.** A ubiquitous-language glossary seeded **from the evidence**
   (not invented) is available for L1 to build on.
6. **Handoff is recorded.** The transition is logged, and L1 Intent artifacts must cite
   the approved Context IDs as their `## Upstream Authority`.

Until conditions 1–6 hold, **L1 Intent artifacts may not enter `review`.** Intent
authored against unapproved or absent Context is invalid by Constitution §5/§5.1.

---

## 9. Acceptance Criteria

This L0 Context Operating Model is complete when **all** of the following hold:

- [ ] All nine required sections are present and non-empty.
- [ ] The document contains **no** product content, requirements, intent, domain
      concepts, application architecture, or technology choices.
- [ ] The evidence taxonomy defines Source Materials, Research, and Context, each with
      purpose, authority level, required metadata, and prohibited content.
- [ ] The source quality model defines primary, secondary, internal, and inferred
      sources with explicit permitted-use rules, including the weakest-link rule.
- [ ] The freshness model defines timeless, time-sensitive, and obsolete evidence with
      handling rules, including as-of dating and retention of obsolete evidence.
- [ ] Contradiction handling forbids silent resolution, defines the Contradiction
      Register, and enumerates the permitted dispositions.
- [ ] The L0 approval gate defines `draft`, `review`, `approved`, `superseded` with
      entry and exit criteria, and states that no bootstrap exception applies.
- [ ] Traceability requires every approved-Context assertion to cite evidence by stable
      ID and conforms to the no-invention rule.
- [ ] The Context → Intent handoff defines objective, checkable preconditions before L1
      may begin.
- [ ] The document declares its own `Status`, `Layer`, `Version`, `Upstream Authority`,
      and `Downstream Consumers`, conforming to the standard defined by the Process
      Constitution.
- [ ] The document is subordinate to the Process Constitution, claims no bootstrap
      exception, and enters the repository via the normal L0 gate (`draft` → review).
