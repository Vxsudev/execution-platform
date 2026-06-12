# Task: Update import commit route and add GET /api/imports

## Parent Spec
specs/phase-3-import-batch-ledger.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Update `POST /api/import/commit` and add `GET /api/imports` in `app/server.js`.

### POST /api/import/commit changes

Current body: `{ rows: [<flat data objects>] }`
New body: `{ filename, sheet, rows: [{ data: <flat data object>, row_number: <int> }] }`

Steps:
1. Extract and validate `filename` — must be a non-empty string ending in `.xlsx`; return 400 if missing/invalid.
2. Extract `sheet` — string, may be empty string (use empty string as fallback).
3. Extract `rows` array — same validation as before (must be Array).
4. Pre-classify all rows to count importable_rows, skipped_rows, warning_count (for the batch record). Use the existing `classifyImportRow` function on `row.data` for each element.
5. INSERT INTO imports with: filename, imported_by = req.user.username, total_rows = rows.length, importable_rows, skipped_rows, warning_count, status = 'complete'. Get `batch_id` from `info.lastInsertRowid`.
6. For each importable row: call `classifyImportRow(row.data || row)`, build the entry via `toImportRow`, set:
   - `row.created_by = req.user.username`
   - `row.updated_by = req.user.username`
   - `row.import_batch_id = batch_id`
   - `row.import_source_sheet = sheet`
   - `row.import_source_row = typeof row_item.row_number === 'number' ? row_item.row_number : null`
7. Use try/catch per-row INSERT as before.
8. Return `{ ok: true, batch_id, inserted_count: ids.length, ids, skipped_count: skipped.length, skipped }`.

Important: The outer loop must destructure `{ data, row_number }` from each element in `rows`. The existing `classifyImportRow` is called with `data` (not the wrapper object). Keep all existing open-mode rules unchanged.

### GET /api/imports (new route)

Add after the existing POST /api/import/commit route:

```javascript
app.get('/api/imports', requireAuth, (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const imports = db.prepare(
    'SELECT id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status FROM imports ORDER BY id DESC'
  ).all();
  res.json({ imports });
});
```

## Acceptance Criteria
- [ ] POST /api/import/commit with `{ filename, sheet, rows: [{data, row_number}] }` succeeds for admin
- [ ] Response from commit includes `batch_id`
- [ ] One row inserted in `imports` per commit call
- [ ] Imported entries have `import_batch_id` set to the batch id
- [ ] Imported entries have `import_source_sheet` set to the sheet value from the body
- [ ] Imported entries have `import_source_row` set to `row_number` from each row object
- [ ] POST /api/import/commit with missing `filename` → 400
- [ ] POST /api/import/commit without auth → 401
- [ ] POST /api/import/commit as non-admin → 403
- [ ] GET /api/imports as admin → 200 with `imports` array
- [ ] GET /api/imports as non-admin → 403
- [ ] GET /api/imports without auth → 401
- [ ] GET /api/imports returns newest first
- [ ] Open-mode classification (title gate, coercion rules) unchanged
- [ ] POST /api/import/preview still returns 200 without DB writes

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-3-import-batch-ledger-001.md
