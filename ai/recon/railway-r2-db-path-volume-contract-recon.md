# Railway R2 — DB_PATH + Volume Contract: Recon

**Feature Slug:** railway-r2-db-path-volume-contract  
**Date:** 2026-06-17  
**Author:** AI Engineering OS (in-session worker)  
**Depends on:** R0 (railway-hosting-readiness-recon @ 3ca17f0), R1 (railway-r1-runtime-start-alignment @ b113f11)

---

## 1. Recon Objective

Strict read-only recon for R2. No app mutations, no Railway deployment, no volume
provisioning. Validate the current hardcoded DB path, the SQLite initialization sequence,
and design the DB_PATH environment variable contract needed for Railway persistent volume
durability.

---

## 2. Files Read

| File | Purpose |
|------|---------|
| `app/db.js` (full, 143 lines) | Hardcoded path, DatabaseSync init, WAL, migrations, seed |
| `app/.env.example` (13 lines) | Current env contract; missing DB_PATH |
| `app/README.md` (R1 state) | Railway Deployment (R1) section; R2 caveat already noted |
| `.gitignore` | DB runtime file exclusions |
| `ai/recon/railway-hosting-readiness-recon.md` (R0 artifact) | Blocker B3 original evidence |
| `ai/state_registry.json` | State: `railway-r2-db-path-volume-contract` absent → fresh lifecycle |

Local governance surfaces checked:

| File | Status |
|------|--------|
| `ai/product-invariants.md` | Absent |
| `ai/runtime-contracts.md` | Absent |
| `ai/service-boundaries.md` | Absent |
| `ai/coding-patterns.md` | Absent |
| `ai/repo-index.md` | Absent |
| `ai/invariant-registry.md` | Present |

Five of six expected adapter docs absent — proceeding with `ai/invariant-registry.md`,
directive authority, and direct code evidence.

---

## 3. Commands Run

```bash
git status && git log --oneline -5
# → clean (2 pre-existing untracked files); HEAD=b113f11
bash vendor/engineering-os/scripts/os-adapter-check.sh
# → 12/12 PASS; STATUS: adapter valid
bash scripts/invariant-check.sh
# → 5/5 PASS
ls app/data.db app/data.db-wal app/data.db-shm
# → all three present
stat -f "%z bytes" app/data.db
# → 90112 bytes
```

---

## 4. Blocker B3 Evidence

**B3 Root cause:** `app/db.js:8`

```javascript
const db = new DatabaseSync(path.join(__dirname, 'data.db'));
```

`__dirname` in `app/db.js` resolves to the directory containing db.js — the `app/`
source directory. On Railway (source deploy, Root Directory = `app`), the working
directory is inside the ephemeral container image. The SQLite file is written to
`/app/data.db` inside the container. There is no persistent volume mounted, so the
file is lost on every redeployment, dyno restart, or container replacement.

**Local DB state at recon time:**
- `app/data.db`: 90,112 bytes (live data)
- `app/data.db-wal`: WAL sidecar (present)
- `app/data.db-shm`: shared-memory sidecar (present)
- All three are `.gitignore`-tracked and not committed — correct behavior

---

## 5. Current DB Initialization Sequence

`app/db.js` init sequence (verbatim references):

| Line | Code | Notes |
|------|------|-------|
| 4 | `const path = require('path')` | path built-in; `fs` NOT required here |
| 5 | `const { DatabaseSync } = require('node:sqlite')` | built-in; no external dep |
| 6 | `const bcrypt = require('bcryptjs')` | external dep (app/node_modules) |
| 8 | `const db = new DatabaseSync(path.join(__dirname, 'data.db'))` | **B3 hardcoded path** |
| 9–13 | `db.exec("PRAGMA journal_mode = WAL;")` in try/catch | WAL applied to the opened db |
| 45–98 | `db.exec(CREATE TABLE IF NOT EXISTS ...)` | idempotent; uses `db` reference |
| 100–108 | `ALTER TABLE ... ADD COLUMN ...` in per-line try/catch | additive; uses `db` reference |
| 112–116 | seed dev users if `NODE_ENV !== 'production'` and users table empty | dev only |
| 117–119 | log WARNING if production and zero users | no seed; warns on empty DB |
| 122–125 | backfill dev user roles if non-production | dev only |
| 128–137 | seed illustrative entries if entries table empty | dev; count==0 guard |
| 143 | `module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS }` | exports db handle |

**Key finding:** All migrations, WAL, and seeds reference `db` — the handle returned by
`new DatabaseSync(...)`. They do NOT reference the path directly. Therefore changing
how the path is resolved at line 8 (pre-open) is fully sufficient. No migration code
changes needed.

---

## 6. Selected DB_PATH Design

### Design decision

Use a single environment variable `DB_PATH`. Follows the directive's recommended shape
exactly. No new external dependencies — `fs` is a Node built-in.

### Proposed implementation

Replace `app/db.js` lines 4–8 (from `const path = ...` through `const db = ...`):

**Before:**
```javascript
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const bcrypt = require('bcryptjs');

const db = new DatabaseSync(path.join(__dirname, 'data.db'));
```

**After:**
```javascript
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const bcrypt = require('bcryptjs');

const defaultDbPath = path.join(__dirname, 'data.db');
const configuredDbPath = process.env.DB_PATH && process.env.DB_PATH.trim()
  ? process.env.DB_PATH.trim()
  : defaultDbPath;
fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true });
const db = new DatabaseSync(configuredDbPath);
```

### Behavioral invariants preserved

| Behavior | Before | After |
|----------|--------|-------|
| Local default path | `app/data.db` | `app/data.db` (unchanged; DB_PATH unset → default) |
| Existing DB not moved | N/A | `mkdirSync` is a no-op for existing dirs; same path → same file |
| WAL mode | applied to `db` | applied to `db` (same reference; same line 10) |
| All migrations | run via `db.exec(...)` | unchanged |
| Dev seed | runs if non-production + empty | unchanged |
| Production seed | skipped; warning logged | unchanged |
| module.exports | `{ db, ... }` | unchanged |

---

## 7. Parent Directory Creation Design

`fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true })`

- For default path `path.join(__dirname, 'data.db')`: `path.dirname(...)` = `__dirname` = app dir (already exists). `mkdirSync` with `{ recursive: true }` is a no-op for existing dirs — safe.
- For Railway path `/data/data.db`: `path.dirname(...)` = `/data`. Railway volumes are mounted before the container starts, but the mount point directory itself must exist. `mkdirSync` creates it if not yet present — harmless if it already exists (Railway mounts).
- For local test path `/tmp/some-test-dir/data.db`: `path.dirname(...)` = `/tmp/some-test-dir`. Created on first boot.
- `{ recursive: true }` never throws on existing directories (unlike the default).

---

## 8. Local Default Behavior (B3 resolution proof)

When `DB_PATH` is unset or empty:
```
configuredDbPath = path.join(__dirname, 'data.db')  // same as before
```
The existing `app/data.db` is opened without any path change. No data migration
needed. No user action required for local development. Zero behavioral change for
existing local development workflows.

---

## 9. Railway Production Volume Contract

| Item | Value | Rationale |
|------|-------|-----------|
| Railway volume mount path | `/data` | Conventional Railway volume mount; clear separation from source |
| `DB_PATH` env var | `/data/data.db` | Full path to DB file inside the volume |
| WAL sidecars | `/data/data.db-wal`, `/data/data.db-shm` | Colocated automatically; same dir |
| Root Directory | `app` | Unchanged from R1 |
| Node version | 24 | Unchanged from R1 |
| `NODE_ENV` | `production` | Must be set; controls seed guards and cookie security |
| `SESSION_SECRET` | 32+ char secret | Must be set; boot refuses if absent in production |
| R3 first-admin bootstrap | Still required | No admin seed in production; B4 remains open |

**WAL sidecar co-location:** SQLite WAL mode writes sidecar files `data.db-wal` and
`data.db-shm` adjacent to the database file. Because all three are resolved relative
to `path.dirname(configuredDbPath)` by SQLite's own logic, mounting `/data` as a
persistent volume ensures all three files persist together. No extra path configuration
needed.

**Volume persistence:** Railway persistent volumes survive redeployments, container
restarts, and dyno replacements. The DB file at `/data/data.db` is durable as long
as the volume exists and is mounted.

---

## 10. .gitignore Analysis

Current `.gitignore` already tracks:
```
app/data.db
app/data.db-shm
app/data.db-wal
data.db
data.db-shm
data.db-wal
```

The Railway volume-backed path `/data/data.db` is outside the source tree entirely
(absolute path outside the repo). No `.gitignore` change needed. **Optional mutation
clause not triggered.**

---

## 11. .env.example Gap

Current `app/.env.example` has no `DB_PATH` entry. It must be added as an optional
commented variable:

```bash
# Optional. Required for Railway production volume-backed SQLite.
# DB_PATH=/data/data.db
```

---

## 12. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| DB_PATH set to relative path (e.g. `data.db`) | Low | `path.dirname('data.db')` = `.` → `mkdirSync('.')` is a no-op; SQLite opens relative to CWD. Documented as anti-pattern; not blocked. |
| DB_PATH set to path inside source tree | Low | User error; no app protection. Documented: must be volume path in production. |
| Existing `app/data.db` opened by both old and new process | N/A | SQLite WAL allows this; `mkdirSync` doesn't move the existing file |
| WAL files stranded on volume if DB moved | Low | Not applicable: volume holds the canonical DB; no migration/move needed |
| `fs` module shadowed or unavailable | None | `fs` is a Node built-in; always available |

---

## 13. Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | Add `const fs = require('fs')` + DB_PATH resolution + mkdirSync before DatabaseSync line |
| `app/.env.example` | Add `DB_PATH` commented variable |
| `app/README.md` | Update Railway Deployment section: add DB_PATH + volume contract; mark R2 addressed |

**Do NOT modify:**
- `app/server.js` — `db` handle is imported; server has no DB path awareness. No change needed.
- `app/public/*`, `app/package.json`, `app/package-lock.json`, `prototypes/`, `sdlc/`, `source-materials/`, `vendor/`

---

## 14. Verification Plan

1. `node --check app/db.js` — syntax check after change
2. `node --check app/server.js` — regression check
3. `node --check app/public/app.js` — regression check
4. `cd app && npm run` — confirm `start` = `node server.js` (unchanged)
5. **Default boot smoke (DB_PATH unset):** `PORT=3987 node server.js` in `app/` → expect running line + existing `app/data.db` untouched
6. **DB_PATH boot smoke:** `TMP_DB_DIR=$(mktemp -d) && DB_PATH="$TMP_DB_DIR/data.db" PORT=3991 node server.js` → expect running line → stop → `test -f "$TMP_DB_DIR/data.db"` → `rm -rf "$TMP_DB_DIR"`
7. `bash scripts/invariant-check.sh` → 5/5 PASS
8. `git status` → only allowed surfaces modified

---

## 15. Dependency on R3

R2 (this directive) addresses **B3 — database durability** only. It does NOT address:

- **B4 — first-admin bootstrap:** production starts with zero users (db.js:117-119 warns but
  does not seed). User creation requires an existing admin (server.js). Bootstrapping the
  first admin user in production is the R3 responsibility.
- **Session/env contract:** `SESSION_SECRET` and `NODE_ENV=production` are documented in
  README but not enforced through Railway environment configuration UI — that is also R3.

R3 is a **hard pre-production prerequisite**: even with R2's volume-backed DB, a production
Railway deploy without a first admin is a dead-end service (no one can log in).

---

## 16. Conclusion

**B3 is addressable with a minimal, surgical change to `app/db.js`** (add `fs` require,
3-line DB_PATH resolution, 1-line mkdirSync before DatabaseSync). Local default behavior is
preserved exactly. Railway volume contract is documented. No behavior regression, no new
external dependencies, no forbidden surfaces touched.

Proceed to spec and OS pipeline.
