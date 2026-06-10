# RECON: track-enum-server-validation

## Capability
Track Enum Server Validation

## Date
2026-06-10

## State at Recon
RECON_READY

## Prior Work
- `canonical-track-taxonomy-enforcement` (RELEASE_APPROVED) added TRACKS constant to db.js, changed track field to select, exposed tracks in /api/schema.
- `backend-required-field-enforcement` (RELEASE_APPROVED) added required-field enforcement for owner/track/title/status.
- TRACKS is already imported in server.js. The only gap is the enum check.

---

## 1. Confirmed Findings from Code

### TRACKS constant (app/db.js line 17–24)
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
Exported at line 97: `module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }`.

### TRACKS is already imported in server.js
Line 6:
```javascript
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');
```
No import change needed.

### /api/schema already exposes tracks
Line 65:
```javascript
res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES, tracks: TRACKS });
```
No schema route change needed.

### Frontend uses state.tracks from schema
app/public/app.js: `state.tracks = schema.tracks || []` and filter uses `state.tracks`.
No frontend change needed (error shape `{ error: "..." }` is already handled by `catch (e) { formErr.textContent = e.message }`).

### Current validate() — the gap (lines 76–95)
```javascript
function validate(data, partial, existingRow) {
  if (!partial) {
    for (const field of REQUIRED_FIELDS) {
      if (!data[field] || !String(data[field]).trim()) return `${field} is required`;
    }
  } else {
    for (const field of REQUIRED_FIELDS) {
      if (data[field] !== undefined && !String(data[field] || '').trim())
        return `${field} cannot be empty`;
    }
    if (existingRow) {
      const merged = { ...existingRow, ...data };
      for (const field of REQUIRED_FIELDS) {
        if (!merged[field] || !String(merged[field]).trim()) return `${field} is required`;
      }
    }
  }
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
  // MISSING: track enum check
  return null;
}
```

**Gap confirmed:** No check for `data.track` against `TRACKS`. A raw POST or PUT with `track: "T2 Cloud"` or any arbitrary string currently passes validation.

---

## 2. Exact Change Required

Three additions to validate():

**A. Enum check for direct track value (after status enum check):**
```javascript
if (data.track !== undefined && !TRACKS.includes(data.track)) return 'invalid track';
```

**B. Merge check for PUT (inside the `if (existingRow)` block, after required-field merge check):**
```javascript
if (merged.track !== undefined && !TRACKS.includes(String(merged.track || '')))
  return 'invalid track';
```
This rejects any PUT that would leave the row with a non-canonical track (e.g., an existing row with an old track value that isn't updated).

**C. Error string:** `'invalid track'` — consistent with existing `'invalid type'` and `'invalid status'` pattern.

---

## 3. Interaction With Required-Field Check

For POST (partial=false):
1. REQUIRED_FIELDS loop runs first → track must be present and non-blank
2. Then enum check: if track is not in TRACKS → 'invalid track'

For PUT (partial=true):
1. Supplied-field required check: if track supplied and blank → 'track cannot be empty'
2. Merge required check: merged.track must be non-blank
3. Direct enum check (new): if track supplied and not in TRACKS → 'invalid track'
4. Merge enum check (new): merged.track must be in TRACKS

Order is correct — required check runs before enum check, so no short-circuit conflict.

---

## 4. No Frontend Change Needed

The frontend modal already catches errors:
```javascript
} catch (e) { back.querySelector('#formErr').textContent = e.message; }
```
And the api() util: `throw new Error((data && data.error) || ('Request failed: ' + res.status))`.
A 400 `{ "error": "invalid track" }` will display "invalid track" in the form error area. No modification required.

---

## 5. Scope Confirmation

No approval, escalation, dashboard, agent, or NDT-SaaS code in scope. Single-file change (server.js).

---

## 6. Risks

| Risk | Severity |
|------|----------|
| Existing DB rows with non-canonical track ('T2 Cloud') will fail PUT merge check | LOW — DB was reset during canonical-track-taxonomy-enforcement verification; seed now uses canonical tracks |
| REQUIRED_FIELDS loop for track covers blank-track case before enum check — no redundancy conflict | NONE |
| No schema or export change needed | NONE |

---

## 7. Recommended Mutation Surfaces

| File | Change |
|------|--------|
| `app/server.js` | Add 2 track enum checks in validate() |
| `app/README.md` | Update API Validation section: track must be canonical |

No other file needs modification.
