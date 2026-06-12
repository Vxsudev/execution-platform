# Task: Verify, document, and finalize P3-8 dashboard relevance

## Parent Spec
specs/phase-3-dashboard-relevance.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run verification checks, perform live smoke tests, update README, advance
state to RELEASE_APPROVED, and append the engineering journal.

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
1. Admin opens Dashboard
2. Dashboard shows all rows — no workspace toggle
3. Execution health shows all-rows total/open/complete/blocked counts
4. Items by status, track, owner load — all rows
5. All 8 dashboard widgets render

### Frontend smoke (track_owner)
1. Track owner opens Dashboard
2. Workspace toggle (All Tracks / My Track) is visible in topbar
3. Default workspace context: whatever state.workspace was (all or my)
4. Click My Track: dashboard scope-label shows "My Track (track)"
5. Click My Track: counts/lists show only assigned-track rows
6. Click All Tracks: scope-label shows "All Tracks", counts show all rows
7. Toggle works without leaving Dashboard

### Frontend smoke (viewer)
1. Viewer opens Dashboard
2. Dashboard shows all rows
3. No workspace toggle visible

### Empty scoped dashboard
1. Track owner with no matching rows in My Track → zeros shown, no crash

### Regression smoke
1. Rows workspace behavior still works (P3-7 row click intact)
2. P3-6 More/Less cells still expand/collapse
3. P3-5 provenance Details modal still works
4. Import History renders
5. Import preview still works
6. Import commit still works
7. Duplicate detection works
8. Delete import batch works
9. Dashboard renders (all 8 cards)
10. User management renders
11. Invariants 5/5

### README update
Add "Dashboard Relevance (Phase 3)" section:
- Admin dashboard: all rows, no scope toggle
- Viewer dashboard: all rows, no scope toggle
- Track owner dashboard: All Tracks / My Track workspace toggle in topbar
- My Track uses assigned-track scope (same as Rows page)
- All Tracks shows all rows for context
- dashboardRows() helper unifies row sourcing across all dashboard widgets
- Frontend-only relevance/prioritization, no permission changes
- P3-9 review checkpoint follows

### State + journal
1. Advance phase-3-dashboard-relevance: EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED
2. Append P3-8 journal entry

### DB hygiene
- No DB changes needed

## Acceptance Criteria
- [ ] node --check public/app.js exits 0
- [ ] node --check server.js exits 0
- [ ] Invariants 5/5 PASS
- [ ] dashboardRows() exists and used by all dashboard helpers
- [ ] Admin dashboard: all rows, no scope toggle
- [ ] Viewer dashboard: all rows, no scope toggle
- [ ] Track owner: workspace toggle on dashboard page
- [ ] Track owner My Track: scoped counts
- [ ] Track owner All Tracks: all-row counts
- [ ] Scope label visible in dashboard
- [ ] All 8 dashboard widgets render
- [ ] Rows workspace behavior unchanged
- [ ] P3-7 row click still works
- [ ] P3-6 cell reveal still works
- [ ] P3-5 provenance modal still works
- [ ] Import routes still work
- [ ] No [FILL:] residue in task files
- [ ] README has Dashboard Relevance section
- [ ] state_registry phase-3-dashboard-relevance = RELEASE_APPROVED
- [ ] Engineering journal appended
- [ ] git status shows only allowed surfaces modified

## Files Likely Affected
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md

## Blocked By
- tasks/phase-3-dashboard-relevance-003.md
