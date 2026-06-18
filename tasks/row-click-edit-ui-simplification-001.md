# Task: Make row/cell click open edit form, remove Edit button, fix modal layering

## Parent Spec
specs/row-click-edit-ui-simplification.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Frontend-only interaction update in `app/public/app.js` + `app/public/style.css`. No backend
or schema change.

`app/public/app.js`:
1. `renderTable` row actions (line 277): remove the Edit button
   `${canEditRow(r) ? '<button ... data-edit ...>Edit</button>' : ''}`. Keep Details
   (`data-info`) and Delete (`data-del`, admin-only).
2. `bindRowActions` (lines 287-288): remove the `data-edit` → `openForm` binding (now dead).
3. `bindRowActions` row handlers (lines 304-320): set row `onclick` (when the click target is
   not a `button, a, input, select, textarea`) to call `openForm(row)`. Remove the 200 ms
   `_rowClickTimer` → `openDetails` logic and the `dblclick` → edit handler. Set the Enter
   `onkeydown` handler to call `openForm(row)`.
4. Remove the now-unused `_rowClickTimer` declaration (line 10).
5. Leave Details (`data-info` → `openDetails`), Delete (`data-del`), and More/Less
   (`data-cell-toggle`, `e.stopPropagation()`) handlers unchanged.

`app/public/style.css`:
6. `.modal-back` (line 72): add `z-index:1000` so the backdrop + modal render above the sticky
   `<th>` (`z-index:2`) and action buttons.

Do NOT touch `app/server.js`, `app/db.js`, `app/public/index.html`, or any auth/permission logic.

## Acceptance Criteria
- [ ] No Edit button and no `data-edit` attribute rendered in row actions
- [ ] Single row/cell click (outside interactive controls) opens the edit form (`openForm`)
- [ ] Enter on a focused row opens the edit form
- [ ] Details button still opens Details (`data-info` → `openDetails`)
- [ ] Delete button unchanged and admin-only (`canDeleteRow` = `isAdmin()`)
- [ ] More/Less `data-cell-toggle` still toggles without opening edit (`stopPropagation` intact)
- [ ] `_rowClickTimer` and `dblclick`-to-edit removed
- [ ] `.modal-back` has `z-index` greater than the sticky header's `z-index:2`
- [ ] `node --check app/public/app.js` passes
- [ ] `app/server.js`, `app/db.js`, `app/public/index.html` unchanged

## Files Likely Affected
- app/public/app.js (renderTable, bindRowActions, _rowClickTimer)
- app/public/style.css (.modal-back z-index)

## Blocked By
- none
