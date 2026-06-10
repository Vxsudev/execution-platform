# Task: Display audit metadata columns in table; keep form audit-free

## Parent Spec
specs/data-model-audit-trail.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description

Edit `app/public/app.js` and `app/README.md` ONLY.

Do NOT modify app/public/index.html, app/public/style.css, app/db.js, or app/server.js.

### Change 1 — Add AUDIT_LABELS constant

After the `TYPE_LABEL` constant (line 8):
```javascript
const TYPE_LABEL = { experiment: 'Experiment', work_item: 'Work Item', task: 'Task' };
```

Add immediately after:
```javascript
const AUDIT_LABELS = { created_at: 'Created', updated_at: 'Updated', created_by: 'Created by', updated_by: 'Updated by' };
```

### Change 2 — Update colLabel() to check AUDIT_LABELS first

Change from:
```javascript
function colLabel(key) { return (state.fields.find((f) => f.key === key) || {}).label || key; }
```

To:
```javascript
function colLabel(key) { return AUDIT_LABELS[key] || (state.fields.find((f) => f.key === key) || {}).label || key; }
```

### Change 3 — Update LIST_COLS to include audit columns

Change from:
```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'type',
];
```

To:
```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'created_by', 'updated_by', 'created_at', 'updated_at', 'type',
];
```

### Change 4 — README Audit Metadata section

Add new "## Audit Metadata" section to `app/README.md` after the "API Validation" section:

```markdown
## Audit Metadata

Every row carries four server-controlled audit fields. The client cannot supply or override them.

| Field | When Set | Value |
|-------|----------|-------|
| `created_at` | On create | Server timestamp (UTC) |
| `created_by` | On create | Authenticated username from session |
| `updated_at` | On every update | Server timestamp (UTC) |
| `updated_by` | On every update | Authenticated username from session |

Audit fields are read-only. They are displayed in the table but are not editable in the create/edit form.
```

### What must NOT change

- `state.fields` / ROW_FIELDS — audit columns must NOT be added (form must stay audit-free)
- `openForm()` logic — unchanged
- `TRUNC_COLS`, `SEARCH_COLS` — unchanged
- `filteredRows()` — unchanged
- `renderTable()` inner rendering — the default `else` branch handles new columns automatically

## Acceptance Criteria
- [ ] `AUDIT_LABELS` constant added after `TYPE_LABEL`.
- [ ] `colLabel()` checks AUDIT_LABELS before state.fields.
- [ ] LIST_COLS includes `created_by`, `updated_by`, `created_at`, `updated_at` before `type`.
- [ ] Table header shows "Created by", "Updated by", "Created", "Updated" columns.
- [ ] Table rows show audit values (e.g. "admin", "system") in the new columns.
- [ ] Create/edit modal does NOT show audit fields.
- [ ] state.fields (ROW_FIELDS) unchanged — audit keys not added.
- [ ] SEARCH_COLS unchanged.
- [ ] TRUNC_COLS unchanged.
- [ ] app/README.md has new "Audit Metadata" section.

## Files Likely Affected
- `app/public/app.js`
- `app/README.md`

## Blocked By
- tasks/data-model-audit-trail-002.md
