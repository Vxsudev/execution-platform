# Task: Update import panel with history and updated commit payload

## Parent Spec
specs/phase-3-import-batch-ledger.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `app/public/app.js` to extend the import panel with Import History and update the commit payload to include batch metadata.

### State additions

Add to the state initialization block (find the `const state = {` object and add):
```javascript
imports: [],
importFilename: null,
```

### New function: loadImports()

Add before `renderImportPanel()`:
```javascript
async function loadImports() {
  if (!isAdmin()) return;
  try {
    const d = await api('/imports');
    state.imports = d.imports || [];
  } catch (_) {
    state.imports = [];
  }
}
```

### renderImportPanel() — add Import History section

Inside the returned template string, add an "Import History" section at the bottom (after skipped rows section and before closing `</div>`):

```javascript
const historyHtml = isAdmin() ? (() => {
  if (!state.imports.length) return '<p class="import-note">No imports yet.</p>';
  return `<h3 class="import-h">Import History</h3>
    <div class="table-scroll"><table><thead><tr>
      <th>#</th><th>File</th><th>By</th><th>Date</th><th>Rows</th><th>Warnings</th><th>Status</th>
    </tr></thead><tbody>
      ${state.imports.map(b => `<tr>
        <td>${b.id}</td>
        <td>${esc(b.filename)}</td>
        <td>${esc(b.imported_by)}</td>
        <td>${esc((b.imported_at || '').slice(0, 16).replace('T', ' '))}</td>
        <td>${b.importable_rows ?? b.total_rows ?? '—'}</td>
        <td>${b.warning_count ?? '—'}</td>
        <td>${esc(b.status)}</td>
      </tr>`).join('')}
    </tbody></table></div>`;
})() : '';
```

Include `${historyHtml}` at the bottom of the returned template string.

### bindImportActions() — update preview handler

After `state.importPreview = data;`, add:
```javascript
state.importFilename = file.name;
```

### bindImportActions() — update commit payload

Change the commit `body` from:
```javascript
body: { rows: p.rows.map(r => r.data) }
```
to:
```javascript
body: {
  filename: state.importFilename || '',
  sheet: p.summary.sheet || '',
  rows: p.rows.map(r => ({ data: r.data, row_number: r.row_number })),
}
```

### bindImportActions() — after commit success

After `await loadRows(); renderApp();`, add a call to `loadImports()` followed by another `renderApp()`:
Actually, sequence should be: after commit success, call loadImports then renderApp. Restructure to:
```javascript
state.importPreview = null;
state.importFilename = null;
state.page = 'rows';
state.workspace = 'all';
await loadRows();
await loadImports();
renderApp();
alert(`Imported ${res.inserted_count} row(s)...`);
```

### Import tab entry

Find where the Import tab renders/activates. When entering the Import tab (state.page === 'import'), `loadImports()` must fire. Look for the navigation handler that sets `state.page = 'import'` and add `await loadImports(); renderApp();` after setting the page state, OR call `loadImports()` at the start of `renderImportPanel()` (as a side effect-free async fetch that triggers a re-render). The cleanest approach: call `loadImports().then(renderApp)` in the navigation click handler for the Import tab link.

Find: the nav link or button that sets state.page to 'import'. Add `loadImports().then(renderApp)` call after the state change.

### style.css additions (minor, if needed)

No new CSS classes should be needed — the import history table uses existing `.table-scroll`, `table`, `th`, `td`, and `.import-h` classes already present. Only add CSS if a style gap is discovered during implementation.

## Acceptance Criteria
- [ ] `state.imports` initialized to `[]`
- [ ] `state.importFilename` initialized to `null`
- [ ] `loadImports()` calls GET /api/imports and stores result in `state.imports`
- [ ] After entering Import tab, `loadImports()` fires and history renders
- [ ] After successful commit, `loadImports()` fires and history updates without page reload
- [ ] Commit payload includes `filename`, `sheet`, `rows: [{data, row_number}]`
- [ ] Import History section renders for admin
- [ ] Import History shows "No imports yet" when `state.imports` is empty
- [ ] Import History shows batch id, filename, imported_by, date, row count, warning count, status after commit
- [ ] No delete button in Import History (P3-2 scope)
- [ ] Existing preview behavior unchanged
- [ ] Existing Rows, Users, Dashboard panels unaffected
- [ ] Commit alert still shows inserted_count and skipped_count

## Files Likely Affected
- app/public/app.js
- app/public/style.css (minor, if needed)

## Blocked By
- tasks/phase-3-import-batch-ledger-002.md
