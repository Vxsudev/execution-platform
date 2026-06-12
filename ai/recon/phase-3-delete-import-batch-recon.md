# Recon: P3-2 Delete Import Batch

Feature Slug: phase-3-delete-import-batch
Date: 2026-06-12
Mode: Read-only. No app code modified.
Upstream recon: ai/recon/phase-3-recon-dag-map.md (P3-0), ai/recon/phase-3-import-batch-ledger-recon.md (P3-1)

---

## 1. Environment

| Check | Result |
|---|---|
| OS mode | OS-ENABLED |
| Adapter | 12/12 PASS |
| Invariants | 5/5 PASS |
| Branch | main |
| Working tree | Clean (commit e17dfc8) |
| Feature state | NOT FOUND → initializes from RECON_READY |
| P3-1 state | RELEASE_APPROVED |

---

## 2. P3-1 Confirmed State

### imports table (9 columns, confirmed via PRAGMA)

```
id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status
```

### entries import columns (confirmed via PRAGMA)

```
import_batch_id INTEGER DEFAULT NULL
import_source_sheet TEXT DEFAULT NULL
import_source_row INTEGER DEFAULT NULL
```

### Live data state

- 0 existing import batches (imports table is empty — test batch from P3-1 verification was cleaned up)
- 65 entries total: all 65 have `import_batch_id = NULL`
- No entries currently tagged to any batch

---

## 3. Existing DELETE Route Conventions (server.js)

### DELETE /api/rows/:id (lines 202–206)

```javascript
app.delete('/api/rows/:id', requireAuth, (req, res) => {
  if (!canDeleteRow(req.user)) return res.status(403).json({ error: 'Forbidden' });
  db.prepare('DELETE FROM entries WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});
```

Pattern: auth → permission → execute → return `{ ok: true }`. No existence check — silent no-op if not found.

### DELETE /api/users/:id (lines 290–300)

```javascript
app.delete('/api/users/:id', requireAuth, (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  if (req.user.id === id) return res.status(403).json({ error: 'cannot delete your own account' });
  const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'user not found' });
  db.prepare('DELETE FROM sessions WHERE user_id = ?').run(id);
  db.prepare('DELETE FROM users WHERE id = ?').run(id);
  res.json({ ok: true });
});
```

Pattern: auth → permission → parse/validate id → guard → existence check (404) → execute (multi-step) → return `{ ok: true }`.

**P3-2 will follow the users DELETE pattern** — explicitly parse numeric id, 404 if not found, multi-step delete. This is the safer pattern that reports errors clearly.

---

## 4. Transaction Support Analysis

`DatabaseSync` (node:sqlite built-in) exposes:
```
exec, prepare, function, createTagStore, location, aggregate, createSession, applyChangeset, enableLoadExtension, enableDefensive, loadExtension, setAuthorizer
```

**No `transaction()` method** (unlike better-sqlite3). BUT `db.exec()` is available and can execute raw SQL including `BEGIN` and `COMMIT`/`ROLLBACK`.

**Viable transaction pattern for P3-2:**
```javascript
db.exec('BEGIN');
try {
  const deleted_entry_count = db.prepare('DELETE FROM entries WHERE import_batch_id = ?').run(id).changes;
  db.prepare('DELETE FROM imports WHERE id = ?').run(id);
  db.exec('COMMIT');
} catch (e) {
  try { db.exec('ROLLBACK'); } catch (_) {}
  throw e; // → 500
}
```

`.run().changes` returns the number of rows affected — useful for `deleted_entry_count`.

WAL mode is already enabled (app/db.js line 10). `BEGIN` in WAL mode takes an immediate write lock — appropriate here.

---

## 5. Import History UI (current state — app.js)

### loadImports() (line 505)

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

### historyHtml in renderImportPanel() (lines 543–573)

Current history table: `#, File, By, Date, Rows, Warnings, Status` columns, no delete button.
No event binding for delete in `bindImportActions()`.

### Import tab reload (line 200)

```javascript
loadImports().then(renderApp);  // fires when navigating to Import tab
```

### After commit success (line 624)

```javascript
await loadImports();  // fires after import commit
```

---

## 6. P3-2 Required Changes

### Backend (app/server.js)

New route after `GET /api/imports`:

```javascript
app.delete('/api/imports/:id', requireAuth, (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ error: 'invalid import id' });
  const existing = db.prepare('SELECT id, filename FROM imports WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'import batch not found' });
  db.exec('BEGIN');
  try {
    const deleted_entry_count = db.prepare('DELETE FROM entries WHERE import_batch_id = ?').run(id).changes;
    db.prepare('DELETE FROM imports WHERE id = ?').run(id);
    db.exec('COMMIT');
    res.json({ ok: true, deleted_entry_count, deleted_import_id: id });
  } catch (e) {
    try { db.exec('ROLLBACK'); } catch (_) {}
    res.status(500).json({ error: 'delete failed: ' + (e && e.message ? e.message : 'unknown error') });
  }
});
```

### Frontend (app/public/app.js)

1. Add Delete button to each row in historyHtml (inside the `<tr>` template)
2. Add delete handler in `bindImportActions()` using event delegation on the import history table

### CSS (app/public/style.css)

Use existing `.danger` class on Delete button — check if it exists for import context, add minimal styling if not.

---

## 7. Destructive Safety Checks

| Safety requirement | Approach |
|---|---|
| Only delete entries for the specified batch | `WHERE import_batch_id = ?` with the explicit batch id |
| Only delete the specified import record | `WHERE id = ?` with the explicit id |
| Manual rows (import_batch_id = NULL) unaffected | NULL != any integer — WHERE clause never matches NULL |
| Other batches unaffected | `import_batch_id = <specific_id>` — other batch ids don't match |
| Transaction atomicity | `BEGIN` + `COMMIT`/`ROLLBACK` wrapping both deletes |
| Double-delete returns 404 | Existence check before BEGIN |
| Non-admin returns 403 | `canImport(req.user)` check |
| Anonymous returns 401 | `requireAuth` middleware |

---

## 8. Rollback Concerns

SQLite `BEGIN`/`COMMIT` transaction ensures atomicity — if `DELETE FROM entries` succeeds but `DELETE FROM imports` fails, ROLLBACK leaves both intact. This prevents orphaned entries (entries with import_batch_id pointing to a deleted imports row).

If the server crashes between `DELETE FROM entries` and `DELETE FROM imports`:
- WAL mode with `ROLLBACK` on crash: SQLite rolls back uncommitted transaction automatically on next open.
- Risk: LOW — SQLite guarantees transaction atomicity at the file level even on crash.

---

## 9. Dependency Relationship to P3-4

P3-4 (true workbook capture) will add an `import_observations` table with `import_batch_id` as FK. When `DELETE /api/imports/:id` is later extended to support P3-4, the route will need to also `DELETE FROM import_observations WHERE import_batch_id = ?`. This is NOT in scope for P3-2. The P3-2 route implementation must NOT add `import_observations` cascade (table doesn't exist yet).

---

## 10. Files to Modify

| File | Change |
|---|---|
| app/server.js | Add DELETE /api/imports/:id route |
| app/public/app.js | Add delete button to Import History + handler |
| app/public/style.css | Add danger button style if needed |
| app/README.md | Update Import Batch Ledger section |

**Do NOT modify:** app/db.js (no schema changes needed), app/public/index.html, app/package.json, app/package-lock.json, vendor/

---

## 11. Stop Conditions (Recon Complete)

- [x] Recon artifact created
- [x] P3-1 state confirmed (RELEASE_APPROVED, 0 batches, 65 manual rows)
- [x] Transaction support analyzed (BEGIN/COMMIT/ROLLBACK via db.exec)
- [x] DELETE route convention established (follow users DELETE pattern)
- [x] Import History UI located (historyHtml in renderImportPanel, bindImportActions)
- [x] Safety constraints mapped
- [x] P3-4 cascade dependency noted (out of scope)
- [x] Files to modify identified
