# Task: Verify, update README, and finalize P3-3

## Parent Spec
specs/phase-3-duplicate-detection.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run all verification checks, perform backend and frontend smoke tests, update
README with the Duplicate Detection section, update state to RELEASE_APPROVED,
and append engineering journal entry.

### Verification checks

1. `node --check app/server.js` → exit 0
2. `node --check app/public/app.js` → exit 0
3. `bash scripts/invariant-check.sh` → 5/5 PASS

### Backend smoke tests

Run app in background, verify with curl:

1. App boots without error
2. Admin login → session token
3. First import preview of test workbook → `duplicate_count = 0`
4. First import commit → batch created, rows inserted
5. Second preview of same workbook → `duplicate_count > 0`, rows marked
6. Second commit (allow_duplicates=false) → duplicates skipped, `duplicate_skipped_count > 0`
7. Batch created even when inserted_count = 0 (if all duplicates)
8. Second commit (allow_duplicates=true) → duplicates inserted, rows get batch metadata
9. GET /api/imports → returns all batches
10. DELETE /api/imports/:id → deletes last batch
11. Manual rows remain import_batch_id = NULL after all operations
12. Vasu → 403 on preview/commit
13. Anonymous → 401 on preview/commit

### Frontend smoke checks

Verify by reading app.js and style.css:
- duplicate_count displayed in summary
- Duplicate badge present in row rendering logic
- allow_duplicates checkbox rendered when duplicates exist
- Commit payload includes allow_duplicates
- Post-commit alert includes duplicate_skipped_count

### README update

Add "Duplicate Detection" section to `app/README.md`:
- Preview detects duplicates by source sheet/row (position match) and by
  normalized title + owner + track (logical match)
- Default commit skips detected duplicates (reported as duplicate_skipped_count)
- Admin can check "Import duplicates anyway" to override default skip behavior
- Duplicate detection is non-destructive: no existing data modified or deleted
- Delete batch (P3-2) remains the rollback mechanism for unwanted imports
- True workbook capture (P3-4) remains planned for future

### State and journal

1. Advance `phase-3-duplicate-detection` to RELEASE_APPROVED in ai/state_registry.json
2. Append P3-3 entry to ai/engineering-journal.md with:
   - capability
   - branch
   - files modified
   - duplicate detection strategy
   - preview changes
   - commit changes
   - frontend changes
   - invariant status
   - verification results
   - unresolved risks
   - P3-4 dependency status

### DB cleanup

If live data.db was used for smoke testing (not a copy), document exact state:
- how many import batches remain
- how many entries with import_batch_id NOT NULL remain
- whether cleanup is needed or state is intentional

## Acceptance Criteria
- [ ] node --check app/server.js → 0
- [ ] node --check app/public/app.js → 0
- [ ] Invariants 5/5 PASS
- [ ] First import preview: duplicate_count = 0
- [ ] First import commit: rows inserted, batch created
- [ ] Second preview: duplicate_count > 0
- [ ] Second commit (allow_duplicates=false): duplicate_skipped_count > 0
- [ ] Second commit (allow_duplicates=true): rows inserted with batch metadata
- [ ] GET /api/imports works
- [ ] DELETE /api/imports/:id works (P3-2 preserved)
- [ ] Manual rows remain import_batch_id = NULL
- [ ] Vasu → 403, anon → 401
- [ ] README has Duplicate Detection section
- [ ] state_registry phase-3-duplicate-detection = RELEASE_APPROVED
- [ ] Engineering journal appended
- [ ] No [FILL:] residue in any task files
- [ ] git status shows only allowed surfaces modified

## Files Likely Affected
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md

## Blocked By
- tasks/phase-3-duplicate-detection-003.md
