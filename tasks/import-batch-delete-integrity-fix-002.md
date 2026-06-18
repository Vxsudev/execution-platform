# Task: Confirm import-delete response display needs no frontend change

## Parent Spec
specs/import-batch-delete-integrity-fix.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Response-display check only (recon found the frontend needs no edit). The Import History delete
handler in `app/public/app.js` (`bindImportActions`, `data-del-batch`) renders the result using
`res.deleted_entry_count` and `res.deleted_observation_count`. After Task 1, `deleted_entry_count`
becomes the accurate total (linked + recovered legacy rows), so the existing message —
"Deleted N imported row(s) … M observation(s) removed." — is now correct without modification.
The new `deleted_legacy_count` field is additive and intentionally not surfaced (no UI redesign).

Outcome: **no change to `app/public/app.js`.** This task documents the deliberate decision so
the responsibility group is covered. Do not modify `app/public/*`.

## Acceptance Criteria
- [ ] Confirmed `app/public/app.js` delete handler reads `deleted_entry_count` + `deleted_observation_count`
- [ ] Those values are accurate after Task 1 (no display correction required)
- [ ] `app/public/app.js`, `app/public/style.css`, `app/public/index.html` unchanged

## Files Likely Affected
- (none — confirmation only)

## Blocked By
- tasks/import-batch-delete-integrity-fix-001.md
