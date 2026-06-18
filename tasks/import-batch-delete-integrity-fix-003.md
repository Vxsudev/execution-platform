# Task: Verify legacy + current batch delete on disposable DBs

## Parent Spec
specs/import-batch-delete-integrity-fix.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the fix on disposable DBs only; live `app/data.db` is never mutated.

Checks (in-session worker):
1. `node --check app/server.js`, `app/db.js`, `app/public/app.js`
2. `cd app && npm run` → start = `node server.js`
3. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` byte-for-byte unchanged
4. **Legacy case (disposable DB):** import a batch (entries linked + `imported_entry`
   observations carry `entry_id`); add a manual row via API; simulate legacy by
   `UPDATE entries SET import_batch_id = NULL` for that batch; DELETE the batch →
   the orphaned entries are removed (via observation `entry_id`), the manual row remains,
   `deleted_entry_count`/`deleted_legacy_count`/`deleted_observation_count` accurate, ledger gone.
5. **Current case (disposable DB):** normal import → DELETE removes linked entries +
   observations + ledger; `deleted_legacy_count` = 0 (no double counting); manual row remains.
6. Unauthenticated DELETE → 401; non-admin DELETE → 403.
7. `bash scripts/invariant-check.sh` → 5/5 PASS
8. `git status` → only allowed surfaces

## Acceptance Criteria
- [x] `node --check` passes on server.js, db.js, public/app.js
- [x] Dev boot smoke prints running line; live `app/data.db` byte-for-byte unchanged
- [x] Legacy case: 3 orphaned entries (NULL batch) named by observations deleted (`deleted_legacy_count=3`, `deleted_entry_count=3`); manual row remains; ledger gone; counts accurate
- [x] Current case: 2 linked entries + observations + ledger deleted; `deleted_legacy_count=0` (no double count); manual row remains
- [x] Unauthenticated DELETE → 401; non-admin (viewer) DELETE → 403
- [x] `app/public/*`, `app/db.js`, schema, package/config/Railway docs unchanged (diff = app/server.js only, plus OS artifacts)
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`
- [x] Verification harness: 13/13 assertions passed

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/import-batch-delete-integrity-fix-002.md
