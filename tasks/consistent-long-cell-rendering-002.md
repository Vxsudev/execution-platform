# Task 002: Spec Lock

**Feature:** consistent-long-cell-rendering
**State:** COMPLETE
**Date:** 2026-06-18

## Objective

Write and lock the spec defining the long-cell rendering contract, field coverage, truncation threshold, More behavior, event preservation, and non-scope.

## Deliverable

`specs/consistent-long-cell-rendering.md` — exists and is locked.

## Key decisions

- Threshold: 80 chars (matches existing TRUNC_COLS fields)
- Fields added: `title`, `parent_item`, `dependencies`, `next_action`
- Fields already handled: `hypothesis`, `design`, `success_criteria`, `outcome`
- No CSS changes needed
- No event handling changes needed
- One-line change to `TRUNC_COLS` in `app/public/app.js`

## Status: COMPLETE
