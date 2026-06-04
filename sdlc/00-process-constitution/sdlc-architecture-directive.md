# SDLC Architecture Directive — Process Constitution

## Status
approved

## Layer
L-gov (governing — sits above L0–L5)

## Version
1.0.0

## Upstream Authority
- Engineering OS integration recon (ratified decisions: conform-via-phases, copy-snapshot vendoring, adapter overlay, build deferral)

## Downstream Consumers
- Every SDLC artifact produced in this repository (all layers L0–L5)
- The Domain Constitution (when it becomes permissible)
- All Architecture Decision Records

---

## 1. Purpose

### 1.1 Why this document exists

This document is the **Process Constitution** of `execution-platform`. It is the
single, highest-standing governing artifact in the repository. It defines **how the
repository operates** — the order in which knowledge is produced, which artifact has
authority over which, what "approved" means, and what may not yet be done.

It exists so that any agent, developer, or future session can understand the
operating model of this repository **without reconstructing it from scattered
documents or guesswork**, and so that the operating model is enforced by rules rather
than by memory.

This document is **process law**. It contains no product content, no domain content,
no technology choices, and no implementation. It governs the *making* of those
things; it is not one of them.

### 1.2 Relationship to the Engineering OS

`execution-platform` adopts the **Engineering OS** (`RaystratSystems-AI-Engineering-OS`)
as its **execution-control spine**: the state machine, the invariant engine, the
artifact-trail token gate, the verification harness, and the engineering journal.
The Engineering OS is **external source authority** and is **read-only** (Section 9).

The division of authority is:

- **The Engineering OS owns** the execution lifecycle and its enforcement gates.
- **This Process Constitution owns** the SDLC progression model, the artifact
  taxonomy, the authority relationships, and the approval semantics of
  `execution-platform`.

Where the Engineering OS provides a mechanism (e.g. product *phases*), this
Constitution declares how `execution-platform` uses that mechanism (e.g. phases carry
the L0–L5 layer identity — Section 3).

### 1.3 Relationship to future SDLC artifacts

Every artifact created in this repository — at any layer — is subordinate to this
document. No artifact may contradict it. The Constitution is amended only through the
ADR process (Section 11); it is never edited silently.

---

## 2. Scope

### 2.1 What the Process Constitution governs

- The SDLC layer model (L0–L5) and its progression.
- The set of permitted artifact classes and each class's tier, owner, and authority.
- The authority relationships between artifact classes.
- The approval-gate semantics (`draft → review → approved → superseded`).
- Traceability obligations on every artifact.
- The separation between Process Constitution and Domain Constitution.
- The rules for integrating the external Engineering OS.
- The rule deferring build-tier decomposition to L5.
- The ADR policy.
- The repository lifecycle from Context to Build.

### 2.2 What it explicitly does NOT govern

- **Product intent or requirements** — these are L1 artifacts, authored later.
- **Domain semantics or product invariants** — these are L2-derived; the Domain
  Constitution is forbidden until its preconditions are met (Section 8).
- **System or application architecture** — an L3/L5 concern.
- **Technology selection** — out of scope for this document entirely.
- **Implementation** — an L5 concern, deferred.
- **The internal logic of the Engineering OS** — it is read-only authority (Section 9).

If a question is "what should the product do / be built with / look like," this
document does not answer it. If a question is "how does work move through this
repository and what governs it," this document is authoritative.

---

## 3. SDLC Layer Model

`execution-platform` is **documentation-first**. Its SDLC spine is a progression of
**knowledge layers**, not a build decomposition. Each layer is realized as one or more
Engineering OS **phases** (`specs/phases/phase-<id>.md`), so the OS state machine and
phase-propagation machinery apply uniformly across the spine. This is the ratified
**conform-via-phases** model.

The build-tier decomposition supplied by the Engineering OS
(`Data Model → Database`, `API Surface → Backend`, `Frontend Surface → Frontend`,
`Verification`) is **not** a layer of this spine. It is the *internal task structure
of L5 only* (Section 10).

### L0 — Context
- **Purpose:** Establish why work is being undertaken and from what evidence.
- **Artifact classes:** Source Materials, Research, Context, Glossary (seed).
- **Outputs:** A curated, cited context corpus; an initial ubiquitous-language glossary.
- **Downstream consumers:** L1 Intent.

### L1 — Intent
- **Purpose:** Define what is wanted, for whom, and under what constraints.
- **Artifact classes:** Product Requirements, Non-Functional Requirements, Actor/Role Catalog.
- **Outputs:** Approved requirement set with stable requirement IDs (traceability roots).
- **Downstream consumers:** L2 Behavior; L4 Test Strategy; the Domain Constitution.

### L2 — Behavior
- **Purpose:** Define how the system behaves — its domain, flows, and access rules.
- **Artifact classes:** Functional Requirements, Domain Model, Workflow Specifications, Authorization Specifications.
- **Outputs:** Approved behavioral corpus; the canonical glossary.
- **Downstream consumers:** L3 Structure; L4 Acceptance Criteria.
- **Constitutional checkpoint:** The **Domain Constitution becomes permissible only
  after this layer is complete and approved** (Section 8). Invariants are *derived*
  here, never asserted before.

### L3 — Structure
- **Purpose:** Define the shape of the system that realizes the approved behavior.
- **Artifact classes:** UI Specifications, Data Model, API Contracts.
- **Outputs:** Approved structural specifications conforming to the Domain Constitution.
- **Downstream consumers:** L5 Build; L4 Acceptance Criteria.

### L4 — Verification
- **Purpose:** Define how correctness will be established before anything is built.
- **Artifact classes:** Acceptance Criteria, Test Strategy.
- **Outputs:** Acceptance criteria bound to requirements; a test strategy mapped to them.
- **Downstream consumers:** L5 Build (verification execution); the verification gate.

### L5 — Build
- **Purpose:** Produce verified implementation from the approved corpus.
- **Artifact classes:** Implementation Plans, and the Engineering OS build-tier task
  decomposition (`database → backend → frontend → verification`).
- **Outputs:** Implementation, executed verification, journal entries.
- **Downstream consumers:** Production system; engineering journal (memory).
- **Note:** This is the **only** layer in which the Engineering OS build-tier task
  model is active. It is deferred here and nowhere earlier (Section 10).

---

## 4. Artifact Classes

Every artifact in this repository belongs to exactly one class below, declares its
layer and status (Section 6), and declares its upstream authority and downstream
consumers (Section 7).

| Class | Layer | Owner | Must NOT contain |
|---|---|---|---|
| **Source Materials** | L0 | Authoring plane | Conclusions, requirements, or invented entities — raw evidence only |
| **Research** | L0 | Authoring plane | Solutions or commitments — analysis of evidence only |
| **Context** | L0 | Authoring plane | Requirements or design |
| **Product Requirements** | L1 | Product | UI layouts, API shapes, schemas, technology |
| **Functional Requirements** | L1→L2 | Product/BA | Endpoints, fields, screens |
| **Non-Functional Requirements** | L1 | Product/Architecture | Implementation detail |
| **Actor / Role Catalog** | L1 | BA | Permission assignments (that is Authorization) |
| **Domain Model** | L2 | BA/Architecture | Physical schema, types, persistence detail |
| **Workflow Specifications** | L2 | BA | Screen layouts, endpoint signatures |
| **Authorization Specifications** | L2 | BA/Security | Auth *implementation* (tokens, libraries) |
| **UI Specifications** | L3 | Design | Visual/framework technology choices |
| **Data Model** | L3 | Architecture | Vendor-specific DDL, technology selection |
| **API Contracts** | L3 | Architecture | Handler implementation |
| **Acceptance Criteria** | L4 | QA/Product | Test code or tooling |
| **Test Strategy** | L4 | QA | Specific test cases or implementation |
| **Architecture Decision Records** | any | Architecture | Reversible, silent edits — append-only (Section 11) |
| **Implementation Plans** | L5 | Engineering | Authored only when the corpus is implementation-ready |

Source Materials, Research, and Context are distinct: **Source Materials** is raw
captured evidence; **Research** is analysis of it; **Context** is the synthesized,
decision-relevant framing handed to L1.

---

## 5. Authority Model

Authority flows **downward**: an upstream artifact constrains its downstream
consumers, and conflicts are resolved in the upstream artifact's favor. There is
exactly one **upward-derivation seam** — the Domain Constitution is *derived from* L2
but *rules over* L3+ (Sections 8 and 10).

```
Context (L0)            ── informs ──► everything; authoritative over nothing

Product Requirements    ──► Functional Requirements, all downstream layers
Non-Functional Reqs     ──► Data Model, API Contracts, Test Strategy, Build
Actor / Role Catalog    ──► Authorization Specs, Workflow Specs, UI Specs

Functional Requirements ──► API Contracts, Acceptance Criteria, Workflows
Domain Model            ──► Data Model, Glossary, functional-requirement semantics
Workflow Specifications ──► UI Specifications, API orchestration, Acceptance Criteria
Authorization Specs     ──► API Contracts (guards), UI Specs (gating), Data Model (scoping)

        ╔═══════════════════════════════════════════════════════════╗
        ║ DOMAIN CONSTITUTION — derived from L2 (Behavior),          ║
        ║ authoritative over L3+ . Forbidden before L2 is approved.  ║
        ╚═══════════════════════════════════════════════════════════╝

UI Specifications       ──► Frontend build (L5)
Data Model              ──► Persistence build (L5), API payload shapes
API Contracts           ──► Frontend build, Backend build (L5)

Acceptance Criteria     ──► Test Strategy, verification gate, Definition-of-Done
Test Strategy           ──► Build verification scripts

Implementation Plans    ──► Task graph only (lowest authority; constrains nothing above)
```

Context is **evidence, not law**: it informs everything and is authoritative over
nothing.

### 5.1 No-Invention Rule (downstream domain-drift prohibition)

Authority flows in one direction; **concept origination does too.** A downstream
artifact may only *elaborate* concepts that already exist in its approved upstream
authority — it may never *originate* them.

**Rule:** *No downstream artifact may introduce new domain concepts, entities, actors,
aggregates, capabilities, workflows, permissions, or terminology that are not present
in its approved upstream authority.*

Illustrative violations (non-exhaustive): a UI Specification inventing a new entity; an
API Contract inventing a new aggregate; a Data Model introducing a concept absent from
the Domain Model; a Workflow Specification referencing an actor absent from the
Actor/Role Catalog; any artifact coining terminology absent from the Glossary.

**Consequences when a downstream need exposes a missing concept:**
1. **Stop** — the downstream artifact may not proceed to invent the concept.
2. **Elevate** — the concept must be raised to the appropriate upstream artifact (the
   one with authority to originate it — e.g. a new entity to the Domain Model, a new
   actor to the Actor/Role Catalog, a new term to the Glossary).
3. **Approve upstream first** — that upstream artifact is reviewed and re-`approved`
   with the new concept before any downstream artifact may reference it.
4. **Elaborate only** — the downstream artifact may then elaborate the now-approved
   concept, never create it.

This rule is part of the constitutional authority model. A downstream artifact that
originates an un-elevated concept is invalid and must not be `approved`.

---

## 6. Approval Gates

Every artifact carries a `## Status` field with one of four values. Status governs
what the artifact may be used for, and aligns with the Engineering OS state machine
where the artifact participates in the pipeline.

| Status | Meaning | Entry criteria | Exit criteria |
|---|---|---|---|
| `draft` | Authored, not yet reviewed | Artifact exists; declares layer + traceability | Submitted for review |
| `review` | Under examination | Content complete; upstream artifacts are `approved` | Reviewer accepts or rejects |
| `approved` | Accepted; may constrain downstream work | Passes review; no conflict with upstream authority; no Constitution violation | — (terminal until superseded) |
| `superseded` | Replaced by a newer artifact | A replacement artifact exists and is `approved`; reference recorded | — (terminal) |

**Gate rules:**
- A downstream artifact may not enter `review` until **all of its upstream-authority
  artifacts are `approved`**.
- No artifact is `approved` while it conflicts with an upstream artifact or with this
  Constitution.
- An artifact is never deleted; obsolete artifacts move to `superseded` with a
  reference to their replacement.

**Engineering OS alignment:** when an artifact drives the OS pipeline, its approval
corresponds to the OS state chain:
`RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE →
VERIFICATION_REQUIRED → RELEASE_APPROVED`. The OS state machine, invariant engine, and
artifact-trail token are the *machine enforcement* of these gates and may not be
bypassed.

---

## 7. Traceability Rules

Traceability is mandatory and is the binding that makes the corpus auditable.

**Every artifact must declare two fields:**
- `## Upstream Authority` — the artifact(s) that constrain it (or "root").
- `## Downstream Consumers` — the artifact class(es) that depend on it (or "none yet").

**Standard:**
1. **Requirement-ID origination** — every Product/Functional requirement receives a
   stable, unique ID at L1/L2. IDs are never reused or renumbered.
2. **Forward closure** — by the time the repository reaches implementation-ready
   state, every requirement ID must trace forward to ≥1 Acceptance Criterion and ≥1
   Test Strategy entry.
3. **Backward closure** — every L3+ artifact must trace backward to an approved L1/L2
   artifact. An artifact with no upstream authority (other than the root Constitution)
   is invalid below L1.
4. **No orphans** — an artifact that nothing consumes and nothing authorizes must not
   exist; either wire it or supersede it.

The traceability chain must **close end-to-end before any L5 Build work begins.**

---

## 8. Process Constitution vs Domain Constitution

*This section is mandatory and load-bearing.*

There are two distinct constitutions, and they must never be conflated:

- **Process Constitution** (this document) = **repository governance.** It defines how
  work is produced. It exists from repository inception and contains zero domain
  content.
- **Domain Constitution** = **product invariants, runtime contracts, and service
  boundaries.** It defines what the system is permanently forbidden to do. It is
  product law, not process law.

**The Domain Constitution is FORBIDDEN until all of the following exist and are
`approved`:**
- Product Requirements
- Functional Requirements
- Domain Model
- Workflow Specifications
- Authorization Specifications

That is: the Domain Constitution may not be authored before **L2 (Behavior) is
complete and approved.**

**Product invariants are discovered, not invented.** An invariant is a *conclusion
drawn from* approved behavior, never a *premise asserted ahead of* it. Asserting
invariants before behavior is understood inverts authority — it lets a guess about the
system veto the requirements that should have produced it. Any purported invariant
authored before its preconditions are met is invalid and must be rejected.

Once permissible, the Domain Constitution is derived from L2, ratified by ADR, and
thereafter sits in authority over L3+ (Section 5). It is amended only by ADR.

---

## 9. Engineering OS Integration Rules

*This section is mandatory.*

1. **Source authority is read-only.** The Engineering OS repository at
   `/Users/vasudevarao/RaystratSystems-AI-Engineering-OS` is the external source
   authority. It **must never be modified, rewritten, deleted from, or created in.**
2. **Adoption is by snapshot and overlay only.** `execution-platform` adopts the
   Engineering OS as a **frozen copy-snapshot** vendored within the project, pinned to
   a recorded source commit and protected by an immutability invariant. The project
   never edits the vendored copy in place; corrections to OS behavior are expressed as
   project-side overlays/proxies, never as edits to OS files.
3. **Project-specific behavior is confined to the overlay.** All
   `execution-platform`-specific configuration, invariants, specs, tasks, and state
   live under:
   ```
   .engineering-os/      (adapter config + project invariants)
   ai/                   (state registry, journal, project control docs)
   specs/                (phase + feature specs)
   tasks/                (generated task graph)
   ```
4. **The OS remains external authority.** `execution-platform` conforms to the
   Engineering OS enforcement spine; it does not fork or reinterpret it.

---

## 10. Build Deferral Rule

*This section is mandatory.*

The Engineering OS build decomposition —

```
Data Model     → Database
API Surface    → Backend
Frontend Surface → Frontend
Verification
```

— is the **internal task structure of L5 Build, and nothing else.**

- It **must not** be used as the SDLC architecture model.
- It **must not** drive the production of L0–L4 artifacts.
- It becomes active **only** when an `approved` L3 specification carries concrete
  Data Model / API Surface / Frontend Surface content and the repository has reached
  implementation-ready state.

L0–L4 produce **governed documents**, not code. Treating the build decomposition as
the spine would start the repository at Structure and skip Context, Intent, and
Behavior — the exact failure this Constitution exists to prevent.

---

## 11. ADR Policy

**When an ADR is required:**
- Ratifying or amending this Process Constitution.
- Ratifying or amending the Domain Constitution (once permissible).
- Any decision that constrains downstream artifacts and is not already fixed by an
  approved upstream artifact (e.g. a cross-cutting structural choice, an OS-integration
  decision, a vendoring or override decision).
- Recording why an artifact was `superseded`.

**Naming standard:** `architecture/decisions/ADR-NNN-<kebab-case-title>.md`, where
`NNN` is a zero-padded, monotonically increasing integer. Numbers are never reused.

**Lifecycle:** `proposed → accepted → superseded`. An ADR is **append-only**: once
written it is never edited or deleted; a reversal is recorded as a *new* ADR that
supersedes the prior one, with a back-reference.

**Approval process:** an ADR enters `accepted` only after review confirms it does not
conflict with this Constitution or any approved upstream artifact. Accepted ADRs are
binding on all subsequent work.

**Bootstrap exception (constitutional self-establishment):** the ADR mechanism is
*established by* this Constitution and therefore cannot govern this Constitution's own
first existence — requiring an ADR to ratify the artifact that defines ADRs would be
circular. Accordingly:

- **Version 1.0.0 of this Process Constitution may be ratified directly**, without an
  ADR, by the first-pass review that approves it. This is the single permitted act of
  self-establishment.
- **Every subsequent amendment** to this Process Constitution (any version after
  1.0.0) **requires an ADR** per this policy.
- All future constitutional revisions follow the ADR lifecycle and approval process
  above without exception.

Once Version 1.0.0 is ratified, the ADR mechanism is active and binds everything
thereafter, including this document.

---

## 12. Repository Lifecycle

The repository progresses strictly through the layer model. Stages are not skipped;
each opens only when its upstream layer is `approved`.

```
L0 Context
   ↓        (curated, cited context corpus + glossary seed)
L1 Intent
   ↓        (approved requirements + actors + NFRs; requirement IDs minted)
L2 Behavior
   ↓        (functional reqs + domain model + workflows + authorization approved)
   ⮑ Domain Constitution becomes permissible (Section 8), ratified by ADR
L3 Structure
   ↓        (UI specs + data model + API contracts approved, conforming to invariants)
L4 Verification
   ↓        (acceptance criteria bound to requirements; test strategy mapped)
   ⮑ traceability chain closes end-to-end
L5 Build
            (implementation plans → OS build-tier task graph → verified implementation → journal)
```

Movement between stages is gated by Section 6 and enforced by the Engineering OS state
machine. The repository is **implementation-ready** when L4 is `approved` and
traceability has closed; only then may L5 begin.

---

## 13. Acceptance Criteria

This Process Constitution is complete when **all** of the following hold:

- [ ] All thirteen required sections are present and non-empty.
- [ ] The document contains **no** product content, domain content, requirements,
      technology choices, application architecture, implementation plans, or code.
- [ ] The SDLC layer model defines, for each of L0–L5: purpose, artifact classes,
      outputs, and downstream consumers.
- [ ] All initial artifact classes are defined with layer, owner, and a
      must-not-contain boundary.
- [ ] The authority model is stated as a directional graph and names the single
      upward-derivation seam (Domain Constitution).
- [ ] The four approval-gate statuses are defined with entry and exit criteria and are
      aligned to the Engineering OS state chain.
- [ ] Traceability obligations (upstream + downstream declarations, forward/backward
      closure, no orphans) are specified.
- [ ] The Process vs Domain Constitution split is stated, the forbidden-until
      precondition is explicit, and "invariants are discovered, not invented" is
      asserted.
- [ ] Engineering OS integration rules state the source path, its read-only status,
      and the snapshot-plus-overlay-only adoption model.
- [ ] The build-deferral rule confines the OS build decomposition to L5.
- [ ] The ADR policy defines trigger conditions, naming, lifecycle, append-only rule,
      and approval.
- [ ] The repository lifecycle defines the Context → Build progression and its gates.
- [ ] The document declares its own `Status`, `Layer`, `Version`, `Upstream
      Authority`, and `Downstream Consumers`, conforming to the standard it defines.
- [ ] The ADR policy includes the bootstrap exception: Version 1.0.0 is ratified
      directly (no ADR), and all subsequent amendments require an ADR — so the document
      contains no circular dependency on the mechanism it establishes.
