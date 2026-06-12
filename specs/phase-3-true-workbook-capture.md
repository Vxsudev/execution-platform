---
Layer: L5-Build
Status: approved
Upstream: specs/phase-3-import-batch-ledger.md, specs/phase-3-delete-import-batch.md, specs/phase-3-duplicate-detection.md
Downstream: specs/phase-3-import-provenance.md (planned, P3-5)
---

# Spec: P3-4 True Workbook Capture

Feature Slug: phase-3-true-workbook-capture
Version: 1.0.0

## Status
approved

## Phase
phase-build

---

## Purpose

Record workbook reality for every import attempt, even when zero execution
rows are inserted. The system distinguishes **execution entries** (rows in
`entries`) from **workbook observations** (rows in a new `import_observations`
table). Skipped, duplicate, and non-executable source content is preserved
under the import batch as observations.

Operator law: **Do not treat "0 execution rows" as "0 captured workbook content."**

---

## Dependencies

- P3-1 (import-batch-ledger): RELEASE_APPROVED — imports table, entries import metadata
- P3-2 (delete-import-batch): RELEASE_APPROVED — transactional delete route
- P3-3 (duplicate-detection): RELEASE_APPROVED — preview/commit duplicate metadata + allow_duplicates

---

## Execution Row vs Observation Distinction

- **Execution rows** = rows inserted into `entries`. Only importable,
  non-duplicate (or override) rows passing P2-4A classification become entries.
  They carry `import_batch_id`, `import_source_sheet`, `import_source_row`.
- **Observations** = audit records of workbook reality in `import_observations`,
  linked by `import_batch_id`. Observations are NEVER entries and never
  participate in execution-table queries, dashboard, or row CRUD.

Validation for execution rows is UNCHANGED from P2-4A. Observations do not relax it.

---

## Observation Schema

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

Flexible TEXT (no CHECK) for observation_type/status to avoid breaking future
capture cases. Added to `app/db.js` via the idempotent `CREATE TABLE IF NOT
EXISTS` pattern. No ALTER on existing tables. No backfill.

observation_type values emitted by P3-4 commit:
- `workbook_sheet` (status `captured`) — one per commit; raw_data = summary counts
- `imported_entry` (status `imported`) — one per inserted entry
- `duplicate_skipped` (status `skipped`, reason `duplicate`) — one per duplicate-skipped row
- `skipped_row` (status `skipped`, reason from classifier) — one per parse-skipped row received

Reserved for future capture (not all emitted now): `malformed_row`, `empty_row`,
`non_executable_sheet`, `header_candidate`.

---

## Backend: Preview Behavior

Route: POST /api/import/preview (updated, still NON-WRITING)

1. Each `skipped_rows` entry now includes raw `data` (so the frontend can
   forward it to commit for observation capture).
2. Summary adds projected capture counts (estimates, no DB writes):
   - `observed_sheet_count` — 1 when a sheet resolved
   - `observation_count` — projection = importable_rows + skipped_rows + 1 (sheet)
3. All existing fields preserved: sheet, total_rows, importable_rows,
   skipped_rows, warning_count, duplicate_count.
4. No observation DB writes in preview.

---

## Backend: Commit Behavior

Route: POST /api/import/commit (updated)

1. Admin-only — unchanged.
2. Revalidation (classifyImportRow) — unchanged.
3. Duplicate detection + allow_duplicates override — unchanged.
4. Batch ledger creation — unchanged semantics.
5. Execution rows still insert into `entries` exactly as P3-3.
6. Accept optional `skipped_rows` array in payload (each `{row_number, reason,
   data}`); defaults to `[]`. Backward compatible.
7. After the entry-insert loop, insert observations linked to `batch_id`:
   - one `workbook_sheet` observation (ALWAYS), raw_data = `{total_rows,
     importable_rows, inserted, duplicate_skipped, parse_skipped}`; reason =
     `'zero execution rows inserted'` when inserted_count === 0
   - one `imported_entry` per inserted entry (source_row, raw_data incl. entry id)
   - one `duplicate_skipped` per duplicate-skipped row (reason `duplicate`)
   - one `skipped_row` per parse-skipped row received (reason from classifier)
8. If all rows skipped/duplicate: imports row + observations created, zero entries.
9. Response adds `observation_count`. Existing fields preserved.

Observations must never become entries. P2-4A execution validation is not relaxed.

---

## Backend: Delete Cascade

Route: DELETE /api/imports/:id (updated)

Inside the existing BEGIN/COMMIT transaction, before deleting entries:
`DELETE FROM import_observations WHERE import_batch_id = ?`.

Response adds `deleted_observation_count`. Manual rows (import_batch_id NULL)
and other batches untouched.

---

## Backend: Import History

Route: GET /api/imports (updated)

Add `observation_count` via correlated subquery
`(SELECT COUNT(*) FROM import_observations o WHERE o.import_batch_id = imports.id)`.

---

## Frontend (Import panel only)

- Preview summary: show observed sheets + projected observation count.
- Commit alert: append observations-captured count + batch id.
- Import History table: add Observations column from `observation_count`.
- Commit payload: send `skipped_rows: state.importPreview.skipped_rows`.
- Delete success alert: append `deleted_observation_count` when returned.
- P3-2 delete UI and P3-3 duplicate UI preserved.
- NO provenance modal, NO table UX, NO dashboard changes.

---

## Permission Model

Unchanged. Admin-only import preview/commit/delete. Vasu → 403. Anon → 401.
Row CRUD permissions unchanged.

---

## Architecture Contracts (P3-4)

MUST:
- Distinguish execution rows from observations
- Preserve entries as execution rows only
- Preserve P2-4A open import mode for importable rows
- Preserve P3-1 ledger, P3-2 delete, P3-3 duplicate behavior
- Keep SQLite source of truth; existing rows/batches valid
- Manual rows remain import_batch_id NULL
- Imported execution rows still carry import_batch_id/source metadata
- Observations attach to import_batch_id
- Zero-insert commit still creates batch + observations

MUST NOT:
- Insert malformed/non-executable rows into entries
- Turn observations into entries
- Relax executable validation beyond P2-4A
- Implement P3-5 provenance modal, dense cell reveal, row/cell click, dashboard relevance
- Weaken admin-only import management or row CRUD permissions
- Modify forbidden surfaces (index.html, package.json, package-lock.json, prototypes, sdlc, source-materials, vendor)

---

## Verification Plan

1. node --check app/server.js, app/db.js, app/public/app.js → 0
2. bash scripts/invariant-check.sh → 5/5 PASS (verification/004 absent; closest wrapper)
3. Live smoke on disposable DB copy:
   - import_observations table exists
   - preview writes no observations
   - normal commit → imports row + entries + observations; response has observation_count
   - duplicate-only commit → batch + observations, inserted_count = 0
   - blank-title skipped rows → skipped_row observations
   - DELETE cascades observations + entries + imports row; returns deleted_observation_count
   - manual rows untouched; other batches untouched
   - Vasu 403; anon 401
   - allow_duplicates still works; GET /api/imports includes observation_count
4. Regression: messy-row preview, P2-4A warnings, duplicate default-skip/override, delete batch, manual create, RBAC, dashboard render, user management.

---

## Non-Scope

- P3-5: import provenance in row details modal
- P3-6: dense cell reveal
- P3-7: row/cell click interaction
- P3-8: dashboard relevance
- P3-9: review checkpoint
