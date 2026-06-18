# Task: Minimal production ephemeral-DB fail-fast guard

## Parent Spec
specs/railway-db-persistence-app-side-recon.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Proven-necessary safe hardening (recon §6). In `app/db.js`, between `DB_PATH` resolution and
`fs.mkdirSync`, add a production-only guard: when `NODE_ENV=production` and `configuredDbPath` starts
with `/data/`, fail fast (exit 1) unless `RAILWAY_VOLUME_MOUNT_PATH` is set AND `/data` exists. This
prevents silent ephemeral-DB creation when the Railway volume is absent/staged-looping, converting
silent data loss into a clear fatal error before any directory or DB file is created.

Constraints honored: production-only; non-`/data` paths and dev unaffected; no schema/bootstrap/seed/
import/auth change; no secrets logged; no Railway/Docker config touched.

## Acceptance Criteria
- [x] Guard inserted before `mkdirSync`
- [x] Fires only in production for `/data/...` paths
- [x] Emits the exact approved FATAL message and exits 1
- [x] Healthy mount (env set + `/data` exists) proceeds normally
- [x] Dev / non-`/data` paths completely unaffected
- [x] No schema, bootstrap, seed, import, auth, or config change

## Files Likely Affected
- app/db.js

## Blocked By
- railway-db-persistence-app-side-recon-001
