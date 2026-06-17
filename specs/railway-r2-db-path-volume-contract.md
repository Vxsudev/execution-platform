# Spec: Railway R2 — DB_PATH + Volume Contract

## Status
approved

## Phase
phase-build

## Feature Slug
railway-r2-db-path-volume-contract

## Depends On
railway-hosting-readiness-recon (R0 @ 3ca17f0), railway-r1-runtime-start-alignment (R1 @ b113f11)

---

## Summary

Add configurable SQLite database path support so Railway production can mount a
persistent volume and store the database outside the ephemeral source tree. Preserves
local default behavior exactly: if `DB_PATH` is not set, the app continues using
`path.join(__dirname, 'data.db')` (= `app/data.db` locally). Addresses Railway readiness
blocker B3.

---

## Background

R0 identified four Railway readiness blockers. R1 resolved B1 (deploy topology) and B2
(Node version). B3 remains:

> **B3 — Hardcoded DB path:** `app/db.js:8` opens the SQLite database at
> `path.join(__dirname, 'data.db')`, which is inside the ephemeral app directory.
> On Railway, the container filesystem is reset on redeploy, so all data is lost.
> A configurable path + Railway persistent volume are required for durability.

---

## Data Model Changes

none

---

## API Surface

Backend runtime surface change: `app/db.js` now resolves the SQLite database path from
`process.env.DB_PATH` if set and non-empty, falling back to the existing default
`path.join(__dirname, 'data.db')`. No HTTP endpoints added, modified, or removed.
The `db` handle exported by `app/db.js` is unchanged in type and interface.

---

## Frontend Surface

none

---

## Non-Scope

- No Railway deployment
- No Railway project/service/volume creation
- No first-admin bootstrap (B4 → R3)
- No auth/session behavior change
- No import/dashboard/table behavior change
- No Postgres introduction
- No Docker/containerization
- No `app/package.json` or `app/package-lock.json` change
- No `app/server.js` change (server imports `db` handle; no path awareness)
- No `app/public/*` change

---

## Implementation Plan

### Task 1 — app/db.js DB_PATH implementation

Modify `app/db.js`:

1. Add `const fs = require('fs');` as first require (before `const path`).
2. Replace the single hardcoded line `const db = new DatabaseSync(path.join(__dirname, 'data.db'));`
   with:
   ```javascript
   const defaultDbPath = path.join(__dirname, 'data.db');
   const configuredDbPath = process.env.DB_PATH && process.env.DB_PATH.trim()
     ? process.env.DB_PATH.trim()
     : defaultDbPath;
   fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true });
   const db = new DatabaseSync(configuredDbPath);
   ```
3. All subsequent code (`PRAGMA WAL`, `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE`,
   seeds, `module.exports`) is unchanged — all reference `db` handle.

### Task 2 — env/docs Railway volume contract

1. `app/.env.example`: add `DB_PATH` as a commented optional variable.
2. `app/README.md`: update Railway Deployment section to add R2 volume contract
   (volume mount path `/data`, env var `DB_PATH=/data/data.db`, WAL colocated).
   Update environment variables table to include `DB_PATH`.

### Task 3 — verification

Run all checks from recon §14:
1. `node --check app/db.js` / `app/server.js` / `app/public/app.js`
2. `cd app && npm run` → `start` = `node server.js`
3. Default boot smoke (DB_PATH unset): running line → stop → `app/data.db` untouched
4. DB_PATH boot smoke: temp dir → running line → stop → file at temp path → cleanup
5. `bash scripts/invariant-check.sh` → 5/5 PASS
6. `git status` → only allowed surfaces

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | DB_PATH resolution (add `fs` require + 4 lines replacing 1) |
| `app/.env.example` | Add commented `DB_PATH` variable |
| `app/README.md` | Add R2 volume contract section + update env vars table |
| `ai/recon/railway-r2-db-path-volume-contract-recon.md` | Recon artifact |
| `specs/railway-r2-db-path-volume-contract.md` | This spec |
| `tasks/railway-r2-db-path-volume-contract-*.md` | OS-generated task graph |
| `ai/state_registry.json` | R2 lifecycle state |
| `ai/engineering-journal.md` | R2 journal entry |

---

## Verification Plan

Boot smokes must confirm:
- Default path `app/data.db` unmodified (local dev unchanged)
- Configured path file created at `DB_PATH` location
- No forbidden surfaces modified
- Invariants 5/5 PASS

---

## Relationship to R3

R2 provides the durable DB storage substrate. R3 (env/session/first-admin bootstrap) is
the next Railway readiness node and a hard pre-production prerequisite — without it,
the production service boots but no user can log in (B4 open).
