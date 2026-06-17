# Task: Verify R4 runbook consistency and confirm no behavior regression

## Parent Spec
specs/railway-r4-service-config-runbook.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Documentation consistency verification for R4. No live boot or Railway deploy.

Checks to run (in-session worker):
1. `node --check app/db.js` / `app/server.js` / `app/public/app.js`
2. `cd app && npm run` → start = `node server.js`
3. Consistency audit of `docs/railway-service-config.md`:
   - Root Directory = `app` ✓
   - Node = 24 ✓ (matches `app/.nvmrc` and `app/package.json engines`)
   - DB_PATH = `/data/data.db` ✓
   - NODE_ENV = `production` ✓
   - SESSION_SECRET ≥32 chars documented ✓
   - Bootstrap vars documented as first-boot only ✓
4. No real secrets or passwords in any committed file
5. `bash scripts/invariant-check.sh` → 5/5 PASS
6. `git status` → only allowed surfaces modified

## Acceptance Criteria
- [x] `node --check` passes on db.js, server.js, public/app.js
- [x] `docs/railway-service-config.md` exists with all 8 sections
- [x] Six config facts consistent: Root Directory=app, Node=24, DB_PATH=/data/data.db, NODE_ENV=production, SESSION_SECRET 32+ chars, bootstrap vars first-boot only
- [x] No secrets in committed artifacts
- [x] `app/db.js`, `app/server.js`, `app/public/*`, `app/package.json`, `app/.nvmrc`, `app/.env.example`, `app/package-lock.json` byte-for-byte unchanged
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/railway-r4-service-config-runbook-001.md
