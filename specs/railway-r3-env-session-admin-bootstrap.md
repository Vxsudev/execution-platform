# Spec: Railway R3 — Env / Session / First-Admin Bootstrap

## Status
approved

## Phase
phase-build

## Feature Slug
railway-r3-env-session-admin-bootstrap

## Depends On
railway-hosting-readiness-recon (R0 @ 3ca17f0), railway-r1-runtime-start-alignment (R1 @ b113f11), railway-r2-db-path-volume-contract (R2 @ a3c1f55)

---

## Summary

Make the app production-login safe for Railway by formalizing the production environment
contract and adding a secure env-driven first-admin bootstrap path. Addresses Railway
readiness blocker B4: production currently has zero users, and all user-creation routes
require an existing admin — a deadlock that makes first login impossible without manual
SQLite surgery.

---

## Background

R0 identified four Railway readiness blockers. R1 resolved B1+B2. R2 resolved B3. B4 remains:

> **B4 — First-admin bootstrap:** `app/db.js:117-119` warns but does not seed in production.
> `POST /api/users` (`app/server.js:232`) requires `requireAuth` + admin role. With zero users,
> no session can be established, no one can log in, and the admin creation route is permanently
> locked behind a 401. Manual DB surgery is the only current path — not acceptable for Railway.

The SESSION_SECRET guard (`app/server.js:45-54`) is already production-correct: fails with
`process.exit(1)` if absent or < 32 chars in production mode. No changes needed there.

---

## Data Model Changes

none

---

## API Surface

Backend boot behavior change: `app/db.js` gains an env-driven first-admin bootstrap
block that runs on module load (synchronously, before Express listens). No HTTP
endpoints added, modified, or removed. The bootstrap block reads
`BOOTSTRAP_ADMIN_USERNAME` and `BOOTSTRAP_ADMIN_PASSWORD` from the process
environment, validates them, and inserts an admin user (bcrypt-hashed) if no admin
exists. Existing admin → no-op. Partial config → `process.exit(1)`.

---

## Frontend Surface

none

---

## Non-Scope

- No Railway deployment
- No Railway project/service/volume creation
- No DB_PATH behavior changes (documented R2)
- No import/table/dashboard behavior change
- No Postgres
- No Docker
- No unauthenticated public bootstrap HTTP endpoint
- No hardcoded production credentials
- No demo users in production
- No `app/package.json` bootstrap script (env-driven boot bootstrap is sufficient)
- No `app/server.js` changes (SESSION_SECRET guard already correct; no new routes)
- No `app/public/*` changes
- No `app/package-lock.json` changes

---

## Implementation Plan

### Task 1 — Bootstrap implementation + env/docs (backend)

**1a. app/db.js — first-admin bootstrap block**

Insert after the non-production seed block (lines 112-116) and before the production
zero-users warning (lines 117-119):

```javascript
// Bootstrap a first admin from env on initial production boot. No-op if admin exists.
// Fails closed if exactly one bootstrap var is set (partial config unsafe in production).
if (process.env.NODE_ENV === 'production') {
  const _bUser = process.env.BOOTSTRAP_ADMIN_USERNAME;
  const _bPass = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  const _hasUser = Boolean(_bUser && _bUser.trim());
  const _hasPass = Boolean(_bPass && _bPass.trim());
  if (_hasUser !== _hasPass) {
    console.error('FATAL: BOOTSTRAP_ADMIN_USERNAME and BOOTSTRAP_ADMIN_PASSWORD must both be set or both be unset.');
    process.exit(1);
  }
  if (_hasUser && _hasPass) {
    if (_bPass.trim().length < 12) {
      console.error('FATAL: BOOTSTRAP_ADMIN_PASSWORD must be at least 12 characters.');
      process.exit(1);
    }
    const _adminCount = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'admin'").get().c;
    if (_adminCount === 0) {
      db.prepare("INSERT INTO users (username, password_hash, role, track_scope) VALUES (?, ?, 'admin', '[]')")
        .run(_bUser.trim(), bcrypt.hashSync(_bPass.trim(), 10));
      console.log(`Bootstrap: admin user '${_bUser.trim()}' created.`);
    } else {
      console.log('Bootstrap: admin already exists, skipping.');
    }
  }
}
```

**1b. app/.env.example — add bootstrap vars**

After the DB_PATH entry, add:
```bash
# First production boot only. Remove BOOTSTRAP_ADMIN_PASSWORD after admin is created.
# BOOTSTRAP_ADMIN_USERNAME=admin
# BOOTSTRAP_ADMIN_PASSWORD=replace-with-12-plus-char-password
```

**1c. app/README.md — R3 section + env table update**

- Update R3 caveat in R2 section to "addressed; R4 next"
- Add "Railway Deployment (R3)" section with full production env contract
- Update production env vars table to include `BOOTSTRAP_ADMIN_USERNAME` / `BOOTSTRAP_ADMIN_PASSWORD`
- Note: remove `BOOTSTRAP_ADMIN_PASSWORD` after first admin is created

### Task 2 — Verification

Run all checks from recon §16:
1. Syntax checks on db.js, server.js, public/app.js
2. Dev boot smoke (NODE_ENV unset): running line, `app/data.db` unchanged
3. Prod without SESSION_SECRET → FATAL exit 1
4. Prod with short SESSION_SECRET → FATAL exit 1
5. Prod with valid SESSION_SECRET + bootstrap vars → admin created in temp DB
6. Second boot same vars + same DB → "already exists", 1 user only
7. Partial config (one var only) → FATAL exit 1
8. Prod with no bootstrap vars + existing admin → running line
9. Verify bcrypt hash format
10. Invariants 5/5 PASS
11. git status — only allowed surfaces

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | Bootstrap block (~22 lines) between non-prod seed and production warning |
| `app/.env.example` | Add commented bootstrap vars |
| `app/README.md` | Add R3 section; update env vars table; update caveats |
| `ai/recon/railway-r3-env-session-admin-bootstrap-recon.md` | Recon artifact |
| `specs/railway-r3-env-session-admin-bootstrap.md` | This spec |
| `tasks/railway-r3-env-session-admin-bootstrap-*.md` | OS-generated task graph |
| `ai/state_registry.json` | R3 lifecycle state |
| `ai/engineering-journal.md` | R3 journal entry |

---

## Security Constraints

- Bootstrap password never logged (only username logged on success)
- Bootstrap password stored as bcrypt hash only (cost factor 10, same as app)
- Bootstrap runs only in `NODE_ENV=production`
- Partial config (`hasUser !== hasPass`) → `process.exit(1)` — fail closed
- Password < 12 chars → `process.exit(1)` — fail closed
- No admin already exists check prevents duplicate creation
- No unauthenticated HTTP endpoint for bootstrap
- Demo credentials (`admin/admin123`) remain dev-only

---

## Relationship to R4

R3 resolves B4 and completes the production env contract. R4 (Railway service config)
finalizes builder settings and optional healthcheck before the R5 deployment smoke.
