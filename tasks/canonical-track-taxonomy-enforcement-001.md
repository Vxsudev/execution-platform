# Task: Add TRACKS constant to db.js, convert track field to select, update seed rows

## Parent Spec
specs/canonical-track-taxonomy-enforcement.md

## Phase
phase-build

## Status
done

## Layer
database

## Description

Edit `app/db.js` ONLY. Do NOT modify server.js, app.js, style.css, or index.html.

### Step 1 — Add TRACKS constant after STATUSES

Find the line:
```javascript
const STATUSES = ['Not Started', 'In Progress', 'Complete', 'Blocked', 'Inconclusive'];
```

Immediately after it, add:
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

### Step 2 — Update track field in ROW_FIELDS from text to select

Find the track entry in ROW_FIELDS:
```javascript
  { key: 'track',           label: 'Track',                   input: 'text',     required: true,  help: 'Select from T1 Device through T6 Sales. Links to the Jun–Nov roadmap.' },
```

Replace it with:
```javascript
  { key: 'track',           label: 'Track',                   input: 'select',   options: TRACKS, required: true,  help: 'Select the astraX track this experiment belongs to. Links to the Jun–Nov roadmap.' },
```

### Step 3 — Update seed rows to canonical track names

Find the seed INSERT calls:
```javascript
  ins.run({ type: 'experiment', title: 'Sample experiment', owner: 'demo', track: 'T1 Device',
```
Change `track: 'T1 Device'` to `track: 'T1 AstraX Device'`.

Find:
```javascript
  ins.run({ type: 'work_item', title: 'Sample work item', owner: 'demo', track: 'T2 Cloud',
```
Change `track: 'T2 Cloud'` to `track: 'T2 AstraX Customer Cloud'`.

### Step 4 — Export TRACKS

Find the module.exports line:
```javascript
module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES };
```
Change it to:
```javascript
module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS };
```

## Acceptance Criteria
- [ ] TRACKS constant defined with exactly 6 canonical values in correct order.
- [ ] track ROW_FIELD has `input: 'select'` and `options: TRACKS`.
- [ ] track ROW_FIELD still has `required: true`.
- [ ] Seed row 1: `track: 'T1 AstraX Device'`.
- [ ] Seed row 2: `track: 'T2 AstraX Customer Cloud'`.
- [ ] module.exports includes TRACKS.
- [ ] No other file modified.

## Files Likely Affected
- `app/db.js`

## Blocked By
- none
