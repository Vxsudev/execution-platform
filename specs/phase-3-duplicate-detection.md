---
Layer: L5-Build
Status: approved
Upstream: specs/phase-3-import-batch-ledger.md, specs/phase-3-delete-import-batch.md
Downstream: specs/phase-3-true-workbook-capture.md (planned)
---

# Spec: P3-3 Duplicate Detection

Feature Slug: phase-3-duplicate-detection
Version: 1.0.0

## Status
approved

## Phase
phase-build

---

## Purpose

Add layered duplicate detection to the XLSX import preview and commit flow.
Re-importing the same workbook or re-importing the same logical rows must not
silently inflate the execution table. Detection uses P3-1 source metadata
(import_source_sheet, import_source_row) where available, and falls back to
logical matching on normalized title + owner + track. Admin may explicitly
override the default skip behavior with allow_duplicates=true.

---

## Dependencies

- P3-1 (phase-3-import-batch-ledger): RELEASE_APPROVED — provides imports table,
  import_batch_id, import_source_sheet, import_source_row in entries
- P3-2 (phase-3-delete-import-batch): RELEASE_APPROVED — delete route preserved
  and tested

---

## Duplicate Matching Strategy

### Layer 1 — Source-position match

Detect existing entries where:
  import_source_sheet = incoming source_sheet
  import_source_row = incoming source_row

Catches re-importing the same workbook at the same row position.

### Layer 2 — Logical match

Detect existing entries where normalized fields match:
  lower(trim(title)) = normalize(incoming.title)
  lower(trim(coalesce(owner,''))) = normalize(incoming.owner)
  lower(trim(coalesce(track,''))) = normalize(incoming.track)

Normalization: trim whitespace, collapse internal spaces, lowercase.

Catches duplicates even when source row metadata is absent or row positions shifted.

### Match priority

Source-position is checked first. If source-position matches and logical also
matches, reason = source_and_logical_match. If only source, reason =
source_row_match. If only logical, reason = logical_match.

### Per-row duplicate metadata

```json
{
  "duplicate": true,
  "duplicate_reason": "source_row_match | logical_match | source_and_logical_match",
  "duplicate_entry_id": 123
}
```

---

## Backend: Preview Route

Route: POST /api/import/preview (existing route, updated behavior)

Changes:
1. After classifyImportRow() for each importable row, run findDuplicateForImportRow()
2. Attach duplicate metadata to each row in the response
3. Add duplicate_count to summary

Response shape (additions in bold):
```json
{
  "summary": {
    "sheet": "...",
    "total_rows": N,
    "importable_rows": N,
    "skipped_rows": N,
    "warning_count": N,
    "duplicate_count": N
  },
  "rows": [{
    "row_number": N,
    "warnings": [],
    "data": {},
    "duplicate": false,
    "duplicate_reason": null,
    "duplicate_entry_id": null
  }],
  "skipped_rows": [...]
}
```

---

## Backend: Commit Route

Route: POST /api/import/commit (existing route, updated behavior)

New payload field:
- allow_duplicates: boolean (default false)

Behavior:
1. Re-classify each row (existing behavior preserved)
2. Re-run duplicate detection server-side (no client trust)
3. Default (allow_duplicates=false): skip duplicate rows
   - Add to skipped array with reason 'duplicate'
4. Override (allow_duplicates=true): import all rows including duplicates
5. Batch record created regardless of outcome (preserves attempt history)
6. Batch counts:
   - total_rows = rows in commit payload
   - importable_rows = rows passing classifyImportRow
   - skipped_rows = parse-failed rows + duplicate-skipped rows
   - warning_count = existing warning count

Response shape (additions):
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

---

## Backend: Helper Functions

Add to server.js near classifyImportRow:

- normalizeDupValue(v): trim, collapse spaces, lowercase
- buildLogicalDupKey(data): composite key string for debugging
- findDuplicateForImportRow(data, sourceSheet, sourceRow): returns duplicate
  metadata object; queries DB with two-layer strategy

No new routes. No schema changes. No db.js modifications.

---

## Frontend: Preview Panel

Additions to renderImportPanel():
1. Summary line includes: "N duplicate(s) found" if duplicate_count > 0
2. Per-row in importable preview table: show Duplicate badge if row.duplicate

---

## Frontend: Commit UX

1. Add allow_duplicates checkbox in import controls area
   - Only visible when preview has duplicate_count > 0
   - Label: "Import duplicates anyway"
   - Default unchecked
2. Commit payload includes allow_duplicates boolean
3. Post-commit alert shows: "Imported N row(s), M duplicate(s) skipped" etc.
4. state.allowDuplicates resets to false on each new preview

---

## Permission Model

No changes to permission model.
- Admin-only import: preserved
- Vasu/anonymous: still 403/401

---

## Architecture Contracts (P3-3 scope)

MUST NOT:
- Delete or modify existing rows
- Create import_observations table
- Add provenance modal
- Alter dashboard behavior
- Alter table row click / cell reveal behavior
- Add DB unique constraints
- Weaken admin-only import management
- Weaken row CRUD permissions
- Change db.js
- Change index.html

MUST:
- Preserve P2-4A open import mode (classifyImportRow unchanged)
- Preserve P3-1 batch ledger behavior
- Preserve P3-2 delete batch behavior
- Preserve all existing permission checks

---

## Verification Plan

1. node --check app/server.js → 0
2. node --check app/public/app.js → 0
3. Smoke: app boots, admin login works
4. First preview of workbook → duplicate_count = 0
5. First commit → batch created, rows inserted, no duplicate_skipped_count > 0
6. Second preview of same workbook → duplicate_count > 0, rows marked duplicate
7. Second commit (allow_duplicates=false) → duplicates skipped, duplicate_skipped_count > 0
8. Second commit (allow_duplicates=true) → duplicates imported, rows get batch metadata
9. Batch created even when all rows duplicate
10. GET /api/imports still works
11. DELETE /api/imports/:id still works
12. Manual rows remain import_batch_id = NULL
13. Vasu → 403 on import routes
14. Anonymous → 401 on import routes
15. Invariants 5/5 PASS
16. No [FILL:] residue

---

## Non-Scope

- P3-4: True workbook capture / import_observations table
- P3-5: Import provenance expansion in row modal
- P3-6: Dense cell reveal
- P3-7: Row/cell click interaction
- P3-8: Dashboard relevance
- P3-9: Review checkpoint
