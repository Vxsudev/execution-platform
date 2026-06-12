# Recon: P3-4 True Workbook Capture

Feature Slug: phase-3-true-workbook-capture
Date: 2026-06-12
Mode: Read-only. No app code modified during recon.
Upstream recon: P3-0 (phase-3-recon-dag-map), P3-1 (import-batch-ledger), P3-2 (delete-import-batch), P3-3 (duplicate-detection)

---

## 1. Environment

| Check | Result |
|---|---|
| OS mode | OS-ENABLED |
| Adapter | 12/12 PASS |
| Invariants | 5/5 PASS |
| Branch | main |
| Working tree | Clean (commit 97f8ea8) |
| P3-1 state | RELEASE_APPROVED |
| P3-2 state | RELEASE_APPROVED |
| P3-3 state | RELEASE_APPROVED |
| Feature state | not in registry → initialize from RECON_READY |

Commands run:
- `git status`, `git log --oneline -3`
- `bash vendor/engineering-os/scripts/os-adapter-check.sh`
- `bash scripts/invariant-check.sh`
- `node -e` PRAGMA/SELECT against app/data.db
- Reads: app/server.js (446–559), app/db.js (45–99)

---

## 2. Database State

### Tables (confirmed via sqlite_master)

```
users, sqlite_sequence, sessions, entries, imports
```

**`import_observations` does NOT exist.** This is the P3-4 target table.

### entries (21 columns) — import metadata present (P3-1)

`import_batch_id INTEGER DEFAULT NULL`, `import_source_sheet TEXT DEFAULT NULL`, `import_source_row INTEGER DEFAULT NULL`

### imports (9 columns) — P3-1 ledger

`id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status`

### Data state

| Metric | Value |
|---|---|
| entries | 65 |
| entries with import_batch_id NOT NULL | 0 |
| entries with import_batch_id NULL (manual) | 65 |
| imports | 1 (batch id=9) |

### PRE-EXISTING ARTIFACT — batch id=9 (NOT created by this work)

```
id=9, filename=astraX-june-to-nov-experiment-all-tracking.xlsx, imported_by=admin,
imported_at=2026-06-12 09:25:30, total_rows=19, importable_rows=19, skipped_rows=19,
warning_count=19, status=complete, linked entries=0
```

Created by the operator testing P3-3 in the UI against the real workbook AFTER P3-3 was committed (09:20). All 19 importable rows were detected as logical duplicates of the existing 65 manual rows and skipped (`allow_duplicates=false`), so `inserted_count=0` but the batch ledger row persisted.

**This is the exact P3-4 motivation made real:** a genuine import attempt with 19 rows of workbook reality, zero execution rows captured, zero observations recorded (P3-4 not built). Operator law: "Do not treat 0 execution rows as 0 captured workbook content."

**Decision:** I did not create batch 9. Per safety doctrine I will NOT delete it unilaterally. I will leave the live DB untouched and run all P3-4 smoke tests against a disposable copy of app/data.db, then document final live-DB state. The additive `import_observations` migration is idempotent and safe to apply to the live DB on next server boot; batch 9 will simply have zero observations (pre-dates capture), which is correct.

---

## 3. Current Import Pipeline (post-P3-3, server.js)

### parseImportWorkbook (single sheet)

Returns `{ sheet, rows: [{ row_number, data }] }` or `{ error }`. Only ONE summary sheet processed. Fully-empty mapped rows are filtered out before return. So the parser already drops empty rows — the commit never sees them.

### POST /api/import/preview (446–474)

- Admin-only. Parses, classifies, runs duplicate detection per importable row.
- Returns `summary {sheet,total_rows,importable_rows,skipped_rows,warning_count,duplicate_count}`, `rows[]` (importable, with duplicate metadata), `skipped_rows[] {row_number, reason}`.
- **skipped_rows currently carry NO raw data** — only row_number + reason.
- Writes nothing. ✅ must remain.

### POST /api/import/commit (476–529)

- Admin-only. Two-pass: classify+detect (P3-3), then insert.
- Frontend sends ONLY `p.rows` (importable) — `p.skipped_rows` are NOT sent today.
- Creates batch ledger row, inserts importable non-duplicate rows into entries with batch+source metadata, skips duplicates.
- Returns `{ok,batch_id,inserted_count,ids,skipped_count,skipped,duplicate_count,duplicate_skipped_count}`.
- Non-transactional; per-row try/catch resilience.

### GET /api/imports (531–537)

Returns all batch ledger rows, newest first. Admin-only.

### DELETE /api/imports/:id (539–555)

Transactional (BEGIN/COMMIT/ROLLBACK). Deletes entries WHERE import_batch_id=id, then imports row. Returns `{ok,deleted_entry_count,deleted_import_id}`. Admin-only. 404 if missing.

---

## 4. Zero-Execution-Row Limitation (the gap P3-4 closes)

Today, an import where all rows are duplicate-skipped (like batch 9) or blank-title-skipped produces a ledger row but ZERO record of what the workbook actually contained. The skipped content is discarded. There is no audit trail of "the workbook had these 19 rows; we chose not to insert them."

---

## 5. Proposed Observation Schema (db.js, additive)

```sql
CREATE TABLE IF NOT EXISTS import_observations (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  import_batch_id   INTEGER NOT NULL,
  source_sheet      TEXT,
  source_row        INTEGER,
  observation_type  TEXT NOT NULL,
  status            TEXT NOT NULL,
  reason            TEXT,
  raw_data          TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
```

Flexible TEXT for observation_type/status (no CHECK) — per directive, to avoid breaking future capture cases. Placed inside the main `db.exec()` schema block in db.js after the `imports` table, alongside the other CREATE TABLE IF NOT EXISTS statements (idempotent).

observation_type values used by P3-4 commit:
- `workbook_sheet` — one per commit, captures sheet + summary counts (status `captured`)
- `imported_entry` — one per inserted execution row (status `imported`)
- `duplicate_skipped` — one per duplicate-skipped row (status `skipped`, reason `duplicate`)
- `skipped_row` — one per parse-skipped row received from frontend (status `skipped`, reason from classifier)

Reserved/future (not all emitted in P3-4): `malformed_row`, `empty_row`, `non_executable_sheet`, `header_candidate`.

---

## 6. Source sheet/row capture strategy

- `imported_entry` observations: `source_sheet` = commit sheet, `source_row` = row_number, `raw_data` = JSON of the classified row data + resulting entry id.
- `duplicate_skipped`: source_sheet/row from payload, raw_data = JSON of row data + duplicate_entry_id.
- `skipped_row`: source_sheet/row from payload, raw_data = JSON of raw row data.
- `workbook_sheet`: source_sheet = sheet, source_row = NULL, raw_data = JSON counts `{total_rows, importable_rows, inserted, duplicate_skipped, parse_skipped}`, reason set to `'zero execution rows inserted'` when inserted_count===0 (satisfies the zero-insert observation requirement).

---

## 7. Commit behavior changes

1. Accept optional `skipped_rows` array in payload (each `{row_number, reason, data}`) so blank-title/parse-skipped rows can be captured as observations. Backward compatible (defaults to `[]`).
2. After existing entry-insert loop, build and insert observation rows linked to batch_id.
3. Always emit the `workbook_sheet` observation (proves the attempt even when inserted_count===0).
4. Response adds `observation_count`.
5. Execution-row validation UNCHANGED — observations never become entries. No relaxation of P2-4A rules.

## 8. Preview behavior changes

- Include raw `data` in each `skipped_rows` entry (so frontend can forward it to commit for capture). Preview still writes nothing.
- Add projected capture counts to summary: `observed_sheet_count` (1 when sheet resolved) and `observation_count` (projection = importable_rows + skipped_rows + 1 sheet). Clearly projections; no DB writes.

## 9. Delete cascade changes

Inside the existing transaction, before deleting entries: `DELETE FROM import_observations WHERE import_batch_id = ?`. Response adds `deleted_observation_count`. Manual rows + other batches untouched (integer id never matches NULL).

## 10. Import history changes

GET /api/imports: add `observation_count` via correlated subquery `(SELECT COUNT(*) FROM import_observations o WHERE o.import_batch_id = imports.id)`. Simple, no JOIN complexity.

---

## 11. Frontend visibility plan (app.js + style.css)

- Preview summary line: show observed sheets + projected observations alongside existing counts.
- Commit alert: append observations-captured count + batch id.
- Import History table: add Observations column reading `observation_count`.
- Commit payload: send `skipped_rows: state.importPreview.skipped_rows` so parse-skips are captured.
- Delete success alert: append `deleted_observation_count` when returned.
- NO provenance modal, NO table UX, NO dashboard changes.

---

## 12. DB migration safety

`CREATE TABLE IF NOT EXISTS import_observations` is idempotent and additive. Existing imports/entries rows remain valid. No ALTER on existing tables. No backfill. Old batch 9 simply has zero observations (correct — it pre-dates capture).

---

## 13. Verification plan

- node --check app/server.js, app/db.js, app/public/app.js → 0
- bash scripts/invariant-check.sh → 5/5 PASS (verification/004 script absent; use closest available wrapper, as in P3-1..P3-3)
- Live smoke on DISPOSABLE DB copy: table exists; preview no-write; normal commit creates entries+observations; duplicate-only commit creates batch+observations with inserted=0; skipped rows captured; delete cascades observations; manual rows untouched; other batches untouched; Vasu 403; anon 401; allow_duplicates still works; GET /api/imports includes observation_count.
- Regression: messy-row preview, P2-4A warnings, duplicate default-skip/override, delete batch, manual create, RBAC, dashboard render, user management.
- Restore disposable DB / leave live DB documented.

---

## 14. Dependency relationship to P3-5

P3-5 (import provenance in row details modal) will READ `import_observations` and the entries import metadata to expose per-row provenance in the UI. P3-4 creates the observation store P3-5 surfaces. P3-4 does NOT add any modal/provenance UI — that is explicitly P3-5 scope. P3-4 unblocks P3-5.

---

## 15. Conflict assessment

No conflicts. All upstream features RELEASE_APPROVED. P3-4 is additive (new table + capture writes + cascade), preserves all P3-1/P3-2/P3-3 behavior. db.js is an allowed surface for P3-4 (unlike P3-3).

## 16. Files to modify

| File | Change |
|---|---|
| app/db.js | Add import_observations table (additive) |
| app/server.js | Preview skipped raw_data + projected counts; commit observation capture; delete cascade; imports observation_count |
| app/public/app.js | Preview summary, commit alert, history column, skipped_rows in payload, delete alert |
| app/public/style.css | Minor, if needed |
| app/README.md | True Workbook Capture section |
| ai/recon/... | This file |
| specs/phase-3-true-workbook-capture.md | New spec |
| tasks/phase-3-true-workbook-capture-001..004.md | New tasks |
| ai/state_registry.json | State transitions |
| ai/engineering-journal.md | Journal entry |

Forbidden (unchanged): app/public/index.html, app/package.json, app/package-lock.json, prototypes/, sdlc/, source-materials/, vendor/
