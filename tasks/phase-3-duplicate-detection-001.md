# Task: Add duplicate detection helpers and update import preview route

## Parent Spec
specs/phase-3-duplicate-detection.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Add three internal helper functions to `app/server.js` for duplicate detection
and update `POST /api/import/preview` to run duplicate checks on each importable
row, reporting results in the preview response.

### Helpers to add (near classifyImportRow, around line 402)

```javascript
function normalizeDupValue(v) {
  if (v == null || v === '') return '';
  return String(v).trim().replace(/\s+/g, ' ').toLowerCase();
}

function buildLogicalDupKey(data) {
  return [normalizeDupValue(data.title), normalizeDupValue(data.owner), normalizeDupValue(data.track)].join('|');
}

function findDuplicateForImportRow(data, sourceSheet, sourceRow) {
  if (sourceSheet && sourceRow) {
    const byPos = db.prepare(
      'SELECT id FROM entries WHERE import_source_sheet = ? AND import_source_row = ? LIMIT 1'
    ).get(sourceSheet, sourceRow);
    if (byPos) {
      const byLogic = db.prepare(
        'SELECT id FROM entries WHERE lower(trim(title))=? AND lower(trim(coalesce(owner,"")))=? AND lower(trim(coalesce(track,"")))=? LIMIT 1'
      ).get(normalizeDupValue(data.title), normalizeDupValue(data.owner || ''), normalizeDupValue(data.track || ''));
      return {
        duplicate: true,
        duplicate_reason: byLogic ? 'source_and_logical_match' : 'source_row_match',
        duplicate_entry_id: byPos.id
      };
    }
  }
  const byLogic = db.prepare(
    'SELECT id FROM entries WHERE lower(trim(title))=? AND lower(trim(coalesce(owner,"")))=? AND lower(trim(coalesce(track,"")))=? LIMIT 1'
  ).get(normalizeDupValue(data.title), normalizeDupValue(data.owner || ''), normalizeDupValue(data.track || ''));
  if (byLogic) {
    return { duplicate: true, duplicate_reason: 'logical_match', duplicate_entry_id: byLogic.id };
  }
  return { duplicate: false };
}
```

### Preview route changes (around line 412)

After `classifyImportRow` succeeds for each row:
1. Call `findDuplicateForImportRow(c.data, parsed.sheet, row_number)`
2. Attach `duplicate`, `duplicate_reason`, `duplicate_entry_id` to each preview row
3. Track `duplicate_count` across all importable rows
4. Add `duplicate_count` to the `summary` object

New preview response shape:
```json
{
  "summary": { "sheet", "total_rows", "importable_rows", "skipped_rows", "warning_count", "duplicate_count" },
  "rows": [{ "row_number", "warnings", "data", "duplicate", "duplicate_reason", "duplicate_entry_id" }],
  "skipped_rows": [...]
}
```

Do NOT change classifyImportRow, parseImportWorkbook, the admin-only gate, or
any other route behavior.

## Acceptance Criteria
- [ ] normalizeDupValue() trims, collapses spaces, lowercases
- [ ] findDuplicateForImportRow() returns { duplicate: false } for new rows
- [ ] findDuplicateForImportRow() returns { duplicate: true, duplicate_reason, duplicate_entry_id } for existing rows
- [ ] GET /api/import/preview response includes duplicate_count in summary
- [ ] GET /api/import/preview response rows include duplicate, duplicate_reason, duplicate_entry_id fields
- [ ] duplicate_count = 0 for first-time import of new workbook
- [ ] duplicate_count > 0 for re-import of same workbook
- [ ] No write to DB during preview
- [ ] node --check app/server.js exits 0

## Files Likely Affected
- app/server.js

## Blocked By
- none
