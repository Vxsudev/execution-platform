# RECON: track-filter-source-recon

## Capability
Track Filter Source Recon

## Date
2026-06-10

## Type
RECON ONLY — no implementation, no spec, no tasks

---

## 1. Files Inspected

- `app/public/app.js` — filter generation, state model
- `app/server.js` — /api/schema handler
- `app/db.js` — ROW_FIELDS definition, seed rows, constants
- `/Users/vasudevarao/Downloads/astraX_JuneToNov_Experiment_All_Tracking.xlsx` — via Python zipfile + openpyxl

---

## 2. Exact Code Path for Track Filter Generation

`app/public/app.js` lines 92–93:

```javascript
function distinctTracks() {
  return [...new Set(state.rows.map((r) => r.track).filter(Boolean))].sort();
}
```

`app/public/app.js` line 115:

```javascript
<select id="fTrack" title="Filter by track">${optionTags(distinctTracks(), state.filters.track)}</select>
```

`state.rows` is populated on boot via `GET /api/rows`, which returns all rows from the SQLite `entries` table. **The track dropdown is built entirely from the `track` column values present in the current database.** No canonical list is consulted.

---

## 3. Exact Source of Current Dropdown Values

The seed in `app/db.js` (lines 82–86) creates exactly two rows:

```javascript
ins.run({ ..., track: 'T1 Device', ... });
ins.run({ ..., track: 'T2 Cloud', ... });
```

When the DB is reset (fresh seed), `distinctTracks()` returns `['T1 Device', 'T2 Cloud']` — exactly two options. If the DB contains real rows with other track values, more options appear. But with a clean seed, only those two are ever shown.

`/api/schema` returns `{ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES }`.
**Tracks are not exposed by `/api/schema`.** There is no `TRACKS` constant in `db.js`.

The `track` field in `ROW_FIELDS` is type `'text'` (free-text input). The `help` text reads:
```
"Select from T1 Device through T6 Sales. Links to the Jun–Nov roadmap."
```
This is guidance only — the field is not a `<select>` with a canonical option list.

---

## 4. Workbook Track Taxonomy Found

Three naming conventions are present in the workbook — all inconsistent with each other:

### Convention A — Sheet 1 (taxonomy/legend, column A):
Full descriptive names used as row labels in the roadmap legend.

| Label |
|-------|
| T1 AstraX Device |
| T2 AstraX Customer Cloud |
| T3 AstraX Ops Cloud |
| T4 Manufacturing partners |
| T5 Business |
| T6 Sales partner |

### Convention B — Sheet 2 data validation (in-cell dropdown formula):
Shortcode names used as the actual allowed values in the Track dropdown in Sheet 2.
Extracted from `<dataValidation>` element: `formula1 = "T1-Device, T2-CustSaaS, T3-OPSSaaS, T4-Manufacturing, T5-Business, T6-Sales"`.

| Shortcode |
|-----------|
| T1-Device |
| T2-CustSaaS |
| T3-OPSSaaS |
| T4-Manufacturing |
| T5-Business |
| T6-Sales |

### Convention C — Actual Sheet 2 data cells (column B, rows 5–15):
The actual values in rows are inconsistent even within the sheet:

| Cell | Value |
|------|-------|
| B5 | `T1 Device` (space, no hyphen) |
| B6–B15 | `T1-Device` (hyphen) |

This means even in the workbook itself, users are not consistently using the dropdown — some cells have `T1 Device`, others `T1-Device`.

### Convention D — App seed rows (current in-use values):
| Seed row | Value |
|----------|-------|
| Sample experiment | `T1 Device` |
| Sample work item | `T2 Cloud` |

`T2 Cloud` appears nowhere in the workbook. It is an app-invented abbreviation.

---

## 5. Mismatch Table

| Workbook Canonical (Sheet 1) | Sheet 2 Dropdown Shortcode | App Seed Value | Status |
|------------------------------|---------------------------|----------------|--------|
| T1 AstraX Device | T1-Device | T1 Device | ⚠️ 3-way mismatch; T1 Device closest to seed but missing hyphen |
| T2 AstraX Customer Cloud | T2-CustSaaS | T2 Cloud | ❌ T2 Cloud is app-invented — not in workbook |
| T3 AstraX Ops Cloud | T3-OPSSaaS | (none in seed) | ❌ Missing from app |
| T4 Manufacturing partners | T4-Manufacturing | (none in seed) | ❌ Missing from app |
| T5 Business | T5-Business | (none in seed) | ❌ Missing from app |
| T6 Sales partner | T6-Sales | (none in seed) | ❌ Missing from app |

**Summary:** Only T1 appears in the app (with a name that doesn't match either workbook convention). T2 in the app is app-invented. T3–T6 are completely missing.

---

## 6. Root Cause

**Primary cause:** `distinctTracks()` builds the filter from `state.rows` at runtime. With only 2 seed rows, only 2 tracks appear. There is no canonical track constant — unlike `STATUSES` and `ROW_TYPES`, which are defined in `db.js` and exposed via `/api/schema`.

**Secondary cause:** The seed row track values do not match any of the workbook's naming conventions:
- `T1 Device` is close to `T1-Device` (Sheet 2 convention) but not exact
- `T2 Cloud` is entirely app-invented — has no workbook counterpart

**Consequence:** Even if real rows are added, track filter values will be inconsistent (T1-Device vs T1 Device vs T1 AstraX Device) unless a canonical list enforces normalization.

---

## 7. Recommended Fix

### 7a. Define a canonical `TRACKS` constant in `app/db.js`

Choose **one** naming convention (see 7b for recommendation) and define:
```javascript
const TRACKS = [
  'T1 AstraX Device',      // or shortcodes — see 7b
  'T2 AstraX Customer Cloud',
  'T3 AstraX Ops Cloud',
  'T4 Manufacturing partners',
  'T5 Business',
  'T6 Sales partner',
];
```

Export alongside existing exports: `module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS };`

### 7b. Which naming convention to use — operator decision required

The workbook contains **three incompatible conventions**. Do not decide silently.

| Option | Values | Pro | Con |
|--------|--------|-----|-----|
| **Sheet 1 full names** | T1 AstraX Device … T6 Sales partner | Descriptive; self-contained | Long; not what team types in Sheet 2 |
| **Sheet 2 shortcodes** | T1-Device … T6-Sales | Matches workbook in-use dropdown | Compact but non-obvious; T2-CustSaaS is cryptic |
| **Custom readable** | T1 Device … T6 Sales | Short, human-readable | Not in workbook at all; same problem as current seed |

**Recommendation:** Use **Sheet 1 full names** (T1 AstraX Device … T6 Sales partner). They are the only names that are self-documenting and correct without context. The Sheet 2 shortcodes are the team's current input convention, but they are inconsistently entered even in the workbook (T1-Device vs T1 Device in the same sheet). Locking to full names makes each track unambiguous in the app's display context. Note that existing real rows in the DB will have old values — a migration note or re-entry will be needed.

### 7c. Convert `track` field in ROW_FIELDS from `input: 'text'` to `input: 'select'`

Change db.js ROW_FIELDS track entry from:
```javascript
{ key: 'track', input: 'text', ... }
```
to:
```javascript
{ key: 'track', input: 'select', options: TRACKS, required: true, ... }
```

This ensures the modal enforces track selection from the canonical list (same pattern as `status` and `type`). **Free-text is the root of the naming inconsistency in the workbook.**

### 7d. Expose tracks via `/api/schema`

In `app/server.js`, change:
```javascript
res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES });
```
to:
```javascript
res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES, tracks: TRACKS });
```

### 7e. Use `schema.tracks` for filter dropdown, not `distinctTracks()`

In `app/public/app.js`, change `distinctTracks()` to use `state.tracks` (loaded from schema):
```javascript
state.tracks = schema.tracks;
// ...
<select id="fTrack" ...>${optionTags(state.tracks, state.filters.track)}</select>
```

This way all 6 tracks appear in the filter immediately after boot, regardless of what rows are in the DB.

### 7f. Update seed rows to use canonical track names

Update `app/db.js` seed:
```javascript
ins.run({ ..., track: 'T1 AstraX Device', ... });   // was 'T1 Device'
ins.run({ ..., track: 'T2 AstraX Customer Cloud', ... }); // was 'T2 Cloud'
```

---

## 8. Allowed Mutation Surfaces for Future Fix

Based on scope of changes required:

| File | Change |
|------|--------|
| `app/db.js` | Add TRACKS constant; update track ROW_FIELD from text→select with options; update seed values |
| `app/server.js` | Add `tracks: TRACKS` to /api/schema response |
| `app/public/app.js` | Load `state.tracks` from schema; replace `distinctTracks()` with `state.tracks` |
| `app/public/style.css` | No change expected |
| `app/public/index.html` | No change expected |
| `app/README.md` | Optional: document track taxonomy |

Do NOT modify:
- `prototypes/`
- `sdlc/`
- Any file outside `app/`

---

## 9. Free-Text vs Dropdown — Operator Decision Required

The directive asks: "Preserve free-text or restrict to dropdown only? Record recommendation, do not decide silently."

**Recommendation: Restrict to dropdown (select).**

Rationale:
- The workbook itself uses a data validation dropdown on column B — the team's intent is a constrained list
- Free-text entry caused T1-Device vs T1 Device inconsistency even within the workbook
- All other constrained fields (status, type) already use select; track should be consistent
- Users who need a new track category should update TRACKS in db.js (an OS-controlled mutation), not freestyle

**Risk of dropdown restriction:** Any existing rows in the DB with non-canonical track values (e.g., 'T2 Cloud') will still be stored and will not appear in the dropdown for editing. A data migration or re-entry would be needed for those rows.

---

## 10. Risks

| Risk | Severity | Notes |
|------|----------|-------|
| Existing rows with old track values won't match dropdown options | MEDIUM | Seed rows have non-canonical values; any real rows added since last DB reset also affected |
| Workbook and app track names diverge again if team updates workbook | LOW | TRACKS constant needs manual sync when workbook track taxonomy changes |
| Sheet 2 shortcodes are what team typed in practice | LOW | If team prefers shortcodes (T1-Device), using full names creates a new mismatch |
| `/api/schema` change is backward-incompatible if other clients consumed schema | NONE | Only one consumer: app.js |
