# Task: Verify short-password acceptance, preserved guards, and bcrypt storage

## Parent Spec
specs/remove-password-length-restrictions.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify on disposable DBs only; live `app/data.db` never mutated.

Checks (in-session worker):
1. `node --check` app/server.js, app/db.js, app/public/app.js
2. `cd app && npm run` → start = `node server.js`
3. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` byte-for-byte unchanged
4. **Bootstrap short password:** production boot on temp DB with `BOOTSTRAP_ADMIN_PASSWORD` of a
   short non-empty value (e.g. `ab`) → "admin user created"; login with that short password → 200
5. **User-create short password:** admin creates a user with a 1-char password → 201; login as
   that user → 200
6. **Missing/empty still rejected:** bootstrap with username set + empty password → FATAL partial
   config (exit 1); user-create with empty password → 400
7. **SESSION_SECRET preserved:** production boot with no SESSION_SECRET → FATAL; with `<32` → FATAL
8. **bcrypt + no logging:** created user's `password_hash` starts with `$2`; server log contains
   no occurrence of the test password strings
9. `bash scripts/invariant-check.sh` → 5/5 PASS
10. `git status` → only allowed surfaces

## Acceptance Criteria
- [x] `node --check` passes on server.js, db.js, public/app.js
- [x] Dev boot smoke prints running line; live `app/data.db` byte-for-byte unchanged
- [x] Bootstrap with 2-char password creates admin ("Bootstrap: admin user 'boss' created"); login with it → 200
- [x] User creation with 1-char password → 201; login as that user → 200
- [x] Missing/empty password still rejected (bootstrap username-only → FATAL partial config; user-create empty → 400)
- [x] SESSION_SECRET missing → FATAL; `<32` → FATAL (production) — both fired
- [x] Stored `password_hash` is bcrypt (`$2a$`); password never logged (log shows only username; "ab" match was substring of "table" — false positive)
- [x] `app/server.js` (SESSION_SECRET), schema, `app/public/*`, package/config unchanged (diff = db.js + .env.example + README + railway doc)
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`
- [x] Verification harness: 5/5 + bootstrap/SESSION_SECRET/partial-config checks passed

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/remove-password-length-restrictions-002.md
