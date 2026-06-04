# Spec Generation Procedure

## Purpose

This document defines how engineering specs are generated from product ideas in this
repository. A spec is the authoritative written record of what a feature does before
any task or code is produced.

**Spec generation produces documentation only.**
Tasks are not generated. Code is not written. The repository is not modified.

---

## Step 1 — Repository Recon

Before writing any spec, perform reconnaissance:

1. Read `ai/repo-index.md` — understand the current system layout and existing surfaces.
2. Read `ai/runtime-contracts.md` — identify invariants the feature must not violate.
3. Read `ai/service-boundaries.md` — confirm which service owns what the feature touches.
4. Read `ai/product-invariants.md` — confirm the proposed feature does not violate any product guarantees before writing the spec.

This ensures the spec describes something that fits the existing architecture rather than
contradicting it.

---

## Step 2 — Duplication Check

Scan `specs/` for existing specs before writing a new one.

Check for:
- A spec that already covers the requested capability
- A spec that partially covers it (the new capability may belong as an extension)
- A spec marked `implemented` that already ships the feature

If a duplicate or overlap exists, report it before proceeding. Do not generate a redundant spec.

---

## Step 3 — Spec Structure

Every spec must follow this exact structure:

```markdown
# Spec: <Title>

## Status
draft

## Capability
Describe the new system behavior introduced by this feature.
Explain the problem being solved and the resulting capability.
Be concrete — what can a user or system do after this feature exists that they cannot do now?

## Data Model Changes
List tables created, modified, or removed.
For each change: table name, what changed, and why.
If no data model changes are required, state: "none".

## API Surface
List every new or modified endpoint.
Format:

METHOD /path
Auth requirement
Purpose (one line)

If no API changes are required, state: "none".

## Frontend Surface
Describe pages, dialogs, workflows, or UI components introduced or changed.
Include which role(s) can access each surface.
If no frontend changes are required, state: "none".

## Operational Workflow
Describe how the feature behaves end-to-end in the running system.
Write as a numbered step-by-step sequence from user action to system response.
Cover the happy path first, then note any error or edge cases.

## Dependencies
List any specs, migrations, or runtime contracts this spec depends on.
If none, state: "none".

## Acceptance Criteria
Concrete, verifiable conditions that define when the feature is complete.
Each criterion must describe observable system behavior that can be checked
during the verification phase.

Include:
- expected API responses or status codes
- expected UI outcomes visible to users
- database state changes when applicable

Verification must be able to reference these criteria directly.

## Out of Scope
Explicitly list what this spec does NOT cover.
This prevents scope creep during task generation and implementation.
```

**A spec must not move to `approved` status unless acceptance criteria are defined.**

---

## Step 4 — Filename Convention

Spec files are named using lowercase kebab-case:

```
specs/<feature-name>.md
```

Examples:
```
specs/audit-log-csv-export.md
specs/device-health-summary.md
specs/user-profile-update.md
```

The filename must match the feature slug used for task files:
```
tasks/<feature-name>-001.md
tasks/<feature-name>-002.md
...
```

---

## Step 5 — Draft → Approved Lifecycle

Specs progress through the following states:

| Status | Meaning |
|--------|---------|
| `draft` | Spec written but not yet reviewed. Tasks may not be generated. |
| `approved` | Spec reviewed and accepted. Task generation may begin. |
| `implemented` | All tasks are `done` and acceptance criteria verified. |
| `superseded` | Replaced by a newer spec. Reference the replacement. |

**A spec must be in `approved` status before task generation begins.**

Setting a spec to `approved` is an explicit decision — it is not automatic. A human or
authorized agent must change the status field after reviewing the spec content.

---

## Step 6 — Task Generation Gate

Task files (`tasks/<feature>-001.md` through `tasks/<feature>-NNN.md`) must not be created
until the spec is in `approved` status.

Implementation must not begin until task files exist.

The enforced sequence is:

```
idea
  ↓
spec written → status: draft
  ↓
spec reviewed → status: approved
  ↓
tasks generated (spec-to-task-playbook.md)
  ↓
implementation begins (task 001)
  ↓
spec → status: implemented
```

Skipping any step in this sequence is a process violation.

---

## Reference — Spec Quality Checklist

Before marking a spec `approved`, verify:

- [ ] Capability section explains the problem and the resulting behavior concretely
- [ ] Data model changes list every table affected
- [ ] API surface lists every endpoint with method, path, and auth requirement
- [ ] Frontend surface identifies which roles can access each new surface
- [ ] Operational workflow covers the full end-to-end sequence
- [ ] Acceptance criteria are defined with observable, verifiable conditions
- [ ] Out of scope section is present and non-empty
- [ ] Filename follows kebab-case convention
- [ ] No duplication with existing specs
- [ ] No runtime contract violations introduced
