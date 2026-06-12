# Task: Add import_observations table and capture observations on commit

## Parent Spec
specs/phase-3-true-workbook-capture.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
Add the `import_observations` table to `app/db.js` and integrate true workbook
capture into `POST /api/import/commit` and `POST /api/import/preview` in
`app/server.js`.

### app/db.js — new table (additive, idempotent)

Add inside the main `db.exec(\`...\`)` schema block, after the `imports` table
definition (before the closing backtick):

```sql
CREATE TABLE IF NOT EXISTS import_observations (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  import_batch_id   INTEGER NOT NULL,
  source_sheet      TEXT,
  source_row        INTEGER,
  observation_type  TEXT NOT NULL,
  status            TEXT NOT NULL,
  reason            TEXT,
  raw_data          TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
```

No CHECK constraints. No ALTER on existing tables. No backfill. Do not modify
existing table definitions, seed logic, or exports.

### app/server.js — preview (POST /api/import/preview)

1. Include raw `data` in each `skipped_rows` entry: change the push to
   `skipped_rows.push({ row_number, reason: c.reason, data })`.
2. Add projected capture counts to `summary` (no DB writes):
   - `observed_sheet_count`: `parsed.sheet ? 1 : 0`
   - `observation_count`: `rows.length + skipped_rows.length + (parsed.sheet ? 1 : 0)`
3. Preserve all existing summary fields and behavior. Preview still writes nothing.

### app/server.js — commit (POST /api/import/commit)

After the existing entry-insert loop (which is unchanged), capture observations.
Accept an optional `skipped_rows` payload array.

1. Read `const payloadSkipped = Array.isArray(req.body.skipped_rows) ? req.body.skipped_rows : [];`
2. Track, during the insert loop, the per-row outcome so observations can be built:
   - inserted rows: keep `{ source_row, entry_id, data }`
   - duplicate-skipped rows: keep `{ source_row, data, duplicate_entry_id }`
3. After the loop, insert observations linked to `batch_id`:
   - ONE `workbook_sheet` observation (ALWAYS):
     - observation_type `workbook_sheet`, status `captured`
     - source_sheet = sheetName, source_row = NULL
     - raw_data = JSON.stringify({ total_rows: rows.length, importable_rows, inserted: ids.length, duplicate_skipped: dup_skipped, parse_skipped })
     - reason = `ids.length === 0 ? 'zero execution rows inserted' : null`
   - one `imported_entry` per inserted entry: status `imported`, source_row, raw_data = JSON of data + `{entry_id}`
   - one `duplicate_skipped` per duplicate-skipped row: status `skipped`, reason `duplicate`, raw_data = JSON of data + `{duplicate_entry_id}`
   - one `skipped_row` per entry in `payloadSkipped`: status `skipped`, reason = that entry's reason, source_row = its row_number, raw_data = JSON of its data
4. Use a prepared INSERT for observations:
   `INSERT INTO import_observations (import_batch_id, source_sheet, source_row, observation_type, status, reason, raw_data) VALUES (?,?,?,?,?,?,?)`
5. Count observations inserted into `observation_count` and add it to the JSON response.
6. Preserve ALL existing response fields (ok, batch_id, inserted_count, ids,
   skipped_count, skipped, duplicate_count, duplicate_skipped_count).

Observations must NEVER be inserted into `entries`. Execution-row validation
(classifyImportRow / P2-4A) is unchanged. Duplicate detection and
allow_duplicates override are unchanged.

## Acceptance Criteria
- [ ] import_observations table exists after server boot (PRAGMA/SELECT)
- [ ] Table has columns: id, import_batch_id, source_sheet, source_row, observation_type, status, reason, raw_data, created_at
- [ ] Preview skipped_rows entries include raw data
- [ ] Preview summary includes observed_sheet_count and observation_count
- [ ] Preview writes zero observations (count unchanged after preview)
- [ ] Normal commit inserts entries AND observations linked to batch_id
- [ ] Commit always inserts exactly one workbook_sheet observation
- [ ] Commit response includes observation_count
- [ ] Duplicate-only commit (inserted_count=0) still inserts batch + observations
- [ ] workbook_sheet observation reason = 'zero execution rows inserted' when inserted_count=0
- [ ] No observation row appears in entries
- [ ] node --check app/db.js exits 0
- [ ] node --check app/server.js exits 0

## Files Likely Affected
- app/db.js
- app/server.js

## Blocked By
- none
