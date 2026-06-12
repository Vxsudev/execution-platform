# Task: Surface true-capture counts in the Import panel

## Parent Spec
specs/phase-3-true-workbook-capture.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `app/public/app.js` (and `app/public/style.css` if needed) to surface
observation capture in the Import panel. Import panel only — no provenance
modal, no table UX, no dashboard changes.

### renderImportPanel() — preview summary

When preview present, extend the summary line with capture projection (only
when available):
- show `observed_sheet_count` sheets and projected `observation_count`
  observations, e.g. append:
  `· <span class="ok">${p.summary.observation_count} observation(s)</span>`
  when `p.summary.observation_count` is a number.
Keep all existing summary spans (importable, warnings, skipped, duplicates).

### renderImportPanel() — Import History table

Add an "Obs" column between Rows and Warnings (or after Warnings):
- header `<th>Obs</th>`
- cell `<td>${b.observation_count ?? '—'}</td>`
Keep the existing Action/Delete column last.

### bindImportActions() — commit payload + alert

1. Commit payload: add `skipped_rows: (state.importPreview.skipped_rows || [])`
   so parse-skipped rows are captured as observations server-side.
2. Post-commit alert: append observations + batch id, e.g.:
   ```javascript
   let msg = `Imported ${res.inserted_count} row(s)`;
   if (res.skipped_count) msg += `, ${res.skipped_count} skipped`;
   if (res.duplicate_skipped_count) msg += ` (${res.duplicate_skipped_count} duplicate(s) skipped)`;
   if (typeof res.observation_count === 'number') msg += ` · ${res.observation_count} observation(s) captured`;
   msg += ` · batch #${res.batch_id}`;
   alert(msg + '.');
   ```

### bindImportActions() — delete success alert

Append deleted observation count when returned:
```javascript
let m = `Deleted ${res.deleted_entry_count} imported row(s) from batch #${batchId}.`;
if (typeof res.deleted_observation_count === 'number') m += ` ${res.deleted_observation_count} observation(s) removed.`;
alert(m);
```

Preserve: existing preview rows table, duplicate badge + "Import duplicates
anyway" checkbox (P3-3), Delete batch button + confirm (P3-2), allow_duplicates
payload field, all error handling. Do NOT add a provenance modal or any
row/cell click behavior.

### style.css

Only add a style if a new class is introduced; reuse existing `.ok`/`.warn`
classes where possible. No layout changes beyond the added column.

## Acceptance Criteria
- [ ] Preview summary shows projected observation count when present
- [ ] Import History table has an observation count column
- [ ] Commit payload includes skipped_rows
- [ ] Commit payload still includes allow_duplicates (P3-3 preserved)
- [ ] Post-commit alert shows observations captured + batch id
- [ ] Delete success alert shows removed observation count when returned
- [ ] Duplicate badge + checkbox (P3-3) still render
- [ ] Delete batch button + confirm (P3-2) still work
- [ ] No provenance/table/dashboard UI added
- [ ] node --check app/public/app.js exits 0

## Files Likely Affected
- app/public/app.js
- app/public/style.css

## Blocked By
- tasks/phase-3-true-workbook-capture-002.md
