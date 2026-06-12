# Recon: P3-1 Import Batch Ledger

Feature Slug: phase-3-import-batch-ledger
Date: 2026-06-12
Mode: Read-only. No app code modified.
Upstream recon: ai/recon/phase-3-recon-dag-map.md (P3-0)

---

## 1. Environment

| Check | Result |
|---|---|
| OS mode | OS-ENABLED |
| Adapter | 12/12 PASS |
| Invariants | 5/5 PASS |
| Branch | main |
| Working tree | Clean (commit 5ce543d) |
| Feature state | NOT FOUND → initializes from RECON_READY |

---

## 2. Database State

### Tables (confirmed via PRAGMA)

```
users, sqlite_sequence, sessions, entries
```

No `imports` table. No import metadata columns in `entries`.

### entries import-related columns (absent — full list)

`id, type, title, owner, track, function_area, parent_item, hypothesis, design, success_criteria, target_end_date, dependencies, outcome, next_action, status, created_at, updated_at, created_by, updated_by`

**Absent:** `import_batch_id`, `import_source_sheet`, `import_source_row`

### Migration safety

The existing additive pattern in `app/db.js` (lines 78–79, 81–82) uses `try { db.exec("ALTER TABLE ... ADD COLUMN ..."); } catch (_) {}`. This is idempotent — safe to run on any DB state. Adding three new nullable columns to `entries` and creating a new `imports` table (IF NOT EXISTS) is additive and non-destructive. Existing rows receive `NULL` for all three new columns — the semantics are correct (NULL = not imported).

---

## 3. Import Commit Flow (current)

### POST /api/import/commit (server.js lines 439–461)

1. Permission check: `canImport(req.user)` — admin only (403 otherwise)
2. Body: `{ rows: [...] }` — each element is `r.data` from the preview (flat data object, NO `row_number`, NO `source_sheet`)
3. Per-row: re-classifies via `classifyImportRow`, inserts into `entries` with `created_by = req.user.username`
4. No batch record created
5. No import metadata stamped on entries
6. Response: `{ ok, inserted_count, ids, skipped_count, skipped }`

**Critical observation:** The commit payload currently discards `row_number` and `source_sheet`. These are in the preview response but stripped by the frontend commit builder at app.js line 584:
```javascript
body: { rows: p.rows.map(r => r.data) }
```

### POST /api/import/preview (server.js lines 412–437)

1. Permission check: admin only
2. Body: `{ filename, content_base64 }` — filename IS received and validated here
3. `parseImportWorkbook` returns `{ sheet, rows: [{ row_number, data }] }` — BOTH `row_number` and `sheet` are already available in preview
4. Response includes: `summary.sheet`, per-row `row_number` and `warnings`
5. Writes nothing to DB

**Key finding:** `filename`, `sheet`, and `row_number` are ALL available at preview time. They are simply not forwarded to the commit route. The commit payload needs to be extended to include them.

---

## 4. Frontend Import Panel (current)

### State (app.js)

- `state.importPreview` — full preview response stored in state after successful preview
- No `state.importFilename` — filename is NOT retained in state after preview

### Commit payload construction (app.js line 584)

```javascript
body: { rows: p.rows.map(r => r.data) }
```

Strips: `row_number`, `warnings`. Does NOT include: `filename`, `sheet`.

### Changes needed for P3-1

1. Store filename in state: `state.importFilename = file.name` after successful preview
2. Update commit payload to:
   ```javascript
   body: {
     filename: state.importFilename,
     sheet: p.summary.sheet,
     rows: p.rows.map(r => ({ data: r.data, row_number: r.row_number }))
   }
   ```
3. After successful commit: clear `state.importFilename`, call new `loadImports()`, refresh panel
4. Add `loadImports()` async function (calls GET /api/imports)
5. Add `state.imports = []` initial state
6. Render import history inside `renderImportPanel()` when `state.imports.length > 0` (admin only)

---

## 5. Backend Changes Needed

### New: `imports` table in `app/db.js`

```sql
CREATE TABLE IF NOT EXISTS imports (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  filename        TEXT NOT NULL,
  imported_by     TEXT NOT NULL,
  imported_at     TEXT NOT NULL DEFAULT (datetime('now')),
  total_rows      INTEGER,
  importable_rows INTEGER,
  skipped_rows    INTEGER,
  warning_count   INTEGER,
  status          TEXT NOT NULL DEFAULT 'complete'
);
```

### New: ALTER TABLE entries (app/db.js)

```sql
ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;
```

### Modified: POST /api/import/commit (app/server.js)

New body shape expected: `{ filename, sheet, rows: [{ data, row_number }] }`

Steps:
1. Validate `filename` string (same pattern as preview: `/\.xlsx$/i`)
2. Validate `rows` is an array
3. Pre-classify all rows to count importable/skipped (for batch record)
4. INSERT INTO imports → get `batch_id`
5. For each importable row: INSERT INTO entries with `import_batch_id = batch_id`, `import_source_sheet = sheet`, `import_source_row = row.row_number`
6. Response includes `batch_id`

### New: GET /api/imports (app/server.js)

Admin-only. Returns all import batches newest first. Non-admin → 403. Anonymous → 401 (requireAuth handles this).

---

## 6. Mutation Risks

| Risk | Severity | Mitigation |
|---|---|---|
| ALTER TABLE fails if column already exists | LOW | try/catch idempotent pattern |
| Commit payload shape change breaks frontend | HIGH | Update frontend atomically with backend; both ship in same P3-1 build |
| Missing filename in commit body | MEDIUM | Validate `filename` in commit route with same regex as preview; 400 on missing |
| batch_id not returned → frontend can't update history | MEDIUM | Response must include `batch_id`; loadImports() called after commit |
| Old entries have import_batch_id = NULL | INTENT | Correct behavior — they pre-date the batch ledger |
| Manual rows after P3-1 get import_batch_id = NULL | INTENT | POST /api/rows does NOT touch import columns |
| Smoke test imports left in DB | MEDIUM | Verification section must clean up test batches + entries |

---

## 7. Invariant Interactions

| Invariant | Impact |
|---|---|
| INV-001: vendor OS immutable | No vendor changes — PASS |
| INV-003: artifact layer/status | Spec must declare Layer+Status — included in spec |
| INV-004: ADRs append-only | No ADRs touched — PASS |
| INV-005: Domain Constitution pre-L2 | Not in scope — PASS |
| INV-006: traceability | Spec must declare upstream+downstream — included |

---

## 8. Dependency Relationship to Later P3 Slices

| P3 Slice | Dependency on P3-1 |
|---|---|
| P3-2 (Delete Batch) | Requires `imports.id` + `entries.import_batch_id` |
| P3-3 (Dedup) | Benefits from `entries.import_source_row` for precise dedup |
| P3-4 (True Capture) | Requires `imports` table as FK root for observations |
| P3-5 (Provenance) | Requires `entries.import_batch_id` + batch filename lookup |

No later P3 slice can be built without P3-1.

---

## 9. Files to Modify

| File | Change |
|---|---|
| app/db.js | Add `imports` table; add 3 ALTER TABLE entries calls |
| app/server.js | Update commit route; add GET /api/imports route |
| app/public/app.js | Update commit payload; add history state + load; update panel render |
| app/public/style.css | Minor: import history table styles if needed |
| app/README.md | Add Import Batch Ledger section |

**Do NOT modify:** app/public/index.html, app/package.json, app/package-lock.json, prototypes/, sdlc/, source-materials/, vendor/

---

## 10. Rollback Concern

SQLite ALTER TABLE is not reversible in-place. If rollback is needed post-deployment:
- Remove the three import metadata columns: not possible without full DB reconstruction
- The columns are nullable and have no CHECK constraints — forward compatible

**Accepted risk:** The columns are additive-only and do not affect any existing query paths. No existing INSERT or SELECT references them. Rollback would require a DB dump + schema recreation, which is acceptable for a dev environment.

---

## Stop Conditions (Recon Complete)

- [x] Recon artifact created
- [x] Current import commit flow analyzed
- [x] Current frontend commit payload analyzed
- [x] DB schema confirmed (no import columns yet)
- [x] Required DB schema additions defined
- [x] Backend changes defined
- [x] Frontend changes defined
- [x] Mutation risks documented
- [x] Invariant interactions checked
- [x] Dependency chain to P3-2/3/4/5 documented
- [x] Rollback concern documented
