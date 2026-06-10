# Task: Add track enum check to validate() in app/server.js

## Parent Spec
specs/track-enum-server-validation.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description

Edit `app/server.js` ONLY. Do NOT modify db.js, app.js, style.css, or index.html.

TRACKS is already imported at line 6 — no import change needed.

### Change 1 — Add track enum check after the status enum check

Find the two existing enum check lines inside validate():
```javascript
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
```

Add a third line immediately after:
```javascript
  if (data.track !== undefined && !TRACKS.includes(data.track)) return 'invalid track';
```

### Change 2 — Add track merge check in the PUT merge block

Find the `if (existingRow) { ... }` block inside validate() which contains the required-field merge loop:
```javascript
    if (existingRow) {
      const merged = { ...existingRow, ...data };
      for (const field of REQUIRED_FIELDS) {
        if (!merged[field] || !String(merged[field]).trim()) return `${field} is required`;
      }
    }
```

Add a track canonicality check immediately after the REQUIRED_FIELDS loop, still inside the `if (existingRow)` block:
```javascript
      if (merged.track !== undefined && !TRACKS.includes(String(merged.track || '')))
        return 'invalid track';
```

The full updated `if (existingRow)` block should look like:
```javascript
    if (existingRow) {
      const merged = { ...existingRow, ...data };
      for (const field of REQUIRED_FIELDS) {
        if (!merged[field] || !String(merged[field]).trim()) return `${field} is required`;
      }
      if (merged.track !== undefined && !TRACKS.includes(String(merged.track || '')))
        return 'invalid track';
    }
```

### Change 3 — Update app/README.md

In the "API Validation" section, add a bullet after the existing PUT description:
- `track` must be one of: T1 AstraX Device, T2 AstraX Customer Cloud, T3 AstraX Ops Cloud, T4 Manufacturing partners, T5 Business, T6 Sales partner. Other values return HTTP 400.

## Acceptance Criteria
- [ ] validate() has `if (data.track !== undefined && !TRACKS.includes(data.track)) return 'invalid track';` after the status enum check.
- [ ] PUT merge block has track canonicality check inside `if (existingRow)`.
- [ ] REQUIRED_FIELDS loop and all existing enum checks (type, status) are unchanged.
- [ ] validate() signature `(data, partial, existingRow)` is unchanged.
- [ ] POST with invalid track → validate returns 'invalid track'.
- [ ] POST with valid canonical track → validate returns null (passes).
- [ ] No modification to db.js, app.js, style.css, or index.html.
- [ ] app/README.md API Validation section updated with canonical track values.

## Files Likely Affected
- `app/server.js`
- `app/README.md`

## Blocked By
- none
