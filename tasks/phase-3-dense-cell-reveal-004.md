# Task: Verify, document, and finalize P3-6 dense cell inline reveal

## Parent Spec
specs/phase-3-dense-cell-reveal.md

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
3. GET /api/rows returns rows (no change to backend)
4. Vasu → 403 on import routes (unchanged)
5. Anon → 401 (unchanged)

### Frontend smoke (admin)
1. Admin opens Rows page
2. Find a row with long hypothesis/design/success_criteria/outcome (length > 80):
   - If no such row exists: create one with a long hypothesis text for testing
   - Row must have a field longer than 80 chars
3. Long cell shows More button (not just hover tooltip)
4. Click More → cell expands inline showing full text
5. Click Less → cell collapses back to ellipsis
6. Keyboard: Tab to More button → Enter → cell expands → Tab back to button → Enter → collapses
7. Empty cell: no More/Less button visible
8. Short cell (≤80 chars): no More/Less button visible
9. Details button on same row → P3-5 modal opens correctly
10. Edit button on same row → edit form opens correctly
11. No row-click behavior (clicking table row itself does nothing)

### Regression smoke
1. Import tab still renders (admin)
2. Import preview still works
3. Import commit still works
4. Duplicate badge + checkbox in preview
5. Delete import batch still works
6. True capture observations still work
7. P3-5 provenance modal still works (manual + imported origin)
8. Manual row creation still works
9. Dashboard still renders
10. User management still works
11. Invariants 5/5 PASS

### README update
Add "Dense Cell Inline Reveal (Phase 3)" section:
- Long truncated cells now have a More/Less toggle button
- Keyboard-accessible (Tab to button, Enter/Space to toggle)
- Expand/collapse is cell-scoped; resets on data refresh
- Full row view still via Details button → P3-5 modal
- Row/cell click-to-open-details planned for P3-7
- Dashboard relevance planned for P3-8

### State + journal
1. Advance phase-3-dense-cell-reveal: EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED
2. Append P3-6 journal entry: capability, branch, files modified, reveal behavior chosen,
   accessibility, invariant status, verification results, unresolved risks, P3-7 dependency

### DB hygiene
- No DB changes needed for P3-6
- If test rows created for smoke: they are manual rows and part of the baseline dataset;
  document their presence or delete after smoke

## Acceptance Criteria
- [ ] node --check public/app.js exits 0
- [ ] node --check server.js exits 0
- [ ] Invariants 5/5 PASS
- [ ] state.expandedCells = new Set() in state object
- [ ] Long cells (>80) show More button
- [ ] Click More expands cell inline
- [ ] Click Less collapses cell
- [ ] Keyboard toggle works
- [ ] Empty/null/short cells show no toggle
- [ ] Details button still opens P3-5 modal
- [ ] Edit/Delete buttons still work
- [ ] No row-click behavior
- [ ] Import routes still work
- [ ] Provenance modal still works
- [ ] Dashboard still renders
- [ ] No [FILL:] residue in task files
- [ ] README has Dense Cell Reveal section
- [ ] state_registry phase-3-dense-cell-reveal = RELEASE_APPROVED
- [ ] Engineering journal appended
- [ ] git status shows only allowed surfaces modified

## Files Likely Affected
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md

## Blocked By
- tasks/phase-3-dense-cell-reveal-003.md
