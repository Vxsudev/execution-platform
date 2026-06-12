# Task: Cascade observations on delete and expose observation_count in history

## Parent Spec
specs/phase-3-true-workbook-capture.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Update the delete and history routes in `app/server.js` for observation
awareness.

### DELETE /api/imports/:id — cascade observations

Inside the existing `db.exec('BEGIN')` / COMMIT / ROLLBACK transaction, BEFORE
deleting entries, delete observations:

```javascript
const deleted_observation_count = db.prepare('DELETE FROM import_observations WHERE import_batch_id = ?').run(id).changes;
const deleted_entry_count = db.prepare('DELETE FROM entries WHERE import_batch_id = ?').run(id).changes;
db.prepare('DELETE FROM imports WHERE id = ?').run(id);
```

Add `deleted_observation_count` to the success response:
`{ ok: true, deleted_observation_count, deleted_entry_count, deleted_import_id: id }`.

Preserve: admin-only gate, 400 invalid id, 404 missing batch, ROLLBACK on error.
Manual rows (import_batch_id NULL) and other batches must remain untouched —
the integer-id WHERE clause never matches NULL.

### GET /api/imports — observation_count

Add a correlated subquery to the SELECT so each batch carries its observation
count:

```sql
SELECT id, filename, imported_by, imported_at, total_rows, importable_rows,
       skipped_rows, warning_count, status,
       (SELECT COUNT(*) FROM import_observations o WHERE o.import_batch_id = imports.id) AS observation_count
FROM imports ORDER BY id DESC
```

Preserve admin-only gate and ordering.

## Acceptance Criteria
- [ ] DELETE removes observations for the batch within the transaction
- [ ] DELETE response includes deleted_observation_count
- [ ] DELETE response still includes deleted_entry_count and deleted_import_id
- [ ] DELETE still deletes entries and imports ledger row for the batch
- [ ] Manual rows (NULL batch) untouched after delete
- [ ] Other batches' observations untouched after delete
- [ ] 404 on missing batch, 400 on invalid id preserved
- [ ] GET /api/imports returns observation_count per batch
- [ ] Admin-only gates preserved (403 non-admin, 401 anon)
- [ ] node --check app/server.js exits 0

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-3-true-workbook-capture-001.md
