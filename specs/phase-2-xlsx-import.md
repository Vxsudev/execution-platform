# Spec: Phase 2 — XLSX Import

## Status
approved

## Phase
phase-build

## Feature Slug
phase-2-xlsx-import

## Goal
Add admin-only XLSX import from the astraX workbook into execution rows with a
two-step model: a non-destructive **preview** (parse + validate, no DB write)
followed by an explicit **commit** (server-side revalidation + insert). The
SQLite database remains the runtime source of truth; the workbook is an
import/template source, never a continuous sync. Backend enforces all
authorization and validation; the frontend is UX only.

## Recon
ai/recon/phase-2-team-operating-model-full-spec-recon.md (§9 XLSX Import Feasibility)

## Dependency
- P2-1 Roles & Permissions Backend (RELEASE_APPROVED) — `canImport(user)` helper, `requireAuth`, role on `req.user`.
- P2-2 Split Workspaces Frontend (RELEASE_APPROVED) — `state.page`, `isAdmin()` helpers, topbar tab pattern.
- P2-3 Admin User Management (RELEASE_APPROVED) — admin topbar tab + page-toggle pattern reused for the Import tab.

## Package Policy
This slice adds **exactly one** runtime dependency: `xlsx` (SheetJS Community
Edition). It is the only Phase-2 feature that changes packages. Install from the
app directory only (`cd app && npm install xlsx`). No other package additions,
no global installs, no alternate XLSX library. Verified available: xlsx@0.18.5,
npm registry reachable, Node 25.4.0 / npm 11.7.0.

---

## Workbook Header Verification (VERIFIED against live file)

Inspected `source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx`
directly (openpyxl, read-only). Findings:

**Sheets:** `Sample Experiment Log` [0], **`All Experiment Summary`** [1] (import
target — 17 cols × 62 rows), `How To Use` [2].

**Header row is ROW 4** (row 1 = title banner, row 2 = how-to banner, row 3 = blank).
Data columns are **col 1–13**. Columns 16–17 are a separate `STATUS SUMMARY` /
`Count` stats panel and MUST NOT be imported.

**Verified header → DB field mapping** (exact labels from row 4):

| Workbook Header (row 4) | DB column | Required |
|---|---|---|
| `Owner` | owner | yes |
| `Track` | track | yes (enum) |
| `Experiment Title` | title | yes |
| `Function` | function_area | |
| `Parent Item` | parent_item | |
| `Description / Hypothesis` | hypothesis | |
| `Experiment Design` | design | |
| `Success Criteria` | success_criteria | |
| `Target End Date` | target_end_date | (date-normalized) |
| `Dependencies` | dependencies | |
| `Test outcome / Finding` | outcome | |
| `Next Action` | next_action | |
| `Status` | status | yes (enum) |
| *(no Type column in workbook)* | type | defaults to `experiment` |

The actual outcome-column label is **`Test outcome / Finding`** (the recon noted
this variant). The workbook has no Type column → imported rows default to
`type = 'experiment'`.

**DATA-QUALITY FINDING (must be surfaced, not silently fixed):** Against strict
canonical validation, the live workbook currently yields **0 valid / 19 invalid**
data rows (+39 fully-empty rows correctly skipped). Track labels in the workbook
are `'T1-Device'` (10), `'T1 Device'` (1), or blank (8) — **none** match the
canonical TRACKS (`'T1 AstraX Device'`, …); 9 rows have blank status, 8 blank
owner. This is expected, faithful behavior: the directive mandates strict track
and status enum validation, and preview surfaces every invalid row with reasons.
**No track normalization/aliasing is in scope** — adding it would defeat the
validation invariant and is not authorized. Operators must either correct the
workbook track labels to the canonical taxonomy before import, or commission a
separate track-normalization slice (future scope). Commit-path verification uses
canonical-track fixtures because the live workbook commits nothing.

---

## Architecture Contract / Invariants
- Admin-only import: `canImport(req.user)` at both route entries; `track_owner`/`viewer` get 403.
- No public upload endpoint; no multipart (base64-in-JSON keeps the dependency count at one).
- Workbook import is one-shot, not continuous sync. Excel never becomes the runtime source of truth; SQLite does.
- Preview parses + validates only — it MUST NOT write the DB.
- Commit MUST revalidate every row server-side (does not trust the preview payload) and insert only valid rows.
- Backend stamps `created_by` and `updated_by` to the importing admin's username.
- Backend validates required fields (owner, track, title, status), track enum (TRACKS), status enum (STATUSES); `type` defaults to `experiment` and, if supplied, must be a valid ROW_TYPES value.
- Fully-empty workbook rows are ignored and not counted as invalid.
- String fields are trimmed; `Target End Date` date cells normalize to `YYYY-MM-DD`, text dates preserved; a blank date does not invalidate a row.
- No dedupe in Phase 2. No approval/escalation workflow, no agents, no dashboard, no deployment.
- Preserve: login/logout, `/api/me` payload, P2-1 row permission guards, P2-2 workspaces, P2-3 user management, required-field + enum validation, audit stamping, row details, search/filter.

---

## Data Model Changes
No `entries` table schema change — all required columns already exist (owner,
track, title, function_area, parent_item, hypothesis, design, success_criteria,
target_end_date, dependencies, outcome, next_action, status, type, created_by,
updated_by). The only data-plumbing change in this slice is adding the `xlsx`
runtime dependency to `app/package.json` and `app/package-lock.json` (the OS
layer model has no dedicated dependency layer, so the dependency install +
live workbook header verification are governed by this slice's first task).
`app/db.js` is NOT modified.

---

## API Surface

Two new routes in `app/server.js`. Both require `requireAuth` + `canImport(req.user)`
(non-admin → 403 `{ "error": "Forbidden" }`; unauthenticated → existing 401).
Because base64 workbook payloads exceed the 100 kb default, a 25 mb JSON body
parser is scoped to these two routes only; the global default parser is preserved
for every other route.

### Helpers to add (before the import routes, in server.js)
- `IMPORT_SHEET = 'All Experiment Summary'` + `resolveImportSheet(wb)` (prefers the named sheet, falls back to a `/summary/i` match).
- `IMPORT_HEADER_MAP` — workbook-label → DB-field (the verified table above). Recognized headers only, so the stats panel is ignored.
- `IMPORT_REQUIRED = ['owner','track','title','status']`.
- `normalizeImportValue(field, value)` — trims strings; for `target_end_date`, formats `Date` cells as `YYYY-MM-DD`.
- `parseImportWorkbook(buffer)` — `XLSX.read(buffer,{type:'buffer',cellDates:true})`, resolve sheet, `sheet_to_json(ws,{header:1,defval:null,blankrows:true})`, locate the header row (the row containing `Owner`+`Track`+`Experiment Title`), map columns, emit `{ sheet, rows:[{ row_number, data }] }` with 1-indexed spreadsheet row numbers, skipping fully-empty mapped rows.
- `validateImportRow(data)` — returns an array of error strings (required fields, track enum, status enum, optional type enum).
- `toImportRow(data)` — projects onto entries columns, forces `type` to a valid ROW_TYPES value defaulting to `experiment`.

### POST /api/import/preview
Request: `{ "filename": "...xlsx", "content_base64": "..." }`. Validates filename
ends in `.xlsx`, decodes base64, parses, validates each row. **No DB write.**
Response:
```json
{
  "summary": { "sheet": "All Experiment Summary", "total_rows": 19, "valid_rows": 0, "invalid_rows": 19 },
  "valid_rows":   [ { "owner": "...", "track": "...", "title": "...", "status": "...", "type": "experiment", "...": "..." } ],
  "invalid_rows": [ { "row_number": 7, "errors": ["owner is required", "invalid track"], "raw": { } } ]
}
```

### POST /api/import/commit
Request: `{ "rows": [ ...valid rows from preview... ] }`. Revalidates every row
server-side; inserts only valid rows; stamps `created_by`/`updated_by` =
`req.user.username`; forces `type` to `experiment` unless a valid ROW_TYPES value
is supplied. Response:
```json
{ "ok": true, "inserted_count": 8, "ids": [101,102], "rejected_count": 0, "rejected": [] }
```

---

## Frontend Surface

Admin-only Import surface in `app/public/app.js` (UX only — backend is authoritative).
Reuse the P2-3 topbar-tab + page-toggle pattern.
- `state.page` extends to `'rows' | 'users' | 'import'`; add `state.importPreview = null`.
- Topbar: an **Import** tab button rendered only when `isAdmin()`, beside the Users tab.
- Clicking Import sets `state.page = 'import'` (clears any stale preview) and re-renders; clicking again returns to rows. Non-admins never see the tab.
- Import panel (`renderImportPanel()`):
  - `.xlsx` file input + **Preview** button.
  - After preview: a summary line (sheet, total / valid / invalid counts).
  - Invalid-row list showing `row_number` + error messages.
  - Valid-row preview table limited to the first 10 rows.
  - **Commit Import** button, enabled only when `valid_rows.length > 0`.
  - After commit: reload rows, return to All Tracks view, show inserted count.
- File→base64 via `FileReader.readAsDataURL` (strip the data-URL prefix) before POSTing JSON.
- `app/public/style.css`: minimal import-panel styles (reuse existing tokens).

---

## Allowed Mutation Surfaces
- app/package.json
- app/package-lock.json
- app/server.js
- app/public/app.js
- app/public/style.css
- app/README.md
- specs/phase-2-xlsx-import.md
- tasks/phase-2-xlsx-import-001.md … tasks/phase-2-xlsx-import-004.md
- ai/state_registry.json
- ai/engineering-journal.md

Do NOT modify: app/db.js, app/public/index.html, prototypes/, sdlc/, vendor/, deployment files.

---

## Verification Plan
1. App boots locally; `xlsx` present in package.json + package-lock.json.
2. Admin login works; admin sees the Import tab; `track_owner`/`viewer` do not.
3. `POST /api/import/preview` (admin) returns sheet name + total/valid/invalid counts and writes nothing to the DB.
4. Invalid rows reported with row numbers + reasons; fully-empty rows ignored.
5. With a canonical-track fixture: valid rows preview (first 10), Commit inserts them, rows appear in All Tracks after reload, `type='experiment'`, `created_by`/`updated_by` = importing admin.
6. Track/status enum + required-field validation reject bad rows at both preview and commit.
7. `track_owner` and `viewer` receive 403 on both `/api/import/preview` and `/api/import/commit`; no Import tab in their UI.
8. Regression: All Tracks view, My Track workspace (vasu, T3 only), Admin Users tab, row CRUD permissions, user-management routes all still work. No public upload route, no continuous sync, no dashboard.
9. Invariants 5/5 PASS; git status shows only allowed surfaces modified.

## Verification Scripts
(none — repo has no scripts/verification/ directory; verification is performed via the supervisor gates, the verification task, and the post-pipeline regression sweep.)

---

## Non-Scope
Continuous Excel sync · multipart upload · track normalization/aliasing · row
dedupe · approval/escalation workflow · agents · dashboard · deployment · public
signup · email invite · password reset · SSO / external auth.
