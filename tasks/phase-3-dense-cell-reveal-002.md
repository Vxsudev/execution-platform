# Task: Update renderTable() for toggle markup and add expandedCells to state

## Parent Spec
specs/phase-3-dense-cell-reveal.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `app/public/app.js`:
1. Add `expandedCells: new Set()` to the `state` object.
2. Update the TRUNC_COLS branch in `renderTable()` to conditionally render
   the toggle markup.

### State change (line 3–7)

Current:
```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null, imports: [], importFilename: null, allowDuplicates: false,
};
```

Change to append `expandedCells: new Set()` at the end of the state object:
```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null, imports: [], importFilename: null,
  allowDuplicates: false, expandedCells: new Set(),
};
```

### renderTable() TRUNC_COLS branch change (lines 260–263)

Current:
```javascript
if (TRUNC_COLS.has(k)) {
  const v = r[k] || '';
  return `<td class="trunc" title="${esc(v)}">${esc(v)}</td>`;
}
```

Replace with:
```javascript
if (TRUNC_COLS.has(k)) {
  const v = r[k] || '';
  if (v.length > 80) {
    const ck = `${r.id}:${k}`;
    const expanded = state.expandedCells.has(ck);
    return expanded
      ? `<td class="trunc has-toggle expanded"><span class="cell-text">${esc(v)}</span><button class="cell-toggle" data-cell-toggle="${esc(ck)}" aria-expanded="true">Less</button></td>`
      : `<td class="trunc has-toggle" title="${esc(v)}"><span class="cell-text">${esc(v)}</span><button class="cell-toggle" data-cell-toggle="${esc(ck)}" aria-expanded="false">More</button></td>`;
  }
  return `<td class="trunc" title="${esc(v)}">${esc(v)}</td>`;
}
```

Note: the `title` attribute is preserved in the collapsed state for short/medium cells
and for the collapsed has-toggle variant. It is omitted in the expanded variant (content
is already fully visible). Empty/null/short cells fall through to the base `.trunc` render.

## Acceptance Criteria
- [ ] state.expandedCells = new Set() added to state object
- [ ] renderTable() renders has-toggle cells for v.length > 80
- [ ] Collapsed has-toggle cell has `data-cell-toggle="${r.id}:${k}"` and `aria-expanded="false"`
- [ ] Expanded has-toggle cell has `aria-expanded="true"` and class `expanded`
- [ ] Short/null/empty cells still render plain `.trunc` (no toggle)
- [ ] node --check public/app.js exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- tasks/phase-3-dense-cell-reveal-001.md
