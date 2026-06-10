# Spec: UX Table Hardening V1

## Status
approved

## Phase
phase-build

## Feature Slug
ux-table-hardening-v1

## Goal
Remove audit metadata from the default always-visible table columns and expose it
through a per-row Details action. The execution table returns to 14 focused columns.
Audit metadata remains accessible but no longer clutters the daily standup view.

## Recon
ai/recon/ux-table-hardening-v1-recon.md

## Allowed Mutation Surfaces
- app/public/app.js
- app/public/style.css
- app/README.md
- ai/recon/ux-table-hardening-v1-recon.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/ux-table-hardening-v1.md
- tasks/ux-table-hardening-v1-001.md
- tasks/ux-table-hardening-v1-002.md
- tasks/ux-table-hardening-v1-003.md
- tasks/ux-table-hardening-v1-004.md

Do NOT modify: app/db.js, app/server.js, app/public/index.html, prototypes/, sdlc/.

---

## Data Model Changes
none

---

## API Surface
none

---

## Frontend Surface

All changes are in `app/public/app.js` and `app/public/style.css` only.

### Change 1 — Remove audit columns from LIST_COLS (app.js)

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

The `AUDIT_LABELS` constant and `colLabel()` update from the prior capability must remain intact
— they are still used by `openDetails()`.

### Change 2 — Add Details button to row actions (app.js)

In `renderTable()`, change the row actions from:
```javascript
return `<tr>${cells}<td><div class="row-actions">
  <button class="icon-btn" data-edit="${r.id}">Edit</button>
  <button class="icon-btn danger" data-del="${r.id}">Delete</button>
</div></td></tr>`;
```

To:
```javascript
return `<tr>${cells}<td><div class="row-actions">
  <button class="icon-btn" data-info="${r.id}">Details</button>
  <button class="icon-btn" data-edit="${r.id}">Edit</button>
  <button class="icon-btn danger" data-del="${r.id}">Delete</button>
</div></td></tr>`;
```

### Change 3 — Bind Details button in bindRowActions() (app.js)

Add before the existing `[data-edit]` binding:
```javascript
  document.querySelectorAll('[data-info]').forEach((b) =>
    b.onclick = () => openDetails(state.rows.find((r) => r.id == b.dataset.info)));
```

### Change 4 — Add openDetails() function (app.js)

Add as a new function after `bindRowActions()` and before `openForm()`:

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

**Key properties:**
- Read-only: no `data-k` inputs, no `querySelectorAll('[data-k]')`, no save action
- Row title shown so user knows which row they're viewing
- `|| '—'` fallback for NULL/empty audit values
- Reuses `.modal-back`, `.modal`, `.modal-actions`, `.btn.ghost` classes — zero new component patterns

### Change 5 — Add details modal CSS (style.css)

Append to the end of `app/public/style.css`:

```css
.modal-sm{width:320px}
.detail-list{margin:0 0 16px;display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px}
.detail-list dt{color:var(--muted)}
.detail-list dd{margin:0;color:var(--text)}
```

### Change 6 — Update README Audit Metadata section (app/README.md)

Update the description in the "Audit Metadata" section to note that fields are accessible
via the row Details action, not in the main table columns:

Replace:
```
Audit fields are read-only. They are displayed in the table but are not editable in the create/edit form.
```

With:
```
Audit fields are read-only. They are accessible via the **Details** button on each row,
which opens a small read-only panel. They do not appear as main table columns.
```

### Preservation requirements
- `AUDIT_LABELS` constant — keep (used by openDetails via colLabel, and retains extensibility)
- `colLabel()` — unchanged
- `TRUNC_COLS` — unchanged
- `SEARCH_COLS` — unchanged
- `filteredRows()` — unchanged
- `openForm()` — unchanged
- `renderApp()` — unchanged
- All filter behavior — unchanged
- All CRUD behavior — unchanged
- Backend audit stamping — unchanged (no server.js change)

---

## Verification Gate

1. Server boots on :3000.
2. Login admin/admin123 → 200.
3. Default table shows 14 columns: owner, track, title, function_area, parent_item, hypothesis,
   design, success_criteria, target_end_date, dependencies, outcome, next_action, status, type.
   No created_by / updated_by / created_at / updated_at as table columns.
4. Details button exists next to Edit / Delete for each row.
5. Click Details → modal opens showing row title + Created by / Updated by / Created / Updated.
6. Details modal is read-only (no save button, no editable fields).
7. Close Details modal → works; returns to table.
8. Create row still works → POST 201; new row appears in table.
9. Edit row still works → PUT 200; changes persist.
10. Delete row still works.
11. Search still works across text columns.
12. Track filter shows all 6 tracks.
13. Status filter works.
14. Type filter works.
15. Required-field validation still works (server and client).
16. Track enum validation still works.
17. Audit stamping still works: new row's Details shows created_by = 'admin'.
18. Refresh → all data and audit metadata persist.
19. No approval, escalation, dashboard, or agent UI.
20. Invariants 5/5 PASS.
21. git status shows only allowed surfaces modified.
