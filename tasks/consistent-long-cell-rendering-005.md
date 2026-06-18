# Task 005: Preserve Row-Click / More-Click Event Behavior

**Feature:** consistent-long-cell-rendering
**State:** COMPLETE
**Date:** 2026-06-18

## Objective

Verify event handling remains correct for the new TRUNC_COLS members. No code changes required.

## Audit Findings

### More/Less button click (app.js:323-330)

```js
document.querySelectorAll('[data-cell-toggle]').forEach((btn) => {
  btn.onclick = (e) => {
    e.stopPropagation();   // ← prevents row edit from firing
    const ck = btn.dataset.cellToggle;
    if (state.expandedCells.has(ck)) state.expandedCells.delete(ck);
    else state.expandedCells.add(ck);
    refreshTable();
  };
});
```

`stopPropagation()` is already present. ✓

### Row click guard (app.js:338-340)

```js
tr.onclick = (e) => {
  if (e.target.closest('button, a, input, select, textarea')) return;
  // ...
};
```

More/Less is a `<button>` — matches the guard selector. Row edit does NOT fire when More/Less is clicked. ✓

### Clicked-cell highlight (app.js:342)

```js
const cell = e.target.closest('td[data-col]');
openForm(row, cell ? cell.dataset.col : null);
```

All TRUNC_COLS cells are rendered with `data-col="${k}"` (app.js:299-300). New field keys pass correctly. ✓

`openForm(row, focusKey)` at app.js:916-923 finds `[data-k="${focusKey}"]` in the edit form — new keys like `dependencies`, `next_action`, `title`, `parent_item` are all in `state.fields` and rendered with `data-k`. ✓

## Status: COMPLETE — No changes made
