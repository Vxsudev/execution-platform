# Task: Add Delete button and handler to Import History in app.js

## Parent Spec
specs/phase-3-delete-import-batch.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `app/public/app.js` to add a Delete button per batch in Import History, with confirmation dialog and post-delete refresh.

### 1. Update historyHtml in renderImportPanel()

Find the import history table (around line 545). Current header:
```
<th>#</th><th>File</th><th>By</th><th>Date</th><th>Rows</th><th>Warnings</th><th>Status</th>
```

Add `<th>Action</th>` at the end.

In the batch row template, add a `<td>` with a delete button carrying `data-del-batch`:
```javascript
<td><button class="btn danger sm" data-del-batch="${b.id}">Delete</button></td>
```

### 2. Add delete handler in bindImportActions()

After the existing commit button handler, add delete button bindings. Because `bindImportActions()` is called after every `renderApp()`, use `querySelectorAll` to bind to the freshly rendered buttons:

```javascript
document.querySelectorAll('[data-del-batch]').forEach((btn) => {
  btn.onclick = async () => {
    const batchId = Number(btn.dataset.delBatch);
    const batch = state.imports.find(b => b.id === batchId);
    const rowCount = batch ? (batch.importable_rows ?? batch.total_rows ?? '?') : '?';
    const msg = `Delete import batch #${batchId}? This will permanently delete ${rowCount} imported row(s). Manual rows will not be touched. This cannot be undone.`;
    if (!confirm(msg)) return;
    setErr('');
    try {
      const res = await api('/imports/' + batchId, { method: 'DELETE' });
      await loadImports();
      await loadRows();
      renderApp();
      alert(`Deleted ${res.deleted_entry_count} imported row(s) from batch #${batchId}.`);
    } catch (e) {
      setErr(e.message || 'Delete failed.');
    }
  };
});
```

Verify that `api()` supports `{ method: 'DELETE' }` by checking existing usage in app.js (e.g., find where DELETE /api/rows/:id is called). Confirm the api helper's signature before writing.

### 3. Check/add .btn.sm CSS in style.css

Look up `app/public/style.css` for `.btn.sm` or similar compact button class. If absent, add to the button styles section:
```css
.btn.sm{font-size:11px;padding:2px 8px;height:22px}
```

If a compact class already exists, use it instead.

### Do NOT add

- No duplicate detection UI
- No provenance UI
- No changes to preview/commit sections
- No changes to Rows, Users, or Dashboard panels

## Acceptance Criteria
- [ ] `node --check app/public/app.js` exits 0
- [ ] Import History table header has "Action" column
- [ ] Each batch row has a Delete button with `data-del-batch` attribute
- [ ] Clicking Delete shows confirm dialog mentioning batch id and row count
- [ ] Canceling dialog does nothing
- [ ] Confirming calls DELETE /api/imports/:id
- [ ] After success: alert shows deleted_entry_count; history refreshes; rows table refreshes
- [ ] After error: importErr element shows error message
- [ ] No duplicate/provenance/true-capture UI added

## Files Likely Affected
- app/public/app.js
- app/public/style.css (minor, if .btn.sm needed)

## Blocked By
- tasks/phase-3-delete-import-batch-002.md
