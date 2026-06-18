# Spec: Guard Demo Entries Seed in Production (MySQL adapter)

## Status
approved

## Phase
phase-build

## Feature Slug
guard-demo-entries-seed-prod-mysql

## Depends On
Recon: ai/recon/guard-demo-entries-seed-prod-mysql-recon.md. Targets current main (5463cf5) AFTER
the MySQL migration (PR #4, aaabd59). Supersedes the stale guard-demo-entries-seed-production / PR #6
(branched pre-migration; closed). Preserves the MySQL adapter as authoritative, the `{ dba, ... }`
export, admin bootstrap (R3), demo-users dev seed, auth, import parser, schema, DB_PATH (R2).

---

## Summary

A fresh production boot inserts 2 demo `entries` rows because the demo-entries seed inside the async
`init()` in `app/db.js` has **no environment guard** — unlike the demo-**users** seed in the same
function, which is gated on `process.env.NODE_ENV !== 'production'`. Wrap the demo-entries seed in the
same guard so production (MySQL) starts with **zero** entries while local/dev (SQLite fallback) keeps
seeding demo rows. The guard is backend-agnostic (it gates shared `init()` seed logic). Nothing else
changes — the MySQL adapter, `dba` surface, backend selection, and exports stay exactly as they are.

---

## Background

After the MySQL migration, `app/db.js` is a dual backend (MySQL via `mysql2/promise`, SQLite dev
fallback) behind one async `dba` adapter, exporting `{ dba, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }`.
Seeding happens in `init()` via `get`/`run`. The demo-users seed and bootstrap admin are
`NODE_ENV`-guarded; the demo-entries seed is the lone unguarded seed, so a clean production database
gets demo rows. Operator wants production to start empty; dev demo seed should remain.

A prior attempt (PR #6) was branched before the migration and operated on the old top-level
`DatabaseSync` SQLite code / `{ db, ... }` export; it was stale and has been closed. This spec
targets the current adapter code and must NOT reintroduce those old constructs.

---

## Data Model Changes

none

---

## API Surface

Backend-only change in `app/db.js`: wrap the demo-entries seed inside `init()` in
`if (process.env.NODE_ENV !== 'production') { ... }` (the exact predicate the demo-users seed already
uses), so the seed runs only outside production. No HTTP routes change. The MySQL adapter remains
authoritative: backend selection (`useMysql`), the `dba` surface, `init()`/pool/connection logic, and
the `{ dba, ... }` export are unchanged. Bootstrap admin, demo-users seed, and audit-column backfill
are unchanged. Auth and the import parser are untouched. The change must NOT reintroduce a top-level
`new DatabaseSync(...)`, a SQLite-only `db.prepare(...)` production path, or a `{ db, ... }` export.

---

## Frontend Surface

none

---

## Non-Scope

- No change to bootstrap admin behavior
- No change to the demo-users seed (already dev-only)
- No change to the MySQL/SQLite backend selection, `dba` adapter surface, or connection/pool logic
- No change to the `{ dba, ... }` export
- No change to auth/session, user create/update
- No change to the import parser or import behavior
- No change to schema/DDL, DB_PATH
- No `app/public/*`, package, or deploy/Railway change; no Docker/Postgres change

---

## Implementation Plan

### Task 1 — Backend: guard demo-entries seed on non-production inside init() (backend)

In `app/db.js`, inside the async `init()` function, change the demo-entries seed from:
```js
// Seed generic illustrative rows to show row shape (not production data).
const e = await get('SELECT COUNT(*) c FROM entries');
if ((e ? e.c : 0) === 0) {
  await run(`INSERT INTO entries (...) VALUES (?,?,?,?,?,?,?,?)`, 'experiment', 'Sample experiment', ...);
  await run(`INSERT INTO entries (...) VALUES (?,?,?,?,?,?,?,?)`, 'work_item',  'Sample work item',  ...);
}
```
to wrap the whole block in a non-production guard, mirroring the demo-users seed:
```js
// Seed generic illustrative rows to show row shape (not production data).
if (process.env.NODE_ENV !== 'production') {
  const e = await get('SELECT COUNT(*) c FROM entries');
  if ((e ? e.c : 0) === 0) {
    await run(...);
    await run(...);
  }
}
```
Do NOT change anything else. Do NOT reintroduce `DatabaseSync`, `db.prepare` production paths, or the
`{ db, ... }` export. Leave the audit-column backfill UPDATEs (after the seed) unchanged.

### Task 2 — Verification

Disposable DBs only (live `app/data.db` untouched), driven via `dba.init()`: production mode empty DB
→ bootstrap admin present + `entries` 0 rows; dev mode empty DB → demo entries (2) + demo users
seeded; module still exports `{ dba, ... }` with no top-level DatabaseSync / `{ db, ... }`; import 64
still works; `node --check`; invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | Wrap the demo-entries seed inside `init()` in `if (process.env.NODE_ENV !== 'production') { ... }` |
| `ai/recon/...` , `specs/...` , `tasks/...` , `ai/state_registry.json` , `ai/engineering-journal.md` | OS artifacts |

---

## Verification Plan

See recon §6. Key assertions: production mode empty DB → bootstrap admin only, `entries` 0 rows; dev
mode empty DB → demo entries + demo users seeded; `{ dba, ... }` export intact and no stale SQLite
constructs reintroduced; import 64 unaffected; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke against the production MySQL instance — confirm a fresh
DB boots with the bootstrap admin and an empty `entries` table.
