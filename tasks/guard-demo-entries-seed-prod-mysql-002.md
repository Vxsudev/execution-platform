# Task: Verify production starts with zero entries; dev seed, adapter, and import 64 intact

## Parent Spec
specs/guard-demo-entries-seed-prod-mysql.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the demo-entries seed guard from task 001 on the current MySQL-adapter `app/db.js`. Use
disposable databases only (a throwaway `DB_PATH`); never mutate the live `app/data.db`. Drive the
seed logic via `dba.init()`. The guard `process.env.NODE_ENV !== 'production'` is backend-agnostic,
so exercising the SQLite fallback with `NODE_ENV=production` proves the production seed behavior for
the MySQL backend too (a live MySQL server is not required).

1. `node --check app/db.js` passes.
2. **Production mode, empty DB:** `NODE_ENV=production`, `BOOTSTRAP_ADMIN_USERNAME` and
   `BOOTSTRAP_ADMIN_PASSWORD` set, fresh `DB_PATH`, no MySQL env (SQLite fallback runs the same
   guarded `init()` path). Require `app/db.js`, `await dba.init()`. Assert `users` contains the
   bootstrap admin (role = admin) and `entries` has **0** rows.
3. **Dev mode, empty DB:** `NODE_ENV` unset, fresh `DB_PATH`. `await dba.init()`. Assert demo entries
   seeded (2 rows) and demo users seeded — dev fallback intact.
4. **Adapter integrity:** `module.exports` is `{ dba, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }`; the
   file contains no top-level `new DatabaseSync(...)` outside `buildSqliteBackend`, no `{ db, ... }`
   export, and `dba` exposes `init`/`get`/`all`/`run`/`exec`/`tx`.
5. **Import 64 still works:** the authoritative 64-row workbook parses to 64 importable rows
   (import code path unchanged by this edit).
6. `bash scripts/invariant-check.sh` → 5/5 PASS; `git status` shows only allowed surfaces
   (`app/db.js`, OS artifacts).

## Acceptance Criteria
- [ ] Production mode empty DB → `users` has bootstrap admin, `entries` has 0 rows
- [ ] Dev mode empty DB → demo entries (2 rows) and demo users seeded (fallback preserved)
- [ ] Export is `{ dba, ... }`; no top-level DatabaseSync / no `{ db, ... }` reintroduced
- [ ] Import of the 64-row workbook still yields 64 importable rows
- [ ] `node --check app/db.js` passes; invariants 5/5; git status only allowed surfaces

## Files Likely Affected
- (verification only — no application source changes)

## Blocked By
- tasks/guard-demo-entries-seed-prod-mysql-001.md
