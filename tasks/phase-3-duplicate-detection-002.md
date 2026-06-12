# Task: Update import commit route with duplicate skip/override behavior

## Parent Spec
specs/phase-3-duplicate-detection.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Update `POST /api/import/commit` in `app/server.js` to re-check duplicates
server-side and default to skipping them. Add `allow_duplicates` payload flag
for explicit admin override. Track duplicate counts in the batch record and
response.

### Commit route changes (around line 439)

1. Extract `allow_duplicates` from request body (default false):
   ```javascript
   const allow_duplicates = req.body.allow_duplicates === true;
   ```

2. After re-classifying each row, run `findDuplicateForImportRow()` server-side.

3. Track `duplicate_count` and `duplicate_skipped_count` across all rows.

4. If `allow_duplicates === false` AND row is a duplicate: add to `skipped` array
   with reason `'duplicate'`, increment skipped counters — do NOT insert.

5. If `allow_duplicates === true`: insert all importable rows regardless of duplicate status.

6. Update the `imports` batch INSERT to use updated `skipped_rows` count:
   - skipped_rows = parse-failed rows + duplicate-skipped rows

7. Return updated response:
   ```json
   {
     "ok": true,
     "batch_id": N,
     "inserted_count": N,
     "ids": [...],
     "skipped_count": N,
     "skipped": [...],
     "duplicate_count": N,
     "duplicate_skipped_count": N
   }
   ```

8. Batch record is ALWAYS created, even if inserted_count = 0 (all rows were duplicates).
   This preserves attempt history for future P3-4 capture.

### Important: batch count accuracy

The imports INSERT currently happens before the insert loop. Move or update the
count to reflect the final outcome:

- `total_rows` = rows.length (payload rows)
- `importable_rows` = rows that pass classifyImportRow (before dup check)
- `skipped_rows` = parse-skipped + duplicate-skipped (when allow_duplicates=false)
- `warning_count` = total warnings from classifiable rows

Implementation note: do a two-pass approach:
1. First pass: classify all rows, run dup detection, compute all counts
2. INSERT imports batch with correct counts
3. Second pass: insert non-skipped rows (or all importable if allow_duplicates=true)

Do NOT change the admin-only gate, classifyImportRow, parseImportWorkbook,
the GET /api/imports route, or the DELETE /api/imports/:id route.

## Acceptance Criteria
- [ ] allow_duplicates=false (default): duplicate rows are skipped, added to skipped array with reason 'duplicate'
- [ ] allow_duplicates=true: duplicate rows are inserted normally with import_batch_id/source metadata
- [ ] Response includes duplicate_count and duplicate_skipped_count
- [ ] Batch record created even when inserted_count = 0
- [ ] imports.skipped_rows reflects parse + duplicate skips when allow_duplicates=false
- [ ] Non-duplicate rows still get import_batch_id, import_source_sheet, import_source_row
- [ ] Vasu → 403, anon → 401 unchanged
- [ ] node --check app/server.js exits 0

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-3-duplicate-detection-001.md
