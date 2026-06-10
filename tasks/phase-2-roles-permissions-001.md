# Task: Add role and track_scope columns to users table with idempotent backfill

## Parent Spec
specs/phase-2-roles-permissions.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
Add two new columns to the `users` table in `app/db.js` using the established try/catch
ALTER TABLE migration pattern. Add non-destructive backfill for local demo users. No new
tables. No changes to the entries table or any other existing schema.

### Migration

Add immediately after the existing audit trail ALTER TABLE block (lines 78-79 in db.js,
which add `created_by` and `updated_by` to entries):

```javascript
try { db.exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer';"); } catch (_) {}
try { db.exec("ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL;"); } catch (_) {}
```

- `role TEXT DEFAULT 'viewer'` — existing users get least-privilege role until backfilled.
- `track_scope TEXT DEFAULT NULL` — NULL treated as empty array by parseScope in server.js.
- try/catch makes both ALTERs idempotent: SQLite throws on duplicate column, suppressed.

### Backfill

Add immediately after the two ALTER TABLE lines above:

```javascript
if (process.env.NODE_ENV !== 'production') {
  db.exec("UPDATE users SET role = 'admin' WHERE username = 'admin' AND (role IS NULL OR role = 'viewer');");
  db.exec("UPDATE users SET role = 'track_owner', track_scope = '[\"T3 AstraX Ops Cloud\"]' WHERE username = 'vasu' AND (role IS NULL OR role = 'viewer');");
}
```

- Guard: `NODE_ENV !== 'production'` — identical to the demo seed guard at db.js:83.
- Idempotent: `(role IS NULL OR role = 'viewer')` condition prevents overwriting a real role.
- admin → role='admin' (no track_scope needed; admin has implicit all-access).
- vasu → role='track_owner', track_scope='["T3 AstraX Ops Cloud"]' (JSON string in DB).

### Preserve all existing db.js behavior

Modify ONLY the area after the entries audit trail block. Do not touch:
- ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS constants
- users table CREATE TABLE DDL
- sessions table CREATE TABLE DDL
- entries table CREATE TABLE DDL
- The two existing try/catch ALTER TABLE blocks for created_by / updated_by on entries
- The entries backfill UPDATE blocks (created_by/updated_by 'system')
- The demo seed if-block (admin/admin123, vasu/vasu123)
- The entries seed if-block
- module.exports at the bottom

## Acceptance Criteria
- [ ] `try { db.exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer';"); } catch (_) {}` present in db.js immediately after the entries audit trail ALTER TABLE lines
- [ ] `try { db.exec("ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL;"); } catch (_) {}` present immediately after the role ALTER TABLE line
- [ ] Backfill block present immediately after: sets admin role='admin' and vasu role='track_owner' track_scope='["T3 AstraX Ops Cloud"]', gated on NODE_ENV !== 'production'
- [ ] Backfill UPDATE conditions include `(role IS NULL OR role = 'viewer')` for idempotency
- [ ] All existing db.js content is unchanged (ROW_FIELDS order, TRACKS array, entries DDL, prior ALTER TABLE blocks, seed blocks, module.exports)
- [ ] App boots without error: `cd app && node server.js` starts and logs the port
- [ ] On fresh dev boot: `SELECT role, track_scope FROM users WHERE username='admin'` returns role='admin'
- [ ] On fresh dev boot: `SELECT role, track_scope FROM users WHERE username='vasu'` returns role='track_owner', track_scope='["T3 AstraX Ops Cloud"]'

## Files Likely Affected
- app/db.js

## Blocked By
- none
