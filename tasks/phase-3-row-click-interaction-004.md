# Task: Verify, document, and finalize P3-7 row/cell click interaction

## Parent Spec
specs/phase-3-row-click-interaction.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run verification checks, perform live smoke tests, update README, advance state
to RELEASE_APPROVED, and append the engineering journal.

### Verification checks
1. `node --check public/app.js` → 0
2. `node --check server.js` → 0 (unchanged)
3. `bash scripts/invariant-check.sh` → 5/5 PASS

### Backend smoke
1. App boots
2. Admin login works
3. GET /api/rows returns rows (unchanged)
4. Role gates: Vasu → 403 on import routes; Anon → 401

### Frontend smoke (admin)
1. Admin opens Rows page
2. Click on a regular cell (not a button) → Details modal opens
3. Click the Details button → Details opens (not duplicated)
4. Click Edit button → edit form opens (not Details first)
5. Click More button on a long cell → cell expands (no Details)
6. Click Less button → cell collapses (no Details)
7. Double-click on a row → Edit form opens (200ms guard prevents Details flash)
8. Keyboard: Tab to row → Enter → Details opens
9. Row focus visible (focus-visible outline)

### Frontend smoke (track_owner — Vasu)
1. Vasu logs in
2. Click row in assigned track → Details opens
3. Double-click row in assigned track → Edit opens
4. Double-click row NOT in assigned track → Edit does NOT open

### Frontend smoke (viewer)
1. Log in as viewer role user (if one exists; if not, document absence and test via code review)
2. Click row → Details opens
3. Double-click row → Edit does NOT open

### Regression smoke
1. P3-5 provenance modal (manual + imported) still works
2. P3-6 More/Less cells still expand/collapse
3. Import History renders
4. Import preview still works
5. Import commit still works
6. Duplicate detection works
7. Delete import batch works
8. Dashboard renders
9. User management renders
10. Invariants 5/5

### README update
Add "Row/Cell Click Interaction (Phase 3)" section:
- Clicking a row opens Details
- Double-clicking an editable row opens Edit form
- Permissions unchanged: viewer/non-scoped track_owner cannot edit via dblclick
- More/Less cell reveal independent (no Details on toggle)
- Dashboard relevance planned for P3-8

### State + journal
1. Advance phase-3-row-click-interaction: EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED
2. Append P3-7 journal entry

### DB hygiene
- No DB changes needed

## Acceptance Criteria
- [ ] node --check public/app.js exits 0
- [ ] node --check server.js exits 0
- [ ] Invariants 5/5 PASS
- [ ] _rowClickTimer exists at module level
- [ ] <tr> has class="clickable-row", data-row-id, tabindex="0"
- [ ] Click row area → Details (200ms timer)
- [ ] Click button → only that button's handler fires (no duplicate Details)
- [ ] Click More/Less → expand/collapse (no Details)
- [ ] Dblclick editable row → Edit (timer canceled)
- [ ] Dblclick non-editable → no Edit
- [ ] Keyboard Enter on row → Details
- [ ] Role gates unchanged (403/401 on import routes)
- [ ] P3-6 cell reveal still works
- [ ] P3-5 provenance modal still works
- [ ] Import routes still work
- [ ] Dashboard still renders
- [ ] No [FILL:] residue in task files
- [ ] README has Row/Cell Click section
- [ ] state_registry phase-3-row-click-interaction = RELEASE_APPROVED
- [ ] Engineering journal appended
- [ ] git status shows only allowed surfaces modified

## Files Likely Affected
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md

## Blocked By
- tasks/phase-3-row-click-interaction-003.md
