# Recon: P3-3 Duplicate Detection

Feature Slug: phase-3-duplicate-detection
Date: 2026-06-12
Mode: Read-only. No app code modified.
Upstream recon: ai/recon/phase-3-import-batch-ledger-recon.md (P3-1), ai/recon/phase-3-delete-import-batch-recon.md (P3-2)

---

## 1. Environment

| Check | Result |
|---|---|
| OS mode | OS-ENABLED |
| Adapter | 12/12 PASS |
| Invariants | 5/5 PASS |
| Branch | main |
| Working tree | Clean (commit a206575) |
| Feature state | RECON_READY (initialized on entry) |
| P3-1 state | RELEASE_APPROVED |
| P3-2 state | RELEASE_APPROVED |

---

## 2. Database State (post-P3-2)

### Tables

```
users, sqlite_sequence, sessions, entries, imports
```

### entries schema (21 columns — P3-1 added 3 import columns)

```
id              INTEGER PRIMARY KEY AUTOINCREMENT
type            TEXT NOT NULL DEFAULT 'experiment' CHECK(...)
title           TEXT NOT NULL
owner           TEXT (nullable)
track           TEXT (nullable)
function_area, parent_item, hypothesis, design, success_criteria,
target_end_date, dependencies, outcome, next_action
status          TEXT NOT NULL DEFAULT 'Not Started' CHECK(...)
created_at, updated_at TEXT NOT NULL DEFAULT datetime('now')
created_by, updated_by TEXT (nullable)
import_batch_id INTEGER DEFAULT NULL   ← P3-1
import_source_sheet TEXT DEFAULT NULL  ← P3-1
import_source_row INTEGER DEFAULT NULL ← P3-1
```

### imports schema (P3-1)

```
id INTEGER PRIMARY KEY AUTOINCREMENT
filename TEXT NOT NULL
imported_by TEXT NOT NULL
imported_at TEXT DEFAULT datetime('now') NOT NULL
total_rows, importable_rows, skipped_rows, warning_count INTEGER
status TEXT DEFAULT 'complete' NOT NULL
```

### Data state

| Metric | Value |
|---|---|
| Total entries | 65 |
| With import_batch_id NOT NULL | 0 (DB cleaned after P3-2 testing) |
| With import_batch_id NULL (manual) | 65 |
| Active import batches | 0 |

---

## 3. Current Import Routes (server.js)

### POST /api/import/preview (lines 412–436)

1. Admin-only (canImport check)
2. Accepts: `{ filename, content_base64 }`
3. Parses workbook via parseImportWorkbook()
4. Classifies each row via classifyImportRow()
5. Returns:
   ```json
   {
     "summary": { "sheet", "total_rows", "importable_rows", "skipped_rows", "warning_count" },
     "rows": [{ "row_number", "warnings", "data" }],
     "skipped_rows": [{ "row_number", "reason" }]
   }
   ```
6. **Writes nothing.** Pure read + classify.

### POST /api/import/commit (lines 439–480)

1. Admin-only
2. Accepts: `{ filename, sheet, rows: [{ data, row_number }] }`
3. Re-classifies each row server-side
4. Creates imports record BEFORE insert loop
5. Inserts importable rows with import_batch_id, import_source_sheet, import_source_row
6. Returns:
   ```json
   { "ok", "batch_id", "inserted_count", "ids", "skipped_count", "skipped" }
   ```

---

## 4. Duplicate Risk Analysis

**Re-importing the same workbook today inserts all rows again as new entries** — no detection exists. With 65 NULL rows and a first import of N rows, a second import of the same workbook would create N duplicate entries.

Two layers of detection are needed:

### Layer 1: Source-position match

If a committed row has `import_source_sheet` + `import_source_row`, query:
```sql
SELECT id FROM entries
WHERE import_source_sheet = ? AND import_source_row = ?
LIMIT 1
```
This catches re-importing the same workbook where row positions have not shifted.

**Available data:** `import_source_sheet` and `import_source_row` are set on every committed row (P3-1). The preview route already provides `row_number` per row, and `sheet` is returned in the summary. The commit payload includes `sheet`.

### Layer 2: Logical match

Normalize title + owner + track:
- trim whitespace
- collapse repeated internal spaces
- compare case-insensitively
- treat null/empty consistently (null → empty string)

Query:
```sql
SELECT id FROM entries
WHERE lower(trim(title)) = ?
  AND lower(trim(coalesce(owner,''))) = ?
  AND lower(trim(coalesce(track,''))) = ?
LIMIT 1
```

This catches duplicates even when workbook row positions shifted or import_source_row is absent.

### Decision: Both layers run for every importable row

Source-position match is fast (indexed INTEGER columns). Logical match adds a small full-scan cost, acceptable for import-time latency. Running both provides highest confidence and best `duplicate_reason` reporting.

---

## 5. Preview Behavior Plan

For each importable row in the preview, after classifyImportRow():
- Run `findDuplicateForImportRow(classifiedData, sheetName, rowNumber)`
- Add duplicate metadata to the preview row:
  ```json
  {
    "duplicate": true,
    "duplicate_reason": "source_row_match" | "logical_match" | "source_and_logical_match",
    "duplicate_entry_id": 123
  }
  ```
- Add `duplicate_count` to the preview summary
- Preview still writes nothing

For first-time imports (no existing imported rows), all rows will have `duplicate: false`. Impact is minimal.

**Sheet name for preview:** The workbook is re-parsed during preview, so `parsed.sheet` is available.

---

## 6. Commit Behavior Plan

1. Re-classify rows (existing behavior)
2. Re-run duplicate detection server-side (not trusting frontend)
3. Default: skip duplicate rows — add to `skipped` array with reason `'duplicate'`
4. If `allow_duplicates: true` in payload: insert duplicates normally
5. Track `duplicate_count` and `duplicate_skipped_count` in response
6. Update batch counts to reflect actual outcome:
   - `skipped_rows` = parse skips + duplicate skips (when allow_duplicates=false)
7. Even if all rows are duplicates → still create batch record (preserves history)

---

## 7. Helper Functions Plan

Add to server.js, near classifyImportRow:

```javascript
function normalizeDupValue(v) {
  if (v == null || v === '') return '';
  return String(v).trim().replace(/\s+/g, ' ').toLowerCase();
}

function buildLogicalDupKey(data) {
  return [
    normalizeDupValue(data.title),
    normalizeDupValue(data.owner),
    normalizeDupValue(data.track)
  ].join('|');
}

function findDuplicateForImportRow(data, sourceSheet, sourceRow) {
  // Layer 1: source-position match
  if (sourceSheet && sourceRow) {
    const byPos = db.prepare(
      'SELECT id FROM entries WHERE import_source_sheet = ? AND import_source_row = ? LIMIT 1'
    ).get(sourceSheet, sourceRow);
    if (byPos) {
      // Check if logical also matches for richer reason
      const titleNorm = normalizeDupValue(data.title);
      const ownerNorm = normalizeDupValue(data.owner || '');
      const trackNorm = normalizeDupValue(data.track || '');
      const byLogic = db.prepare(
        'SELECT id FROM entries WHERE lower(trim(title))=? AND lower(trim(coalesce(owner,"")))=? AND lower(trim(coalesce(track,"")))=? LIMIT 1'
      ).get(titleNorm, ownerNorm, trackNorm);
      return {
        duplicate: true,
        duplicate_reason: byLogic ? 'source_and_logical_match' : 'source_row_match',
        duplicate_entry_id: byPos.id
      };
    }
  }
  // Layer 2: logical match
  const titleNorm = normalizeDupValue(data.title);
  const ownerNorm = normalizeDupValue(data.owner || '');
  const trackNorm = normalizeDupValue(data.track || '');
  const byLogic = db.prepare(
    'SELECT id FROM entries WHERE lower(trim(title))=? AND lower(trim(coalesce(owner,"")))=? AND lower(trim(coalesce(track,"")))=? LIMIT 1'
  ).get(titleNorm, ownerNorm, trackNorm);
  if (byLogic) {
    return { duplicate: true, duplicate_reason: 'logical_match', duplicate_entry_id: byLogic.id };
  }
  return { duplicate: false };
}
```

No schema changes. No new DB migration. No new routes.

---

## 8. Frontend UX Plan

### Preview panel changes

1. Add `duplicate_count` to preview summary line
2. Add per-row duplicate indicator badge: `<span class="badge warn">Duplicate</span>`
3. Show `duplicate_reason` as tooltip or short text if useful

### Commit UX changes

1. Add `allow_duplicates` checkbox below commit button (shown only when `duplicate_count > 0`)
2. Checkbox label: "Import duplicates anyway"
3. Commit payload adds `allow_duplicates: true | false`
4. After commit: show inserted + skipped + duplicate_skipped in the alert

### State additions

```javascript
state.allowDuplicates = false; // reset on each preview
```

---

## 9. Safety Notes

- **Non-destructive by design:** duplicate detection reads existing entries — never writes or deletes
- **No unique constraints added:** avoids blocking legitimate re-imports with explicit override
- **No schema migration needed:** all required columns exist from P3-1
- **NULL import_batch_id rows:** logical match still works — manual rows can also be logical duplicates
- **allow_duplicates=true path:** if admin explicitly overrides, all rows import with full batch metadata
- **Batch creation when all rows are duplicates:** batch still created; history preserved for P3-4 future capture

---

## 10. P3-4 and P3-5 Dependency Status

| Future feature | Status | Dependency on P3-3 |
|---|---|---|
| P3-4 True Workbook Capture | Not implemented | import_observations table (not created by P3-3) |
| P3-5 Import Provenance Expansion | Not implemented | Modal provenance display (not added by P3-3) |

P3-3 does NOT create import_observations. P3-3 does NOT add provenance modal UI. P3-3 does NOT change table/dashboard behavior.

---

## 11. Files to Modify

| File | Change |
|---|---|
| app/server.js | Add helpers; update /api/import/preview; update /api/import/commit |
| app/public/app.js | Update renderImportPanel(); update bindImportActions(); update commit payload |
| app/public/style.css | Add .badge.warn style if needed |
| app/README.md | Add Duplicate Detection section |
| ai/recon/phase-3-duplicate-detection-recon.md | This document |
| specs/phase-3-duplicate-detection.md | New spec |
| tasks/phase-3-duplicate-detection-001..004.md | New tasks |
| ai/state_registry.json | Feature state transitions |
| ai/engineering-journal.md | Journal entry |

**Do NOT modify:** app/db.js, app/public/index.html, app/package.json, vendor/, prototypes/, sdlc/, source-materials/

---

## 12. Conflict Assessment

No conflicts detected. P3-1 and P3-2 are RELEASE_APPROVED. P3-3 builds cleanly on existing schema and routes.
