# RECON: canonical-track-taxonomy-enforcement

## Capability
Canonical Track Taxonomy Enforcement

## Date
2026-06-10

## State at Recon
RECON_READY

## Prior Recon
ai/recon/track-filter-source-recon.md (confirmed below)

---

## 1. Confirmed Findings

### Track filter is row-derived (confirmed)

`app/public/app.js` lines 92–93:
```javascript
function distinctTracks() {
  return [...new Set(state.rows.map((r) => r.track).filter(Boolean))].sort();
}
```
Used at line 115 for the `<select id="fTrack">` options. With a 2-row seed, exactly 2 tracks appear.

### /api/schema does not expose tracks (confirmed)

`app/server.js` line 65:
```javascript
res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES });
```
No `tracks` key.

### No TRACKS constant exists (confirmed)

`app/db.js` exports: `{ db, ROW_FIELDS, ROW_TYPES, STATUSES }` — no TRACKS.

### track field is text, not select (confirmed)

`app/db.js` line 22:
```javascript
{ key: 'track', label: 'Track', input: 'text', required: true, ... }
```

### Seed uses non-canonical values (confirmed)

- `'T1 Device'` — not in workbook (workbook: T1 AstraX Device / T1-Device)
- `'T2 Cloud'` — entirely app-invented, not in workbook at all

---

## 2. Canonical Track Decision

**Operator-authorised in directive:** Use Sheet 1 full names as canonical display/storage values.

| Canonical Track |
|-----------------|
| T1 AstraX Device |
| T2 AstraX Customer Cloud |
| T3 AstraX Ops Cloud |
| T4 Manufacturing partners |
| T5 Business |
| T6 Sales partner |

**Track field must be dropdown-only.** Free-text caused naming inconsistency in both the workbook and the app.

---

## 3. Changes Required

| File | Change |
|------|--------|
| `app/db.js` | Add `const TRACKS = [...]` with 6 canonical values. Change track `ROW_FIELD` from `input:'text'` to `input:'select', options: TRACKS`. Update seed rows from `'T1 Device'`/`'T2 Cloud'` to canonical names. Export TRACKS. |
| `app/server.js` | Import TRACKS from db.js. Add `tracks: TRACKS` to `/api/schema` response. |
| `app/public/app.js` | Add `tracks: []` to state. Load `state.tracks = schema.tracks` on init. Replace `distinctTracks()` with `state.tracks` for the track filter `<select>`. Keep `distinctTracks()` or remove it (it is no longer needed for the canonical filter). |
| `app/README.md` | Add canonical track taxonomy table; note track is dropdown-only. |

---

## 4. DB Impact

The `entries` table `track` column remains `TEXT` — no schema migration needed. The change is application-layer policy only: the form dropdown constrains input to canonical values, and the seed is updated to match.

Any existing rows with old non-canonical track values ('T1 Device', 'T2 Cloud') will persist in the DB unmodified. The filter will now show the canonical list regardless, so those rows will not be filtered out by the "T1 AstraX Device" filter option — they will only appear under "All" unless the user edits them to use the canonical value. This is acceptable for v1 (noted as residual risk).

---

## 5. Track Enum Validation

The directive says: "Raw API POST with invalid track is rejected if validation supported; if not, record as next risk."

The backend `validate()` function does not currently check if `track` is a valid enum value (unlike `type` and `status`). Adding this would require extending `validate()` in `server.js` to check `TRACKS.includes(data.track)`. This is NOT in the current allowed surfaces list for this capability — it is a separate future capability. **Recording as unresolved risk: track enum validation at API layer not implemented; raw API callers can still POST arbitrary track values.**

---

## 6. Risks

| Risk | Severity |
|------|----------|
| Existing DB rows with 'T1 Device' or 'T2 Cloud' persist; filter won't match them | LOW — DB reset fixes this; acceptable for demo |
| track enum not validated server-side (only constrained by UI dropdown) | MEDIUM — raw API bypass still possible; deferred |
| Schema change adds `tracks` to /api/schema — only consumer is app.js; no breakage | NONE |
