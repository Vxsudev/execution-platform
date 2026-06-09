# Source Material — L1 Product Intent Scope Narrowing (2026-06-07)

**Source ID:** SRC-005
**Source type:** Stakeholder discussion / v1 scope-narrowing direction (text exchange)
**Classification (COM §3):** Primary, internal
**Freshness class (COM §4):** Time-sensitive
**Stakeholder:** Vijay Chilakapati (founder)
**Communication date / as-of:** 2026-06-07
**Captured into repository:** 2026-06-09 by Vasu (vasu@astraanalytical.com)
**Fidelity:** Verbatim quotes preserved; capture context and operator correction labeled separately

> **Note on document class.** This file preserves raw stakeholder evidence (the verbatim
> block below) together with a clearly-delineated operator capture context. Only the
> verbatim block is primary stakeholder evidence. The operator correction is recorded as
> authoritative project direction for disambiguation, not as a stakeholder utterance.

---

## 1. Verbatim Stakeholder Evidence

Direct quotation from Vijay, preserved exactly as received:

> "Keep it simple, ability to create and edit experiment. Use access control like we
> already have.
>
> Just a nicer table editor"

### Follow-up clarification exchange

**Question put to Vijay:**

> "When you say 'access control like we already have,' do you mean same OPS Cloud user
> roles/permissions, or just the same general pattern?"

**Vijay's response (verbatim):**

> "Yes"

**Capture note on the response:** The question was posed as an either/or (same OPS Cloud
roles/permissions **vs.** same general pattern). The reply "Yes" does not select between
the two alternatives and is therefore **ambiguous on its face**. The disambiguating
authority is the operator correction in §2 below, which resolves the ambiguity in favor
of "same general pattern, not reuse." The ambiguity itself is preserved here as evidence.

---

## 2. Operator Capture Context and Correction

The following is authoritative project direction recorded at capture time. It is **not** a
stakeholder utterance; it is the operator's correction of a prior architectural
assumption and the boundary set within which the verbatim evidence must be interpreted.

### 2.1 Separate-application boundary (correction of prior assumption)

`execution-platform` is a **completely separate application** from the existing NDT-SaaS
cloud platform. It has **absolutely nothing to do with NDT-SaaS** unless explicitly
stated otherwise in a later, recorded direction. The phrase "access control like we
already have" / "OPS Cloud" must **not** be read as an instruction to import, reuse, or
depend on NDT-SaaS architecture, authentication, data model, or access-control
implementation.

### 2.2 Resolution of the "access control" ambiguity

"Access control like we already have" is to be interpreted as: **follow a similar, simple
access-control pattern** — not as reuse of NDT-SaaS auth or access-control code. The
exact access-control design for execution-platform remains **unresolved** and is deferred
to a later layer.

### 2.3 v1 scope interpretation boundaries

Within the separate-application boundary, the verbatim evidence narrows v1 product scope
as follows:

- **v1 is a simple controlled table editor.**
- **v1 supports creating and editing experiments / work-items / tasks** (row records).
- **Experiments, work-items, and tasks share the same columns** in v1.
- **Mandatory-field policy is unresolved** — which columns (if any) are required is not
  yet decided.
- **Escalation-to-Vijay must not be modeled** as a product pathway. (No escalation
  workflow appears in the verbatim v1 framing; the operator additionally directs that it
  not be built.)
- **Access control** for v1 means a simple, separate-app access-control **pattern**, with
  exact design unresolved (§2.2).
- **Dashboard, operations agents, and management-execution expansion are future
  direction, not v1 build scope.**

---

## 3. Allowed / Prohibited Usage

Per the Source Intake Register §5 usage rules (SRC-005 entry).

**Allowed usage:**
- Narrows Product Intent v1 to a simple controlled table editor.
- Supports create/edit of experiment / work-item / task rows as v1 intent.
- Supports removing escalation-to-Vijay from product scope.
- Supports treating access control as a simple separate-app pattern constraint (not
  NDT-SaaS reuse).

**Prohibited usage:**
- May **not** define UI layout.
- May **not** define database schema.
- May **not** define API endpoints.
- May **not** define exact auth/access-control implementation.
- May **not** import or assume NDT-SaaS architecture.
- May **not** introduce an escalation workflow.
- May **not** define dashboard or operations-agent functionality for v1.

---

## 4. Open Items Carried From This Source

- Mandatory-field policy for the shared column set — **unresolved**.
- Exact access-control design for the separate application — **unresolved**.
- Relationship/distinction (if any) between "experiment", "work-item", and "task" beyond
  sharing columns — **unresolved** (relates to OQ-06).
