# Spec: P3-2 Delete Import Batch

## Status
approved

## Phase
phase-build

## Layer
L5-Build

## Upstream
- ai/recon/phase-3-recon-dag-map.md (P3-0 DAG map)
- ai/recon/phase-3-delete-import-batch-recon.md (P3-2 implementation recon)
- phase-3-import-batch-ledger (P3-1 — provides imports table + entries.import_batch_id)

## Downstream
- phase-3-duplicate-detection (P3-3 — no dependency on P3-2, but ordered after for safety)
- phase-3-true-workbook-capture (P3-4 — will extend DELETE /api/imports/:id to cascade import_observations when that table exists)
- phase-3-import-provenance (P3-5 — reads import_batch_id from entries; P3-2 removes entries cleanly)

## Capability

Before P3-2, there is no way to undo or remove a committed import batch. Once rows are imported they can only be deleted one-by-one via the manual DELETE /api/rows/:id route (admin-only, one row at a time). Admins have no batch-level rollback.

After P3-2:
- Admins can delete an import batch by clicking Delete in the Import History section.
- A confirmation dialog states what will be permanently deleted.
- The backend atomically removes all entries where `import_batch_id = <id>` and the import record itself.
- Manual rows (import_batch_id = NULL) are never touched.
- Rows from other import batches are never touched.
- The route is admin-only.
- The Import History refreshes after deletion; the Rows table refreshes.

## Data Model Changes

None. P3-2 uses the existing `imports` table and `entries.import_batch_id` column established in P3-1. No new tables, no schema migrations, no ALTER TABLE.

## API Surface

### New: DELETE /api/imports/:id

**Auth:** requireAuth + canImport (admin only). Non-admin → 403. Anonymous → 401.

**Path parameter:** `id` — numeric import batch id.

**Behavior:**

1. Parse `id` from `req.params.id` as integer. If non-integer or <= 0 → 400.
2. Look up `imports WHERE id = ?`. If not found → 404 "import batch not found".
3. Begin a SQLite transaction: `db.exec('BEGIN')`.
4. `DELETE FROM entries WHERE import_batch_id = ?` — record `.changes` as `deleted_entry_count`.
5. `DELETE FROM imports WHERE id = ?`.
6. `db.exec('COMMIT')`.
7. Return `{ ok: true, deleted_entry_count, deleted_import_id: id }`.
8. On error: `db.exec('ROLLBACK')` and return 500 with error message.

**Idempotency:** NOT required. Double-delete returns 404.

**Response on success:**
```json
{
  "ok": true,
  "deleted_entry_count": 19,
  "deleted_import_id": 1
}
```

### Unchanged: GET /api/imports, POST /api/import/preview, POST /api/import/commit

All existing import routes unchanged.

## Frontend Surface

### Modified: Import History section (admin only)

**Changes to `historyHtml` in `renderImportPanel()`:**

Add a Delete column to the history table header and a delete button per row:

```
| # | File | By | Date | Rows | Warnings | Status | Action |
| 1 | astraX.xlsx | admin | 2026-06-12 | 19 | 36 | complete | [Delete] |
```

The Delete button carries a `data-batch-id` attribute. Style: `class="btn danger sm"` or similar compact danger variant.

**Changes to `bindImportActions()`:**

Add event delegation on the import history table to handle delete button clicks:

1. Intercept click on `[data-batch-id]` within the import history section.
2. Show native `confirm(...)` dialog: `"Delete import batch #N? This will permanently delete X rows imported in this batch. Manual rows will not be touched. This cannot be undone."`
3. If confirmed: call `DELETE /api/imports/:id`.
4. On success: show alert with `deleted_entry_count`; call `loadImports()` + `loadRows()` + `renderApp()`.
5. On error: display error message in `importErr` element.
6. If canceled: do nothing.

## Operational Workflow

### Happy path — delete import batch

1. Admin navigates to Import tab → Import History shows existing batches.
2. Admin clicks Delete next to batch #1.
3. Browser shows: `"Delete import batch #1? This will permanently delete 19 rows imported in this batch. Manual rows will not be touched. This cannot be undone."`
4. Admin clicks OK.
5. Frontend calls `DELETE /api/imports/1`.
6. Backend: existence check → BEGIN → DELETE entries WHERE import_batch_id = 1 (19 rows) → DELETE imports WHERE id = 1 → COMMIT → return `{ ok: true, deleted_entry_count: 19, deleted_import_id: 1 }`.
7. Frontend shows alert: "Deleted 19 imported row(s)."
8. Import History refreshes — batch #1 gone.
9. Rows table refreshes — the 19 imported rows gone; manual rows still present.

### Admin cancels delete

Step 3 → Admin clicks Cancel → nothing happens.

### Double-delete attempt

Second DELETE /api/imports/1 → 404 "import batch not found".

### Non-admin attempt

DELETE /api/imports/1 (as vasu/track_owner) → 403 Forbidden.

### Anonymous attempt

DELETE /api/imports/1 (no session) → 401 Not authenticated.

## Dependencies

- P3-1: phase-3-import-batch-ledger — provides `imports` table and `entries.import_batch_id` (required)
- No other P3 slices required before P3-2

## Acceptance Criteria

1. DELETE /api/imports/:id (admin, valid existing batch) → 200 `{ ok, deleted_entry_count, deleted_import_id }`
2. All entries with matching import_batch_id are deleted
3. No entries with NULL import_batch_id are deleted
4. No entries with a different import_batch_id are deleted
5. The imports ledger row is deleted
6. DELETE /api/imports/:id (non-admin) → 403
7. DELETE /api/imports/:id (anonymous) → 401
8. DELETE /api/imports/:id (non-existent id) → 404
9. DELETE /api/imports/:id (non-integer id) → 400
10. Double delete → 404 on second call
11. Import History shows Delete button per batch (admin only)
12. Confirmation dialog mentions batch id and row count
13. After confirm: Import History refreshes, Rows table refreshes
14. After cancel: nothing changes
15. On backend error: error message shown in Import tab
16. GET /api/imports after delete no longer includes deleted batch
17. GET /api/rows after delete no longer includes deleted entries
18. Existing import commit behavior unchanged
19. Import preview unchanged
20. Manual row creation still produces import_batch_id = NULL
21. All Phase 2 RBAC flows still pass
22. Invariants 5/5 PASS
23. No `[FILL:]` residue in task files
24. git status: only allowed surfaces modified

## Out of Scope

- import_observations cascade (P3-4 — table doesn't exist yet)
- Soft-delete or status="deleted" on imports record
- Per-row delete of imported entries (existing DELETE /api/rows/:id handles that)
- Duplicate detection (P3-3)
- True workbook capture (P3-4)
- Import provenance in row details modal (P3-5)
- Row click / cell reveal UX (P3-6, P3-7)
- Dashboard workspace filtering (P3-8)
- Any new npm packages
- Any schema changes (no db.js modification)
