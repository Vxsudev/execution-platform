# Guard Demo Entries Seed in Production (MySQL adapter): Recon

**Feature Slug:** guard-demo-entries-seed-prod-mysql  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** 5463cf5

---

## 1. Recon Objective

Read-only recon to find the demo **entries** seed in the **current** `app/db.js` — which after the
MySQL migration (commit `aaabd59`, PR #4) is a dual-backend async adapter (`dba`) — and guard it so
a fresh **production** boot starts with **zero** entries, while preserving the bootstrap admin flow,
the local/dev demo seed, the MySQL adapter as authoritative, auth, and the import parser.

---

## 2. Critical Context — supersedes the earlier stale attempt

An earlier attempt (`guard-demo-entries-seed-production`, PR #6) was branched from `c3eb156`, which
PRE-DATES the MySQL migration. That branch operated on the OLD top-level `DatabaseSync` SQLite code
and the `{ db, ... }` export. **It was stale and has been closed/deleted.** This recon targets
current `main` (`5463cf5`), where:

- `app/db.js` is a **dual backend** behind one async interface: MySQL (`mysql2/promise` pool) when
  `MYSQL_URL`/`MYSQLHOST` is present (production), SQLite (`node:sqlite`) as local/dev fallback.
- The module exports **`{ dba, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }`** (NOT `{ db, ... }`).
- All seeding happens inside the async **`init()`** function via `get`/`run`/`exec` (backend-agnostic).
- There is **no** top-level `new DatabaseSync(...)` production path anymore.

This fix must NOT reintroduce any of those old constructs.

---

## 3. Files Read

| File | Finding |
|------|---------|
| `app/db.js` (current main) | Demo **entries** seed inside `init()` (`const e = await get('SELECT COUNT(*) c FROM entries')` → insert 2 rows) is **NOT** `NODE_ENV`-guarded — runs in every environment, including production MySQL |
| `app/db.js` (current main) | Demo **users** seed in `init()` IS guarded: `if (process.env.NODE_ENV !== 'production') { ... }` — the pattern to mirror |
| `app/db.js` (current main) | Bootstrap admin block (production-only, presence/partial-config fail-closed, create-only-if-no-admin, bcrypt) — must stay unchanged |
| `app/db.js` (current main) | Exports `{ dba, ... }`; `dba.init()` is the async entry point; `usingMysql` getter exposes backend choice |
| `app/server.js` (current main) | Uses `await dba.get/all/run(...)`; calls `dba.init()` at startup — out of scope for this change |

---

## 4. The Seed To Guard — `app/db.js` (inside `init()`, ~lines 378-393)

```js
// Seed generic illustrative rows to show row shape (not production data).
const e = await get('SELECT COUNT(*) c FROM entries');
if ((e ? e.c : 0) === 0) {
  await run(`INSERT INTO entries (...) VALUES (?,?,?,?,?,?,?,?)`, 'experiment', 'Sample experiment', ...);
  await run(`INSERT INTO entries (...) VALUES (?,?,?,?,?,?,?,?)`, 'work_item',  'Sample work item',  ...);
}
```

No `NODE_ENV` guard → a fresh production database (MySQL or SQLite) gets 2 demo rows. Mirror the
demo-users seed structure: wrap the whole block in `if (process.env.NODE_ENV !== 'production') { ... }`.

The guard is **backend-agnostic** (it gates the shared `init()` seed, not backend code), so it
applies identically whether the active backend is MySQL or the SQLite dev fallback.

---

## 5. What Changes vs What Stays

### Changes
- Wrap the demo-entries seed (the `SELECT COUNT(*) FROM entries` read + the two `INSERT`s) in
  `if (process.env.NODE_ENV !== 'production') { ... }`, mirroring the demo-users seed above it.

### Stays (must NOT change)
- Bootstrap admin (production-only, presence/partial-config fail-closed, create-only-if-no-admin, bcrypt).
- Demo **users** seed (already dev-only).
- Local/dev demo **entries** seed still runs when `NODE_ENV !== 'production'`.
- Audit-column backfill `UPDATE entries SET created_by/updated_by` (no-ops on empty prod table).
- **MySQL adapter remains authoritative**; backend selection (`useMysql`), `dba` surface, exports
  `{ dba, ... }`, `init()`/pool/connection logic — all unchanged.
- Auth (`app/server.js`), import parser, schema/DDL — unchanged.

### MUST NOT reintroduce (stale-PR regressions to avoid)
- Top-level `new DatabaseSync(configuredDbPath)`.
- SQLite-only `db.prepare(...)` production path.
- `{ db, ... }` export.

---

## 6. Verification Plan

Disposable DBs only; live `app/data.db` never mutated; throwaway `DB_PATH`. Driven via `dba.init()`.
1. `node --check app/db.js`.
2. **Production mode, empty DB:** `NODE_ENV=production` + `BOOTSTRAP_ADMIN_USERNAME/PASSWORD` set,
   fresh `DB_PATH`, no MySQL env (SQLite fallback exercises the same guarded `init()` path) →
   `await dba.init()` → assert `users` has the bootstrap admin (role=admin) and `entries` = **0**.
3. **Dev mode, empty DB:** `NODE_ENV` unset, fresh `DB_PATH` → `await dba.init()` → assert demo
   entries seeded (2 rows) and demo users seeded.
4. **Export/adapter integrity:** module exports `{ dba, ... }`; no top-level `DatabaseSync`; no
   `db.prepare` production path; no `{ db, ... }` export.
5. **Import 64 still works:** the authoritative 64-row workbook parses to 64 importable rows
   (import code path unchanged by this edit).
6. `bash scripts/invariant-check.sh` → 5/5; `git status` → only allowed surfaces.

Note: the `NODE_ENV !== 'production'` guard is backend-agnostic, so steps 2-3 prove the production
vs dev behavior for the MySQL backend as well; a live MySQL server is not required to prove the guard.

---

## 7. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Re-introducing stale SQLite/`{db}` constructs | High | Edit ONLY the seed condition inside `init()`; explicit "must not reintroduce" list; verify exports |
| Guard suppresses dev seed too | Low | Mirror exact demo-users predicate (`!== 'production'`); dev path unchanged |
| Touching bootstrap/auth/import/adapter | Medium | Single block-wrap; node --check + invariants + export check |

---

## 8. Non-Scope

Auth/session, user create/update, import parser, schema/DDL, bootstrap admin behavior, MySQL/SQLite
backend selection and connection logic, `dba` surface, `app/public/*`, Railway/deploy. No Docker,
no Postgres, no deploy.

---

## 9. Next Recommended Node

Railway redeploy smoke against the production **MySQL** instance — confirm a fresh DB boots with the
bootstrap admin and an empty `entries` table.
