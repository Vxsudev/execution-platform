# RECON: data-model-audit-trail

## Capability
Data Model Audit Trail

## Date
2026-06-10

## State at Recon
RECON_READY

## Prior Work
- `backend-required-field-enforcement` (RELEASE_APPROVED) — validate() enforces owner/track/title/status.
- `canonical-track-taxonomy-enforcement` (RELEASE_APPROVED) — TRACKS constant, select field, schema exposure.
- `track-enum-server-validation` (RELEASE_APPROVED) — backend rejects non-canonical track values.
- All prior capabilities are RELEASE_APPROVED; working tree is clean at `d25129a`.

---

## 1. Current entries Table Schema

From `app/db.js` lines 57–75:

```sql
CREATE TABLE IF NOT EXISTS entries (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  type             TEXT NOT NULL DEFAULT 'experiment' CHECK (type IN ('experiment','work_item','task')),
  title            TEXT NOT NULL,
  owner            TEXT,
  track            TEXT,
  function_area    TEXT,
  parent_item      TEXT,
  hypothesis       TEXT,
  design           TEXT,
  success_criteria TEXT,
  target_end_date  TEXT,
  dependencies     TEXT,
  outcome          TEXT,
  next_action      TEXT,
  status           TEXT NOT NULL DEFAULT 'Not Started' CHECK (status IN ('Not Started','In Progress','Complete','Blocked','Inconclusive')),
  created_at       TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### Audit Column Status

| Column | Present | Behavior |
|--------|---------|----------|
| `created_at` | ✅ YES | DEFAULT (datetime('now')) on INSERT; never touched on UPDATE |
| `updated_at` | ✅ YES | DEFAULT (datetime('now')) on INSERT; manually updated in PUT route |
| `created_by` | ❌ NO | Missing — gap to fill |
| `updated_by` | ❌ NO | Missing — gap to fill |

---

## 2. Current updated_at Stamping (app/server.js lines 125–129)

```javascript
const keys = Object.keys(data);
if (keys.length) {
  const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now')";
  db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.params.id);
}
```

`updated_at` is already server-side stamped on every PUT. This is correct behavior.
`updated_by` needs to be added to the same SQL update expression.

---

## 3. Current POST Route (app/server.js lines 109–118)

```javascript
app.post('/api/rows', requireAuth, (req, res) => {
  const data = sanitize(req.body || {});
  if (!data.type) data.type = 'experiment';
  const err = validate(data, false, null);
  if (err) return res.status(400).json({ error: err });
  const keys = Object.keys(data);
  const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
    .run(...keys.map(k => data[k]));
  res.status(201).json({ row: db.prepare('SELECT * FROM entries WHERE id = ?').get(Number(info.lastInsertRowid)) });
});
```

`created_at`/`updated_at` are handled by DB DEFAULT. `created_by`/`updated_by` must be stamped from `req.user.username` by adding them to `data` before INSERT.

---

## 4. Authenticated User Identity

`requireAuth` (server.js line 33–38):
```javascript
function requireAuth(req, res, next) {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: 'Not authenticated' });
  req.user = u;
  next();
}
```

`currentUser()` returns `{ id, username }` from session. So `req.user.username` is a reliable string (e.g. `"admin"`, `"vasu"`) in all `requireAuth` routes. ✅

---

## 5. sanitize() — Client-Forgery Prevention

```javascript
const FIELD_KEYS = ROW_FIELDS.map(f => f.key);
function sanitize(body) {
  const out = {};
  for (const k of FIELD_KEYS) {
    if (body[k] !== undefined) out[k] = body[k] === null ? null : String(body[k]);
  }
  return out;
}
```

`sanitize()` only passes through keys that are in `FIELD_KEYS` (ROW_FIELDS). Since `created_by`, `updated_by`, `created_at`, `updated_at` are NOT in ROW_FIELDS, any client-submitted values for these fields are silently stripped. No additional protection needed — the whitelist model already covers it. ✅

---

## 6. Migration / Backfill Pattern

SQLite supports `ALTER TABLE entries ADD COLUMN <name> <type>` but does NOT support `IF NOT EXISTS` for ADD COLUMN. To make the migration idempotent (safe for existing DBs), wrap each ALTER in a try/catch:

```javascript
try { db.exec("ALTER TABLE entries ADD COLUMN created_by TEXT;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN updated_by TEXT;"); } catch (_) {}
```

SQLite will throw `"duplicate column name: created_by"` if the column already exists. The catch suppresses this, making the migration re-runnable.

**Backfill**: Existing rows will have NULL for `created_by`/`updated_by`. The directive allows backfilling with `"system"`:
```javascript
db.exec("UPDATE entries SET created_by = 'system' WHERE created_by IS NULL;");
db.exec("UPDATE entries SET updated_by = 'system' WHERE updated_by IS NULL;");
```

This is safe — it only touches rows that haven't been stamped yet.

---

## 7. Frontend Column Display

Current `LIST_COLS` in `app/public/app.js` (line 12–16):
```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'type',
];
```

`colLabel(key)` reads label from `state.fields` (ROW_FIELDS). Audit columns are NOT in ROW_FIELDS, so `colLabel('created_by')` returns the raw key `'created_by'` — not a nice label.

**Fix**: Add an `AUDIT_LABELS` constant in app.js for label overrides, and update `colLabel()` to check it first. Add `created_by`, `updated_by`, `created_at`, `updated_at` to LIST_COLS. The table already has horizontal scroll — the added columns are low-noise metadata at the right edge.

The create/edit modal uses `state.fields` (ROW_FIELDS). Since audit columns are not added to ROW_FIELDS, they will NOT appear in the form. Audit immutability is preserved. ✅

---

## 8. ROW_FIELDS — Audit columns must NOT be added

Audit fields (`created_at`, `updated_at`, `created_by`, `updated_by`) must not be added to ROW_FIELDS because:
1. `sanitize()` uses FIELD_KEYS → adding them would allow client override
2. The form renders from `state.fields` (ROW_FIELDS) → adding them would make them editable
3. They are server-controlled metadata, not user-facing form fields

Backend will stamp them directly in the POST/PUT handlers after sanitize() runs.

---

## 9. No Approval / Escalation / Dashboard Scope

Confirmed absent from all app files:
- No approval workflow
- No escalation
- No dashboard
- No agent code
- No NDT-SaaS imports

---

## 10. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| ALTER TABLE fails on existing DB with duplicate column | LOW | try/catch makes migration idempotent |
| Existing rows have NULL created_by/updated_by | LOW | Backfill UPDATE sets 'system' before seed check |
| Client attempts to forge audit fields via POST/PUT body | NONE | sanitize() whitelist already blocks non-FIELD_KEYS |
| updated_by not stamped if no data fields change (empty PUT body) | LOW | `if (keys.length)` guard — empty PUT returns current row without UPDATE; acceptable since no actual change occurred |
| Table width increases by 4 columns | LOW | Table already has horizontal scroll; audit columns appended at right edge |

---

## 11. Recommended Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | ALTER TABLE ADD COLUMN created_by/updated_by; backfill UPDATE |
| `app/server.js` | POST: stamp created_by + updated_by from req.user.username; PUT: add updated_by to SQL |
| `app/public/app.js` | Add AUDIT_LABELS const; update colLabel(); add audit columns to LIST_COLS |
| `app/README.md` | Document audit metadata and that fields are backend-controlled |

No changes to: `app/public/index.html`, `app/public/style.css`, `prototypes/`, `sdlc/`.

---

## 12. Exact Changes Required

### app/db.js — After `db.exec(CREATE TABLE...)` block

```javascript
// Additive migration: add audit-by columns if not present (idempotent)
try { db.exec("ALTER TABLE entries ADD COLUMN created_by TEXT;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN updated_by TEXT;"); } catch (_) {}
db.exec("UPDATE entries SET created_by = 'system' WHERE created_by IS NULL;");
db.exec("UPDATE entries SET updated_by = 'system' WHERE updated_by IS NULL;");
```

### app/server.js — POST handler (after sanitize + validate, before INSERT)

```javascript
data.created_by = req.user.username;
data.updated_by = req.user.username;
```

### app/server.js — PUT handler (change setSql)

From:
```javascript
const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now')";
db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.params.id);
```

To:
```javascript
const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now'), updated_by = ?";
db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.user.username, req.params.id);
```

### app/public/app.js — Add AUDIT_LABELS and update colLabel()

```javascript
const AUDIT_LABELS = { created_at: 'Created', updated_at: 'Updated', created_by: 'Created by', updated_by: 'Updated by' };
```

Update `colLabel()`:
```javascript
function colLabel(key) { return AUDIT_LABELS[key] || (state.fields.find((f) => f.key === key) || {}).label || key; }
```

Add to LIST_COLS (append at end, before 'type'):
```javascript
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'created_by', 'updated_by', 'created_at', 'updated_at', 'type',
];
```
