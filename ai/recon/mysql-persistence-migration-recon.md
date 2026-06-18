# MySQL Persistence Migration — Recon

**Feature Slug:** mysql-persistence-migration
**Date:** 2026-06-18
**Author:** AI Engineering OS (in-session worker)
**HEAD at recon:** 2516932 (branch `fix/railway-db-volume-guard`; migration will branch from `main`)
**Mode:** RECON (implementation deferred to TASK_GRAPH_LOCKED)

---

## 1. Objective

The operator is abandoning Railway volume-backed SQLite (volume attach repeatedly fails/loops/resets)
and has provisioned a Railway MySQL service. Migrate production persistence from synchronous
`node:sqlite` file storage to MySQL while preserving all current behavior: login, sessions, users, row
CRUD, import preview/commit/history/observations, batch delete, access model, row-click edit, and admin
bootstrap semantics.

---

## 2. Files Inspected

| File | Role |
|------|------|
| `app/db.js` | DB open, schema DDL, idempotent ALTERs, demo seed, prod bootstrap, backfills, exports `{ db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }` |
| `app/server.js` | All HTTP routes + every runtime DB call (sync `db.prepare().get()/.all()/.run()`, `db.exec()` for transactions) |
| `app/package.json` | deps: `bcryptjs`, `express@^4.19.2`, `xlsx`; `engines.node >= 24`; `start: node server.js` |
| `app/.env.example` | current env contract (`SESSION_SECRET`, `NODE_ENV`, `PORT`, `DB_PATH`, bootstrap vars) |
| `app/README.md` | Railway R1–R3 deploy docs; DB described as built-in `node:sqlite` persisting to `data.db` |
| `app/.nvmrc` | Node 24 pin |

Governance surfaces present: `.engineering-os/adapter.config.sh`, `ai/invariant-registry.md`,
`ai/engineering-journal.md`. (`ai/product-invariants.md`, `runtime-contracts.md`,
`service-boundaries.md`, `coding-patterns.md`, `repo-index.md` not present.)

---

## 3. Driver Characteristics (the core problem)

`node:sqlite` `DatabaseSync` is **synchronous**: `db.prepare(sql).get(...)/.all(...)/.run(...)` and
`db.exec(sql)` return immediately. `mysql2/promise` is **asynchronous** (`pool.query(sql, params)` →
`Promise<[rows, fields]>`). There is no transparent sync→async shim. **Therefore every route handler
and helper that touches the DB must become `async`/`await`.** This is the dominant cost of the
migration, not the SQL dialect.

Express is **4.19.2** → async handler rejections are **not** auto-forwarded to the error middleware.
A small `wrap(asyncFn)` helper (catch → `next(err)` or 500 JSON) is required to keep error semantics.

---

## 4. Full DB Touchpoint Inventory

### 4.1 `app/db.js`

| Line(s) | Call | Notes |
|---------|------|-------|
| 14 | `new DatabaseSync(configuredDbPath)` | open; MySQL = create pool from env |
| 16 | `PRAGMA journal_mode = WAL` | **SQLite-only** — drop for MySQL |
| 51–104 | `db.exec(<multi-statement CREATE TABLE …>)` | MySQL needs per-statement execution or `multipleStatements` |
| 106–114 | `try { db.exec("ALTER TABLE … ADD COLUMN …") } catch {}` | idempotent migrations; MySQL dup-column = `ER_DUP_FIELDNAME` (still catchable) |
| 118–122 | demo users seed (`!production`) | `.prepare/.get/.run` |
| 125–147 | prod admin bootstrap | `.get` count, `.run` insert |
| 148–150 | no-users warning (prod) | `.get` count |
| 153–156 | demo role backfill (`!production`) | `db.exec UPDATE` |
| 159–168 | demo entries seed (empty-table only) | `.get` count, `.run` insert |
| 171–172 | audit-column backfill | `db.exec UPDATE` |

### 4.2 `app/server.js`

| Line(s) | Route / fn | Call | Dialect-sensitive? |
|---------|-----------|------|--------------------|
| 81–84 | `currentUser` | SELECT join `.get` | portable |
| 96 | `/api/login` | SELECT user `.get` | portable |
| 101 | `/api/login` | INSERT sessions `.run` | portable |
| 114 | `/api/logout` | DELETE sessions `.run` | portable |
| 161 | `GET /api/rows` | SELECT `.all` | portable |
| 164 | `GET /api/rows/:id` | SELECT `.get` | portable |
| 177–179 | `POST /api/rows` | INSERT `.run` (**lastInsertRowid**) + SELECT `.get` | insertId |
| 182,192,194 | `PUT /api/rows/:id` | SELECT `.get`, UPDATE `.run`, SELECT `.get` | **`datetime('now')` literal** in UPDATE |
| 198 | `DELETE /api/rows/:id` | DELETE `.run` | portable |
| 222 | `GET /api/users` | SELECT `.all` | portable |
| 240–242 | `POST /api/users` | INSERT `.run` (**lastInsertRowid**) + SELECT `.get` | insertId |
| 245 | `POST /api/users` | error text `includes('UNIQUE constraint')` | **MySQL = `ER_DUP_ENTRY`** |
| 255,278,280 | `PUT /api/users/:id` | SELECT `.get`, UPDATE `.run`, SELECT `.get` | portable |
| 288,290,291 | `DELETE /api/users/:id` | SELECT `.get`, DELETE `.run` ×2 | portable |
| 421,425–442 | dup detection | `.get` with `lower(trim(coalesce(...)))` | `LOWER/TRIM/COALESCE` portable |
| 507–510 | `POST /api/import/commit` | INSERT imports `.run` (**lastInsertRowid**) | insertId |
| 532–534 | import commit | INSERT entries `.run` (**lastInsertRowid**) in loop | insertId |
| 546–552 | import commit | `obsStmt = db.prepare(...)` **reused** in loop `.run` | adapter must allow repeated exec |
| 574–578 | `GET /api/imports` | SELECT `.all` with correlated subquery | portable |
| 586 | `DELETE /api/imports/:id` | SELECT `.get` | portable |
| 588,620,623 | batch delete | `db.exec('BEGIN'/'COMMIT'/'ROLLBACK')` | **transaction API differs** |
| 597–599 | batch delete | SELECT `.all` | portable |
| 606,607,615 | batch delete | DELETE `.run` (**.changes**) | affectedRows |
| 619 | batch delete | DELETE imports `.run` | portable |

**Summary of dialect-sensitive runtime SQL:** exactly one literal — `datetime('now')` in the entries
UPDATE (192). Everything else is portable with `?` placeholders. The remaining differences are in the
**driver result shape** (`lastInsertRowid`→`insertId`, `.changes`→`affectedRows`), **transactions**,
**schema DDL**, and **error codes** — all of which the adapter boundary absorbs.

---

## 5. Schema Mapping (SQLite → MySQL)

CHECK/ENUM kept **app-level** (validation already enforced in `server.js` `validate()` /
`classifyImportRow`), per Architecture Contract — avoids MySQL ENUM portability friction.

| Table.column | SQLite | MySQL equivalent |
|--------------|--------|------------------|
| `*.id` | `INTEGER PRIMARY KEY AUTOINCREMENT` | `INT AUTO_INCREMENT PRIMARY KEY` |
| `users.username` | `TEXT UNIQUE NOT NULL` | `VARCHAR(255) NOT NULL UNIQUE` (TEXT can't be UNIQUE without prefix len) |
| `users.password_hash` | `TEXT NOT NULL` | `VARCHAR(255) NOT NULL` (bcrypt = 60 chars) |
| `users.role` | `TEXT DEFAULT 'viewer'` | `VARCHAR(32) DEFAULT 'viewer'` |
| `users.track_scope` | `TEXT DEFAULT NULL` | `TEXT NULL` (JSON string; app-parsed) |
| `sessions.token` | `TEXT PRIMARY KEY` | `VARCHAR(255) PRIMARY KEY` |
| `sessions.user_id` | `INTEGER NOT NULL` | `INT NOT NULL` |
| `entries.type/status` | `TEXT … CHECK(...)` | `VARCHAR(32)` + app-level validation |
| `entries.title` | `TEXT NOT NULL` | `TEXT NOT NULL` (always supplied on insert) |
| `entries` free-text cols | `TEXT` | `TEXT NULL` |
| `entries.import_batch_id` | `INTEGER` | `INT NULL` |
| `entries.import_source_row` | `INTEGER` | `INT NULL` |
| `imports.*` counts | `INTEGER` | `INT` |
| `import_observations.raw_data` | `TEXT` | `MEDIUMTEXT` (JSON blobs can exceed 64KB across a batch) |
| all `created_at/updated_at/imported_at` | `TEXT DEFAULT (datetime('now'))` | `DATETIME DEFAULT CURRENT_TIMESTAMP` |

**Timestamp read parity:** SQLite returns `'YYYY-MM-DD HH:MM:SS'` strings. mysql2 returns `DATETIME` as
JS `Date` by default → would change JSON shape. **Configure mysql2 with `dateStrings: true`** so
DATETIME comes back as `'YYYY-MM-DD HH:MM:SS'` strings, matching SQLite. The UPDATE at server.js:192
must stop using `datetime('now')`; pass a JS-computed `'YYYY-MM-DD HH:MM:SS'` value as a bound param so
the statement is dialect-free.

---

## 6. Adapter Recommendation

**Yes — a thin async DB adapter minimizes `server.js` churn and is the right boundary.** Recommend a
**dual-backend** adapter selected by environment, exposing one async interface:

```
dba.get(sql, ...params)   → first row | undefined
dba.all(sql, ...params)   → row[]
dba.run(sql, ...params)   → { insertId, changes }   // normalized across drivers
dba.tx(async (t) => {...}) → transaction; t has the same get/all/run
dba.init()                 → create schema + run idempotent migrations + seed/bootstrap
```

- **Backend selection:** if `MYSQL_URL` or `MYSQLHOST` present → **MySQL** (`mysql2/promise` pool);
  else → **SQLite** (`node:sqlite`, current `data.db`/`DB_PATH` path) for local dev. This honors
  "prefer adapter boundary," keeps the fast zero-dependency local loop, and does **not** delete SQLite
  support (migration principle #4). Production on Railway sets MySQL vars → MySQL path; no `/data`
  volume dependency remains.
- **Why dual, not MySQL-only:** local dev and the existing smoke flows run without a MySQL server;
  only the one non-portable literal (`datetime('now')`) needs changing for portability, so the dual
  cost is low. (If the operator prefers MySQL-only, the SQLite branch can be dropped later — recorded
  as an open decision in the spec's rollback section.)
- **Result normalization:** SQLite `{ lastInsertRowid, changes }` and mysql2
  `{ insertId, affectedRows }` both map to `{ insertId, changes }`.
- **Transactions:** `dba.tx()` wraps SQLite `BEGIN/COMMIT/ROLLBACK` and mysql2
  `conn.beginTransaction()/commit()/rollback()` (dedicated connection from the pool). The batch-delete
  route (server.js:588–625) becomes a single `dba.tx()` block.
- **Error mapping:** adapter (or a helper) exposes `isUniqueViolation(err)` = mysql2
  `err.code === 'ER_DUP_ENTRY'` || `/UNIQUE constraint/.test(err.message)`. server.js:245 uses it.
- **Safe logging only:** on init log provider name, `host present: yes/no`, `database present: yes/no`,
  `connection established: yes/no`. Never log credentials or the connection URL.

`server.js` changes are mechanical: `db.prepare(SQL).get(a,b)` → `await dba.get(SQL, a, b)`, handlers
become `async` and are wrapped with `wrap()`; the batch-delete transaction block is restructured into
`dba.tx()`. `ROW_FIELDS/ROW_TYPES/STATUSES/TRACKS` exports are unchanged.

---

## 7. Package & Env Changes

**Package (`app/package.json` + lockfile):** add `mysql2` (no ORM — no Prisma/Sequelize/Drizzle).
`bcryptjs`, `express`, `xlsx` unchanged. `node:sqlite` retained (built-in).

**Env contract (Railway app variables):**
- **Add** MySQL connection source — prefer `MYSQL_URL`; fallback to `MYSQLHOST`, `MYSQLPORT`,
  `MYSQLUSER`, `MYSQLPASSWORD`, `MYSQLDATABASE`.
- **Keep** `SESSION_SECRET` (still required in production), `PORT` (Railway-injected), `NODE_ENV`.
- **Keep** `BOOTSTRAP_ADMIN_USERNAME`/`BOOTSTRAP_ADMIN_PASSWORD` for first boot; remove
  `BOOTSTRAP_ADMIN_PASSWORD` after admin exists (unchanged semantics).
- **Retire** `DB_PATH` as the production path (still valid for local SQLite dev). The
  `fix/railway-db-volume-guard` `/data` guard becomes inert in MySQL production (guard only fires when
  `DB_PATH` starts with `/data/`).

Update `app/.env.example` and `app/README.md` (env table + DB-provider section).

---

## 8. Migration Risks

| Risk | Mitigation |
|------|-----------|
| Missed `await` → handler returns before query resolves / unhandled rejection | `wrap()` all async handlers; grep for residual `db.prepare`/`.get(`/`.all(`/`.run(` after refactor |
| mysql2 returns `Date` objects → client JSON shape drift | `dateStrings: true` in pool config |
| `TEXT UNIQUE`/`TEXT PRIMARY KEY` invalid in MySQL | `VARCHAR(255)` for `username`, `sessions.token` |
| `lastInsertRowid`/`.changes` undefined on MySQL | adapter normalizes to `{ insertId, changes }` |
| UNIQUE-violation detection breaks (different error text) | `isUniqueViolation()` covers `ER_DUP_ENTRY` + SQLite text |
| Transaction (`db.exec BEGIN/COMMIT`) not valid via pool.query | `dba.tx()` uses a dedicated pooled connection |
| Multi-statement schema `db.exec` rejected by mysql2 | execute DDL statement-by-statement (no `multipleStatements`) |
| `raw_data` JSON exceeds TEXT 64KB across a batch | `MEDIUMTEXT` |
| Credential leakage in logs | safe-log policy (presence booleans only) |
| Local dev has no MySQL | dual backend keeps SQLite for dev |
| Reused `obsStmt` prepared once, run many | adapter `run()` is per-call; loop calls `dba.run()` (or `t.run()` inside tx) |

---

## 9. Verification Plan

```bash
node --check app/db.js && node --check app/server.js
cd app && npm install            # adds mysql2
npm run start                    # boots (SQLite locally; MySQL when env present)
```

**MySQL smoke (disposable, never Railway/production data):** run a throwaway `mysql:8` container, e.g.
`docker run --rm -e MYSQL_ROOT_PASSWORD=test -e MYSQL_DATABASE=execdb -p 3399:3306 mysql:8`, then boot
the app with `MYSQL_URL=mysql://root:test@127.0.0.1:3399/execdb NODE_ENV=production SESSION_SECRET=…`
and exercise the 15 required smokes via HTTP (cookie jar): boot+schema-init idempotent, bootstrap
creates admin on empty DB, restart skips bootstrap, login, create user, create/edit row, import
preview, import commit writes all importable rows from `source-materials/workbooks/…xlsx`, import
history count, batch delete (entries+observations), restart preserves data, no `/data/data.db`
dependency, no secrets in logs. **Plus** an equivalent SQLite-backed async smoke to prove the refactor
preserves the existing path. Disposable DBs only; live `app/data.db` untouched; no deploy.

> Note (resolved post-review): the operator's current workbook
> `~/Downloads/astraX_JuneToNov_Experiment_All_Tracking (1).xlsx` (79 matrix rows) yields exactly **64**
> importable rows — verified on MySQL (preview=commit=batch-delete=64, blank-title→Untitled, blank rows
> ignored). The stale `source-materials/.../astraX-june-to-nov-experiment-all-tracking.xlsx` (62 matrix
> rows) yields 19; an early smoke used it, which was a fixture error, not a migration regression. Use the
> Downloads workbook as the authoritative import fixture.

---

## 10. Non-Scope

- No Railway resource mutation; no production data import until MySQL smoke passes; no deploy.
- No frontend/UX change (row-click edit, clicked-cell highlight, import pagination, access control
  untouched) unless async error display proves unavoidable — then STOP and report.
- No ORM. No Docker/Railway config files. No schema semantics change beyond dialect equivalence.
- No change to bootstrap semantics, password policy, or import classification logic.
- The unguarded demo-entries seed (db.js:159, additive/empty-only) remains as-is.

---

## 11. Verdict

Migration is **feasible with a thin dual-backend async adapter**. The only non-portable runtime SQL is
a single `datetime('now')` literal; all other complexity is driver-shape (insertId/changes),
transactions, schema DDL, and error codes — all absorbed by the adapter. The dominant work is the
mechanical sync→async conversion of `server.js` handlers (wrapped for Express 4). SQLite is retained
for local dev (not deleted). Recommend proceeding to SPEC_LOCKED → TASK_GRAPH_LOCKED.
