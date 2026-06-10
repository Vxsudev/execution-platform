# Spec: Canonical Track Taxonomy Enforcement

## Status
approved

## Phase
phase-build

## Feature Slug
canonical-track-taxonomy-enforcement

## Goal
Replace row-derived/free-text track behavior with a canonical workbook-derived track
taxonomy exposed by the backend schema and used by the frontend filter and create/edit form.
The app always shows all six astraX tracks in the filter and form regardless of DB content.

## Recon
ai/recon/canonical-track-taxonomy-enforcement-recon.md

## Allowed Mutation Surfaces
- app/db.js
- app/server.js
- app/public/app.js
- app/README.md
- ai/recon/canonical-track-taxonomy-enforcement-recon.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/canonical-track-taxonomy-enforcement.md
- tasks/canonical-track-taxonomy-enforcement-*.md

Do NOT modify: app/public/style.css, app/public/index.html, prototypes/, sdlc/.

## Data Model Changes

### Add TRACKS constant to app/db.js

After the STATUSES definition, add:

```javascript
const TRACKS = [
  'T1 AstraX Device',
  'T2 AstraX Customer Cloud',
  'T3 AstraX Ops Cloud',
  'T4 Manufacturing partners',
  'T5 Business',
  'T6 Sales partner',
];
```

### Update track ROW_FIELD from text input to select

Change the track entry in ROW_FIELDS from:
```javascript
{ key: 'track', label: 'Track', input: 'text', required: true,
  help: 'Select from T1 Device through T6 Sales. Links to the Jun–Nov roadmap.' }
```
to:
```javascript
{ key: 'track', label: 'Track', input: 'select', options: TRACKS, required: true,
  help: 'Select the astraX track this experiment belongs to. Links to the Jun–Nov roadmap.' }
```

### Update seed rows to use canonical track names

Change:
- `track: 'T1 Device'` → `track: 'T1 AstraX Device'`
- `track: 'T2 Cloud'` → `track: 'T2 AstraX Customer Cloud'`

### Export TRACKS

Change module.exports from:
```javascript
module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES };
```
to:
```javascript
module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS };
```

## API Surface

### Import TRACKS in app/server.js

Change the destructuring import from:
```javascript
const { db, ROW_FIELDS, ROW_TYPES, STATUSES } = require('./db');
```
to:
```javascript
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');
```

### Expose tracks in /api/schema

Change the schema response from:
```javascript
res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES });
```
to:
```javascript
res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES, tracks: TRACKS });
```

## Frontend Surface

### Add tracks to state in app/public/app.js

Add `tracks: []` to the state object:
```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' },
};
```

### Load schema.tracks on init

In the `init()` function where schema is loaded:
```javascript
const schema = await api('/schema');
state.fields = schema.fields; state.types = schema.types; state.statuses = schema.statuses;
state.tracks = schema.tracks || [];
```

### Replace distinctTracks() with state.tracks for the filter

In `renderApp()`, change the track filter select from:
```javascript
<select id="fTrack" title="Filter by track">${optionTags(distinctTracks(), state.filters.track)}</select>
```
to:
```javascript
<select id="fTrack" title="Filter by track">${optionTags(state.tracks, state.filters.track)}</select>
```

The `distinctTracks()` function is no longer used for the canonical filter. It may be removed or kept for reference — if kept, it must not be used for the filter select.

### Keep all other behavior

- CRUD (create, edit, delete) — unchanged
- Status/Type filters — unchanged
- Search — unchanged
- Row filter logic `if (track && r.track !== track) return false;` — unchanged

## Verification Gate

1. Server boots on :3000.
2. Login with admin/admin123 → 200.
3. `GET /api/schema` returns `tracks` array with all 6 canonical values in order.
4. Track filter `<select>` shows all 6 tracks even with a fresh 2-row seed.
5. New row modal track field is a `<select>` (not a free-text `<input type="text">`).
6. Create row with track = T3 AstraX Ops Cloud → 201, row appears in table.
7. Filter to T3 AstraX Ops Cloud → row is visible.
8. Edit row to track = T5 Business → 200.
9. Refresh → row persists with T5 Business.
10. Search still works across text columns.
11. Status and Type filters still work.
12. No escalation/approval/dashboard/agent UI.
13. Invariants 5/5 PASS.
14. git status shows mutations only within allowed surfaces.
