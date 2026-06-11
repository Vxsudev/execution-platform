# Recon: Phase 2 Review Checkpoint (P2-6)

Generated: 2026-06-12
Feature Slug: phase-2-review-checkpoint
Recon Mode: Read-only — no product mutation

---

## 1. Environment Validation

| Check | Result |
|---|---|
| Repository mode | OS-ENABLED (vendor/engineering-os/ + .engineering-os/ present) |
| OS adapter check | 12/12 PASS |
| Git working tree | Clean (commit 11d7ff2) |
| Latest commit | `11d7ff2 feat: add basic execution-health dashboard` |
| P2-5 committed | ✓ |
| P2-4A committed | ✓ (bad04b9) |
| P2-4 committed | ✓ (306ec7d) |
| P2-1 through P2-3 | ✓ (committed prior) |

---

## 2. State Registry Audit

File: `ai/state_registry.json`

All Phase 2 features confirmed RELEASE_APPROVED:

| Feature Slug | State | Updated At |
|---|---|---|
| phase-2-roles-permissions | RELEASE_APPROVED | 2026-06-10T10:46:28Z |
| phase-2-split-workspaces | RELEASE_APPROVED | 2026-06-10T11:13:17Z |
| phase-2-admin-user-management | RELEASE_APPROVED | 2026-06-10T14:06:01Z |
| phase-2-xlsx-import | RELEASE_APPROVED | 2026-06-10T15:58:20Z |
| phase-2-xlsx-import-open-mode | RELEASE_APPROVED | 2026-06-10T21:41:51Z |
| phase-2-basic-dashboard | RELEASE_APPROVED | 2026-06-11T21:44:02Z |

Pre-Phase-2 features (all RELEASE_APPROVED): promote-execution-table-v1-scaffold, excel-like-team-summary-view, v1-serialized-build-roadmap-dag, backend-required-field-enforcement, canonical-track-taxonomy-enforcement, track-enum-server-validation, data-model-audit-trail, ux-table-hardening-v1, auth-hardening-v1

---

## 3. Spec/Task Coverage Audit

Specs present in `specs/`:
- phase-2-roles-permissions.md
- phase-2-split-workspaces.md
- phase-2-admin-user-management.md
- phase-2-xlsx-import.md
- phase-2-xlsx-import-open-mode.md
- phase-2-basic-dashboard.md

All specs have Status: approved, Phase: phase-build.

Tasks present in `tasks/`:
- phase-2-roles-permissions-001..003
- phase-2-split-workspaces-001..003
- phase-2-admin-user-management-001..004
- phase-2-xlsx-import-001..004
- phase-2-xlsx-import-open-mode-001..003
- phase-2-basic-dashboard-001..003

Total: 6 specs / 19 task files. All Phase 2 capabilities have spec+task coverage.

---

## 4. App Architecture Summary

### Backend (`app/server.js` — 464 lines)

- **Framework:** Express + node:sqlite (DatabaseSync, WAL mode)
- **Auth:** HMAC-signed session tokens (sha256), `sid` cookie, `SESSION_SECRET`
- **Middleware:** Default 100kb JSON parser; scoped 25mb parser for import routes
- **Routes confirmed:**
  - `POST /api/login` — bcrypt verify, session insert, signed cookie
  - `POST /api/logout` — session delete, cookie clear
  - `GET /api/me` — current user (id, username, role, track_scope); no password_hash
  - `GET /api/schema` — ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS
  - `GET /api/rows` — requireAuth, all entries ordered updated_at DESC
  - `GET /api/rows/:id` — requireAuth
  - `POST /api/rows` — requireAuth, validate (strict), canCreateRow check
  - `PUT /api/rows/:id` — requireAuth, validate (strict partial), canEditRow check
  - `DELETE /api/rows/:id` — requireAuth, canDeleteRow (admin only)
  - `GET /api/users` — requireAuth + canManageUsers (admin only)
  - `POST /api/users` — requireAuth + canManageUsers
  - `PUT /api/users/:id` — requireAuth + canManageUsers + self-demote guard
  - `DELETE /api/users/:id` — requireAuth + canManageUsers + self-delete guard
  - `POST /api/import/preview` — importJsonParser + requireAuth + canImport (admin only)
  - `POST /api/import/commit` — importJsonParser + requireAuth + canImport (admin only)

- **Permission model:**
  - `canCreateRow`: admin=true, track_owner if track in scope, viewer=false
  - `canEditRow`: admin=true, track_owner if existing+next track in scope, viewer=false
  - `canDeleteRow`: admin only
  - `canImport`: admin only
  - `canManageUsers`: admin only

- **Validation (CRUD):** Strict — TRACKS array, STATUSES array, ROW_TYPES array; rejects non-canonical values
- **Import validation:** Open-mode classifyImportRow — only blank title skips; non-canonical track imported as-is; non-canonical/blank status coerced to "Not Started"; owner blank→"Unassigned"

### Database (`app/db.js` — 116 lines, NOT modified in P2-5 or P2-6)

- **entries.status:** CHECK constraint — 5 canonical values only
- **entries.type:** CHECK constraint — 3 canonical values only
- **entries.track:** Free TEXT (no CHECK) — can store shorthand
- **entries.owner:** Nullable TEXT (no CHECK)
- **Schema migrations:** Additive ALTER TABLE with try/catch (created_by, updated_by, role, track_scope)
- **Seed users:** admin (role=admin) + vasu (role=track_owner, scope=["T3 AstraX Ops Cloud"])

### Frontend (`app/public/app.js` — 681 lines)

- **state.page:** 'rows' | 'users' | 'import' | 'dashboard'
- **state.workspace:** 'all' | 'my' (track_owner only, scoped to Rows view)
- **Tabs:** Universal Rows+Dashboard; admin-only Users+Import; New-row button Rows-only
- **Dashboard:** renderDashboard() + helpers (isClosed, isOpen, byCount, parseDateSafe, blockedRows, overdueRows, recentRows, openNextActions, dashStats)
- **Import:** renderImportPanel() — open-mode language; preview + commit; commit sends rows.map(r => r.data)

---

## 5. Live Smoke Test Results

Server: http://localhost:3000 (already running, node server.js)
DB state: 64 rows, 2 users (admin, vasu)

### Admin flow

| Test | Expected | Result |
|---|---|---|
| POST /api/login admin | 200, user.id | ✓ authenticated |
| GET /api/me | role=admin, no password_hash | ✓ |
| GET /api/rows | 200, 64 rows, no password_hash | ✓ |
| GET /api/users | 200, 2 users, no password_hash | ✓ |
| POST /api/import/preview (empty) | 400 (content_base64 required) | ✓ |
| PUT /api/users/1 role=viewer (self-demote) | 403 | ✓ |
| DELETE /api/users/1 (self-delete) | 403 | ✓ |

### Track owner flow (vasu)

| Test | Expected | Result |
|---|---|---|
| GET /api/me | role=track_owner, scope=[T3 AstraX Ops Cloud] | ✓ |
| GET /api/rows | 200 | ✓ |
| GET /api/users | 403 | ✓ |
| POST /api/import/preview | 403 | ✓ |
| POST /api/import/commit | 403 | ✓ |
| POST /api/rows T3 | 201 | ✓ (cleanup: deleted) |
| POST /api/rows T1 | 403 | ✓ |
| DELETE /api/rows/:id | 403 | ✓ |

### Anonymous

| Test | Expected | Result |
|---|---|---|
| GET /api/rows | 401 | ✓ |
| GET /api/users | 401 | ✓ |

### CRUD strict validation

| Test | Expected | Result |
|---|---|---|
| POST /api/rows with track="T1-Device" | 400 invalid track | ✓ |

### Frontend assets

| Asset | Check | Result |
|---|---|---|
| /app.js | contains renderDashboard | ✓ (2 occurrences) |
| /app.js | contains renderImportPanel | ✓ (2 occurrences) |

---

## 6. Import Coverage Audit

### Workbook: astraX-june-to-nov-experiment-all-tracking.xlsx

**Sheets found:** `['Sample Experiment Log', 'All Experiment Summary', 'How To Use']`

**Sheet selected by importer:** `All Experiment Summary` (matches IMPORT_SHEET constant exactly; fallback: first sheet matching /summary/i)

**All Experiment Summary structure:**
- Total matrix rows: 62
- Header row detected at: row index 3 (spreadsheet row 4)
- Header columns: Owner, Track, Experiment Title, Function, Parent Item, Description/Hypothesis, Experiment Design, Success Criteria, Target End Date, Dependencies, Test outcome/Finding, Next Action, Status (+ blank cols + STATUS SUMMARY / Count side panel)

**Data rows after header:**
- Non-empty rows: **19**
- Blank-title rows: **0** (no rows skipped by importer)

**Track distribution in All Experiment Summary:**
```
T1 Device:   1 row
T1-Device:   10 rows
(blank):     8 rows  → coerced to "Unassigned Track" by open-mode
```

**Live preview result (confirmed against running server):**
```
sheet: All Experiment Summary
total_rows: 19 | importable: 19 | skipped: 0 | warnings: 36
track distribution: {T1 Device: 1, T1-Device: 10, Unassigned Track: 8}
```

### Sample Experiment Log analysis

**Structure:** Personal experiment log template. 25 rows total. No "Owner" column — header detection fails (IMPORT_HEADER_MAP requires Owner+Track+Experiment Title). This sheet is intentionally NOT processed by the importer.

**T1-T6 content in Sample Experiment Log:**
- Row 6: T1 AstraX Device — 1 sample row
- Row 7: T2 AstraX Customer Cloud — 1 sample row
- Row 8: T3 AstraX Ops Cloud — 1 sample row
- Row 9: T4 Manufacturing partners (inferred from context)
- ...T5 and T6 also present as sample rows

These are **template example rows**, not operational data.

---

## 7. Import Coverage Finding

**Did the importer ingest only T1? Yes.**

**Why?** The 'All Experiment Summary' sheet contains only T1 experiments (T1-Device / T1 Device labels). T2-T6 tracks have no rows in this sheet. The sheet structure reflects the state of the team's actual experiment tracking data — only T1 has been populated in the summary.

**Root cause:** Data coverage, not an importer bug. The importer correctly processes all 19 rows in the importable sheet. T2-T6 experiments have not been entered into the 'All Experiment Summary' sheet by the team.

**Contributing factors:**
- The 'Sample Experiment Log' sheet has T1-T6 sample rows but uses a different column layout (no Owner column) — the header detection algorithm correctly skips it because the IMPORT_HEADER_MAP requires Owner + Track + Experiment Title in the same header row.
- 8 blank-track rows exist in 'All Experiment Summary'; these are imported as "Unassigned Track" by the open-mode importer — they may represent T2-T6 rows that were entered without filling in the Track column.

**Is the cause parser range, sheet selection, title rule, workbook structure, or data itself?**
Primarily **data itself** (sheet not populated for T2-T6) with a secondary **sheet selection** observation (only one sheet is ever processed — there is no multi-sheet ingestion capability).

**What should P3 address?** See Section 8.

---

## 8. P3 Carry-Forward Requirements

### P3-1: Import Batch Management

**Problem:** There is no mechanism to identify which DB rows came from which import, or to undo an import.

**Proposed data model:**
```sql
CREATE TABLE imports (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  filename     TEXT NOT NULL,
  imported_by  TEXT NOT NULL,
  imported_at  TEXT NOT NULL DEFAULT (datetime('now')),
  row_count    INTEGER,
  warning_count INTEGER,
  status       TEXT DEFAULT 'complete'
);

ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;
```

- Manual rows: import_batch_id = NULL
- Imported rows: import_batch_id = imports.id

**Destructive action:** `DELETE /api/imports/:id` (admin only) — deletes all entries where import_batch_id = id.

### P3-2: Full Workbook Capture

**Problem:** Only the 'All Experiment Summary' sheet is imported. If T2-T6 teams use separate sheets or separate workbooks, their data is not captured.

**Questions for operator:**
1. Will T2-T6 teams populate the same 'All Experiment Summary' sheet, or use separate workbooks?
2. Should the importer scan all sheets for rows matching the IMPORT_HEADER_MAP format?
3. Is there a plan to standardize the workbook template across all tracks?

**Options:**
- Option A: Multi-sheet scan — iterate all sheets, find any with Owner+Track+Experiment Title header, import from all.
- Option B: Multi-workbook import — allow importing N workbook files per session (one per track).
- Option C: Documentation — document that all tracks must populate 'All Experiment Summary' before importing.

### P3-3: Duplicate Detection

**Problem:** Re-importing the same workbook after adding new rows would create duplicates for previously-imported rows (no dedup mechanism exists).

**Proposed:** Check for existing rows by (title + owner + track) before inserting, or use import_source_row to detect prior imports of the same source row.

### P3-4: Viewer Role Visibility

**Problem:** The import panel is admin-only (correct). But imported rows with "Unassigned Track" or non-canonical track labels may confuse viewers who see these in the Rows table with no context about their origin.

**Proposed:** Show import_batch_id context in the details modal (for auditing purposes).

---

## 9. Execution Risks

| Risk | Severity | Mitigation |
|---|---|---|
| DB has no import_batch_id — can't undo import | HIGH | P3 priority: import batch management |
| T2-T6 data not in workbook yet — importable_rows always T1-only | MEDIUM | Operator awareness; data entry needed |
| Non-canonical track labels stored (T1-Device vs T1 AstraX Device) | LOW | Dashboard preserves them; search works; P3 can add display normalization |
| 64 rows in DB (mix of seed, manual, and possibly imported) — no provenance | MEDIUM | P3 import_batch_id will address |
| SESSION_SECRET falls back to dev-insecure string in non-production | LOW | Production deployment must set SESSION_SECRET env var |

---

## 10. Invariant Interactions

| Invariant | Impact on P2-6 |
|---|---|
| INV-001: vendor OS immutable | P2-6 may not alter vendor/engineering-os/ |
| INV-003: artifacts declare Layer+Status | spec and tasks must declare Layer/Status/traceability |
| INV-004: ADRs append-only | no ADR changes in P2-6 |
| INV-005: Domain Constitution pre-L2 | no domain constitution created |
| INV-006: traceability | spec and tasks must declare upstream/downstream |
| INV-002: no app code pre-L5 | N/A (repo is in L5 build phase) |

All 5 active invariants pass (verified by invariant-engine.sh at session start).

---

## 11. Files Read

- app/server.js (464 lines — full)
- app/public/app.js (681 lines — key sections)
- app/db.js (116 lines — full)
- app/package.json (18 lines)
- app/public/style.css (118 lines — confirmed dashboard CSS present)
- ai/state_registry.json — full
- ai/invariant-registry.md — full
- .engineering-os/adapter.config.sh — full
- specs/phase-2-basic-dashboard.md — full
- specs/phase-2-xlsx-import-open-mode.md — full
- vendor/engineering-os/scripts/os-adapter-check.sh (via execution)
- vendor/engineering-os/scripts/invariant-engine.sh (via execution)

## 12. Commands Run

```
git log --oneline -10
git status --short
ls vendor/engineering-os/ && ls .engineering-os/
bash vendor/engineering-os/scripts/os-adapter-check.sh
bash vendor/engineering-os/scripts/invariant-engine.sh
cat ai/state_registry.json
wc -l app/server.js app/public/app.js app/public/style.css app/db.js app/package.json
# node workbook analysis (sheet list, header detection, data range, track distribution)
# curl smoke tests (admin, vasu, anon, CRUD strict validation, self-demote/delete)
# live import preview with real workbook
```
