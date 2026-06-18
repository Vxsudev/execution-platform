# Task: Confirm import preview display needs no frontend change

## Parent Spec
specs/sheet2-inclusive-import-capture.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Preview-display check only (recon found nothing to change). The import preview in
`app/public/app.js` (`renderImportPanel`) shows `summary.importable_rows`, a per-row table with a
**Warnings** column, and the skipped-rows table. After Task 1, the previously-skipped blank-title
row appears as an importable row titled `Untitled` carrying the warning `'title blank; set to
Untitled'`, rendered identically to existing warnings. `importable_rows` increases accordingly
and the commit count matches. No display mismatch → **no change to `app/public/*`.**

Outcome: documents the deliberate decision so the responsibility group is covered. Do not modify
`app/public/app.js`, `app/public/index.html`, or `app/public/style.css`.

## Acceptance Criteria
- [ ] Confirmed preview renders `importable_rows` + per-row Warnings column (existing UI)
- [ ] New `Untitled` row + "title blank" warning surface via existing rendering (no code change)
- [ ] `app/public/app.js`, `app/public/index.html`, `app/public/style.css` unchanged

## Files Likely Affected
- (none — confirmation only)

## Blocked By
- tasks/sheet2-inclusive-import-capture-001.md
