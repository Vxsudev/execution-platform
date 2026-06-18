# Task: Guard the demo-entries seed so it does not run in production

## Parent Spec
specs/guard-demo-entries-seed-production.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
In `app/db.js`, the demo-**entries** seed runs whenever the `entries` table is empty, in EVERY
environment — so a fresh production database gets 2 demo rows. Gate it on non-production, exactly
like the demo-**users** seed directly above it already does.

Make a SINGLE change. Find this line (the demo-entries seed condition, near the comment
`// Seed generic illustrative rows to show row shape (not production data).`):

```js
if (db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
```

Change it to:

```js
if (process.env.NODE_ENV !== 'production' && db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
```

Do NOT change anything else. Specifically, leave unchanged:
- the seed body (the two `ins.run({...})` demo rows)
- the bootstrap admin block (production-only, presence/partial-config fail-closed,
  create-only-if-no-admin, `bcrypt.hashSync`)
- the demo-users seed (already guarded with `process.env.NODE_ENV !== 'production'`)
- the audit-column backfill `UPDATE entries SET created_by/updated_by ...` statements
- DB/connection logic, schema/migrations, `app/server.js` (auth), and the import parser

This mirrors the existing predicate `process.env.NODE_ENV !== 'production'` already used by the
demo-users seed in the same file.

## Acceptance Criteria
- [ ] The demo-entries seed `if` condition in `app/db.js` is prefixed with `process.env.NODE_ENV !== 'production' &&`
- [ ] No other line in `app/db.js` is changed (bootstrap, demo-users seed, audit backfill, schema all intact)
- [ ] `app/server.js`, the import parser, schema, and DB connection logic are unchanged
- [ ] `node --check app/db.js` passes

## Files Likely Affected
- app/db.js (single-line condition change to the demo-entries seed)

## Blocked By
- none
