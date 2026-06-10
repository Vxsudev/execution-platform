# Task: Add created_by and updated_by columns to entries table with backfill

## Parent Spec
specs/data-model-audit-trail.md

## Phase
phase-build

## Status
done

## Layer
database

## Description

Edit `app/db.js` ONLY.

### Step 1 — Add migration block after the `db.exec(CREATE TABLE...)` block

Locate the closing `);` of the CREATE TABLE block (currently ends around line 76).
Immediately after it, add:

```javascript
try { db.exec("ALTER TABLE entries ADD COLUMN created_by TEXT;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN updated_by TEXT;"); } catch (_) {}
db.exec("UPDATE entries SET created_by = 'system' WHERE created_by IS NULL;");
db.exec("UPDATE entries SET updated_by = 'system' WHERE updated_by IS NULL;");
```

**Why try/catch?** SQLite throws `"duplicate column name: created_by"` when the column already exists.
The catch suppresses this, making the migration idempotent for existing databases.

**Why UPDATE backfill?** Existing rows get NULL by default. The UPDATE stamps `'system'` for
rows that predate this migration — safe to run on every boot since it only touches NULL rows.

### Invariants

- The existing CREATE TABLE block must remain UNCHANGED.
- `created_at` and `updated_at` already exist — do NOT add ALTER for them.
- No other changes to db.js in this task.
- No change to ROW_FIELDS, TRACKS, STATUSES, ROW_TYPES, or module.exports.

## Acceptance Criteria
- [ ] `ALTER TABLE entries ADD COLUMN created_by TEXT` added (try/catch wrapped).
- [ ] `ALTER TABLE entries ADD COLUMN updated_by TEXT` added (try/catch wrapped).
- [ ] Backfill UPDATE for created_by (WHERE IS NULL) added.
- [ ] Backfill UPDATE for updated_by (WHERE IS NULL) added.
- [ ] All four lines are immediately after the existing CREATE TABLE block.
- [ ] Existing CREATE TABLE block is unchanged.
- [ ] ROW_FIELDS does not contain created_by or updated_by.
- [ ] module.exports is unchanged.
- [ ] `node app/server.js` boots without error after change.
- [ ] `SELECT id, created_by, updated_by FROM entries` returns rows with non-NULL values.

## Files Likely Affected
- `app/db.js`

## Blocked By
- none
