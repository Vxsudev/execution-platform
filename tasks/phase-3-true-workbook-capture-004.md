# Task: Verify, document, and finalize P3-4 true workbook capture

## Parent Spec
specs/phase-3-true-workbook-capture.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run verification checks, perform live smoke tests on a DISPOSABLE copy of
app/data.db, update README, advance state to RELEASE_APPROVED, and append the
engineering journal.

### Verification checks
1. `node --check app/db.js` → 0
2. `node --check app/server.js` → 0
3. `node --check app/public/app.js` → 0
4. `bash scripts/invariant-check.sh` → 5/5 PASS (scripts/verification/00x absent — report and use closest wrapper)

### Backend smoke (disposable DB copy)
Copy app/data.db → /tmp copy; run server with DATA pointed at the copy if
supported, otherwise back up and restore app/data.db. Verify:
1. App boots; import_observations table exists.
2. Admin login works.
3. Preview writes zero observations.
4. Normal commit → imports row + entries + observations; response has observation_count.
5. Commit response observation_count = inserted + duplicate_skipped + parse_skipped + 1 (sheet).
6. Duplicate-only commit (allow_duplicates=false, all dup) → batch + observations, inserted_count=0.
7. Blank-title skipped rows in payload → skipped_row observations.
8. workbook_sheet observation reason = 'zero execution rows inserted' when inserted=0.
9. DELETE /api/imports/:id removes entries + observations + ledger row; returns deleted_observation_count.
10. Manual rows untouched; other batches untouched.
11. Vasu preview/commit/delete → 403.
12. Anonymous preview/commit/delete → 401.
13. allow_duplicates=true still imports duplicates (P3-3).
14. GET /api/imports includes observation_count.

### Frontend smoke (read app.js)
- Preview summary shows observation projection.
- Commit alert shows observation_count + batch id.
- Import History has observation column.
- Delete alert shows deleted_observation_count.
- P3-3 duplicate UI + P3-2 delete UI intact.
- No provenance/table/dashboard UI.

### README update
Add "True Workbook Capture" section to app/README.md:
- execution rows → entries; workbook observations → import_observations
- zero inserted rows can still produce captured observations
- delete import batch removes entries AND observations for that batch
- P3-5 will expose provenance/details more fully later

### State + journal
1. Advance phase-3-true-workbook-capture: EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED via `bash scripts/state-manager.sh`.
2. Append P3-4 journal entry: capability, branch, files modified, observation schema, preview/commit changes, delete cascade changes, frontend changes, invariant status, verification results, unresolved risks, P3-5 dependency status.

### DB hygiene
- Do not leave test data in the LIVE app/data.db. Smoke on disposable copy.
- Document final live-DB state (note pre-existing batch id=9 from operator P3-3 testing — left intentionally).

## Acceptance Criteria
- [ ] node --check passes for db.js, server.js, app.js
- [ ] Invariants 5/5 PASS
- [ ] import_observations table exists on boot
- [ ] Preview writes no observations
- [ ] Normal commit creates entries + observations + observation_count
- [ ] Zero-insert commit creates batch + observations, inserted_count=0
- [ ] Skipped rows captured as observations
- [ ] DELETE cascades observations; returns deleted_observation_count
- [ ] Manual rows remain import_batch_id NULL
- [ ] Other batches untouched on delete
- [ ] Vasu 403; anon 401 on import routes
- [ ] allow_duplicates override still works
- [ ] GET /api/imports includes observation_count
- [ ] README has True Workbook Capture section
- [ ] state_registry phase-3-true-workbook-capture = RELEASE_APPROVED
- [ ] Engineering journal appended
- [ ] No [FILL:] residue in task files
- [ ] Live DB not polluted by smoke tests
- [ ] git status shows only allowed surfaces modified

## Files Likely Affected
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md

## Blocked By
- tasks/phase-3-true-workbook-capture-003.md
