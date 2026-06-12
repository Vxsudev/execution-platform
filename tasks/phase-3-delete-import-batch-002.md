# Task: Add DELETE /api/imports/:id route to server.js

## Parent Spec
specs/phase-3-delete-import-batch.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Add `DELETE /api/imports/:id` to `app/server.js` immediately after the `GET /api/imports` route.

### Route implementation

```javascript
app.delete('/api/imports/:id', requireAuth, (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ error: 'invalid import id' });
  const existing = db.prepare('SELECT id FROM imports WHERE id = ?').get(id);
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

### Safety constraints (MUST preserve each)

- `WHERE import_batch_id = ?` — scoped to specific batch; NULL rows never match an integer
- `WHERE id = ?` — deletes exactly one imports record
- `Number.isInteger(id) && id > 0` — rejects NaN (from `Number('abc'`) and negative/zero ids
- Existence check before BEGIN — 404 on already-deleted (double-delete safe)
- Transaction wrapping — atomicity: if entries delete succeeds but imports delete fails, ROLLBACK leaves both intact
- No `import_observations` cascade — table doesn't exist yet (P3-4 scope)
- No soft-delete — hard delete as authorized

### Do NOT add

- No audit log
- No import_observations handling
- No status field update
- No separate route for deleting individual imported entries

## Acceptance Criteria
- [ ] `node --check app/server.js` exits 0
- [ ] DELETE /api/imports/:id (admin, existing) → 200 `{ ok, deleted_entry_count, deleted_import_id }`
- [ ] DELETE /api/imports/:id (non-admin track_owner) → 403
- [ ] DELETE /api/imports/:id (anonymous) → 401
- [ ] DELETE /api/imports/:id (non-existent id integer) → 404
- [ ] DELETE /api/imports/:id (non-integer path like 'abc') → 400
- [ ] Double-delete → 404 on second call
- [ ] Entries with matching import_batch_id deleted (count matches deleted_entry_count)
- [ ] Entries with NULL import_batch_id untouched
- [ ] Imports record deleted
- [ ] Transaction: partial failure rolls back (not testable directly but code must be correct)

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-3-delete-import-batch-001.md
