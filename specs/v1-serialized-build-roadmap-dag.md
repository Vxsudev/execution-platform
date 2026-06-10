# Spec: V1 Serialized Build Roadmap DAG

## Status
approved

## Phase
phase-build

## Feature Slug
v1-serialized-build-roadmap-dag

## Goal
Create the authoritative serialized build roadmap for execution-platform v1.
The roadmap defines the ordered DAG of remaining capabilities, marks what is
done vs. next vs. deferred, identifies the critical path to demo release, and
names the next immediate capability.

## Recon
ai/recon/v1-serialized-build-roadmap-dag-recon.md

## Allowed Mutation Surfaces
- ai/recon/v1-serialized-build-roadmap-dag-recon.md
- roadmap/v1-build-roadmap-dag.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/v1-serialized-build-roadmap-dag.md
- tasks/v1-serialized-build-roadmap-dag-*.md

Do NOT modify any file under app/, prototypes/, or sdlc/.

## Data Model Changes
none

## API Surface
none

## Frontend Surface

Create `roadmap/v1-build-roadmap-dag.md`.

### Section 1 — Current Baseline

Describe the current working state:
- app boots on :3000
- login works (admin/admin123)
- full CRUD over entries table
- SQLite persistence survives restart
- Excel-like 14-column Team Summary view (Sheet-2 contract order)
- client-side required-field enforcement
- prototype preserved untouched in prototypes/

Two RELEASE_APPROVED capabilities in state_registry.json:
- promote-execution-table-v1-scaffold
- excel-like-team-summary-view

Latest commit: f6a24b6 — working tree clean.

### Section 2 — Mermaid DAG

Produce a `flowchart TD` Mermaid diagram. Use these exact node IDs and labels:

```
N0: ✅ DONE — Current Baseline
N1: ✅ DONE — Commit Current UX Pass
N2: ▶ NEXT — Backend Integrity
N3: ⏸ BLOCKED — Data Model Hardening
N4: ⏸ BLOCKED — UX Table Hardening
N5: ⏸ BLOCKED — Auth Hardening
N6: DEFERRED — Import / Export
N7: ⏸ BLOCKED — Deployment Path
N8: 🚀 RELEASE — Client Demo Release
```

Edge order (use `-->` for critical-path edges, `-.->` for deferred):
N0 --> N1
N1 --> N2
N2 --> N3
N3 --> N4
N3 --> N5
N4 --> N8
N5 --> N7
N7 --> N8
N3 -.-> N6
N6 -.-> N8

Apply classDef:
- done: green (#2d6a4f, white text)
- current: blue (#0077b6, white text)  [used for N2 "NEXT"]
- blocked: gray (#6c757d, white text)
- deferred: dark gray (#495057, #ccc text)
- release: gold (#d4a017, black text)

### Section 3 — Capability Queue

For each node N0–N8, a table row with:
| Node | Capability | Purpose | Allowed Surfaces | Verification Gate | Depends On | Release Impact |

See recon for node purposes. Surfaces for each:
- N2: app/server.js
- N3: app/db.js, app/server.js (migration helper only)
- N4: app/public/app.js, app/public/style.css
- N5: app/db.js, app/server.js, app/.env.example, app/README.md
- N6: app/server.js, app/public/app.js, app/public/style.css (deferred)
- N7: app/Dockerfile, app/docker-compose.yml, app/.env.example, app/README.md
- N8: git tag, app/README.md (release notes)

### Section 4 — Critical Path

```
Commit Baseline (✅ DONE)
  → Backend Integrity
    → Data Model Hardening
      → Auth Hardening
        → Deployment Path
          → Client Demo Release
```

Note: UX Table Hardening (N4) runs in parallel with Auth Hardening (N5) after
Data Model Hardening (N3), and is also required before Client Demo Release.

### Section 5 — Non-Critical / Later Work

List with single-sentence rationale for each:
- Import / Export
- Advanced filters (multi-select, date range)
- Dashboards
- Approval workflow
- Agents / AI automation
- IoT / digital twin
- Role-based access control

### Section 6 — Next Immediate Capability

State explicitly:

**Next capability: Backend Required Field Enforcement**
**Reason:** client-side validation in app.js is bypassable via raw API calls.
`validate()` in server.js currently enforces only `title`. Owner, track, and
status must also be validated server-side on POST (required-field enforcement).

## Verification Gate

1. `roadmap/v1-build-roadmap-dag.md` exists and has all six sections.
2. Mermaid block present with all N0–N8 nodes.
3. No app/ code modified.
4. No deferred items pulled back into v1 critical path.
5. Next Immediate Capability explicitly named.
6. `ai/engineering-journal.md` appended.
7. `ai/state_registry.json` updated to RELEASE_APPROVED.
8. git status reported — no mutations outside allowed surfaces.
