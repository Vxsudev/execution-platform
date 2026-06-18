# Spec: Consistent Long Cell Rendering

**Feature slug:** consistent-long-cell-rendering
**State:** SPEC_LOCKED
**Date:** 2026-06-18
**Recon:** ai/recon/consistent-long-cell-rendering-recon.md

---

## Goal

Make all long-text cells in the Rows table render consistently with bounded width, truncation, and the existing More/Less reveal affordance. No single cell can expand the table horizontally to an unusable width.

---

## Long-Cell Rendering Contract

All columns capable of holding long text must follow this contract:

1. **Bounded:** Cell width is capped at `max-width:260px` (collapsed) or `max-width:420px` (expanded).
2. **Truncated by default:** Short values (≤80 chars) display inline with ellipsis if they exceed the cell width. No More button shown.
3. **Preview + More for long values:** Values exceeding 80 chars show a one-line truncated preview and a `More` button.
4. **Expand on More:** Clicking More reveals the full content in-cell, up to 420px wide with `pre-wrap` wrapping. Button label changes to `Less`.
5. **Collapse on Less:** Clicking Less returns to truncated preview.
6. **More/Less does not open edit form:** The `.cell-toggle` button calls `stopPropagation()` — existing behavior, must remain.
7. **Row click opens edit:** Clicking any table row cell that is NOT a button opens the edit form — existing behavior, must remain.
8. **Clicked-cell field highlight:** Clicking a cell passes `data-col` to `openForm(row, focusKey)` — existing behavior, must remain.
9. **Table horizontal overflow:** Table scrolls inside `.table-scroll` (overflow:auto). No field can produce infinite-width expansion.
10. **No backend or data mutation:** Display layer only.

---

## Field Coverage

### Long-text fields (ALL must be in TRUNC_COLS):

| Column Label | Field Key | Already in TRUNC_COLS? | Action |
|---|---|---|---|
| Experiment Title | `title` | No | ADD |
| Parent Item | `parent_item` | No | ADD |
| Description / Hypothesis | `hypothesis` | Yes | Keep |
| Experiment Design | `design` | Yes | Keep |
| Success Criteria | `success_criteria` | Yes | Keep |
| Dependencies | `dependencies` | No | ADD |
| Outcome / Finding | `outcome` | Yes | Keep |
| Next Action | `next_action` | No | ADD |

### Short-value fields (excluded from TRUNC_COLS — no change):

- `owner` — username, always short
- `track` — track name, bounded enum
- `function_area` — short label
- `target_end_date` — YYYY-MM-DD format
- `status` — rendered as styled span
- `type` — rendered as tag badge

---

## Truncation Threshold

80 characters. Values ≤80 chars: `td.trunc` only (max-width + ellipsis). Values >80 chars: `td.trunc.has-toggle` with `.cell-text` preview and `.cell-toggle` More button.

This matches the existing threshold already used for `hypothesis`, `design`, `success_criteria`, `outcome`. No change to threshold value.

---

## More Behavior

- Existing pattern: `More` / `Less` toggle via `state.expandedCells` Set keyed by `${rowId}:${fieldKey}`.
- Existing CSS: `td.trunc.has-toggle.expanded` at 420px max-width, `.cell-text` uses `pre-wrap`.
- Existing event: `e.stopPropagation()` on `.cell-toggle` click prevents row edit.
- No changes to this mechanism — just more fields flow through it.

---

## Row-Click Interaction Preservation

- `tr.onclick` guard: `if (e.target.closest('button, a, input, select, textarea')) return;`
- More/Less is a `<button>` — the guard short-circuits before `openForm` is called.
- Cell clicked: `const cell = e.target.closest('td[data-col]')` — `data-col` attribute present on all cells. Field highlight in `openForm` works for all new TRUNC_COLS entries.
- No changes needed to event handling code.

---

## CSS Table Layout Contract

- `table { min-width:1700px }` — minimum table width, preserved.
- `th,td { white-space:nowrap }` — applies to all cells; `td.trunc.has-toggle` overrides with `white-space:normal`.
- `td.trunc { max-width:260px }` — caps all truncated cells at 260px.
- `td.trunc.has-toggle.expanded { max-width:420px }` — expanded cap.
- `.table-scroll { overflow:auto }` — horizontal scroll on table container.
- No CSS changes needed.

---

## Non-Scope

- No backend changes (server.js, db.js, schema, auth, MySQL)
- No import parser changes
- No row schema changes
- No column additions or removals
- No column label changes
- No reordering of LIST_COLS
- No change to Details modal rendering
- No change to Dashboard, Users, or Import pages
- No deployment

---

## Implementation

**One change, one file:**

```js
// app/public/app.js, line 42
// BEFORE:
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);

// AFTER:
const TRUNC_COLS = new Set([
  'title', 'parent_item',
  'hypothesis', 'design', 'success_criteria',
  'dependencies', 'outcome', 'next_action',
]);
```

---

## Verification Plan

1. `node --check app/public/app.js` — syntax clean
2. `npm start` in app/ — server starts on expected port
3. Load Rows page — table renders, all columns present
4. With a row containing long Dependencies text: cell shows bounded preview + More (not full-width)
5. Click More: content expands in-cell, no edit form opens
6. Click Less: returns to preview
7. Click table row (not button): edit form opens, field highlight on clicked column still works
8. Verify hypothesis/design/success_criteria/outcome behavior unchanged
9. Search, Status/Track/Type filters, All Tracks/My Track still work
10. Dashboard, Users, Import pages load without regression
