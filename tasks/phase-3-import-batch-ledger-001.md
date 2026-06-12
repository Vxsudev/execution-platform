# Task: Add imports ledger table and entry import metadata columns

## Parent Spec
specs/phase-3-import-batch-ledger.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
Add the `imports` ledger table and three nullable import metadata columns to `entries` in `app/db.js`. Use the existing additive try/catch ALTER TABLE pattern already present in the file.

Changes to `app/db.js`:

1. Add `CREATE TABLE IF NOT EXISTS imports (...)` to the main `db.exec(...)` block — place it after the `entries` table definition.

2. Add three new additive migration lines after the existing try/catch ALTER TABLE block (after the `updated_by` and `role`/`track_scope` lines):
   ```javascript
   try { db.exec("ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;"); } catch (_) {}
   try { db.exec("ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;"); } catch (_) {}
   try { db.exec("ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;"); } catch (_) {}
   ```

The `imports` table schema:
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

Do NOT modify existing table definitions, seed logic, backfill queries, or exports.

## Acceptance Criteria
- [ ] `imports` table exists in the DB after `node app/server.js` starts (verified via PRAGMA table_info or SELECT)
- [ ] `imports` table has all 9 columns: id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status
- [ ] `entries` table has `import_batch_id INTEGER DEFAULT NULL` column
- [ ] `entries` table has `import_source_sheet TEXT DEFAULT NULL` column
- [ ] `entries` table has `import_source_row INTEGER DEFAULT NULL` column
- [ ] All existing `entries` rows have `import_batch_id = NULL` (no backfill)
- [ ] Server starts without error after migration
- [ ] No existing spec, seed, or backfill logic modified

## Files Likely Affected
- app/db.js

## Blocked By
- none
