# Task: Add cell-toggle event binding in bindRowActions()

## Parent Spec
specs/phase-3-dense-cell-reveal.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `bindRowActions()` in `app/public/app.js` to handle `[data-cell-toggle]`
button clicks. This is the only JS event-binding change required for P3-6.

### Current bindRowActions() (lines 275–286)

```javascript
function bindRowActions() {
  document.querySelectorAll('[data-info]').forEach((b) =>
    b.onclick = () => openDetails(state.rows.find((r) => r.id == b.dataset.info)));
  document.querySelectorAll('[data-edit]').forEach((b) =>
    b.onclick = () => openForm(state.rows.find((r) => r.id == b.dataset.edit)));
  document.querySelectorAll('[data-del]').forEach((b) =>
    b.onclick = async () => {
      if (!confirm('Delete this row?')) return;
      await api('/rows/' + b.dataset.del, { method: 'DELETE' });
      await loadRows(); renderApp();
    });
}
```

### Change: append cell-toggle handler before the closing `}`

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
```

### Why e.stopPropagation()

Defensive: prevents the toggle click from bubbling to any future row-click
listener that P3-7 may add to `<tr>`. No existing listener on `<tr>` today, but
this makes P3-7 implementation safer.

### Why refreshTable() not renderApp()

`refreshTable()` re-renders only the table section and re-binds actions.
`renderApp()` re-renders the whole app including nav bars, controls, etc. — overkill
for a single cell toggle. Using `refreshTable()` also avoids any import-panel state reset.

## Acceptance Criteria
- [ ] `[data-cell-toggle]` querySelectorAll added inside bindRowActions()
- [ ] onclick handler calls e.stopPropagation()
- [ ] Toggle key added/deleted from state.expandedCells on click
- [ ] refreshTable() called after state update
- [ ] Existing [data-info], [data-edit], [data-del] handlers unchanged
- [ ] node --check public/app.js exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- tasks/phase-3-dense-cell-reveal-002.md
