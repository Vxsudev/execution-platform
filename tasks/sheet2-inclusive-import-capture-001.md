# Task: Default blank Experiment Title to "Untitled" in classifyImportRow

## Parent Spec
specs/sheet2-inclusive-import-capture.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Make Sheet 2 import inclusive by defaulting a blank title instead of skipping the row, in
`app/server.js`.

1. Add a constant beside the existing open-mode defaults
   (`IMPORT_UNASSIGNED_OWNER`/`IMPORT_UNASSIGNED_TRACK`/`IMPORT_DEFAULT_STATUS`):
   `const IMPORT_UNTITLED = 'Untitled';`
2. In `classifyImportRow`, replace the blank-title early return
   ```js
   if (!title) return { importable: false, reason: 'title is required' };
   ```
   with logic that keeps the row importable: set the working title to `IMPORT_UNTITLED` when
   blank and record a warning `'title blank; set to Untitled'`. Ensure `out.title` ends up as
   the trimmed real title when present, or `IMPORT_UNTITLED` when blank. Continue through the
   existing owner/track/status defaulting + warnings unchanged.

Keep everything else identical: owner→`Unassigned`, track→`Unassigned Track`, non-canonical track
imported as-is (warning), blank/non-canonical status→`Not Started`, type coercion. Do NOT change
`parseImportWorkbook` (its fully-blank-row drop stays, so empty rows are never imported). Do NOT
change duplicate detection, observation capture, the commit insert, `app/db.js`, schema, or
`app/public/*`.

## Acceptance Criteria
- [ ] `IMPORT_UNTITLED = 'Untitled'` constant added with the other import defaults
- [ ] `classifyImportRow` no longer returns `importable:false` for a blank title; it defaults to `Untitled` + warning
- [ ] A blank-title row that has other data is now importable (e.g. `owner=Abhilash`, no title → `title=Untitled`)
- [ ] Blank owner/track/status defaults and non-canonical-track-as-is behavior unchanged
- [ ] `parseImportWorkbook` fully-blank-row drop unchanged (empty rows still excluded)
- [ ] Duplicate detection, observation capture, commit insert, `app/db.js`, schema unchanged
- [ ] `node --check app/server.js` passes

## Files Likely Affected
- app/server.js (IMPORT_UNTITLED constant + classifyImportRow blank-title branch)

## Blocked By
- none
