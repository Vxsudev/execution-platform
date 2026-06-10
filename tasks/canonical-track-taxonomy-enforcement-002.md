# Task: Import TRACKS in server.js and expose via /api/schema

## Parent Spec
specs/canonical-track-taxonomy-enforcement.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description

Edit `app/server.js` ONLY. Do NOT modify db.js, app.js, style.css, or index.html.

### Step 1 — Import TRACKS in server.js

Find the require line at the top:
```javascript
const { db, ROW_FIELDS, ROW_TYPES, STATUSES } = require('./db');
```

Change it to:
```javascript
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');
```

### Step 2 — Expose tracks in /api/schema response

Find the schema route handler:
```javascript
app.get('/api/schema', requireAuth, (req, res) => {
  res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES });
});
```

Change it to:
```javascript
app.get('/api/schema', requireAuth, (req, res) => {
  res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES, tracks: TRACKS });
});
```

That is the only change needed in server.js. No other modifications.

## Acceptance Criteria
- [ ] TRACKS is imported from ./db in the destructuring require.
- [ ] GET /api/schema response includes `tracks` key with the 6 canonical values.
- [ ] No other change to server.js.
- [ ] No modification to db.js, app.js, style.css, or index.html.

## Files Likely Affected
- `app/server.js`

## Blocked By
- tasks/canonical-track-taxonomy-enforcement-001.md
