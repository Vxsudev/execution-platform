# RECON: v1-serialized-build-roadmap-dag

## Capability
V1 Serialized Build Roadmap DAG

## Date
2026-06-10

## State at Recon
RECON_READY

---

## 1. Current App Baseline

Confirmed by reading `app/` and `git log`:

| Item | State |
|------|-------|
| app/ scaffold | exists, committed |
| Server | Express + node:sqlite + bcrypt + express-session |
| Database | SQLite (data.db), WAL mode with fallback, auto-seeded |
| CRUD | GET /api/rows, POST /api/rows, PUT /api/rows/:id, DELETE /api/rows/:id |
| Auth | Session cookie, login/logout, two dev users (admin, vasu) |
| Frontend | 14-column Excel-like table, search + Status/Track/Type filters, create/edit modal |
| Column contract | 13 Sheet-2 columns + Type tag, in workbook order |
| Persistence | Survives server restart |
| Node requirement | ≥ 22.5 (node:sqlite experimental) |

### Committed capabilities (RELEASE_APPROVED)
1. `promote-execution-table-v1-scaffold` — bootstrapped app/ from prototype; retired INV-002
2. `excel-like-team-summary-view` — Sheet-2 column order, dense grid, filters, modal helper text

### Latest commit
`f6a24b6 feat: align app with team experiment summary sheet`
Working tree: clean.

---

## 2. Unresolved Risks (Confirmed)

| # | Risk | Severity | Details |
|---|------|----------|---------|
| R-01 | Backend required-field bypass | HIGH | `validate()` in server.js enforces only `title`. Client-side checks (owner/track/status) can be bypassed via raw API calls. |
| R-02 | Hardcoded demo credentials | MEDIUM | `admin/admin123` and `vasu/vasu123` are seeded in db.js. No way to change without editing source. |
| R-03 | No credential hygiene gate | MEDIUM | Cookie secret missing; `express-session` uses default insecure secret in current scaffold. |
| R-04 | Local SQLite only | MEDIUM | No backup, no migration strategy, `data.db` in the app/ directory. |
| R-05 | No deployment configuration | HIGH | No Dockerfile, no Procfile, no platform config. Zero path to running anywhere except developer laptop. |
| R-06 | No import/export | LOW | Users can't bulk-load from Excel or export the table to CSV. Manual entry only. |
| R-07 | No CI pipeline | LOW | `npm start` only. No automated test run, no lint, no deployment automation. |
| R-08 | node:sqlite experimental | LOW | ExperimentalWarning on every boot. Requires Node ≥ 22.5. Documented in README. |

---

## 3. Proposed Build DAG

### Node definitions

| Node | Name | Status | Dependency |
|------|------|--------|------------|
| 0 | Current Baseline | DONE | — |
| 1 | Commit Current UX Pass | DONE | 0 |
| 2 | Backend Integrity | NEXT | 1 |
| 3 | Data Model Hardening | BLOCKED | 2 |
| 4 | UX Table Hardening | BLOCKED | 3 |
| 5 | Auth Hardening | BLOCKED | 3 |
| 6 | Import / Export | DEFERRED | 3 |
| 7 | Deployment Path | BLOCKED | 5 |
| 8 | Client Demo Release | RELEASE | 4 + 7 |

### Node purposes

**Node 2 — Backend Integrity**
Add required-field enforcement to `server.js` `validate()`: owner, track, status must be non-empty on POST. Partial-update (PUT) exempted. Closes R-01.

**Node 3 — Data Model Hardening**
Add NOT NULL constraints on owner/track/status columns at DB level; add index on status and track for filter performance; verify target_end_date stores as ISO text. Closes R-04 (partial).

**Node 4 — UX Table Hardening**
Date column formatting (ISO → human-readable), status badge alignment, edge-case empty state, filter dropdown re-population after create/edit. Non-blocking for demo but improves polish.

**Node 5 — Auth Hardening**
Move credentials to `.env` (SESSION_SECRET, ADMIN_PASS, VASU_PASS); update db.js seed to read from env; update README with env var documentation. Closes R-02, R-03.

**Node 6 — Import / Export** *(deferred — non-critical path)*
CSV export of current filtered view; optional CSV import from Excel export. Not blocking demo release.

**Node 7 — Deployment Path**
Dockerfile + docker-compose.yml; `.env.example`; README deployment section; platform-agnostic. Closes R-05.

**Node 8 — Client Demo Release**
Tag v1.0.0; update README with demo instructions; confirm no hardcoded credentials in shipped image.

---

## 4. Critical Path

```
Node 1 (Baseline committed)
  → Node 2 (Backend Integrity)
    → Node 3 (Data Model Hardening)
      → Node 5 (Auth Hardening)
        → Node 7 (Deployment Path)
          → Node 8 (Client Demo Release)
```

Node 4 (UX Table Hardening) is on the path to Node 8 (required for polished demo) but not strictly on the release-blocking critical path.

Node 6 (Import/Export) is deferred — can be added post-v1.0.0.

---

## 5. Deferred Items (Non-v1)

These are outside the v1 table editor scope and must not be reintroduced:

| Item | Authority |
|------|-----------|
| Approval workflow | CTX-10, PIB v1 scope lock |
| Escalation workflow | CTX-10, PIB v1 scope lock |
| Dashboard / management read surface | PIB v1 scope lock |
| Agents / AI automation | PIB v1 scope lock |
| IoT / digital twin integration | PIB v1 scope lock |
| Import/Export (v1.1+) | Deferred from v1 critical path |
| Advanced filters (multi-select, date range) | Post-demo enhancement |
| Role-based access control | Post-v1 (single-team v1 is sufficient) |

---

## 6. Risks to Roadmap

- None of the deferred items are required for demo release.
- Node 4 (UX Table Hardening) could be skipped for an MVP demo if time-constrained; backend integrity and auth are the real blockers.
- The build-map at `sdlc/00-process-constitution/execution-platform-build-map.md` is now superseded by actual build progress; this roadmap document is the operative reference.

---

## 7. Files to Create

| File | Purpose |
|------|---------|
| `roadmap/v1-build-roadmap-dag.md` | Authoritative build roadmap with Mermaid DAG, capability queue, critical path |
| `ai/recon/v1-serialized-build-roadmap-dag-recon.md` | This file |
