# Task 003: Normalize Long-Cell Field Rendering

**Feature:** consistent-long-cell-rendering
**State:** COMPLETE
**Date:** 2026-06-18

## Objective

Extend `TRUNC_COLS` to include all long-text-capable fields so they render consistently with bounded width, truncation, and More/Less.

## File Modified

`app/public/app.js:42`

## Change

```js
// BEFORE:
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);

// AFTER:
const TRUNC_COLS = new Set([
  'title', 'parent_item',
  'hypothesis', 'design', 'success_criteria',
  'dependencies', 'outcome', 'next_action',
]);
```

## Why This Is Safe

- The rendering code at app.js:293-303 is already correct for TRUNC_COLS members.
- CSS rules `td.trunc`, `td.trunc.has-toggle`, `.cell-text`, `.cell-toggle`, `td.trunc.has-toggle.expanded` are already present and complete.
- Short values (≤80 chars) get `td.trunc` with max-width:260px + ellipsis. No More button.
- Long values (>80 chars) get `td.trunc.has-toggle` with preview + More button.
- No new code paths, no new CSS, no new HTML attributes.

## Status: COMPLETE
