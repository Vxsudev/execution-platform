# Task: Add evidence-based legacy orphan recovery to import batch delete

## Parent Spec
specs/import-batch-delete-integrity-fix.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Extend `DELETE /api/imports/:id` in `app/server.js` (currently lines 576-593) so deleting a
batch also removes **legacy orphaned** imported rows — entries created by an older code version
that recorded batch-linked `imported_entry` observations but did NOT stamp `import_batch_id` on
the entries. Recovery is batch-scoped and evidence-based only.

Within the existing `BEGIN`/`COMMIT` transaction, in this order:
1. `SELECT raw_data FROM import_observations WHERE import_batch_id = :id AND observation_type =
   'imported_entry'`; parse each `raw_data` JSON; collect positive-integer `entry_id` values
   (skip null/unparseable raw_data and non-integer ids).
2. `DELETE FROM entries WHERE import_batch_id = :id` → linked-row count.
3. If any collected ids: `DELETE FROM entries WHERE id IN (<ids>)` → legacy count. (Current
   imports' rows were already removed in step 2, so they are not double-counted.)
4. `DELETE FROM import_observations WHERE import_batch_id = :id`.
5. `DELETE FROM imports WHERE id = :id`.

Response: keep `ok`, `deleted_observation_count`, `deleted_import_id`; set `deleted_entry_count`
= linked + legacy (accurate total); add `deleted_legacy_count` (transparency; UI ignores it).

Constraints: batch-scoped only; evidence-based only (entry_id recorded by THIS batch); no
heuristic matching; no global orphan sweep; no backfill. Manual rows (no `import_batch_id`,
never named in observations) untouched. Keep admin-only (`canImport`), 400/404 guards, and the
transactional ROLLBACK-on-error. Do NOT change import preview/commit, `app/db.js`, schema, or
any other route.

## Acceptance Criteria
- [ ] Delete collects `entry_id` from the batch's `imported_entry` observations' `raw_data`
- [ ] Entries with `import_batch_id = :id` are deleted (current linked rows)
- [ ] Legacy entries (NULL `import_batch_id`) whose ids are named by the batch's observations are deleted
- [ ] `deleted_entry_count` = total entries removed (linked + legacy); `deleted_legacy_count` added
- [ ] Observations for the batch and the ledger row are deleted
- [ ] Manual rows and other batches' rows are untouched; no double counting for current imports
- [ ] Route remains admin-only; 400/404 guards and transactional rollback intact
- [ ] Null/unparseable `raw_data` and non-integer `entry_id` handled defensively
- [ ] `node --check app/server.js` passes; no change to import preview/commit, db.js, schema

## Files Likely Affected
- app/server.js (DELETE /api/imports/:id)

## Blocked By
- none
