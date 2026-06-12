# Task: Add row click/dblclick/keyboard event handlers in bindRowActions()

## Parent Spec
specs/phase-3-row-click-interaction.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Append the `[data-row-id]` event handler block to `bindRowActions()` in `app/public/app.js`.
This is the main interaction logic for P3-7.

### Current bindRowActions() closing (lines 294–303)

```javascript
  document.querySelectorAll('[data-cell-toggle]').forEach((btn) => {
    btn.onclick = (e) => {
      e.stopPropagation();
      const ck = btn.dataset.cellToggle;
      if (state.expandedCells.has(ck)) state.expandedCells.delete(ck);
      else state.expandedCells.add(ck);
      refreshTable();
    };
  });
}
```

### Change — append before the closing `}` of bindRowActions

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

### Guard explanation

`e.target.closest('button, a, input, select, textarea')` returns non-null if the click
target is inside or IS any of those elements. This prevents the row-click handler from
firing when:
- Details / Edit / Delete buttons are clicked (they are `<button>` elements)
- More/Less cell-toggle button is clicked (also a `<button>`, plus has stopPropagation)

Without this guard, clicking the Details button would open Details twice (once from the
button's own handler, once from the row onclick). The guard makes the `<tr>` handler
skip when a button was clicked, so only the button's own handler fires.

### Permission safety

`canEditRow(row)` (line 24–27 in app.js) returns:
- admin: always true
- track_owner: `userScope().includes(row.track)`
- viewer: always false

Double-click edit is gated identically to the Edit button. No new permission surface.

### Timer
200ms disambiguates single-click from double-click. `_rowClickTimer` is module-level
(declared in task-002), so it survives `refreshTable()` re-renders.

## Acceptance Criteria
- [ ] `[data-row-id]` forEach block added in bindRowActions()
- [ ] tr.onclick fires openDetails via 200ms timer
- [ ] tr.onclick guard: e.target.closest('button, a, input, select, textarea')
- [ ] tr.ondblclick fires openForm only when canEditRow(row)
- [ ] tr.ondblclick clears _rowClickTimer
- [ ] tr.onkeydown fires openDetails on Enter
- [ ] Existing [data-info], [data-edit], [data-del], [data-cell-toggle] handlers unchanged
- [ ] node --check public/app.js exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- tasks/phase-3-row-click-interaction-002.md
