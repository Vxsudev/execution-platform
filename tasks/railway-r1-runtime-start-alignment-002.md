# Task: Verify R1 runtime/start alignment and confirm no behavior regression

## Parent Spec
specs/railway-r1-runtime-start-alignment.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Regression verification for R1. Confirm the runtime/start alignment is correct
and that no app behavior or forbidden surface changed. Closest available checks
are used (no `scripts/verification/` corpus exists in this repo).

Checks run (in-session worker):
- `node --check app/server.js`, `app/db.js`, `app/public/app.js` → all OK
- `cd app && npm run` → `start` = `node server.js`
- Boot smoke: `PORT=3987 node server.js` → printed
  `execution-table-app running on http://localhost:3987`, then stopped
  (SIGTERM, exit 143). No DB rows created (seed guards are count==0; DB already
  populated).
- `git diff` confirms `app/server.js`, `app/db.js`, `app/public/*`,
  `app/package-lock.json` unchanged.
- `bash scripts/invariant-check.sh` → 5/5 PASS (also enforced by the
  execution-supervisor invariant gate).

## Acceptance Criteria
- [x] `node --check` passes on server.js, db.js, public/app.js
- [x] Boot smoke prints the running line and is stopped cleanly
- [x] `app/server.js`/`app/db.js`/`app/public/*`/`app/package-lock.json` unchanged
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue remains in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/railway-r1-runtime-start-alignment-001.md
