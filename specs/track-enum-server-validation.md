# Spec: Track Enum Server Validation

## Status
approved

## Phase
phase-build

## Feature Slug
track-enum-server-validation

## Goal
Backend rejects arbitrary track values and accepts only the six canonical TRACKS values
exported from app/db.js. Closes the track enum bypass risk identified in the
canonical-track-taxonomy-enforcement recon.

## Recon
ai/recon/track-enum-server-validation-recon.md

## Allowed Mutation Surfaces
- app/server.js
- app/README.md
- ai/recon/track-enum-server-validation-recon.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/track-enum-server-validation.md
- tasks/track-enum-server-validation-001.md
- tasks/track-enum-server-validation-002.md
- tasks/track-enum-server-validation-003.md

Do NOT modify: app/db.js, app/public/app.js, app/public/style.css, app/public/index.html,
prototypes/, sdlc/.

Note: TRACKS is already imported in server.js from the canonical-track-taxonomy-enforcement
capability. No import change is needed.

## Data Model Changes
none

## API Surface

Extend `validate()` in `app/server.js` with track enum enforcement.

### Current state (confirmed by recon)

`TRACKS` is already imported at line 6:
```javascript
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');
```

Current enum checks at lines 93–94:
```javascript
if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
```

### Change 1 — Add track enum check after status check

After the status enum line, add:
```javascript
if (data.track !== undefined && !TRACKS.includes(data.track)) return 'invalid track';
```

### Change 2 — Add track merge check in PUT merge block

Inside the `if (existingRow) { ... }` block, after the required-field merge loop, add:
```javascript
if (merged.track !== undefined && !TRACKS.includes(String(merged.track || '')))
  return 'invalid track';
```

### Preservation requirements
- Required-field validation (REQUIRED_FIELDS loop) must remain unchanged.
- type enum check must remain unchanged.
- status enum check must remain unchanged.
- validate() signature `(data, partial, existingRow)` must remain unchanged.
- Error format: `{ "error": "..." }` HTTP 400 — unchanged.

### Behavior
- POST with track not in TRACKS → 400 `{ "error": "invalid track" }`.
- PUT with track (supplied) not in TRACKS → 400 `{ "error": "invalid track" }`.
- PUT that leaves merged row with non-canonical track → 400 `{ "error": "invalid track" }`.
- POST and PUT with canonical track values → pass through to downstream required/enum checks.

### README update
Update the API Validation section in `app/README.md` to state that `track` must be one
of the six canonical values. List the canonical tracks.

## Frontend Surface
none

## Verification Gate

1. Server boots on :3000.
2. Login admin/admin123 → 200.
3. POST with track "T2 Cloud" (invalid) → 400 `{ "error": "invalid track" }`.
4. POST with track "T3 AstraX Ops Cloud" (valid) → 201.
5. PUT setting track to "Fake Track" → 400 `{ "error": "invalid track" }`.
6. PUT setting track to "T5 Business" → 200.
7. GET /api/schema tracks array unchanged — all 6 canonical values present.
8. Required-field behavior unchanged: POST without owner → 400 "owner is required".
9. Type/status enum behavior unchanged: POST with invalid status → 400 "invalid status".
10. Invariants 5/5 PASS.
11. git status shows mutations only in app/server.js and app/README.md.
