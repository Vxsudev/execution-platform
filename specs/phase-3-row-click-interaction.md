---
Slug: phase-3-row-click-interaction
Layer: frontend
Upstream: specs/phase-3-import-provenance.md, specs/phase-3-dense-cell-reveal.md
Downstream: specs/phase-3-dashboard-relevance.md
Status: approved
Phase: phase-build
---

## Status
approved

## Phase
phase-build

# Spec: P3-7 Row/Cell Click Interaction

## Purpose

Allow users to open row Details from the row/cell area without horizontally scrolling
to the Actions column. Editable users may double-click a row to open the edit form.
This must preserve all role permissions and must not interfere with P3-6 inline cell reveal.

## Dependencies

- P3-5 (import provenance) — Details modal is the target of row single-click
- P3-6 (dense cell reveal) — More/Less buttons use e.stopPropagation(); must not
  open Details when toggling cells

## Current Horizontal-Scroll Actions Problem

The table has a minimum width of 1700px. Users on smaller viewports must scroll right to
reach the Actions column. A row/cell click shortcut removes this friction.

## Row Click Behavior

**Single click** on non-interactive row/cell area:
- Guard: `if (e.target.closest('button, a, input, select, textarea')) return;`
- After 200ms timer: `openDetails(row)` — timer canceled if dblclick fires

**Double click** on row:
- Guard: same as above
- Cancels the pending 200ms Details timer
- If `canEditRow(row)` → `openForm(row)`
- If not → do nothing

**Timer rationale**: 200ms prevents Details from flickering open when the user
double-clicks to edit. Details only opens if no dblclick follows within 200ms.

**Keyboard (Enter on focused row)**:
- `if (e.key === 'Enter') { e.preventDefault(); openDetails(row); }`
- No keyboard shortcut for edit (not required)

## Permission Safeguards

- `canEditRow(row)` gates double-click edit — identical to the Edit button guard
- Viewer: `canEditRow(row)` is always false → no edit path from dblclick
- Track owner: `canEditRow(row)` checks `userScope().includes(row.track)` — scoped
- Admin: `canEditRow(row)` always true
- No new permission surfaces introduced

## P3-6 More/Less Conflict Handling

- `[data-cell-toggle]` buttons already call `e.stopPropagation()` → will not bubble to `<tr>`
- The `e.target.closest('button')` guard also prevents row-click when clicking any button
- Double protection: stopPropagation + closest-button guard

## Markup Changes

Each `<tr>` in renderTable():
```html
<tr class="clickable-row" data-row-id="${r.id}" tabindex="0">
```

Module-level timer variable: `let _rowClickTimer = null;`

## bindRowActions() Addition

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

## CSS Changes

```css
.clickable-row{cursor:pointer}
.clickable-row:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
```

Note: `tr:hover td{background:var(--panel2)}` already exists — hover color unchanged.

## Keyboard Accessibility

- `tabindex="0"` on each `<tr>` — makes rows Tab-focusable
- `:focus-visible` outline on focused row
- Enter → openDetails(row)

## Frontend Mutation Plan

### app/public/app.js
1. Add `let _rowClickTimer = null;` at module level (after `state` block)
2. Add `class="clickable-row"`, `data-row-id="${r.id}"`, `tabindex="0"` to `<tr>` in renderTable()
3. Add `[data-row-id]` event handler block in bindRowActions()

### app/public/style.css
Add 2 new rules.

## Non-Scope

- No dashboard changes (P3-8)
- No inline cell edit
- No per-cell edit
- No import route changes
- No backend changes
- No schema changes
- No duplicate detection changes

## Verification Plan

1. `node --check public/app.js` → 0
2. `bash scripts/invariant-check.sh` → 5/5 PASS
3. Admin: row single-click → Details; dblclick → Edit
4. Track owner: dblclick own-track row → Edit; other-track → nothing
5. Viewer: dblclick → no Edit
6. Action buttons (Details/Edit/Delete): no double-open
7. More/Less: no Details on toggle
8. Keyboard Enter on focused row → Details
9. Regression: import, provenance modal, P3-6 reveal, dashboard all intact
