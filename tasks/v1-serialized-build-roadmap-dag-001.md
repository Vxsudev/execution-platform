# Task: Create roadmap/v1-build-roadmap-dag.md with full Mermaid DAG and capability queue

## Parent Spec
specs/v1-serialized-build-roadmap-dag.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description

Create `roadmap/v1-build-roadmap-dag.md`. This is a pure document creation task —
do NOT modify any file under app/, prototypes/, or sdlc/.

First run `mkdir -p roadmap` to create the directory.

The document must contain exactly these six sections:

---

### Section 1 — Current Baseline

Describe the confirmed working state of the app:
- Runs on :3000
- Login (admin/admin123, vasu/vasu123)
- Full CRUD: GET/POST /api/rows, PUT/DELETE /api/rows/:id
- SQLite persistence (data.db, WAL mode, survives restart)
- 14-column Excel-like Team Summary table (Sheet-2 contract column order)
- Client-side required fields: owner, track, title, status
- Prototype preserved untouched in prototypes/execution-table-app/
- Node ≥ 22.5 required (node:sqlite experimental)

Completed capabilities (both RELEASE_APPROVED):
- `promote-execution-table-v1-scaffold`
- `excel-like-team-summary-view`

Latest commit: f6a24b6 — working tree clean at roadmap creation.

---

### Section 2 — Mermaid DAG

Produce a Mermaid `flowchart TD` diagram. Use these exact classDef colors:

```
classDef done     fill:#2d6a4f,color:#fff,stroke:#1b4332
classDef current  fill:#0077b6,color:#fff,stroke:#023e8a
classDef blocked  fill:#6c757d,color:#fff,stroke:#495057
classDef deferred fill:#495057,color:#ccc,stroke:#343a40
classDef release  fill:#d4a017,color:#000,stroke:#a07800
```

Nodes (use multi-line labels with `\n`):
```
N0["✅ DONE\nCurrent Baseline\napp boots · CRUD · Excel table\nlogin · SQLite persistence"]:::done
N1["✅ DONE\nCommit Current UX Pass\nall app changes committed\nbranch: main f6a24b6"]:::done
N2["▶ NEXT\nBackend Integrity\nrequired-field enforcement\nowner/track/status in validate()"]:::current
N3["⏸ BLOCKED\nData Model Hardening\nNOT NULL constraints · indices\nstatus/track DB-level guard"]:::blocked
N4["⏸ BLOCKED\nUX Table Hardening\ndate formatting · polish\nedge-case empty states"]:::blocked
N5["⏸ BLOCKED\nAuth Hardening\nenv-based credentials\nSESSION_SECRET from .env"]:::blocked
N6["DEFERRED\nImport / Export\nCSV export · optional import\nv1.1+ scope"]:::deferred
N7["⏸ BLOCKED\nDeployment Path\nDockerfile · docker-compose.yml\n.env.example · README deploy"]:::blocked
N8["🚀 RELEASE\nClient Demo Release\nv1.0.0 tag · demo docs\nno hardcoded credentials"]:::release
```

Edges:
```
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
```

---

### Section 3 — Capability Queue

A markdown table with these columns:
`| Node | Capability Name | Purpose | Allowed Surfaces | Verification Gate | Depends On | Release Impact |`

Rows for N0–N8. Use the node purposes and surface constraints from the spec's
Frontend Surface section and from ai/recon/v1-serialized-build-roadmap-dag-recon.md.

---

### Section 4 — Critical Path

Render as a chain:
```
Commit Baseline ✅
  → Backend Integrity
    → Data Model Hardening
      → Auth Hardening
        → Deployment Path
          → Client Demo Release 🚀
```

Add a note that UX Table Hardening (N4) runs in parallel with Auth Hardening (N5)
after Data Model Hardening, and both N4 and N7 must complete before N8.

---

### Section 5 — Non-Critical / Later Work

List with one-sentence rationale each:
1. Import / Export — users can manually enter rows; bulk load deferred post-demo
2. Advanced filters (multi-select, date range) — current AND filters sufficient for v1 team
3. Dashboards — out of v1 scope per Product Intent Brief (PIB)
4. Approval workflow — no acceptance lifecycle in v1 (CON-002 open; CTX-10 deferred)
5. Agents / AI automation — future direction per AFD-01; not v1 scope
6. IoT / digital twin — NDT-SaaS concern, explicitly separated from this platform
7. Role-based access control — single-team v1 is sufficient; RBAC is post-v1

---

### Section 6 — Next Immediate Capability

State explicitly:

**Next capability: Backend Required Field Enforcement**
**Feature slug:** `backend-required-field-enforcement`
**Reason:** `validate()` in `app/server.js` currently enforces only `title` is non-empty.
`owner`, `track`, and `status` are required per the schema (`ROW_FIELDS` required: true)
but a raw API caller (curl, Postman) can POST a row with empty owner/track and bypass all
client-side checks. This closes risk R-01 from the recon.
**Allowed surfaces:** app/server.js only (validate() function, POST handler).
**Verification:** POST /api/rows with missing owner → 400. POST with all required → 201.

---

## Acceptance Criteria
- [ ] roadmap/ directory exists.
- [ ] roadmap/v1-build-roadmap-dag.md exists.
- [ ] Document has all six sections: Current Baseline, Mermaid DAG, Capability Queue, Critical Path, Non-Critical Later Work, Next Immediate Capability.
- [ ] Mermaid block contains all nodes N0–N8 with correct classDef styling.
- [ ] Capability Queue table has a row for each node N0–N8.
- [ ] Critical Path section explicitly names the chain ending at Client Demo Release.
- [ ] Next Immediate Capability section names "Backend Required Field Enforcement" with reason.
- [ ] No file under app/, prototypes/, or sdlc/ was modified.

## Files Likely Affected
- `roadmap/v1-build-roadmap-dag.md` (created)

## Blocked By
- none
