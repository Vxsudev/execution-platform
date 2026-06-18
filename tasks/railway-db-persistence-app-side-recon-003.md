# Task: Verify guard + invariants (disposable DB paths only)

## Parent Spec
specs/railway-db-persistence-app-side-recon.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Verification using only disposable DB paths; live `app/data.db` not mutated; no deploy. Confirm syntax,
the guard's failure and pass-through branches, bootstrap on the success path, and that `/data` is never
created on the host during the failure test. Re-run invariants.

## Acceptance Criteria
- [x] `node --check app/db.js` OK
- [x] `node --check app/server.js` OK
- [x] Success case (`/tmp` path): guard skipped, bootstrap runs, exit 0
- [x] Failure case (`/data`, no volume env): FATAL exit 1, `/data` NOT created
- [x] Staged-loop case (env set, `/data` missing): FATAL exit 1
- [x] Healthy-mount branch (env set, dir exists): proceeds (branch-simulated)
- [x] `scripts/invariant-check.sh` → 5/5 PASS
- [x] Live `app/data.db` untouched; no Railway config changed; no deploy

## Files Likely Affected
- (none — verification only)

## Blocked By
- railway-db-persistence-app-side-recon-002
