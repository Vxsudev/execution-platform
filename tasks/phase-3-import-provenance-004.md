# Task: Verify, document, and finalize P3-5 import provenance

## Parent Spec
specs/phase-3-import-provenance.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run verification checks, perform live smoke tests on a disposable copy of
app/data.db, update README, advance state to RELEASE_APPROVED, and append the
engineering journal.

### Verification checks
1. `node --check server.js` → 0 (unchanged)
2. `node --check public/app.js` → 0
3. `bash scripts/invariant-check.sh` → 5/5 PASS

### Backend smoke
1. App boots; GET /api/rows returns import_batch_id/source fields
2. Admin login works
3. GET /api/rows: no password_hash in payload
4. GET /api/imports: returns id, filename, imported_by, imported_at, status, observation_count
5. Import preview still works (no changes — smoke only)
6. Import commit still works (no changes — smoke only)
7. Duplicate detection still works
8. Delete batch still works
9. Vasu (track_owner) → 403 on import routes
10. Anonymous → 401 on import routes

### Frontend smoke (admin)
1. Admin opens Rows page
2. Admin clicks Details on a manual row:
   - Modal is wide (not .modal-sm)
   - All row content fields render (no crash on empty fields)
   - Audit section shows 4 fields
   - Provenance shows "Manual / Legacy" badge
   - No import batch fields displayed
3. Create a test import or use existing batch-9:
   If creating: use a disposable DB copy, commit 1+ rows, verify imported entry.
   If not creating: document that no imported entries exist and test manually via
   injecting a row with import_batch_id set.
4. Admin clicks Details on imported row:
   - Row content renders
   - Audit section renders
   - Provenance shows "Imported" badge
   - Shows batch id, source_sheet, source_row
   - If state.imports loaded: shows filename, imported_by, imported_at
5. Track owner clicks Details on visible row:
   - Modal renders with content + audit + provenance
   - No crash on empty state.imports
6. Close button works
7. Click-outside-modal closes it

### Regression smoke
1. Import History still renders (admin)
2. Delete Import Batch still works
3. Duplicate badge + checkbox still render in preview
4. Observation count column in history table
5. Manual row creation still works
6. New manual row has import_batch_id = NULL
7. Dashboard still renders
8. User management still works
9. Invariants 5/5 PASS

### README update
Add "Import Provenance (Phase 3)" section:
- Details now shows all row content fields
- Imported rows show import batch and source metadata
- Manual/legacy rows show Manual / Legacy origin
- Import provenance is read-only
- Row/cell click interaction planned for P3-7
- Inline dense cell reveal planned for P3-6

### State + journal
1. Advance phase-3-import-provenance: EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED
2. Append P3-5 journal entry: capability, branch, files modified, backend decision (Option A),
   modal redesign, CSS additions, smoke results, invariant status, P3-6/P3-7 dependency status

### DB hygiene
- Use disposable DB copy if injecting test imports
- Restore live DB to original state or document intentional changes
- Manual rows used for smoke testing: safe to leave (part of baseline)

## Acceptance Criteria
- [ ] node --check server.js exits 0
- [ ] node --check public/app.js exits 0
- [ ] Invariants 5/5 PASS
- [ ] Details modal is .modal-wide (not .modal-sm)
- [ ] All 14 row fields display in modal
- [ ] Audit section displays
- [ ] Manual row shows Manual / Legacy provenance
- [ ] Imported row shows Imported provenance with batch + source fields
- [ ] No crash on NULL import_batch_id
- [ ] state.imports lazy-load works for admin + imported row
- [ ] Import routes still work (preview, commit, delete, history)
- [ ] Duplicate detection still works
- [ ] True capture observations still work
- [ ] No [FILL:] residue in task files
- [ ] README has Import Provenance section
- [ ] state_registry phase-3-import-provenance = RELEASE_APPROVED
- [ ] Engineering journal appended
- [ ] Live DB not polluted by smoke tests
- [ ] git status shows only allowed surfaces modified

## Files Likely Affected
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md

## Blocked By
- tasks/phase-3-import-provenance-003.md
