# Task: Verify P3-1, run smoke tests, update README, advance to RELEASE_APPROVED

## Parent Spec
specs/phase-3-import-batch-ledger.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run all verification checks, execute the full smoke test suite, update the README, advance state to RELEASE_APPROVED. DO NOT modify ai/engineering-journal.md — the supervisor owns that file.

### Verification checks

Run available scripts (verification/ dir does not exist — run equivalent):

1. App starts: `node app/server.js &` — server should bind port 3000
2. No syntax errors: `node --check app/server.js && node --check app/public/app.js`

### Smoke test suite

Use a FRESH test DB copy to avoid polluting the live `app/data.db`. Pattern:
```bash
cp app/data.db /tmp/test-p3-1.db
TEST_DB=/tmp/test-p3-1.db node app/server.js &
# ... tests ...
# cleanup: kill server, rm /tmp/test-p3-1.db
```

OR verify against the live DB and manually clean up created test imports + entries afterwards (preferred approach used in prior P2 checks).

**Tests to execute (as curl commands against running server):**

1. Admin login → get cookie
2. GET /api/imports (admin) → 200, `{"imports":[]}`
3. GET /api/imports (no auth) → 401
4. GET /api/imports (vasu/track_owner) → 403
5. POST /api/import/preview with real workbook → 200, `summary.sheet` present, rows with `row_number`
6. POST /api/import/commit with `{filename, sheet, rows:[{data,row_number}]}` → 200, includes `batch_id`
7. GET /api/imports (admin) after commit → 200, one batch in list
8. SELECT from imports table → one row with correct filename, imported_by, row counts
9. SELECT entries WHERE import_batch_id IS NOT NULL → rows from commit have batch id set
10. SELECT entries WHERE import_batch_id IS NOT NULL AND import_source_sheet IS NOT NULL → source sheet set
11. SELECT entries WHERE import_batch_id IS NOT NULL AND import_source_row IS NOT NULL → source row set
12. SELECT entries WHERE created_by NOT IN ('admin','system','vasu') AND import_batch_id IS NULL → smoke_owner row unaffected
13. POST /api/import/commit missing filename → 400
14. POST /api/rows (manual create, admin) → 201; verify import_batch_id IS NULL on new row
15. Existing P2 flows: admin login/me, vasu login/me, GET /api/rows, GET /api/users (admin 200, vasu 403)
16. Self-demote guard: PUT /api/users/1 role=viewer → 403
17. Self-delete guard: DELETE /api/users/1 → 403
18. Invariant engine: `bash vendor/engineering-os/scripts/invariant-engine.sh` → 5/5 PASS

**Cleanup after smoke tests:** DELETE the test import batch and its associated entries from the live DB, OR use a throw-away DB copy.

### README update

Add an "Import Batch Ledger" section to `app/README.md` (or create it if not present), explaining:
- Every import commit creates a batch record in the `imports` table
- Imported entries carry `import_batch_id`, `import_source_sheet`, `import_source_row`
- Manual entries have `import_batch_id = NULL`
- Import history is admin-only (GET /api/imports)
- Delete import batch is planned for P3-2 and is not yet available

### State advance

After all checks pass, advance state to RELEASE_APPROVED:
```bash
bash scripts/state-manager.sh advance phase-3-import-batch-ledger RELEASE_APPROVED
```

(The supervisor transitions through EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED automatically, but document the state outcome.)

### Git

Run `git status --short` — confirm only allowed surfaces are modified:
- app/db.js
- app/server.js
- app/public/app.js
- app/public/style.css (if changed)
- app/README.md
- ai/recon/phase-3-import-batch-ledger-recon.md
- specs/phase-3-import-batch-ledger.md
- tasks/phase-3-import-batch-ledger-001..004.md
- ai/state_registry.json
- ai/engineering-journal.md (supervisor-owned — do NOT touch)

DO NOT modify: app/public/index.html, app/package.json, app/package-lock.json, prototypes/, sdlc/, source-materials/, vendor/

## Acceptance Criteria
- [ ] `node --check app/server.js` exits 0
- [ ] `node --check app/public/app.js` exits 0
- [ ] App boots without error on port 3000
- [ ] GET /api/imports (admin) → 200 with `imports` array
- [ ] GET /api/imports (anon) → 401
- [ ] GET /api/imports (track_owner) → 403
- [ ] POST /api/import/commit (admin, valid payload) → 200 with `batch_id`
- [ ] Imports table has one row after commit
- [ ] Imported entries have `import_batch_id`, `import_source_sheet`, `import_source_row` set
- [ ] Manual row POST → `import_batch_id = NULL`
- [ ] Old entries unchanged (import_batch_id = NULL)
- [ ] POST /api/import/commit missing filename → 400
- [ ] Import History section visible in Import tab for admin after commit
- [ ] No delete import button in UI
- [ ] Invariants 5/5 PASS
- [ ] No `[FILL:]` residue in task files
- [ ] app/README.md has Import Batch Ledger section
- [ ] state_registry phase-3-import-batch-ledger = RELEASE_APPROVED
- [ ] git status: only allowed surfaces modified
- [ ] Test imports / entries cleaned up from live DB (no test data left behind)

## Files Likely Affected
- app/README.md
- ai/state_registry.json (supervisor handles)

## Blocked By
- tasks/phase-3-import-batch-ledger-003.md
