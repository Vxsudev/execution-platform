# Task: Implement DB_PATH configurable database path and Railway volume contract docs

## Parent Spec
specs/railway-r2-db-path-volume-contract.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Resolve Railway readiness blocker B3 (hardcoded DB path) via a surgical change to
`app/db.js` plus env/docs updates. No HTTP endpoint changes, no migration changes,
no seed changes.

### 1. app/db.js — DB_PATH resolution (B3 root cause fix)

Mutate `app/db.js:4–8` only. All other lines (WAL, migrations, seeds, exports) unchanged.

**Change:**  
Add `const fs = require('fs')` as the first require (before `const path = require('path')`).  
Replace the single hardcoded line:
```javascript
const db = new DatabaseSync(path.join(__dirname, 'data.db'));
```
with:
```javascript
const defaultDbPath = path.join(__dirname, 'data.db');
const configuredDbPath = process.env.DB_PATH && process.env.DB_PATH.trim()
  ? process.env.DB_PATH.trim()
  : defaultDbPath;
fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true });
const db = new DatabaseSync(configuredDbPath);
```

Behavioral invariants:
- `DB_PATH` unset → `configuredDbPath = path.join(__dirname, 'data.db')` → same as before
- `DB_PATH=/data/data.db` → opens at `/data/data.db`; creates `/data` dir if needed
- `mkdirSync` with `{ recursive: true }` is a no-op for existing directories
- `db` handle is unchanged in type and interface; `module.exports` unchanged
- WAL, migrations, seeds all reference `db` → unchanged behaviour

Do NOT modify `app/server.js`, `app/public/*`, `app/package.json`, `app/package-lock.json`.

### 2. app/.env.example — add DB_PATH variable

Add commented optional DB_PATH variable after the `PORT` block:
```bash
# Optional. Required for Railway production volume-backed SQLite.
# DB_PATH=/data/data.db
```

### 3. app/README.md — Railway volume contract

Update the README:
- Mark R2 as addressed in the R1 deployment section's R2 caveat note
- Add a "Railway Deployment (R2)" section with the volume contract table
- Update the Production Environment Variables table to include DB_PATH

## Acceptance Criteria
- [x] `app/db.js` has `const fs = require('fs')` as first require
- [x] `app/db.js:8` area uses `process.env.DB_PATH` with fallback to `path.join(__dirname, 'data.db')`
- [x] `app/db.js` calls `fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true })` before `new DatabaseSync`
- [x] `app/.env.example` has commented `DB_PATH=/data/data.db` variable
- [x] `app/README.md` documents Railway volume mount path `/data`, env var `DB_PATH=/data/data.db`, WAL colocated
- [x] `app/server.js`, `app/public/*`, `app/package.json`, `app/package-lock.json` byte-for-byte unchanged
- [x] No `node:sqlite` flag added, no Docker, no schema change, no first-admin bootstrap

## Files Likely Affected
- app/db.js (DB_PATH resolution — 5 lines replace 1)
- app/.env.example (add DB_PATH comment)
- app/README.md (Railway Deployment R2 section + env vars table)

## Blocked By
- none
