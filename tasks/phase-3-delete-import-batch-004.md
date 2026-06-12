# Task: Verify P3-2 smoke tests, update README, confirm RELEASE_APPROVED

## Parent Spec
specs/phase-3-delete-import-batch.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run all verification and smoke tests for P3-2. Update README. DO NOT modify ai/engineering-journal.md — supervisor owns it.

### Verification checks

```bash
node --check app/server.js
node --check app/public/app.js
```

Both must exit 0.

### Backend smoke tests

Start server, login as admin, then:

1. GET /api/imports → 200, empty array (or existing batches)
2. POST /api/import/commit with a valid workbook payload → 200, batch_id returned
3. Note the batch_id and inserted_count for the test batch
4. DELETE /api/imports/:batch_id (admin) → 200, `{ ok, deleted_entry_count, deleted_import_id }`
5. Verify deleted_entry_count matches inserted_count from step 2
6. GET /api/imports → batch no longer present
7. GET /api/rows → entries from that batch gone; manual entries still present
8. DELETE /api/imports/:batch_id again → 404 (double-delete)
9. DELETE /api/imports/abc → 400
10. DELETE /api/imports/99999 → 404
11. Login as vasu → DELETE /api/imports/1 → 403
12. Anonymous DELETE /api/imports/1 → 401

### Two-batch isolation test

1. Import twice → batch_A and batch_B
2. DELETE batch_A → confirm deleted_entry_count = A rows
3. Verify batch_B entries still in DB: `SELECT COUNT(*) FROM entries WHERE import_batch_id = batch_B_id`
4. DELETE batch_B to clean up

### DB-level safety verification

```bash
node -e "
const {db} = require('./app/db');
const nullCount = db.prepare('SELECT COUNT(*) c FROM entries WHERE import_batch_id IS NULL').get().c;
console.log('NULL batch entries:', nullCount, '(should be >= original 65)');
const totalImports = db.prepare('SELECT COUNT(*) c FROM imports').get().c;
console.log('imports remaining:', totalImports, '(should be 0 after full cleanup)');
" 2>/dev/null
```

### Regression smoke tests

1. POST /api/import/preview → 200 (no DB writes, unchanged)
2. POST /api/import/commit → 200 with batch_id (creates new batch)
3. GET /api/imports → 200 (admin only)
4. GET /api/users → admin 200, vasu 403
5. POST /api/rows (admin, T1 AstraX Device) → 201, import_batch_id = NULL
6. Invariants: `bash vendor/engineering-os/scripts/invariant-engine.sh` → 5/5 PASS
7. No [FILL:] residue: `grep -r '\[FILL:' tasks/phase-3-delete-import-batch-00*.md` → empty
8. git status --short: only allowed surfaces modified

### Cleanup

All test batches and associated entries MUST be deleted via DELETE /api/imports/:id before this task marks done. Verify live DB returns to original 65 NULL-batch entries.

### README update

Update `app/README.md` to add or extend the import management section:
- Admins can delete an import batch via the Import History Delete button
- Deletion permanently removes all entries tagged to that batch
- Manual rows (import_batch_id = NULL) are never touched
- Double-delete returns 404 (idempotent-safe)
- P3-3 duplicate detection is planned next

### State advance

```bash
bash scripts/state-manager.sh advance phase-3-delete-import-batch RELEASE_APPROVED
```

## Acceptance Criteria
- [ ] `node --check app/server.js` exits 0
- [ ] `node --check app/public/app.js` exits 0
- [ ] DELETE /api/imports/:id (admin, existing) → 200 with ok + counts
- [ ] DELETE /api/imports/:id (non-admin) → 403
- [ ] DELETE /api/imports/:id (anon) → 401
- [ ] DELETE /api/imports/:id (missing) → 404
- [ ] DELETE /api/imports/:id (non-integer) → 400
- [ ] Double-delete → 404
- [ ] Batch entries gone from DB; manual entries untouched
- [ ] Two-batch isolation: deleting one batch does not affect the other
- [ ] Import History Delete button visible per batch
- [ ] Confirm dialog appears; cancel does nothing
- [ ] After delete: history + rows refresh; alert shows deleted_entry_count
- [ ] Invariants 5/5 PASS
- [ ] No [FILL:] residue
- [ ] app/README.md updated
- [ ] state_registry = RELEASE_APPROVED
- [ ] git status: only allowed surfaces modified
- [ ] Test data cleaned up (live DB back to ≥65 NULL-batch entries, 0 imports remaining)

## Files Likely Affected
- app/README.md
- ai/state_registry.json

## Blocked By
- tasks/phase-3-delete-import-batch-003.md
