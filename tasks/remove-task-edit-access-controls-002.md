# Task: Open frontend create/edit UI + track dropdown; update README

## Parent Spec
specs/remove-task-edit-access-controls.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
In `app/public/app.js`, open the create/edit UI to any authenticated user and show all
tracks in the create/edit form. In `app/README.md`, update the docs that describe the old
edit restrictions so they stay accurate.

`app/public/app.js`:
1. `canCreateInCurrentWorkspace()` (lines 21-25) → return true (any authenticated user sees
   the New row button on the Rows page).
2. `canEditRow(row)` (lines 26-30) → return true (Edit button + double-click-to-edit open
   for any authenticated user, any row).
3. Create/edit form track dropdown (lines 821-822): show all `f.options` tracks for every
   user; remove the `isTrackOwner()` → `userScope()` restriction and the auto-select-first-
   scoped-track logic. Other select fields (status, type) unchanged.
4. Keep `canDeleteRow()` admin-only.
5. Keep My Track / All toggle (lines 147-151), `visibleRowsForWorkspace`, and `dashboardRows`
   unchanged — My Track stays a pure view/filter; toggle visibility (track_owner only) is
   intentionally left as-is (no UI redesign).

`app/README.md`:
- Update the Roles table, "My Track Workspace", and "Frontend control visibility" sections
  so they state: any authenticated user can create/edit any row; My Track is a view/filter
  only; delete/import/user-management remain admin-only.

Do NOT touch `app/public/index.html`, `app/public/style.css`, or any auth/session behavior.

## Acceptance Criteria
- [ ] `canCreateInCurrentWorkspace()` returns true for any authenticated user
- [ ] `canEditRow(row)` returns true for any authenticated user, any row
- [ ] Create/edit form track dropdown lists all canonical tracks for every role
- [ ] `canDeleteRow()` remains admin-only
- [ ] My Track / All toggle, `visibleRowsForWorkspace`, `dashboardRows` unchanged
- [ ] `app/README.md` Roles / My Track / control-visibility sections reflect open create/edit
- [ ] `app/public/index.html` and `app/public/style.css` unchanged
- [ ] `node --check app/public/app.js` passes

## Files Likely Affected
- app/public/app.js (canCreateInCurrentWorkspace, canEditRow, openForm track dropdown)
- app/README.md (Roles / My Track / control-visibility sections)

## Blocked By
- tasks/remove-task-edit-access-controls-001.md
