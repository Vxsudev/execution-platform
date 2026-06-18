# Spec: Import Batch Delete Integrity Fix

## Status
approved

## Phase
phase-build

## Feature Slug
import-batch-delete-integrity-fix

## Depends On
Recon: ai/recon/import-batch-delete-integrity-fix-recon.md. Builds on the import ledger / observation capture (P3-2..P3-4). Preserves access-control removal, row-click edit, auth/session, DB_PATH, bootstrap, Railway config.

---

## Summary

Extend `DELETE /api/imports/:id` so it also removes **legacy orphaned** imported rows — entries
created by an older code version that recorded batch-linked `imported_entry` observations but
did not stamp `import_batch_id` on the entries. Recovery is **batch-scoped and evidence-based**:
only entries whose ids are recorded in *that batch's own* `imported_entry` observation
`raw_data.entry_id` are deleted, in addition to entries with matching `import_batch_id`. No
heuristic matching, no global orphan sweep, no backfill. Manual rows and current
import/delete behavior are unchanged.

---

## Background

Recon proved (disposable-DB reproduction with the real astraX workbook) that current import
**correctly** stamps `import_batch_id` and current delete **correctly** removes linked entries
+ observations + ledger. The reported bug ("19-row batch → Delete removes 20 observations but 0
rows; rows remain") is **legacy data**: those 19 entries have `import_batch_id IS NULL`, so
`DELETE FROM entries WHERE import_batch_id = N` matches none, while the 20 batch-linked
observations are removed. The current code's `imported_entry` observations store the entry's id
in `raw_data.entry_id` (`server.js:553`), giving a precise, batch-scoped record of which entries
each batch produced — the evidence used to recover legacy orphans.

---

## Data Model Changes

none

---

## API Surface

`DELETE /api/imports/:id` (`app/server.js`) gains evidence-based legacy recovery. Within the
existing transaction, before deleting the batch's observations, collect entry ids from this
batch's `imported_entry` observations (`raw_data.entry_id`). Delete order:
1. entries where `import_batch_id = :id` (current linked rows),
2. entries whose id is in the collected observation `entry_id` set (legacy orphans; the
   `import_batch_id = :id` delete already removed any that were linked, so no double count),
3. observations where `import_batch_id = :id`,
4. ledger row where `id = :id`.

Response keeps `ok`, `deleted_observation_count`, `deleted_entry_count` (now the accurate
**total** removed = linked + legacy), `deleted_import_id`, and adds `deleted_legacy_count` for
transparency. Route stays admin-only (`canImport`), transactional, 400/404 guards unchanged. No
other route changes. Import preview, commit, and duplicate detection unchanged.

---

## Frontend Surface

none — `app/public/app.js` already displays `deleted_entry_count` + `deleted_observation_count`,
which remain accurate (the new `deleted_legacy_count` is additive and ignored by the UI).

---

## Non-Scope

- No change to import preview, import commit, or duplicate detection
- No heuristic matching; no global orphan sweep; no one-time backfill
- No `app/db.js`, schema, DB_PATH, bootstrap, auth/session, Railway config change
- No access-control or row-click edit change
- No `app/public/*`, package, or config file change
- No Docker, Postgres, deployment
- No live `app/data.db` mutation (verification uses disposable DBs only)

---

## Implementation Plan

### Task 1 — Backend: evidence-based legacy recovery in batch delete (backend)

In `app/server.js` `DELETE /api/imports/:id` (currently lines 576-593): inside the existing
`BEGIN`/`COMMIT` transaction, before deleting observations, `SELECT raw_data FROM
import_observations WHERE import_batch_id = :id AND observation_type = 'imported_entry'`, parse
each `raw_data` JSON, and collect integer `entry_id` values. After `DELETE FROM entries WHERE
import_batch_id = :id`, also `DELETE FROM entries WHERE id IN (<collected ids>)` (only if any).
Set `deleted_entry_count` = linked + legacy; add `deleted_legacy_count`. Keep observation +
ledger deletes and all guards. Manual rows (no `import_batch_id`, never named in observations)
are untouched. Defensive: skip null/unparseable `raw_data` and non-integer ids.

### Task 2 — Verification

Disposable-DB tests (live `app/data.db` never touched):
- **Legacy case:** import a batch, then `UPDATE entries SET import_batch_id = NULL` for that
  batch (simulating pre-linkage data; observations still carry `entry_id`); add a manual row;
  DELETE the batch → orphaned entries removed via observation evidence, manual row remains,
  counts accurate.
- **Current case:** normal import → DELETE removes linked entries + observations + ledger; no
  double counting; manual row remains.
- Unauthenticated DELETE → 401; non-admin DELETE → 403.
- `node --check`; dev boot smoke; invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/server.js` | Evidence-based legacy recovery in `DELETE /api/imports/:id` |
| `ai/recon/import-batch-delete-integrity-fix-recon.md` | Recon artifact |
| `specs/import-batch-delete-integrity-fix.md` | This spec |
| `tasks/import-batch-delete-integrity-fix-*.md` | OS-generated task graph |
| `ai/state_registry.json` | Lifecycle state |
| `ai/engineering-journal.md` | Journal entry |

---

## Verification Plan

See Implementation Plan Task 2. Key assertions: legacy orphan rows (NULL `import_batch_id`)
named by a batch's `imported_entry` observations are deleted with the batch; current linked
imports still delete fully; manual rows preserved; `deleted_entry_count`/`deleted_observation_count`
accurate; admin-only + auth guards intact; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — redeploy and confirm batch delete (including any
legacy batches) removes imported rows on the live deployment.
