# Task: Implement env-driven first-admin bootstrap and production env/docs contract

## Parent Spec
specs/railway-r3-env-session-admin-bootstrap.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Resolve Railway readiness blocker B4 (first-admin bootstrap deadlock) and finalize the
production env contract documentation. Three file mutations; no HTTP endpoint changes,
no schema changes, no demo seed changes.

### 1. app/db.js — first-admin bootstrap block

Insert a bootstrap block between the non-production seed block (line 116) and the existing
production zero-users warning (lines 117-119). The block is production-only, fail-closed on
partial config, fail-closed on short password, idempotent (no-op if admin exists), and
stores only a bcrypt hash — never logs the password.

### 2. app/.env.example — bootstrap vars

After the DB_PATH entry, add commented bootstrap vars with a note to remove
BOOTSTRAP_ADMIN_PASSWORD after the first admin is created.

### 3. app/README.md — R3 section + env table update

Update the "R3 — env + first admin" caveat to "addressed; see R3 below". Add a "Railway
Deployment (R3)" section with the full production env contract and bootstrap workflow.
Update the Production Environment Variables table to include both bootstrap vars.

Do NOT modify app/server.js — SESSION_SECRET guard is already production-correct.

## Acceptance Criteria
- [ ] `app/db.js` bootstrap block: production-only, fail-closed on partial config, fail-closed on short password, bcrypt hash, no password logged
- [ ] `app/db.js` bootstrap is a no-op when both vars unset
- [ ] `app/db.js` bootstrap skips when admin already exists (idempotent)
- [ ] `app/.env.example` has commented `BOOTSTRAP_ADMIN_USERNAME` and `BOOTSTRAP_ADMIN_PASSWORD`
- [ ] `app/README.md` has Railway Deployment (R3) section with full production env contract
- [ ] `app/server.js`, `app/public/*`, `app/package.json`, `app/package-lock.json` byte-for-byte unchanged
- [ ] No unauthenticated bootstrap HTTP endpoint added

## Files Likely Affected
- app/db.js (bootstrap block ~22 lines)
- app/.env.example (add bootstrap vars)
- app/README.md (R3 section + env vars table)

## Blocked By
- none
