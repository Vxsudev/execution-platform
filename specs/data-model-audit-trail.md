# Spec: Data Model Audit Trail

## Status
approved

## Phase
phase-build

## Feature Slug
data-model-audit-trail

## Goal
Add durable accountability metadata to execution rows so each record carries creation and
update traceability: who created it, who last updated it, and when. Metadata is stamped
server-side from the authenticated session; the client cannot supply or override it.

## Recon
ai/recon/data-model-audit-trail-recon.md

## Allowed Mutation Surfaces
- app/db.js
- app/server.js
- app/public/app.js
- app/README.md
- ai/recon/data-model-audit-trail-recon.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/data-model-audit-trail.md
- tasks/data-model-audit-trail-001.md
- tasks/data-model-audit-trail-002.md
- tasks/data-model-audit-trail-003.md
- tasks/data-model-audit-trail-004.md

Do NOT modify: app/public/index.html, app/public/style.css, prototypes/, sdlc/.

---

## Data Model Changes

Add two new columns to the `entries` table in `app/db.js`.

### New Columns

| Column | Type | Nullable | Stamped By |
|--------|------|----------|------------|
| `created_by` | TEXT | YES | Backend: `req.user.username` on POST |
| `updated_by` | TEXT | YES | Backend: `req.user.username` on POST + PUT |

`created_at` and `updated_at` already exist in the schema — no DDL change needed for those.

### Migration (additive, idempotent)

After the existing `db.exec(CREATE TABLE...)` block, add:

```javascript
try { db.exec("ALTER TABLE entries ADD COLUMN created_by TEXT;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN updated_by TEXT;"); } catch (_) {}
db.exec("UPDATE entries SET created_by = 'system' WHERE created_by IS NULL;");
db.exec("UPDATE entries SET updated_by = 'system' WHERE updated_by IS NULL;");
```

The try/catch makes the ALTER idempotent — SQLite throws on a duplicate column name, which is
caught and suppressed. The UPDATE backfills any existing rows with `'system'` for both fields.

### Seed Rows

Seed rows remain unchanged — the ALTER+backfill runs before the seed check, so seed rows inserted
fresh will get created_by/updated_by stamped via the POST handler.

---

## API Surface

Extend POST and PUT handlers in `app/server.js` to server-stamp audit metadata.

### Invariants

- `created_by` is set on POST, never on PUT.
- `updated_by` is set on both POST and PUT.
- `created_at` is already set by DB DEFAULT on INSERT — no change needed.
- `updated_at` is already updated in the PUT SQL — no change needed.
- Client-submitted audit fields are blocked by `sanitize()` (whitelist model, audit keys not in
  ROW_FIELDS / FIELD_KEYS). No additional protection required.

### POST handler change

After `const err = validate(data, false, null);` passes and before the INSERT:

```javascript
data.created_by = req.user.username;
data.updated_by = req.user.username;
```

Because `data` is built by `sanitize()` (which only passes ROW_FIELDS keys), adding these two
keys directly to `data` means they'll be included in the dynamic INSERT without touching the
client-submitted body.

### PUT handler change

Change the `setSql` line from:
```javascript
const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now')";
db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.params.id);
```

To:
```javascript
const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now'), updated_by = ?";
db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.user.username, req.params.id);
```

`updated_by = ?` is appended to the SET clause alongside `updated_at = datetime('now')`.
The extra `?` binds to `req.user.username` appended before the row id.

### API response

`SELECT * FROM entries` already returns all columns — once the columns exist, the row response
from POST and PUT will automatically include `created_by` and `updated_by`. No schema route change
needed. The existing `/api/schema` response does not need to expose audit fields (they are
read-only metadata, not form fields).

### Preservation requirements

- `validate()` signature and logic are unchanged.
- `sanitize()` is unchanged — audit fields are not in ROW_FIELDS so cannot pass through.
- `REQUIRED_FIELDS` loop is unchanged.
- type / status / track enum checks are unchanged.
- `created_at` / `created_by` are never touched in PUT — original values are preserved.
- Error format `{ "error": "..." }` HTTP 400 — unchanged.

---

## Frontend Surface

Display audit metadata in the table. Do not expose audit fields in the create/edit form.

### AUDIT_LABELS constant (app/public/app.js)

Add after the existing `TYPE_LABEL` constant:

```javascript
const AUDIT_LABELS = { created_at: 'Created', updated_at: 'Updated', created_by: 'Created by', updated_by: 'Updated by' };
```

### colLabel() update

Change from:
```javascript
function colLabel(key) { return (state.fields.find((f) => f.key === key) || {}).label || key; }
```

To:
```javascript
function colLabel(key) { return AUDIT_LABELS[key] || (state.fields.find((f) => f.key === key) || {}).label || key; }
```

### LIST_COLS update

Add `created_by`, `updated_by`, `created_at`, `updated_at` before `type` (last column):

```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'created_by', 'updated_by', 'created_at', 'updated_at', 'type',
];
```

### Form — no change

The modal renders from `state.fields` (ROW_FIELDS). Audit columns are not added to ROW_FIELDS,
so they will not appear in the form and cannot be edited. ✅

### README update

Add an "Audit Metadata" section to `app/README.md` documenting the four audit columns and that
they are backend-controlled.

---

## Verification Gate

1. Server boots on :3000 after `rm -f app/data.db*`.
2. Login admin/admin123 → 200.
3. GET /api/rows → existing seed rows have `created_by = 'system'` and `updated_by = 'system'`.
4. POST valid row → 201; response includes `created_by = 'admin'`, `updated_by = 'admin'`, non-null `created_at`.
5. POST with forged `created_by = 'hacker'` → 201; response `created_by = 'admin'` (forge ignored).
6. PUT valid row → 200; response `updated_by = 'admin'`, `updated_at` changed; `created_by` and `created_at` unchanged.
7. PUT with forged `updated_by = 'hacker'` → 200; response `updated_by = 'admin'` (forge ignored).
8. Required-field validation still works: POST without owner → 400 "owner is required".
9. Track enum validation still works: POST with bad track → 400 "invalid track".
10. Status enum validation still works: POST with bad status → 400 "invalid status".
11. UI: table shows Created by, Updated by, Created, Updated columns.
12. UI: create/edit form does NOT show audit fields.
13. UI: create row still works; edit row still works.
14. Refresh → audit metadata persists.
15. No approval, escalation, dashboard, or agent UI.
16. Invariants 5/5 PASS.
17. git status shows only allowed surfaces modified.
