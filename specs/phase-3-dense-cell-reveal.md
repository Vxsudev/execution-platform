---
Slug: phase-3-dense-cell-reveal
Layer: frontend
Upstream: specs/phase-3-import-provenance.md
Downstream: specs/phase-3-row-click-interaction.md
Status: approved
Phase: phase-build
---

## Status
approved

## Phase
phase-build

# Spec: P3-6 Dense Cell Inline Reveal

## Purpose

Improve dense table readability by allowing long truncated cells to reveal and
collapse their full content inline. The hover tooltip is not a keyboard-accessible
or touch-accessible path to full content. This slice adds a visible toggle affordance
on long-text cells so all users can expand the content without opening the Details modal.

## Dependency

- P3-5 (import provenance) — Details modal is the definitive full-row view; P3-6 adds
  cell-scoped inline reveal as a lighter-weight complement

## Current Truncation Problem

TRUNC_COLS = `['hypothesis', 'design', 'success_criteria', 'outcome']`

Current cell render: `<td class="trunc" title="${esc(v)}">${esc(v)}</td>`

CSS: `td.trunc{max-width:260px;overflow:hidden;text-overflow:ellipsis}`

The `title` attribute (hover tooltip) is the only full-content path. It is:
- not keyboard accessible
- not touch accessible
- timing-dependent
- not readable for long content

## Chosen Reveal / Collapse Behavior

### Trigger
Show toggle when `v.length > 80` (heuristic for genuinely long content).
Empty, null, or short (≤80) cells: unchanged; no toggle shown.

### DOM — collapsed
```html
<td class="trunc has-toggle">
  <span class="cell-text">${esc(v)}</span>
  <button class="cell-toggle" data-cell-toggle="${esc(ck)}"
    aria-expanded="false">More</button>
</td>
```
Where `ck = "${r.id}:${k}"`.

### DOM — expanded
```html
<td class="trunc has-toggle expanded">
  <span class="cell-text">${esc(v)}</span>
  <button class="cell-toggle" data-cell-toggle="${esc(ck)}"
    aria-expanded="true">Less</button>
</td>
```

### State
Add `expandedCells: new Set()` to the top-level `state` object.
Key format: `"${rowId}:${fieldKey}"` — e.g. `"42:hypothesis"`.

### Toggle handler (in bindRowActions)
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

### Reset behavior
Expanded cells persist across search/filter re-renders (state survives `refreshTable()`).
Expanded cells reset on `loadRows()` calls — intentional; stale expand state is unexpected
after a data refresh.

## Keyboard Accessibility

- Toggle button is a standard `<button>` — Tab-focusable by default
- Enter/Space on focused button triggers onclick — standard browser behavior
- `aria-expanded="true/false"` communicates state to assistive technology

## CSS Changes

```css
td.trunc.has-toggle{overflow:visible;white-space:normal;vertical-align:top;max-width:260px}
td.trunc.has-toggle .cell-text{display:block;max-width:100%;overflow:hidden;
  text-overflow:ellipsis;white-space:nowrap}
.cell-toggle{display:inline-block;font-size:10px;padding:1px 5px;margin-top:2px;
  border-radius:3px;border:1px solid var(--line);background:transparent;
  color:var(--accent);cursor:pointer;line-height:1.4}
.cell-toggle:focus{outline:2px solid var(--accent);outline-offset:1px}
td.trunc.has-toggle.expanded{max-width:420px}
td.trunc.has-toggle.expanded .cell-text{overflow:visible;text-overflow:clip;
  white-space:pre-wrap;word-break:break-word;max-width:400px}
```

## Frontend Mutation Plan

### app/public/app.js
1. Add `expandedCells: new Set()` to `state` object
2. Update TRUNC_COLS branch in `renderTable()` — conditional toggle markup
3. Add `[data-cell-toggle]` handler in `bindRowActions()`

### app/public/style.css
Add 6 new rules (see CSS Changes above).

## Non-Scope

- No row-click behavior (P3-7)
- No double-click edit
- No dashboard cell changes
- No import preview table changes
- No user management table changes
- No Details modal changes (P3-5 provenance intact)
- No backend changes
- No schema changes

## P3-7 Dependency Note

P3-7 will add `<tr>` click. P3-7 must exclude `[data-cell-toggle]` button clicks.
The `e.stopPropagation()` in the toggle handler prevents future row-click propagation.

## Verification Plan

1. `node --check public/app.js` → 0
2. `bash scripts/invariant-check.sh` → 5/5 PASS
3. Smoke: long cell shows More → expand → Less → collapse
4. Smoke: empty/null/short cells show no toggle
5. Smoke: keyboard Tab + Enter toggles
6. Smoke: Details/Edit/Delete buttons still work
7. Regression: import, provenance modal, dashboard intact
