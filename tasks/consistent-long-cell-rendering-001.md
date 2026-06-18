# Task 001: Recon + Root Cause

**Feature:** consistent-long-cell-rendering
**State:** COMPLETE
**Date:** 2026-06-18

## Objective

Inspect frontend source, identify why Dependencies and other long-text fields expand the table horizontally, document root cause.

## Deliverable

`ai/recon/consistent-long-cell-rendering-recon.md` — exists and contains root cause.

## Root Cause (summary)

`TRUNC_COLS` at `app/public/app.js:42` only includes 4 of 8 long-text-capable fields:
`hypothesis`, `design`, `success_criteria`, `outcome`.

Missing: `title`, `parent_item`, `dependencies`, `next_action`.

Fields not in `TRUNC_COLS` render as plain `<td>` with `white-space:nowrap` and no `max-width`.
This causes unconstrained horizontal cell growth.

CSS infrastructure for bounded, truncated, More/Less cells is complete and correct — only field membership is wrong.

## Status: COMPLETE
