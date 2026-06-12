# Spec: P3-1 Import Batch Ledger

## Status
approved

## Phase
phase-build

## Layer
L4-Data

## Upstream
- ai/recon/phase-3-recon-dag-map.md (P3-0 recon foundation)
- ai/recon/phase-3-import-batch-ledger-recon.md (P3-1 implementation recon)
- phase-2-xlsx-import (import pipeline baseline)
- phase-2-xlsx-import-open-mode (open-mode classification baseline)

## Downstream
- phase-3-delete-import-batch (P3-2 — depends on imports.id + entries.import_batch_id)
- phase-3-duplicate-detection (P3-3 — uses import_source_row for dedup key)
- phase-3-true-workbook-capture (P3-4 — observations table references imports.id)
- phase-3-import-provenance (P3-5 — details modal reads import_batch_id + batch filename)

## Capability

Before P3-1, every import commit inserts rows into `entries` with no record of which import they came from. Imported rows and manually-created rows are indistinguishable. There is no way to audit import history or identify which entries belong to which workbook upload.

After P3-1:
- Every import commit creates one record in a new `imports` ledger table, capturing the filename, operator, timestamp, and row counts.
- Each inserted entry carries `import_batch_id` (foreign reference to the imports record), `import_source_sheet` (name of the workbook sheet it came from), and `import_source_row` (1-indexed spreadsheet row number).
- Manually-created rows continue to have `import_batch_id = NULL` — they are not affected.
- Admins can retrieve the full import history via GET /api/imports.
- The Import tab displays the import history list to admins after each commit and on tab load.
- The commit response includes `batch_id`.

This establishes the foundation required for P3-2 (delete batch), P3-3 (duplicate detection), P3-4 (true workbook capture), and P3-5 (import provenance in row details).

## Data Model Changes

### New table: `imports`

```sql
CREATE TABLE IF NOT EXISTS imports (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  filename        TEXT NOT NULL,
  imported_by     TEXT NOT NULL,
  imported_at     TEXT NOT NULL DEFAULT (datetime('now')),
  total_rows      INTEGER,
  importable_rows INTEGER,
  skipped_rows    INTEGER,
  warning_count   INTEGER,
  status          TEXT NOT NULL DEFAULT 'complete'
);
```

### Modified table: `entries` (additive only)

Three nullable columns added via the existing idempotent `try { db.exec("ALTER TABLE ..."); } catch (_) {}` pattern:

```sql
ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;
```

- Existing rows receive `NULL` for all three columns.
- Manually-created rows (POST /api/rows) remain `NULL` for all three columns.
- Imported rows receive `import_batch_id = <batch id>`, `import_source_sheet = <sheet name>`, `import_source_row = <spreadsheet row number>`.

No existing column is modified. No existing constraint is modified. No existing row is backfilled beyond the NULL defaults.

## API Surface

### Modified: POST /api/import/commit

**Auth:** requireAuth + canImport (admin only) — unchanged

**Request body change:** Extends to include batch metadata. New shape:
```json
{
  "filename": "astraX-june-to-nov.xlsx",
  "sheet": "All Experiment Summary",
  "rows": [
    { "data": { "title": "...", ... }, "row_number": 5 },
    ...
  ]
}
```

The `data` object shape is unchanged. `row_number` and `sheet` are new fields.

**Behavior change:**
1. Validate `filename` (string, must end `.xlsx`); 400 on missing/invalid.
2. Pre-classify all rows to compute `importable_rows`, `skipped_rows`, `warning_count`.
3. INSERT INTO imports — returns `batch_id`.
4. For each importable row: INSERT INTO entries with `import_batch_id = batch_id`, `import_source_sheet = req.body.sheet`, `import_source_row = row.row_number`.
5. Open-mode classification rules are unchanged.

**Response change:** Adds `batch_id`:
```json
{
  "ok": true,
  "batch_id": 1,
  "inserted_count": 19,
  "ids": [66, 67, ...],
  "skipped_count": 0,
  "skipped": []
}
```

### New: GET /api/imports

**Auth:** requireAuth + canImport (admin only); non-admin → 403; anonymous → 401

**Purpose:** List all import batches, newest first.

**Response:**
```json
{
  "imports": [
    {
      "id": 1,
      "filename": "astraX-june-to-nov.xlsx",
      "imported_by": "admin",
      "imported_at": "2026-06-12T06:00:00",
      "total_rows": 19,
      "importable_rows": 19,
      "skipped_rows": 0,
      "warning_count": 36,
      "status": "complete"
    }
  ]
}
```

No DELETE in P3-1.

### Unchanged: POST /api/import/preview

Preview receives `filename` and `content_base64`. It already returns `row_number` per row and `sheet` in the summary. No changes required.

## Frontend Surface

### Modified: Import panel (admin only)

**State additions:**
- `state.imports` — array of import batch objects from GET /api/imports; initially `[]`
- `state.importFilename` — filename retained from the last preview file selection

**Changes to `renderImportPanel()`:**

Adds an "Import History" section below the existing preview/commit controls. Visible only to admin. Displays a compact table:

| Batch | File | By | Date | Rows | Warnings | Status |
|---|---|---|---|---|---|---|
| #1 | astraX-june-to-nov.xlsx | admin | 2026-06-12 06:00 | 19 | 36 | complete |

Empty state: "No imports yet."

**Changes to `bindImportActions()`:**

1. After successful preview: `state.importFilename = file.name`
2. Commit payload updated to: `{ filename: state.importFilename, sheet: p.summary.sheet, rows: p.rows.map(r => ({ data: r.data, row_number: r.row_number })) }`
3. After successful commit: call `loadImports()` then `renderApp()`

**New function `loadImports()`:**

```javascript
async function loadImports() {
  if (!isAdmin()) return;
  try {
    const d = await api('/imports');
    state.imports = d.imports || [];
  } catch (_) {
    state.imports = [];
  }
}
```

Called on: entering Import tab, after successful commit.

**No changes to:**
- Rows table
- Dashboard
- Users panel
- Details modal (P3-5 scope)
- Row click behavior (P3-7 scope)

## Operational Workflow

### Happy path — import with batch tracking

1. Admin selects Import tab → `loadImports()` fires → import history section renders (may be empty on first use)
2. Admin chooses .xlsx file → clicks Preview → `state.importFilename` saved, preview data stored in `state.importPreview`
3. Admin reviews preview table (unchanged UX)
4. Admin clicks Commit Import → confirm dialog
5. Frontend sends POST /api/import/commit with `{ filename, sheet, rows: [{data, row_number}] }`
6. Backend validates filename, classifies rows, INSERTs into `imports`, INSERTs entries with `import_batch_id`
7. Response: `{ ok, batch_id, inserted_count, ids, skipped_count, skipped }`
8. Frontend calls `loadImports()` → refreshes history → `renderApp()`
9. Import History now shows the new batch

### Manual row creation (unchanged)

POST /api/rows → INSERT INTO entries (no import columns set) → `import_batch_id = NULL`

### Non-admin attempts GET /api/imports

403 Forbidden

### Anonymous access

401 Not authenticated (requireAuth middleware, unchanged)

## Dependencies

- P3-0 recon: `ai/recon/phase-3-recon-dag-map.md`
- P3-1 slice recon: `ai/recon/phase-3-import-batch-ledger-recon.md`
- Phase 2 baseline: `phase-2-xlsx-import`, `phase-2-xlsx-import-open-mode`
- No external runtime dependencies added (no new npm packages)

## Acceptance Criteria

1. `imports` table exists in DB with columns: id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status
2. `entries` table has columns: import_batch_id, import_source_sheet, import_source_row (all nullable)
3. POST /api/import/commit creates exactly one `imports` row per commit call
4. POST /api/import/commit response includes `batch_id`
5. Each entry inserted by commit has `import_batch_id = <batch id>`
6. Each entry inserted by commit has `import_source_sheet = <sheet name from commit body>`
7. Each entry inserted by commit has `import_source_row = <row_number from preview row>` where row_number was present
8. Manually-created entries (POST /api/rows) have `import_batch_id = NULL`
9. Existing entries before P3-1 have `import_batch_id = NULL`
10. GET /api/imports (admin) returns 200 with `imports` array
11. GET /api/imports (non-admin / track_owner) returns 403
12. GET /api/imports (anonymous) returns 401
13. Import History section renders in Import tab for admin
14. Import History shows batch after commit without page reload
15. Import History shows "No imports yet" when no batches exist
16. Open-mode classification behavior is unchanged (title-only gate, coercion rules unchanged)
17. POST /api/import/preview behavior is unchanged
18. Existing P2 smoke tests continue to pass (rows, users, sessions, permissions)
19. No delete-import UI appears (P3-2 scope)
20. No duplicate detection UI appears (P3-3 scope)
21. Invariants 5/5 PASS
22. No `[FILL:]` residue in task files
23. Git status: only allowed surfaces modified

## Out of Scope

- DELETE /api/imports/:id (P3-2)
- Cascade delete of entries by batch (P3-2)
- Duplicate detection at preview or commit (P3-3)
- Multi-sheet workbook scanning (P3-4)
- import_observations table (P3-4)
- Import provenance in row details modal (P3-5)
- Row click to open details (P3-7)
- Dense cell content reveal (P3-6)
- Track-owner dashboard workspace filtering (P3-8)
- Any change to manual CRUD validation
- Any change to role permissions
- Any change to dashboard behavior
- Any change to row table UX
- Any change to app/public/index.html
- Any npm package additions
