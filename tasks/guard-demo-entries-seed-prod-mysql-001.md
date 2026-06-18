# Task: Guard the demo-entries seed (inside init()) so it does not run in production

## Parent Spec
specs/guard-demo-entries-seed-prod-mysql.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
IMPORTANT CONTEXT: `app/db.js` on current main is a dual-backend async adapter (MySQL via
`mysql2/promise`, SQLite dev fallback) behind `dba`. It exports `{ dba, ROW_FIELDS, ROW_TYPES,
STATUSES, TRACKS }`. All seeding happens inside the async `init()` function using `get`/`run`. Do
NOT reintroduce any pre-migration constructs: no top-level `new DatabaseSync(...)`, no SQLite-only
`db.prepare(...)` production path, no `{ db, ... }` export.

The demo-**entries** seed inside `init()` runs whenever the `entries` table is empty, in EVERY
environment — so a fresh production database gets 2 demo rows. Gate it on non-production, exactly
like the demo-**users** seed in the same function already does.

Make a SINGLE, surgical change. Find this block inside `init()` (near the comment
`// Seed generic illustrative rows to show row shape (not production data).`):

```js
// Seed generic illustrative rows to show row shape (not production data).
const e = await get('SELECT COUNT(*) c FROM entries');
if ((e ? e.c : 0) === 0) {
  await run(
    `INSERT INTO entries (type,title,owner,track,function_area,hypothesis,success_criteria,status)
     VALUES (?,?,?,?,?,?,?,?)`,
    'experiment', 'Sample experiment', 'demo', 'T1 AstraX Device', 'Engineering',
    'If we do X then Y because Z.', 'Baseline metric improves', 'Not Started');
  await run(
    `INSERT INTO entries (type,title,owner,track,function_area,hypothesis,success_criteria,status)
     VALUES (?,?,?,?,?,?,?,?)`,
    'work_item', 'Sample work item', 'demo', 'T2 AstraX Customer Cloud', 'Software',
    null, null, 'In Progress');
}
```

Wrap the WHOLE block (the `SELECT COUNT(*)` read AND the two inserts) in a non-production guard,
mirroring the demo-users seed structure above:

```js
// Seed generic illustrative rows to show row shape (not production data).
if (process.env.NODE_ENV !== 'production') {
  const e = await get('SELECT COUNT(*) c FROM entries');
  if ((e ? e.c : 0) === 0) {
    await run(
      `INSERT INTO entries (type,title,owner,track,function_area,hypothesis,success_criteria,status)
       VALUES (?,?,?,?,?,?,?,?)`,
      'experiment', 'Sample experiment', 'demo', 'T1 AstraX Device', 'Engineering',
      'If we do X then Y because Z.', 'Baseline metric improves', 'Not Started');
    await run(
      `INSERT INTO entries (type,title,owner,track,function_area,hypothesis,success_criteria,status)
       VALUES (?,?,?,?,?,?,?,?)`,
      'work_item', 'Sample work item', 'demo', 'T2 AstraX Customer Cloud', 'Software',
      null, null, 'In Progress');
  }
}
```

Do NOT change anything else. Specifically leave unchanged:
- the bootstrap admin block (production-only, presence/partial-config fail-closed,
  create-only-if-no-admin, `bcrypt.hashSync`)
- the demo-users seed (already guarded with `process.env.NODE_ENV !== 'production'`)
- the audit-column backfill `UPDATE entries SET created_by/updated_by ...` statements (keep them
  AFTER the guarded seed block, unguarded — they are harmless no-ops on an empty table)
- the MySQL/SQLite backend selection (`useMysql`), the `dba` adapter surface, `init()`/pool/connection
  logic, and the `module.exports = { dba, ... }` line
- `app/server.js` (auth), the import parser, schema/DDL

## Acceptance Criteria
- [ ] The demo-entries seed block inside `init()` is wrapped in `if (process.env.NODE_ENV !== 'production') { ... }`
- [ ] `app/db.js` still exports `{ dba, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }` (NOT `{ db, ... }`)
- [ ] No top-level `new DatabaseSync(...)` and no SQLite-only `db.prepare(...)` production path are introduced
- [ ] Bootstrap admin, demo-users seed, audit backfill, backend selection, and `dba` surface are unchanged
- [ ] `app/server.js`, the import parser, and schema/DDL are unchanged
- [ ] `node --check app/db.js` passes

## Files Likely Affected
- app/db.js (wrap the demo-entries seed block inside init() in a non-production guard)

## Blocked By
- none
