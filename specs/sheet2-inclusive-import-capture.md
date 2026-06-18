# Spec: Sheet 2 Inclusive Import Capture

## Status
approved

## Phase
phase-build

## Feature Slug
sheet2-inclusive-import-capture

## Depends On
Recon: ai/recon/sheet2-inclusive-import-capture-recon.md. Preserves duplicate detection, import batch delete integrity, access-control removal, row-click edit, DB_PATH, bootstrap, auth/session.

---

## Summary

Make Sheet 2 (`All Experiment Summary`) import fully inclusive: every non-empty item row becomes
an execution row. Recon (operator's current workbook) confirmed the one real omission — rows with
item data but a **blank Experiment Title** are skipped as `"title is required"` (e.g. row 54:
`owner=Abhilash`, `status=Not Started`). Fix: default a blank title to `Untitled` (informational
warning), matching the existing `Unassigned` / `Unassigned Track` / `Not Started` defaults. Blank
owner/track/status and non-canonical tracks were already warnings (not skips) and are unchanged.
Fully-blank rows are still dropped by the parser.

---

## Background

`classifyImportRow` (`app/server.js`) returns `importable:false, reason:'title is required'` for a
blank title. `parseImportWorkbook` already drops rows whose every mapped column is blank *before*
classification, so any row reaching classification has real data. Defaulting its blank title imports
a genuine item without ever importing an empty row. The side `STATUS SUMMARY` panel is in unmapped
columns and is never imported. `entries.title` is `TEXT NOT NULL`; a defaulted non-empty title
satisfies the schema (no schema change).

Operator current workbook Sheet 2: 63 title-bearing rows import today; 1 blank-title-with-data row
(row 54) dropped; 11 fully-blank dropped. After fix: 64 import, 0 non-empty rows dropped.

---

## Data Model Changes

none

---

## API Surface

`classifyImportRow` (used by both `POST /api/import/preview` and `POST /api/import/commit`,
`app/server.js`) changes its blank-title branch: instead of marking the row unimportable, it
defaults `title` to a new `IMPORT_UNTITLED = 'Untitled'` constant and pushes a warning
(`'title blank; set to Untitled'`). The row then imports like any other. No routes added/removed;
no other classification or default behavior changes. Preview and commit stay in agreement (same
function). Duplicate detection, observation capture, and batch delete are untouched.

---

## Frontend Surface

none — `app/public/app.js` import preview already renders `importable_rows` and per-row warnings;
the new "title blank" warning displays like the existing ones. No display mismatch.

---

## Non-Scope

- Sheet 1 (`Sample Experiment Log`) and Sheet 3 (`How To Use`) — untouched
- Whole-workbook observation capture, duplicate detection, batch delete — unchanged
- Access-control removal, row-click edit, DB_PATH, bootstrap, auth/session — unchanged
- No schema change; no `app/public/*`, package, config, or Railway-doc change
- No Docker, Postgres, deployment; no live `app/data.db` mutation
- Fully-blank rows remain excluded (parser drop, unchanged)

---

## Implementation Plan

### Task 1 — Backend: default blank title to Untitled in classifyImportRow (backend)

In `app/server.js`: add `const IMPORT_UNTITLED = 'Untitled';` beside the other open-mode defaults.
In `classifyImportRow`, replace the blank-title early return with: set `out.title = IMPORT_UNTITLED`
and push warning `'title blank; set to Untitled'`, then continue through the normal
owner/track/status defaulting. Keep everything else identical (owner/track/status defaults,
non-canonical track as-is, status/type coercion). The parser's fully-blank-row drop
(`parseImportWorkbook`) is unchanged, so empty rows are never imported.

### Task 2 — Frontend: confirm preview display needs no change (frontend)

Confirm `app/public/app.js` preview already shows `importable_rows` and the per-row Warnings column;
the new warning surfaces identically. No `app/public/*` change.

### Task 3 — Verification

Disposable DBs only (recon §12): preview the operator's current workbook → `importable == 64`,
row 54 present as `Untitled` with a title-blank warning, 0 non-empty rows skipped; commit →
`inserted_count == 64`, row 54 stored `title=Untitled, owner=Abhilash, import_source_row=54`;
blank/non-canonical defaults still apply; fully-blank still excluded; preview == commit; batch
delete still removes the imported rows; manual rows untouched; `node --check`; dev boot smoke;
invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/server.js` | `IMPORT_UNTITLED` constant + blank-title default in `classifyImportRow` |
| `ai/recon/...`, `specs/...`, `tasks/...`, `ai/state_registry.json`, `ai/engineering-journal.md` | OS artifacts |

---

## Verification Plan

See recon §12. Key assertions: operator's current workbook yields 64 importable (was 63), the
blank-title row imports as `Untitled` with a warning, fully-blank rows still excluded, preview ==
commit, duplicate/observation/batch-delete behavior preserved.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — confirm inclusive Sheet 2 import on the live deploy.
