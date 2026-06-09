# Task: Enforce required owner/track/status on create in server.js

## Parent Spec
specs/excel-like-team-summary-view.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Edit `app/server.js` ONLY. Routes, auth, and response shapes are unchanged.

Update the `validate(data, partial)` function so that on create (partial=false)
the following are required and non-empty (trimmed): title, owner, track, status.
- title: already enforced; keep.
- owner: if missing/blank on create → return 'owner is required'.
- track: if missing/blank on create → return 'track is required'.
- status: POST already defaults status to 'Not Started' before validate, so it
  will be present; still validate it is one of STATUSES.

On update (partial=true): only validate fields actually supplied (do not force
owner/track to be present). Keep the existing partial title check.

Keep `GET /api/schema` returning ROW_FIELDS (now including `help` and `required`)
— no code change needed there beyond what db.js exports.

Do NOT add new routes. Do NOT change auth or {rows}/{row} response shapes.
Do NOT modify any file outside app/server.js.

## Acceptance Criteria
- [ ] POST /api/rows with missing owner returns 400 'owner is required'.
- [ ] POST /api/rows with missing track returns 400 'track is required'.
- [ ] POST /api/rows with all of title/owner/track present (status defaulted) returns 201.
- [ ] PUT /api/rows/:id with a partial body (e.g. only status) still succeeds.
- [ ] Invalid status on create or update returns 400 'invalid status'.
- [ ] No new routes added; response shapes unchanged.

## Files Likely Affected
- `app/server.js`

## Blocked By
- tasks/excel-like-team-summary-view-001.md
