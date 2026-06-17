# Task: Verify open create/edit, preserved auth, and admin-only delete/import/users

## Parent Spec
specs/remove-task-edit-access-controls.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the access-control removal and confirm no regression to authentication, sessions,
delete/import/user-management gating, or Railway hardening. All HTTP tests use a disposable
temp DB; live `app/data.db` is never mutated.

Checks (in-session worker):
1. `node --check` app/server.js, app/db.js, app/public/app.js
2. `cd app && npm run` → start = `node server.js`
3. Dev boot smoke (NODE_ENV unset, temp PORT) → running line; `app/data.db` untouched
4. Production boot smoke on temp DB (valid SESSION_SECRET) → boots; auth guard intact
5. Unauthenticated `POST /api/rows` (no cookie) → 401
6. Authenticated non-admin (track_owner, viewer) create + edit a row in a track outside any
   prior scope → 201 / 200 against a disposable DB
7. Authenticated non-admin DELETE row → 403 (delete stays admin-only)
8. Authenticated non-admin import/users routes → 403 (unchanged)
9. `bash scripts/invariant-check.sh` → 5/5 PASS
10. `git status` → only allowed surfaces

## Acceptance Criteria
- [x] `node --check` passes on server.js, db.js, public/app.js
- [x] Dev boot smoke prints running line; `app/data.db` byte-for-byte unchanged (90112 bytes before+after)
- [x] Unauthenticated mutation → 401
- [x] track_owner and viewer can create + edit any row across tracks (201/200) — verified: track_owner created+edited a row in T1→T5 outside scope; viewer created+edited a row
- [x] Non-admin delete/import/user-management → 403 (admin-only preserved) — track_owner+viewer DELETE → 403, track_owner GET /api/users → 403, import preview → 403
- [x] SESSION_SECRET guard, first-admin bootstrap, DB_PATH behavior unchanged (production boot on temp DB created bootstrap admin)
- [x] `app/db.js`, `app/public/index.html`, `app/public/style.css`, `app/package.json`, `app/.nvmrc`, `app/.env.example`, `docs/railway-service-config.md` unchanged
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`
- [x] Canonical track-value validation still enforced (non-canonical track → 400)
- [x] My Track / All toggle + view-filter helpers preserved (17 references intact)
- [x] HTTP harness: 15/15 assertions passed

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/remove-task-edit-access-controls-002.md
