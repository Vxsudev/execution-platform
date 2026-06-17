# Task: Verify R3 bootstrap implementation and confirm no behavior regression

## Parent Spec
specs/railway-r3-env-session-admin-bootstrap.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Regression and contract verification for R3. Confirms bootstrap behavior, production
fail-closed guards, idempotency, bcrypt storage, and that no forbidden surface changed.
Uses disposable temp DB paths only — live `app/data.db` is never touched.

Checks to run (in-session worker):
1. `node --check app/db.js` / `app/server.js` / `app/public/app.js`
2. `cd app && npm run` → `start` = `node server.js`
3. Dev boot smoke (NODE_ENV unset, PORT 3987): running line → stop → `app/data.db` unchanged
4. Prod no SESSION_SECRET: `NODE_ENV=production DB_PATH="$TMP/d.db" node server.js` → FATAL exit 1
5. Prod short SESSION_SECRET: `NODE_ENV=production SESSION_SECRET="short" ...` → FATAL exit 1
6. Prod valid SESSION_SECRET + bootstrap vars: admin created in temp DB → running line → stop
7. Verify temp DB: 1 user, role='admin', password_hash starts with '$2' (bcrypt)
8. Idempotent second boot: same vars + same DB → "already exists, skipping" → still 1 user
9. Partial config (USERNAME only, no PASSWORD): → FATAL exit 1
10. Prod no bootstrap vars + existing admin (from test 8's DB): → running line → stop
11. Invariants 5/5 PASS
12. `git status` → only allowed surfaces

## Acceptance Criteria
- [x] `node --check` passes on db.js, server.js, public/app.js
- [x] Dev boot smoke: running line; `app/data.db` 90112 bytes unmodified
- [x] Prod without SESSION_SECRET → FATAL, exit 1
- [x] Prod with short SESSION_SECRET → FATAL, exit 1
- [x] Prod bootstrap: admin created in temp DB, running line printed ("Bootstrap: admin user 'testadmin' created.")
- [x] Temp DB has exactly 1 user with role='admin' and bcrypt password_hash (`$2a$10$...`)
- [x] Second boot with same bootstrap vars → "Bootstrap: admin already exists, skipping.", still 1 user
- [x] Partial config (USERNAME only, no PASSWORD) → FATAL, exit 1
- [x] `app/server.js`, `app/public/*`, `app/package.json`, `app/package-lock.json` byte-for-byte unchanged
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/railway-r3-env-session-admin-bootstrap-001.md
