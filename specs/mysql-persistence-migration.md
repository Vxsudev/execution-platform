# Spec: MySQL Persistence Migration

## Status
approved

## Phase
phase-build

## Feature Slug
mysql-persistence-migration

## Depends On
Recon: ai/recon/mysql-persistence-migration-recon.md. Supersedes the Railway volume-backed SQLite
production path (railway-r2-db-path-volume-contract) and the volume guard
(fix/railway-db-volume-guard). Branches from `main`.

---

## Summary

Replace production SQLite file persistence with Railway MySQL via a thin async DB adapter, preserving
all current behavior (login, sessions, users, row CRUD, import preview/commit/history/observations,
batch delete, access model, row-click edit, admin bootstrap). A **dual-backend** adapter selects MySQL
when MySQL env vars are present (production) and SQLite otherwise (local dev), behind one async
interface. `server.js` handlers become `async`/`await` and are wrapped for Express 4 error
forwarding. No frontend/UX change. No Railway volume dependency remains in the production path.

---

## Target DB Provider Behavior

- **Production:** MySQL (`mysql2/promise` connection pool). No `node:sqlite`, no `/data` volume.
- **Local dev:** SQLite (`node:sqlite`, `DB_PATH` or `app/data.db`) retained — not deleted.
- **Selection:** MySQL if `MYSQL_URL` or `MYSQLHOST` is set; else SQLite.
- **Safe logging only** at init: provider name, `host present: yes/no`, `database present: yes/no`,
  `connection established: yes/no`. Never log credentials or connection URLs.

## MySQL Env Variable Contract

Connection source precedence:
1. `MYSQL_URL` (full connection string)
2. Fallback to individual: `MYSQLHOST`, `MYSQLPORT` (default 3306), `MYSQLUSER`, `MYSQLPASSWORD`,
   `MYSQLDATABASE`.

Retained: `SESSION_SECRET` (required in production, 32+ chars), `PORT` (Railway-injected), `NODE_ENV`,
`BOOTSTRAP_ADMIN_USERNAME`/`BOOTSTRAP_ADMIN_PASSWORD` (first boot only). `DB_PATH` retired from the
production path (still valid for local SQLite). Pool configured with `dateStrings: true` so DATETIME
returns `'YYYY-MM-DD HH:MM:SS'` strings (matching SQLite output shape).

## Schema Contract

Tables (unchanged set): `users`, `sessions`, `entries`, `imports`, `import_observations`. Behavior
preserved: auto-increment integer PKs; `users.username` UNIQUE; `sessions.token` PK; entries
auto-increment id; `import_batch_id`; observations linked to import batch; timestamps via
MySQL-compatible defaults (`DATETIME DEFAULT CURRENT_TIMESTAMP`). `username`/`sessions.token` use
`VARCHAR(255)`; free text uses `TEXT`; `import_observations.raw_data` uses `MEDIUMTEXT`. Type/status/
role validation stays **app-level** (no MySQL ENUM/CHECK), matching existing `validate()` /
`classifyImportRow`. Schema initializes idempotently (CREATE TABLE IF NOT EXISTS executed
statement-by-statement; ALTER ADD COLUMN guarded against dup-column errors).

## Adapter / API Contract

`app/db.js` exports an async adapter `dba` plus the existing `{ ROW_FIELDS, ROW_TYPES, STATUSES,
TRACKS }`:

```
dba.get(sql, ...params)  → first row | undefined
dba.all(sql, ...params)  → row[]
dba.run(sql, ...params)  → { insertId, changes }      // normalized across drivers
dba.tx(async (t) => {})  → transaction; t has get/all/run
dba.init()               → schema + idempotent migrations + seed/bootstrap (awaited at boot)
dba.isUniqueViolation(e) → bool (ER_DUP_ENTRY | /UNIQUE constraint/)
```

All runtime SQL uses `?` placeholders and stays dialect-portable. The one non-portable literal
(`datetime('now')` in the entries UPDATE) is replaced by a JS-computed `'YYYY-MM-DD HH:MM:SS'` bound
param. `server.js` calls become `await dba.<m>(...)`; handlers are `async` and wrapped with `wrap()`.

## Bootstrap Contract (unchanged semantics)

- Production requires `SESSION_SECRET` (32+ chars) — fatal otherwise.
- First admin created **only when no admin exists**; existing admin password **never overwritten**.
- Partial bootstrap env (exactly one of username/password) remains **fatal**.
- No password length restriction (current approved behavior preserved).
- Bootstrap runs against MySQL on production boot, no-op once an admin row exists.

## Import Contract (unchanged behavior)

- Preview is read-only (no writes).
- Commit writes **all previewed importable rows** to MySQL.
- Duplicate detection (source-row + logical) preserved; `allow_duplicates` honored.
- Import history (`imports`) and observations (`import_observations`) preserved.
- Batch delete removes the batch's entries + observations (incl. evidence-based legacy-orphan
  recovery) inside a `dba.tx()` transaction; counts returned unchanged.

## Rollback / Fallback Decision

Dual-backend retains SQLite as the local-dev fallback, so reverting the branch fully restores the
prior path; production simply unsets MySQL vars. **Open decision for the operator:** keep dual-backend
long-term, or drop the SQLite branch for MySQL-only once Railway MySQL is proven. Default: keep dual
(lower risk, no behavior loss). No destructive change to existing data; live `app/data.db` untouched.

## UI Contract

No frontend changes. Row-click edit, clicked-cell highlight, import pagination, and access-control
behavior unchanged. If async error display proves unavoidable → STOP and report (forbidden-file rule).

## Verification Plan

Per recon §9: `node --check` both files; `npm install` (mysql2); boot on disposable `mysql:8`
container; run the 15 required smokes over HTTP (boot/schema idempotent, bootstrap create + restart
skip, login, create user, create/edit row, import preview, commit writes all importable rows from the
current workbook, history count, batch delete, restart-preserves-data, no `/data` dependency, no
secrets logged); plus a SQLite-backed async smoke to prove path parity. Disposable DBs only; no
Railway mutation; no production data import; no deploy.

## Non-Scope

ORMs; Docker/Railway config; frontend/UX; bootstrap/password/import-classification semantics; schema
semantics beyond dialect equivalence; production data import; deploy. Demo-entries seed (db.js:159)
left as-is.
