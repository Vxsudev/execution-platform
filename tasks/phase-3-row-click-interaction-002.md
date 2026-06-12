# Task: Add row markup and module-level timer variable

## Parent Spec
specs/phase-3-row-click-interaction.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Two changes to `app/public/app.js`:
1. Add `let _rowClickTimer = null;` at module level (after the `state` block).
2. Update the `<tr>` template in `renderTable()` to add `class`, `data-row-id`, `tabindex`.

### Change 1 — Module-level timer (after state block, ~line 8)

Add this line after the closing `};` of the `state` object:

```javascript
let _rowClickTimer = null;
```

This timer is used by the click/dblclick handlers in task-003 to disambiguate single-click
(open Details after 200ms) from double-click (open Edit immediately, cancel timer).
Stored at module level so it persists across `refreshTable()` calls.

### Change 2 — <tr> markup in renderTable() (~line 274)

Current:
```javascript
return `<tr>${cells}<td><div class="row-actions">
```

Change to:
```javascript
return `<tr class="clickable-row" data-row-id="${r.id}" tabindex="0">${cells}<td><div class="row-actions">
```

This:
- Adds `.clickable-row` for CSS cursor/focus styles
- Adds `data-row-id` for event delegation lookup in bindRowActions
- Adds `tabindex="0"` for keyboard focus

### What must NOT change
- Cells render logic (TRUNC_COLS, status, type, etc.) — unchanged
- Actions column (Details/Edit/Delete buttons) — unchanged
- `state` object contents — unchanged

## Acceptance Criteria
- [ ] `let _rowClickTimer = null;` exists at module level
- [ ] `<tr>` in renderTable has `class="clickable-row"`
- [ ] `<tr>` has `data-row-id="${r.id}"`
- [ ] `<tr>` has `tabindex="0"`
- [ ] All cell rendering logic unchanged
- [ ] node --check public/app.js exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- tasks/phase-3-row-click-interaction-001.md
