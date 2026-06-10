# Task: Verify all auth-hardening-v1 stop conditions

## Parent Spec
specs/auth-hardening-v1.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Execute all verification gates from the spec's Verification Gate section. No code changes.
Run the server locally and verify each condition. Report PASS/FAIL per check.

### Local development verification (no SESSION_SECRET set)

1. Server boots: `npm start` from `app/` directory — expect no FATAL messages, server listens on port 3000.
2. Login smoke: `POST /api/login` with `{ username: 'admin', password: 'admin123' }` → 200; response sets cookie `sid`; cookie value contains a dot (signed token format `token.hmac`).
3. Auth check: `GET /api/me` with cookie → 200 `{ user: { id, username } }`.
4. Rows access: `GET /api/rows` with cookie → 200.
5. Audit stamp: `POST /api/rows` with valid row body + cookie → 201; response `created_by === 'admin'`.
6. Logout: `POST /api/logout` with cookie → 200; subsequent `GET /api/me` → 401.
7. Post-logout rows: `GET /api/rows` without cookie → 401.
8. Required-field regression: `POST /api/rows` without `owner` field → 400, `{ "error": "owner is required" }`.
9. Track enum regression: `POST /api/rows` with invalid track value → 400, `{ "error": "invalid track" }`.

### Production mode verification

10. Missing SECRET: `NODE_ENV=production npm start` (no SESSION_SECRET set) → process exits non-zero; stderr contains "FATAL: SESSION_SECRET environment variable is required".
11. Weak SECRET: `NODE_ENV=production SESSION_SECRET=short npm start` → process exits non-zero; stderr contains "FATAL: SESSION_SECRET must be at least 32 characters".
12. Valid SECRET: `NODE_ENV=production SESSION_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))") npm start` → boots successfully.
13. Secure cookie: In production mode login, `Set-Cookie` header on `/api/login` includes `Secure` attribute.

### Invariant check

14. Run invariant engine: `bash vendor/engineering-os/scripts/invariant-check.sh` → 5/5 PASS.

### Surface audit

15. `git diff --name-only HEAD~1..HEAD` (or `git status`) — only these files modified:
    - `app/server.js`
    - `app/db.js`
    - `app/README.md`
    - `app/.env.example`
    - Task/spec/recon/state files in `ai/`, `specs/`, `tasks/`
    - No changes to: `app/public/app.js`, `app/public/style.css`, `app/public/index.html`, `prototypes/`, `sdlc/`

## Acceptance Criteria
- [x] Local dev boots without SESSION_SECRET.
- [x] Login response cookie value contains a dot (HMAC-signed format).
- [x] GET /api/me returns 200 with cookie.
- [x] GET /api/rows returns 200 with cookie, 401 without.
- [x] POST /api/rows stamps created_by = authenticated username.
- [x] Logout invalidates session (me → 401 after logout).
- [x] Required-field validation still returns 400.
- [x] Track enum validation still returns 400.
- [x] NODE_ENV=production without SESSION_SECRET → FATAL exit.
- [x] NODE_ENV=production with SESSION_SECRET < 32 chars → FATAL exit.
- [x] NODE_ENV=production with valid SESSION_SECRET → boots.
- [x] Production login cookie has Secure attribute.
- [x] Invariant engine: 5/5 PASS.
- [x] Surface audit: no frontend/prototypes/sdlc files modified.

## Files Likely Affected
- none (verification only; no code edits)

## Blocked By
- tasks/auth-hardening-v1-002.md
