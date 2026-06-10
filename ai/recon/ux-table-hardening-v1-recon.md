# RECON: ux-table-hardening-v1

## Capability
UX Table Hardening V1

## Date
2026-06-10

## State at Recon
RECON_READY

## Prior Work
- `data-model-audit-trail` (RELEASE_APPROVED) — added created_by/updated_by to DB and server.
  Added AUDIT_LABELS, updated colLabel(), added all 4 audit columns to LIST_COLS.
- All prior capabilities RELEASE_APPROVED; working tree clean.

---

## 1. Current Table Column Model

`app/public/app.js` lines 11–16:

```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'created_by', 'updated_by', 'created_at', 'updated_at', 'type',
];
```

**18 columns** in the default view. The 4 audit columns (`created_by`, `updated_by`, `created_at`,
`updated_at`) are appended to the end of execution columns, before `type`.

**UX issue**: The table is already wide with 14 execution columns. 4 additional audit columns
push the horizontally-scrollable table significantly wider. For day-to-day execution tracking,
audit metadata is low-frequency information that clutters the default scan.

---

## 2. Current Audit Metadata Infrastructure

### AUDIT_LABELS (app.js line 9)
```javascript
const AUDIT_LABELS = { created_at: 'Created', updated_at: 'Updated', created_by: 'Created by', updated_by: 'Updated by' };
```
Already present. colLabel() checks this before state.fields. ✅

### colLabel() (app.js line 91)
```javascript
function colLabel(key) { return AUDIT_LABELS[key] || (state.fields.find((f) => f.key === key) || {}).label || key; }
```
Audit labels work correctly. ✅

### Audit columns NOT in ROW_FIELDS
Audit fields are not in `state.fields` (ROW_FIELDS) so the form never renders them. ✅

### API row responses include audit metadata
`SELECT * FROM entries` returns all columns including `created_by`, `updated_by`, `created_at`,
`updated_at`. Every row in `state.rows` already has these fields. ✅

---

## 3. Current Row Actions (app.js lines 168–171)

```javascript
return `<tr>${cells}<td><div class="row-actions">
  <button class="icon-btn" data-edit="${r.id}">Edit</button>
  <button class="icon-btn danger" data-del="${r.id}">Delete</button>
</div></td></tr>`;
```

Currently: Edit + Delete only. No Details/Info action. Adding a third action here is the
minimal, consistent pattern.

### bindRowActions() (lines 176–184)
```javascript
function bindRowActions() {
  document.querySelectorAll('[data-edit]').forEach((b) =>
    b.onclick = () => openForm(state.rows.find((r) => r.id == b.dataset.edit)));
  document.querySelectorAll('[data-del]').forEach((b) =>
    b.onclick = async () => {
      if (!confirm('Delete this row?')) return;
      await api('/rows/' + b.dataset.del, { method: 'DELETE' });
      await loadRows(); renderApp();
    });
}
```

Binds by data attribute. Adding `[data-info]` binding follows the same pattern. ✅

---

## 4. Modal Infrastructure (app.js lines 211–244, style.css lines 71–82)

Existing modal CSS:
```css
.modal-back{position:fixed;inset:0;background:rgba(0,0,0,.55);...}
.modal{background:var(--panel);border:1px solid var(--line);border-radius:14px;width:600px;max-width:100%;padding:22px}
```

The details modal can reuse `.modal-back` + `.modal` classes. It needs a narrower width and a
definition-list style for 4 label-value pairs. Minimal new CSS:
```css
.modal-sm{width:320px}
.detail-list{margin:0 0 16px;display:grid;grid-template-columns:auto 1fr;gap:6px 16px;font-size:13px}
.detail-list dt{color:var(--muted)}
.detail-list dd{margin:0;color:var(--text)}
```

No structural CSS changes needed. Dark theme variables already defined in `:root`. ✅

---

## 5. UX Issue Summary

| Issue | Severity | Fix |
|-------|----------|-----|
| 4 audit columns in default table = 18 total visible columns | HIGH — clutters execution scan | Remove from LIST_COLS |
| No way to view audit metadata after removal | HIGH — audit data inaccessible | Add Details button → read-only modal |
| Edit/Delete-only row actions | LOW | Add Details button (same icon-btn style) |

---

## 6. Recommended Changes

### app/public/app.js

1. **LIST_COLS**: Remove `created_by`, `updated_by`, `created_at`, `updated_at`. Back to 14 columns.
2. **renderTable row actions**: Add `<button class="icon-btn" data-info="${r.id}">Details</button>` before Edit.
3. **bindRowActions**: Add `[data-info]` binding → calls `openDetails(row)`.
4. **New function `openDetails(row)`**: Renders a small read-only modal with 4 audit fields.

### app/public/style.css

Add 4 lines for `.modal-sm` (narrower details modal) and `.detail-list` (2-col label/value grid).

### app/README.md

Update the Audit Metadata section to note that audit fields are accessible via the Details row action.

---

## 7. openDetails() Design

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

- Uses existing `.modal-back` / `.modal` / `.modal-actions` / `.btn.ghost` classes
- Read-only: no `data-k` inputs, no `[data-k]` querySelectorAll, no save button
- Row title shown in `<h2>` so the user knows which row they're viewing
- `row.created_by || '—'` gives a clean fallback for NULL/empty values

---

## 8. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Users previously relied on audit columns in the table | LOW — feature was added in the same session; no users have adapted | Audit data is still accessible |
| Multiple details modals if user clicks quickly | LOW | Each click appends a new modal-back; user can close individually |
| `id="closeDetailsBtn"` not unique if multiple modals open | LOW | `.querySelector('#closeDetailsBtn')` scopes to the `back` element — works correctly per-modal |

---

## 9. Invariant Interactions

No backend changes → INV-001, INV-003, INV-004, INV-005, INV-006 unaffected.
No DB or API change — audit stamping behavior preserved.
No approval/escalation/dashboard/agent scope introduced.

---

## 10. Recommended Mutation Surfaces

| File | Change |
|------|--------|
| `app/public/app.js` | Remove audit from LIST_COLS; add Details button + binding + openDetails() |
| `app/public/style.css` | Add .modal-sm and .detail-list (4 lines) |
| `app/README.md` | Update Audit Metadata section |

No backend, DB, or other file changes needed.
