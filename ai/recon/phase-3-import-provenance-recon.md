# Recon: P3-5 Import Provenance in Row Details

## Date
2026-06-12

## Feature Slug
phase-3-import-provenance

## Commands Run
- `bash vendor/engineering-os/scripts/os-adapter-check.sh` → 12/12 PASS
- `bash scripts/invariant-check.sh` → 5/5 PASS
- `PRAGMA table_info(entries)` — 22 columns confirmed
- `PRAGMA table_info(import_observations)` — 9 columns confirmed
- `SELECT count(*) FROM entries WHERE import_batch_id IS NOT NULL` → 0 (all 65 entries are manual; batch 9 had 0 inserts)
- `cat ai/state_registry.json` — phase-3-import-provenance not present; full lifecycle required

## Git State
- Branch: main (clean, 4 commits ahead of origin)
- Latest commit: b287010 — feat: add P3-4 true workbook capture

---

## Current Details Modal Behavior

`openDetails(row)` in `app/public/app.js` line 672–695:
- Synchronous function (not async)
- Renders a `.modal-sm` (320px wide) with only 4 audit fields: created_by, updated_by, created_at, updated_at
- No row content fields
- No provenance section
- Must be redesigned for P3-5

---

## Row Payload Findings (GET /api/rows)

`app/server.js:166–168` — `SELECT * FROM entries ORDER BY updated_at DESC, id DESC`

Columns returned per row (22 total):
- Execution: `id, type, title, owner, track, function_area, parent_item, hypothesis, design, success_criteria, target_end_date, dependencies, outcome, next_action, status`
- Audit: `created_at, updated_at, created_by, updated_by`
- Import provenance: `import_batch_id, import_source_sheet, import_source_row`

All provenance fields are already in the row payload. No backend change needed.

---

## Import Metadata Availability (GET /api/imports)

`app/server.js` — returns: `id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status, observation_count`

`loadImports()` in `app.js:505–513` — admin-only, lazy-loaded when Import page is opened.

`state.imports` will be empty `[]` for non-admin users and for admin who has not visited the Import tab in the current session.

---

## Backend / Frontend Dependency Decision

**Option A — Client-side join (selected)**

Row payload already includes `import_batch_id`, `import_source_sheet`, `import_source_row`. Frontend joins `row.import_batch_id` to `state.imports` for enrichment when available.

- Basic provenance (batch id, source sheet, source row) — available to all roles from the row object itself
- Enriched provenance (filename, imported_by, imported_at, observation_count) — available to admin only when `state.imports` is populated
- Lazy-load: if `isAdmin() && row.import_batch_id && !state.imports.length`, call `loadImports()` inside `openDetails()` before rendering

**Option B — Not needed.** Current payload is sufficient.

No changes to `app/server.js` required.

---

## Provenance Display Model

**Manual row (import_batch_id = NULL):**
- Origin badge: Manual / Legacy
- Note: no import batch
- Audit section still shows created_by / created_at

**Imported row (import_batch_id IS NOT NULL):**
- Origin badge: Imported
- Always: Batch ID, Source Sheet, Source Row (from row object)
- When state.imports available: Filename, Imported by, Imported at, Batch status, Observation count

**Unknown / legacy:** same as manual (import_batch_id IS NULL → treat as manual)

---

## Security / Exposure Assessment

- No new API routes
- No new DB columns or writes
- Row data is already delivered by `GET /api/rows` behind `requireAuth`
- Import batch metadata (filename, imported_by) only shown to admin via existing `GET /api/imports`
- Details modal is read-only; no edit/write paths introduced
- `password_hash` and `session` data are not in `entries` table — no exposure risk

---

## Current State of Fields Schema (db.js:28–43)

14 fields in ROW_FIELDS:
```
owner, track, title, function_area, parent_item,
hypothesis, design, success_criteria, target_end_date,
dependencies, outcome, next_action, status, type
```
Long-text (textarea): hypothesis, design, success_criteria, outcome

---

## Mutation Plan

### app/public/app.js
1. Make `openDetails()` async
2. Lazy-load imports for admin when row has import_batch_id and state.imports is empty
3. Render 3 sections:
   - **Row Content** — all 14+ fields in a readable grid; long-text fields use `.detail-long`
   - **Audit** — created_by, created_at, updated_by, updated_at
   - **Provenance** — import origin badge + batch/source metadata or Manual/Legacy
4. Modal changes from `.modal-sm` (320px) to `.modal-wide` (760px)
5. `openDetails()` call site (line 277): no change needed — existing `b.onclick = () => openDetails(...)` will work with async function

### app/public/style.css
Add:
- `.modal-wide` (760px width)
- `.detail-section` (section wrapper with heading)
- `.detail-grid` (2-col label/value grid for compact fields)
- `.detail-label` (muted label)
- `.detail-value` (text value)
- `.detail-long` (full-width long text block)
- `.origin-badge` base + `.origin-badge.imported` (blue) + `.origin-badge.manual` (muted)

### app/README.md
Add "Import Provenance (Phase 3)" section.

### No changes to:
- app/server.js
- app/db.js
- app/public/index.html

---

## Dependency Relationship to P3-6 / P3-7

- P3-6 (dense cell inline reveal): operates on the main table rows inline — no dependency on P3-5 Details modal
- P3-7 (row/cell click interaction): adds click-to-open Details from row click — depends on P3-5 modal being the right shape
- P3-5 explicitly does NOT implement P3-6 or P3-7

---

## Verification Plan

1. `node --check server.js` (no changes expected)
2. `node --check public/app.js`
3. `bash scripts/invariant-check.sh` → 5/5
4. Backend smoke: no changes to import routes; verify row + import routes intact
5. Frontend smoke: admin + track_owner + viewer Details modal behavior; manual vs imported row

---

## Conflicts
None found.
