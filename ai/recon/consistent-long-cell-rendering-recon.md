# Recon: consistent-long-cell-rendering

**Feature slug:** consistent-long-cell-rendering
**State at recon:** RECON_READY
**Date:** 2026-06-18

---

## Files Inspected

- `app/public/app.js` (942 lines)
- `app/public/style.css` (205 lines)

---

## Current Table Render Path

1. `renderApp()` → for Rows page, renders `<div class="table-scroll" id="tableScroll">` and calls `refreshTable()`.
2. `refreshTable()` calls `filteredRows()` then `renderTable(rows)` and sets `innerHTML` of `#tableScroll`.
3. `renderTable(rows)` iterates `LIST_COLS` (14 columns) and produces `<tr>` per row with per-column cell rendering.
4. `bindRowActions()` attaches all click handlers after render.

---

## Column Definitions (app.js:36-47)

```js
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'type',
];

// Only these 4 get truncated rendering:
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);
```

---

## Current Long-Cell Render Path (app.js:293-303)

```js
if (TRUNC_COLS.has(k)) {
  const v = r[k] || '';
  if (v.length > 80) {
    const ck = `${r.id}:${k}`;
    const expanded = state.expandedCells.has(ck);
    return expanded
      ? `<td class="trunc has-toggle expanded" ...><span class="cell-text">${esc(v)}</span><button class="cell-toggle" ...>Less</button></td>`
      : `<td class="trunc has-toggle" ...><span class="cell-text">${esc(v)}</span><button class="cell-toggle" ...>More</button></td>`;
  }
  return `<td class="trunc" ...>${esc(v)}</td>`;
}
// ALL other columns fall through to:
return `<td data-col="${k}">${esc(r[k])}</td>`;
```

---

## Field-by-Field Rendering Behavior

| Column | Key | In TRUNC_COLS | Gets max-width? | Gets More? | Bug? |
|---|---|---|---|---|---|
| Owner | `owner` | No | No | No | Low risk — usually short username |
| Track | `track` | No | No | No | Low risk — track names are short |
| Experiment Title | `title` | **No** | **No** | **No** | **YES — can be long, stretches table** |
| Function | `function_area` | No | No | No | Low risk — usually short |
| Parent Item | `parent_item` | **No** | **No** | **No** | **YES — can be long multi-word text** |
| Description/Hypothesis | `hypothesis` | Yes | Yes | Yes | OK |
| Experiment Design | `design` | Yes | Yes | Yes | OK |
| Success Criteria | `success_criteria` | Yes | Yes | Yes | OK |
| Target End Date | `target_end_date` | No | No | No | Low risk — YYYY-MM-DD format |
| **Dependencies** | `dependencies` | **No** | **No** | **No** | **YES — primary bug. Long text, no bounds** |
| Outcome / Finding | `outcome` | Yes | Yes | Yes | OK |
| **Next Action** | `next_action` | **No** | **No** | **No** | **YES — can be long action text** |
| Status | `status` | No | No | No | OK — enum, always short |
| Type | `type` | No | No | No | OK — rendered as tag badge |

---

## CSS Layout Diagnosis

### Table base (`style.css:46-53`)
```css
table { border-collapse:collapse; width:100%; min-width:1700px; font-size:12.5px }
th,td { text-align:left; padding:4px 8px; height:30px; vertical-align:middle;
        white-space:nowrap; border-bottom:1px solid var(--line); border-right:1px solid var(--line) }
td.trunc { max-width:260px; overflow:hidden; text-overflow:ellipsis }
```

### Dense-cell reveal rules (`style.css:158-163`)
```css
td.trunc.has-toggle { overflow:visible; white-space:normal; vertical-align:top; max-width:260px }
td.trunc.has-toggle .cell-text { display:block; max-width:100%; overflow:hidden;
                                  text-overflow:ellipsis; white-space:nowrap }
.cell-toggle { display:inline-block; font-size:10px; padding:1px 5px; margin-top:2px;
               border-radius:3px; border:1px solid var(--line); background:transparent;
               color:var(--accent); cursor:pointer; line-height:1.4 }
.cell-toggle:focus { outline:2px solid var(--accent); outline-offset:1px }
td.trunc.has-toggle.expanded { max-width:420px }
td.trunc.has-toggle.expanded .cell-text { overflow:visible; text-overflow:clip;
                                           white-space:pre-wrap; word-break:break-word; max-width:400px }
```

### Table container (`style.css:44-45`)
```css
.table-scroll { overflow:auto; border:1px solid var(--line); border-radius:8px;
                background:var(--panel); max-height:calc(100vh - 170px) }
```

The `.table-scroll` has `overflow:auto` — it scrolls but DOES NOT cap horizontal width. With `white-space:nowrap` on `td`, any cell with a long value and no `max-width` will stretch the column indefinitely.

---

## Root Cause

**Single-line cause:** `TRUNC_COLS` (app.js:42) only lists 4 of 8 long-text-capable fields. The missing 4 — `dependencies`, `next_action`, `title`, `parent_item` — fall through to unconstrained `<td>` rendering with `white-space:nowrap`, causing infinite horizontal expansion.

The CSS infrastructure for bounded, truncated, More/Less cells is **complete and correct**. Only the field membership in `TRUNC_COLS` is wrong.

---

## Proposed Fix

**Minimal:** Extend `TRUNC_COLS` to include all long-text fields.

```js
// BEFORE (app.js:42)
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);

// AFTER
const TRUNC_COLS = new Set([
  'title', 'parent_item',
  'hypothesis', 'design', 'success_criteria',
  'dependencies', 'outcome', 'next_action',
]);
```

- No CSS changes needed.
- No HTML changes needed.
- No backend changes.
- Existing `td.trunc`, `td.trunc.has-toggle`, `.cell-text`, `.cell-toggle`, and `td.trunc.has-toggle.expanded` rules already handle all cases.
- `stopPropagation()` on `.cell-toggle` click (app.js:326) already prevents row-edit trigger when clicking More/Less.
- Short values (≤80 chars) in these fields will simply get `td.trunc` with bounded width and ellipsis. No More button shown unless content exceeds 80 chars.

---

## Risks

- **Title column:** Short titles (common) unaffected. Long titles get bounded truncation — acceptable since the full title is available in the Details modal and edit form.
- **Regression check:** Existing 4 TRUNC_COLS columns already work. Adding 4 more uses identical code path — no new logic introduced.
- **Event behavior:** `e.stopPropagation()` is already on the cell-toggle button. Row click handler guards `e.target.closest('button, a, input, select, textarea')` — More/Less button is a `<button>`, so row edit will not fire when clicking More.
- **Expanded state persistence:** `state.expandedCells` is a `Set` keyed by `${rowId}:${fieldKey}`. New field keys work identically.

---

## Verification Plan

1. `node --check app/public/app.js` — syntax check
2. Start local server: `cd app && npm start`
3. Load Rows table with rows containing long values in `dependencies`, `next_action`, `title`, `parent_item`
4. Verify: Dependencies cell shows bounded preview + More (not full-width text)
5. Verify: Clicking More expands content; does NOT open edit form
6. Verify: Clicking the table row (not More button) still opens edit form
7. Verify: hypothesis / design / success_criteria / outcome behavior unchanged
8. Verify: All Tracks / My Track filter still works
9. Verify: Filters and search still work
10. Verify: Dashboard, Users, Import pages unaffected
