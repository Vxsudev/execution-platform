# Spec: Backend Required Field Enforcement

## Status
approved

## Phase
phase-build

## Feature Slug
backend-required-field-enforcement

## Goal
Enforce required row fields at the backend API layer so raw API clients cannot create or
update invalid rows by bypassing frontend validation. The backend must reject create/update
requests that have missing or blank required fields: title, owner, track, status.

## Recon
ai/recon/backend-required-field-enforcement-recon.md

## Allowed Mutation Surfaces
- app/server.js
- app/README.md
- ai/recon/backend-required-field-enforcement-recon.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/backend-required-field-enforcement.md
- tasks/backend-required-field-enforcement-*.md

Do NOT modify: app/db.js, app/public/app.js, app/public/style.css, app/public/index.html,
prototypes/, sdlc/.

## Data Model Changes
none

## API Surface

Update `validate()` function in `app/server.js`.

### Required fields
Derive REQUIRED_FIELDS from ROW_FIELDS at module load time (do not hardcode strings):
```
const REQUIRED_FIELDS = ROW_FIELDS.filter(f => f.required).map(f => f.key);
```
This yields: ['owner', 'track', 'title', 'status'] (order matches ROW_FIELDS order).

### POST validation (partial=false)
All required fields must be present and non-blank after sanitize():
- For each field in REQUIRED_FIELDS: if (!data[field] || !String(data[field]).trim()) → return `${field} is required`
- POST with missing title → 400 `{ error: "title is required" }`
- POST with missing owner → 400 `{ error: "owner is required" }`
- POST with missing track → 400 `{ error: "track is required" }`
- POST with missing status → 400 `{ error: "status is required" }`

Remove the `if (!data.status) data.status = 'Not Started';` default assignment in the POST
route BEFORE validate() is called — status must now be explicitly supplied. (The frontend
already always sends status='Not Started' for new rows.)

### PUT validation (partial=true)
Two-stage check:
Stage 1 — Supplied field check: if any required field is present in data and is blank:
  return `${field} cannot be empty`
Stage 2 — Merge check: after merging existing row + incoming data, if any required field
  in the merged result is blank or null:
  return `${field} is required`
Pass the existing row to validate() as a third argument from the PUT route handler.

### Status enum check
Remove the `data.status !== ''` guard from the existing enum check. New check:
  `if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';`
Blank status is now caught by the required-field check before the enum check runs.

### validate() signature
```
function validate(data, partial, existingRow)
```
existingRow is only used for the PUT merge check (partial=true). Pass null for POST calls.

### Error format
All errors: `{ error: "..." }` with HTTP 400. No change to format — compatible with
existing frontend `throw new Error(data.error)` pattern.

### type default
The `if (!data.type) data.type = 'experiment';` default in the POST route remains.
type is not a required field.

## Frontend Surface
none

## Verification Gate

1. Server boots: `npm start` logs port on :3000.
2. Login: POST /api/login admin/admin123 → 200, cookie set.
3. POST without title → 400 `{ error: "title is required" }`.
4. POST without owner → 400 `{ error: "owner is required" }`.
5. POST without track → 400 `{ error: "track is required" }`.
6. POST without status → 400 `{ error: "status is required" }`.
7. POST with all required fields (title+owner+track+status) → 201.
8. PUT setting owner='' → 400 `{ error: "owner cannot be empty" }`.
9. PUT with valid partial update (status only) → 200.
10. Invariants 5/5 PASS.
11. UI modal: create row, edit row — both succeed (no regression).
12. No approval/dashboard/agent UI in any response.
