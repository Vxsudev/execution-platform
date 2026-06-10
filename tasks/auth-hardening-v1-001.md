# Task: Gate demo user seeding on NODE_ENV !== 'production' in app/db.js

## Parent Spec
specs/auth-hardening-v1.md

## Phase
phase-build

## Status
done

## Layer
database

## Description

Edit `app/db.js` ONLY. No schema changes. Change the demo user seed behavior.

### Current code (lines 82–87)

```javascript
// Seed users (change these in production).
if (db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}
```

### Change: gate on NODE_ENV

Replace the entire user seed block with:

```javascript
// Seed demo users only in non-production environments.
if (process.env.NODE_ENV !== 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}
if (process.env.NODE_ENV === 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  console.warn('WARNING: No users exist in the database. See README for production setup instructions.');
}
```

### Invariants

- No schema change (no ALTER TABLE, no CREATE TABLE modification).
- No change to entries seed behavior.
- No change to module.exports.
- No change to TRACKS, ROW_FIELDS, ROW_TYPES, STATUSES.
- Local dev (NODE_ENV unset or !== 'production'): behavior unchanged — admin/admin123 still seeded on fresh DB.

## Acceptance Criteria
- [ ] User seed block replaced with NODE_ENV-gated version.
- [ ] Non-production: fresh DB still seeds admin/admin123 and vasu/vasu123.
- [ ] Production gating line added: `process.env.NODE_ENV === 'production' && count === 0` → console.warn.
- [ ] No schema or export changes.
- [ ] Server boots with no NODE_ENV set (local dev).

## Files Likely Affected
- `app/db.js`

## Blocked By
- none
