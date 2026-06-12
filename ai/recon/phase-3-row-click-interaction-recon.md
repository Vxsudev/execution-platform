# Recon: P3-7 Row/Cell Click Interaction

## Date
2026-06-12

## Feature Slug
phase-3-row-click-interaction

## Commands Run
- `bash vendor/engineering-os/scripts/os-adapter-check.sh` → 12/12 PASS
- `bash scripts/invariant-check.sh` → 5/5 PASS
- Read app/public/app.js lines 1–303 (state, renderTable, bindRowActions)
- Read app/public/style.css full
- `git status` → main, clean, 6 commits ahead of origin

---

## Current Row/Action Event Model

### renderTable() <tr> markup (line 274)
```javascript
return `<tr>${cells}<td><div class="row-actions">
  <button class="icon-btn" data-info="${r.id}">Details</button>
  ${canEditRow(r) ? `<button class="icon-btn" data-edit="${r.id}">Edit</button>` : ''}
  ${canDeleteRow() ? `<button class="icon-btn danger" data-del="${r.id}">Delete</button>` : ''}
</div></td></tr>`;
```
- No `class`, `data-row-id`, `tabindex`, or event handler on `<tr>`
- No row-level click/keyboard interaction exists yet

### bindRowActions() (lines 283–303)
- `[data-info]` → `openDetails(row)` — no stopPropagation
- `[data-edit]` → `openForm(row)` — no stopPropagation
- `[data-del]` → api DELETE → loadRows + renderApp — no stopPropagation
- `[data-cell-toggle]` → toggle expandedCells + refreshTable + **e.stopPropagation()**

### P3-6 toggle model
The `.cell-toggle` / `[data-cell-toggle]` handler calls `e.stopPropagation()` — events from More/Less clicks will NOT bubble to a `<tr>` onclick. ✅

### Permission helpers (lines 24–29)
```javascript
function canEditRow(row)  {
  if (isAdmin()) return true;
  if (isTrackOwner()) return userScope().includes(row.track);
  return false;
}
function canDeleteRow() { return isAdmin(); }
```

### Existing hover (style.css line 54)
`tr:hover td{background:var(--panel2)}` — already exists; hover color affordance already present.

---

## Interaction Conflict Analysis

### Action buttons vs row-click
`[data-info]`, `[data-edit]`, `[data-del]` buttons do NOT call `e.stopPropagation()`.
Adding a `<tr>` onclick without a guard would make these buttons ALSO trigger row click.
**Fix**: guard with `if (e.target.closest('button, a, input, select, textarea')) return;`
This catches all action buttons and the More/Less button.

### More/Less toggle vs row-click
`[data-cell-toggle]` calls `e.stopPropagation()` already. Belt-and-suspenders: the guard
`e.target.closest('button')` also catches it. Double protection. ✅

### Double-click vs single-click
Browser fires: mousedown → mouseup → click → mousedown → mouseup → click → dblclick.
Binding both onclick and ondblclick to `<tr>` without a timer would open Details twice
before opening Edit on a double-click. **Fix**: 200ms timer on single-click (clear on dblclick).
`_rowClickTimer` stored at module level to survive across `refreshTable()` calls.

---

## Chosen Row Click Behavior

### Single click
- Guard: `if (e.target.closest('button, a, input, select, textarea')) return;`
- Start 200ms timer → `openDetails(row)`
- Timer clears on dblclick (so Details doesn't open on double-click)

### Double click
- Same guard
- `clearTimeout(_rowClickTimer)` → cancel pending Details
- If `canEditRow(row)` → `openForm(row)`
- If not → do nothing

### Keyboard (Enter on focused row)
- `tr.onkeydown = (e) => { if (e.key === 'Enter') { e.preventDefault(); openDetails(row); } }`
- No double-click keyboard shortcut (not required by directive)

---

## Accessibility Plan

- `tabindex="0"` on each `<tr>` — makes rows Tab-focusable
- `class="clickable-row"` — CSS `:focus-visible` shows outline
- `role` not needed — `<tr>` is already `row` role in accessibility tree
- `aria-label` not needed — existing cell content describes the row

---

## Permission Safety Plan

- `canEditRow(row)` guards double-click edit (identical to the Edit button guard)
- Viewer (`isViewer()` = neither admin nor track_owner): `canEditRow(row)` returns false → no edit on dblclick
- Track owner: `canEditRow(row)` checks `userScope().includes(row.track)` → scoped correctly
- Admin: `canEditRow(row)` always true
- No new permission surfaces introduced

---

## Mutation Plan

### app/public/app.js

1. **Module level** — after `state = {...}` block: add `let _rowClickTimer = null;`

2. **renderTable()** — change `<tr>` to:
   ```javascript
   `<tr class="clickable-row" data-row-id="${r.id}" tabindex="0">`
   ```

3. **bindRowActions()** — append before closing `}`:
   ```javascript
   document.querySelectorAll('[data-row-id]').forEach((tr) => {
     const row = state.rows.find(r => r.id === Number(tr.dataset.rowId));
     if (!row) return;
     tr.onclick = (e) => {
       if (e.target.closest('button, a, input, select, textarea')) return;
       clearTimeout(_rowClickTimer);
       _rowClickTimer = setTimeout(() => openDetails(row), 200);
     };
     tr.ondblclick = (e) => {
       if (e.target.closest('button, a, input, select, textarea')) return;
       clearTimeout(_rowClickTimer);
       if (canEditRow(row)) openForm(row);
     };
     tr.onkeydown = (e) => {
       if (e.key === 'Enter') { e.preventDefault(); openDetails(row); }
     };
   });
   ```

### app/public/style.css

Add 2 new rules:
```css
.clickable-row{cursor:pointer}
.clickable-row:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
```
Note: `.clickable-row:hover td` not needed — `tr:hover td` already exists at line 54.

---

## Verification Plan

1. `node --check public/app.js` → 0
2. `bash scripts/invariant-check.sh` → 5/5 PASS
3. Admin: click row/cell area (not button) → Details opens
4. Admin: dblclick editable row → Edit opens (no Details flash)
5. Admin: click Details button → Details opens (row click guard prevents double-open)
6. Admin: click Edit button → Edit opens
7. Admin: click More/Less → cell expands/collapses (no Details opens)
8. Track owner: click row → Details opens
9. Track owner: dblclick own-track row → Edit opens
10. Track owner: dblclick other-track row → nothing (canEditRow=false)
11. Viewer: click row → Details opens
12. Viewer: dblclick → Details opens (from 200ms single-click path or nothing — NO Edit)
13. Keyboard: Tab to row → Enter → Details opens

---

## Dependency Relationship to P3-8

P3-8 (dashboard relevance) operates on the dashboard tab, not the rows table.
P3-7's clickable-row class and _rowClickTimer have no coupling to the dashboard.
P3-8 may add row-click on dashboard mini-tables — it should follow the same guard pattern.

---

## Conflicts
None found.
