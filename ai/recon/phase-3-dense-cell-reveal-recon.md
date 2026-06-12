# Recon: P3-6 Dense Cell Inline Reveal

## Date
2026-06-12

## Feature Slug
phase-3-dense-cell-reveal

## Commands Run
- `bash vendor/engineering-os/scripts/os-adapter-check.sh` → 12/12 PASS
- `bash scripts/invariant-check.sh` → 5/5 PASS
- Read app/public/app.js lines 34–292 (table render, bindings)
- Read app/public/style.css full
- `git status` → main, clean, 5 commits ahead of origin

---

## Current Truncation Implementation

### TRUNC_COLS (app.js:41)
```javascript
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);
```
Four columns. Confirmed: hypothesis, design, success_criteria, outcome.

### Cell render (app.js:260–263)
```javascript
if (TRUNC_COLS.has(k)) {
  const v = r[k] || '';
  return `<td class="trunc" title="${esc(v)}">${esc(v)}</td>`;
}
```
Single-line ellipsis. The `title` attribute is the ONLY full-content path.

### CSS (style.css:53)
```css
td.trunc{max-width:260px;overflow:hidden;text-overflow:ellipsis}
```
Global `th,td` rule at line 47 sets `white-space:nowrap` — applies to all cells.

### Tooltip limitation
The `title` attribute tooltip is:
- Not reachable by keyboard (no keyboard path)
- Not reachable on touch devices
- Timing-dependent (hover delay)
- Not readable for very long content
- The ONLY current path to full content

---

## Current Table Rendering Flow

- `refreshTable()` (line 237–242): sets `tableScroll.innerHTML = renderTable(rows)`, then calls `bindRowActions()`
- `renderTable()` (line 244–273): generates `<table>` with TRUNC_COLS cells as `.trunc`
- `bindRowActions()` (line 275–286): binds `[data-info]` (Details), `[data-edit]` (Edit), `[data-del]` (Delete)

### State object (app.js:3–7)
```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null, imports: [], importFilename: null, allowDuplicates: false,
};
```
No `expandedCells` — needs to be added.

---

## Current Tooltip and Title Usage

TRUNC_COLS cells: `title="${esc(v)}"` — hover tooltip only
Dashboard mini-table cells: `title="${esc(...)}"` — NOT in TRUNC_COLS scope; NOT touched
Import preview table (line 540): `.trunc` with `title` — NOT touched (different table/context)
Track scope cell (line 416): `.trunc` with `title` — NOT touched (user management table)

**P3-6 must only modify the main rows table TRUNC_COLS cells.**

---

## Interaction Conflict Analysis

- `[data-info]`, `[data-edit]`, `[data-del]` — on action buttons, not on cells
- No row-click exists (`<tr>` has no onclick — P3-7 not implemented)
- No double-click-edit exists
- Cell-toggle button inside a TRUNC_COLS cell will not conflict with any existing handlers
- `e.stopPropagation()` added defensively

---

## Chosen Reveal Behavior

### Reveal trigger
- TRUNC_COLS cell with `v.length > 80` (heuristic for "genuinely long content")
- Short/null/empty cells: no toggle shown; existing behavior unchanged

### DOM structure (collapsed)
```html
<td class="trunc has-toggle">
  <span class="cell-text">${esc(v)}</span>
  <button class="cell-toggle" data-cell-toggle="${esc(ck)}" aria-expanded="false">More</button>
</td>
```
Where `ck = "${r.id}:${k}"`.

### DOM structure (expanded)
```html
<td class="trunc has-toggle expanded">
  <span class="cell-text">${esc(v)}</span>
  <button class="cell-toggle" data-cell-toggle="${esc(ck)}" aria-expanded="true">Less</button>
</td>
```

### State key
`state.expandedCells` — a `Set` of strings like `"42:hypothesis"`.

### Toggle handler (added in bindRowActions)
```javascript
document.querySelectorAll('[data-cell-toggle]').forEach((btn) => {
  btn.onclick = (e) => {
    e.stopPropagation();
    const ck = btn.dataset.cellToggle;
    if (state.expandedCells.has(ck)) {
      state.expandedCells.delete(ck);
    } else {
      state.expandedCells.add(ck);
    }
    refreshTable();
  };
});
```

### Reset behavior
Expanded cells persist across search/filter (state.expandedCells survives `refreshTable()`).
Expanded cells reset on `loadRows()` — intentional; stale expand state is unexpected after data refresh.
Persistence across re-renders: not required per directive.

---

## Accessibility Plan

- `aria-expanded="true/false"` on the toggle button
- Button is a standard `<button>` element — keyboard-focusable by default
- Enter/Space on focused button triggers onclick — standard browser behavior
- No additional ARIA needed for this simple pattern

---

## CSS Plan

```css
/* has-toggle cells: overflow visible to show button below text */
td.trunc.has-toggle{overflow:visible;white-space:normal;vertical-align:top;max-width:260px}
td.trunc.has-toggle .cell-text{display:block;max-width:100%;overflow:hidden;
  text-overflow:ellipsis;white-space:nowrap}
.cell-toggle{display:inline-block;font-size:10px;padding:1px 5px;margin-top:2px;
  border-radius:3px;border:1px solid var(--line);background:transparent;
  color:var(--accent);cursor:pointer;line-height:1.4}
.cell-toggle:focus{outline:2px solid var(--accent);outline-offset:1px}
/* expanded state */
td.trunc.has-toggle.expanded{max-width:420px}
td.trunc.has-toggle.expanded .cell-text{overflow:visible;text-overflow:clip;
  white-space:pre-wrap;word-break:break-word;max-width:400px}
```

---

## Mutation Plan

### app/public/app.js
1. Add `expandedCells: new Set()` to state object (line 6)
2. Update TRUNC_COLS branch in `renderTable()` (line 260–263) for toggle rendering
3. Add `[data-cell-toggle]` handler in `bindRowActions()` (line 275–286)

### app/public/style.css
Add 7 new CSS rules after existing dashboard styles.

### app/README.md
Add "Dense Cell Inline Reveal (Phase 3)" section.

### NOT modified
- app/server.js
- app/db.js
- app/public/index.html
- Dashboard mini-table (different context; uses its own .trunc/.card structure)
- Import preview table
- User management table

---

## Dependency Relationship to P3-7

P3-7 (row/cell click interaction) will add a `<tr>` click or cell click to open Details. P3-6 establishes that cell-toggle buttons use `e.stopPropagation()`. P3-7 must be aware that TRUNC_COLS cells have a nested button — P3-7's row-click handler must exclude `[data-cell-toggle]` targets. This risk is documented but P3-7 is out of scope here.

---

## Verification Plan

1. `node --check public/app.js` → 0
2. `bash scripts/invariant-check.sh` → 5/5 PASS
3. Smoke: long cell shows More button → click → expands → click Less → collapses
4. Smoke: empty/null cell and short (≤80) cell: no toggle
5. Smoke: keyboard Tab to toggle → Enter → expands
6. Smoke: Details/Edit/Delete buttons still work after toggle
7. Regression: import, dashboard, provenance modal still work

---

## Conflicts
None found.
