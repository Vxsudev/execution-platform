# Task: Verify inclusive Sheet 2 capture on the operator's current workbook (disposable DB)

## Parent Spec
specs/sheet2-inclusive-import-capture.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify on disposable DBs only; live `app/data.db` never mutated. Use the operator's current
workbook `~/Downloads/astraX_JuneToNov_Experiment_All_Tracking (1).xlsx`.

Checks (in-session worker):
1. `node --check` app/server.js, app/db.js, app/public/app.js; `cd app && npm run`
2. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` byte-for-byte unchanged
3. **Preview** the current workbook → `importable_rows == 64` (was 63); the blank-title row
   (row 54, `owner=Abhilash`) is importable as `Untitled` with a "title blank" warning; **0**
   non-empty rows in skipped
4. **Commit** → `inserted_count == 64`; query temp DB: a row with `title='Untitled'`,
   `owner='Abhilash'`, `import_source_row=54` exists
5. Defaults still apply: blank owner→`Unassigned`, blank track→`Unassigned Track`, blank
   status→`Not Started`, non-canonical track stored as-is (spot-check from the workbook)
6. Fully-blank rows still excluded (importable count = title-bearing + blank-title-with-data only)
7. Preview `importable_rows` == commit `inserted_count`
8. Observations recorded; `DELETE /api/imports/:id` removes all imported rows (incl. Untitled);
   manual rows untouched
9. `bash scripts/invariant-check.sh` → 5/5; `git status` → only allowed surfaces

## Acceptance Criteria
- [x] `node --check` passes on server.js, db.js, public/app.js
- [x] Dev boot smoke prints running line; live `app/data.db` byte-for-byte unchanged
- [x] Current workbook preview: `importable_rows == 64` (was 63); blank-title row imports as `Untitled` with title-blank warning; 0 non-empty rows skipped
- [x] Commit `inserted_count == 64`; `Untitled`/`owner=Abhilash`/`import_source_row=54` row present in temp DB
- [x] Blank owner→Unassigned still applies (2 imported rows defaulted); non-canonical/defaults preserved
- [x] Fully-blank rows still excluded (64 imported + 11 fully-blank = 75 rows below header); preview == commit
- [x] Observations recorded (65 = 1 sheet + 64); batch delete removed all 64 imported rows; manual row preserved
- [x] `app/public/*`, `app/db.js`, schema, package/config/Railway docs unchanged (diff = app/server.js only)
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`
- [x] Consolidated verification harness: 8/8 assertions passed

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/sheet2-inclusive-import-capture-002.md
