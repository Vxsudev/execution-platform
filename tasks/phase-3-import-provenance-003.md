# Task: Redesign openDetails() for full row content and import provenance

## Parent Spec
specs/phase-3-import-provenance.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Replace the current minimal `openDetails(row)` with a fully-featured async version
that shows three labeled sections: Row Content, Audit, and Provenance. The modal
must use `.modal-wide` and the CSS classes from task-002.

### Row field order and labels

Display all fields in this order (skip if null/empty — show '—' fallback):

| Key | Label | Long text? |
|---|---|---|
| type | Type | |
| title | Experiment Title | |
| owner | Owner | |
| track | Track | |
| function_area | Function | |
| parent_item | Parent Item | |
| hypothesis | Description / Hypothesis | yes |
| design | Experiment Design | yes |
| success_criteria | Success Criteria | yes |
| target_end_date | Target End Date | |
| dependencies | Dependencies | |
| outcome | Outcome / Finding | yes |
| next_action | Next Action | |
| status | Status | |

Long-text fields render as:
```html
<div class="detail-long-label">{label}</div>
<div class="detail-long">{esc(value) || '—'}</div>
```
in the same `.detail-grid` container.

Compact fields render as:
```html
<div class="detail-label">{label}</div>
<div class="detail-value">{esc(value) || '—'}</div>
```

### Audit section

Four compact rows: Created by, Created at, Updated by, Updated at.

### Provenance section

```javascript
if (row.import_batch_id) {
  // Lazy-load enrichment for admin
  if (isAdmin() && !state.imports.length) await loadImports();
  const batchMeta = state.imports.find(b => b.id === row.import_batch_id) || null;
  // Render Imported badge + batch fields
} else {
  // Render Manual / Legacy badge
}
```

**Imported row provenance fields:**
- Origin: `<span class="origin-badge imported">Imported</span>`
- Import Batch: `#${row.import_batch_id}`
- Source Sheet: `row.import_source_sheet || '—'`
- Source Row: `row.import_source_row != null ? row.import_source_row : '—'`
- When batchMeta available: Filename, Imported by, Imported at (sliced to 16 chars, T→space), Batch status, Observations

**Manual/legacy row:**
- Origin: `<span class="origin-badge manual">Manual / Legacy</span>`
- Note: `Row was created or updated manually. No import batch.`

### Full function signature

```javascript
async function openDetails(row) {
  if (row.import_batch_id && isAdmin() && !state.imports.length) {
    await loadImports();
  }
  // ... build sections and modal HTML ...
}
```

### Call site (line 277)
Existing `b.onclick = () => openDetails(state.rows.find(...))` — no change needed.
An async function called without await returns a Promise which browsers handle silently.
The modal renders after the await (loadImports), no change to event binding is needed.

### Modal structure
```html
<div class="modal-back">
  <div class="modal modal-wide">
    <h2>{title}</h2>
    <div class="detail-section">
      <h3>Row Content</h3>
      <div class="detail-grid">
        <!-- compact fields -->
        <!-- long text fields with .detail-long-label + .detail-long -->
      </div>
    </div>
    <div class="detail-section">
      <h3>Audit</h3>
      <div class="detail-grid"><!-- 4 audit rows --></div>
    </div>
    <div class="detail-section">
      <h3>Provenance</h3>
      <div class="detail-grid"><!-- provenance rows --></div>
    </div>
    <div class="modal-actions">
      <button class="btn ghost" id="closeDetailsBtn">Close</button>
    </div>
  </div>
</div>
```

### What to preserve
- Existing `.modal-back` click-to-close behavior
- `#closeDetailsBtn` close button
- `esc()` used on all user-controlled strings
- No edit/write paths introduced
- No row-click event added to the table
- No inline cell reveal

## Acceptance Criteria
- [ ] openDetails is async
- [ ] Modal uses .modal-wide (760px)
- [ ] All 14 row fields render (compact or long-text)
- [ ] Audit section shows 4 fields
- [ ] Imported row shows Imported badge + batch id + source sheet + source row
- [ ] Admin + imported row: shows filename/imported_by/imported_at when batchMeta available
- [ ] Manual row shows Manual/Legacy badge + note
- [ ] NULL import_batch_id does not crash
- [ ] Lazy loadImports() called for admin + imported row + empty state.imports
- [ ] esc() used on all displayed values
- [ ] click-to-close on .modal-back preserved
- [ ] Close button works
- [ ] No row-click added to table
- [ ] No inline cell reveal
- [ ] node --check public/app.js exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- tasks/phase-3-import-provenance-002.md
