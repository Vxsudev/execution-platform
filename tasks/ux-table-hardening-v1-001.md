# Task: Remove audit columns from default table; add Details row action with read-only modal

## Parent Spec
specs/ux-table-hardening-v1.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description

Edit `app/public/app.js` and `app/public/style.css`. Also update `app/README.md`.
Do NOT modify app/db.js, app/server.js, app/public/index.html.

### Change 1 — Remove audit columns from LIST_COLS (app.js line 12–16)

Change from:
```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'created_by', 'updated_by', 'created_at', 'updated_at', 'type',
];
```

To:
```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'type',
];
```

Also update the comment above LIST_COLS from:
`// Table columns: 13 Sheet-2 contract columns in workbook order, audit metadata, then Type tag.`
to:
`// Table columns: 13 Sheet-2 contract columns in workbook order, then a compact Type tag column.`

### Change 2 — Add Details button to row actions (app.js renderTable)

Find (lines 168–171):
```javascript
    return `<tr>${cells}<td><div class="row-actions">
      <button class="icon-btn" data-edit="${r.id}">Edit</button>
      <button class="icon-btn danger" data-del="${r.id}">Delete</button>
    </div></td></tr>`;
```

Change to:
```javascript
    return `<tr>${cells}<td><div class="row-actions">
      <button class="icon-btn" data-info="${r.id}">Details</button>
      <button class="icon-btn" data-edit="${r.id}">Edit</button>
      <button class="icon-btn danger" data-del="${r.id}">Delete</button>
    </div></td></tr>`;
```

### Change 3 — Bind Details button in bindRowActions()

Add at the top of `bindRowActions()`, before the `[data-edit]` block:
```javascript
  document.querySelectorAll('[data-info]').forEach((b) =>
    b.onclick = () => openDetails(state.rows.find((r) => r.id == b.dataset.info)));
```

### Change 4 — Add openDetails() function

Add as a new function immediately before `openForm()`:

```javascript
function openDetails(row) {
  const fields = [
    ['Created by', row.created_by || '—'],
    ['Updated by', row.updated_by || '—'],
    ['Created',    row.created_at || '—'],
    ['Updated',    row.updated_at || '—'],
  ];
  const back = document.createElement('div');
  back.className = 'modal-back';
  back.innerHTML = `
    <div class="modal modal-sm">
      <h2>${esc(row.title || 'Row details')}</h2>
      <dl class="detail-list">
        ${fields.map(([l, v]) => `<dt>${esc(l)}</dt><dd>${esc(v)}</dd>`).join('')}
      </dl>
      <div class="modal-actions">
        <button class="btn ghost" id="closeDetailsBtn">Close</button>
      </div>
    </div>`;
  document.body.appendChild(back);
  back.addEventListener('mousedown', (e) => { if (e.target === back) back.remove(); });
  back.querySelector('#closeDetailsBtn').onclick = () => back.remove();
}
```

### Change 5 — Add CSS for details modal (style.css)

Append to end of `app/public/style.css`:
```css
.modal-sm{width:320px}
.detail-list{margin:0 0 16px;display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px}
.detail-list dt{color:var(--muted)}
.detail-list dd{margin:0;color:var(--text)}
```

### Change 6 — Update README Audit Metadata description (app/README.md)

Find:
```
Audit fields are read-only. They are displayed in the table but are not editable in the create/edit form.
```

Replace with:
```
Audit fields are read-only. They are accessible via the **Details** button on each row,
which opens a small read-only panel. They do not appear as main table columns.
```

### Preservation requirements

- `AUDIT_LABELS` constant — keep intact (used by `openDetails` via `colLabel`)
- `colLabel()` — unchanged
- `TRUNC_COLS`, `SEARCH_COLS` — unchanged
- `filteredRows()`, `renderApp()`, `openForm()` — unchanged
- All filter behavior, CRUD behavior, audit stamping — unchanged

## Acceptance Criteria
- [ ] LIST_COLS contains 14 columns: owner, track, title, function_area, parent_item, hypothesis, design, success_criteria, target_end_date, dependencies, outcome, next_action, status, type.
- [ ] created_by, updated_by, created_at, updated_at are NOT in LIST_COLS.
- [ ] AUDIT_LABELS constant remains in app.js.
- [ ] Details button added to row actions (data-info attribute).
- [ ] [data-info] binding added to bindRowActions().
- [ ] openDetails() function exists and renders audit fields in a read-only modal.
- [ ] openDetails modal has no save/edit controls.
- [ ] .modal-sm and .detail-list added to style.css.
- [ ] README Audit Metadata description updated.
- [ ] openForm() is unchanged.
- [ ] filteredRows(), renderApp(), bindRowActions() preserve all existing behavior.

## Files Likely Affected
- `app/public/app.js`
- `app/public/style.css`
- `app/README.md`

## Blocked By
- none
