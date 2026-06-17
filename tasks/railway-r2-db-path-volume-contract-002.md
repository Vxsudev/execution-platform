# Task: Verify R2 DB_PATH implementation and confirm no behavior regression

## Parent Spec
specs/railway-r2-db-path-volume-contract.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Regression and contract verification for R2. Confirm DB_PATH resolution is correct,
local default behavior is preserved, Railway volume contract is documented, and no
forbidden surface changed. No `scripts/verification/` corpus exists in this repo;
closest available checks are used.

Checks to run (in-session worker):
1. `node --check app/db.js` → syntax OK after change
2. `node --check app/server.js` → no regression
3. `node --check app/public/app.js` → no regression
4. `cd app && npm run` → `start` = `node server.js` (unchanged)
5. **Default boot smoke (DB_PATH unset):** `PORT=3987 node server.js` from `app/` → running line → stop → `app/data.db` unmodified
6. **DB_PATH boot smoke:** `TMP=$(mktemp -d) && DB_PATH="$TMP/data.db" PORT=3991 node server.js` → running line → stop → `test -f "$TMP/data.db"` → `rm -rf "$TMP"`
7. `bash scripts/invariant-check.sh` → 5/5 PASS
8. `git diff --name-only HEAD` → only allowed surfaces in diff; `app/server.js`, `app/public/*`, `app/package.json`, `app/package-lock.json` unchanged

## Acceptance Criteria
- [x] `node --check` passes on db.js, server.js, public/app.js
- [x] Default boot smoke: running line printed; `app/data.db` unmodified (90112 bytes, unchanged)
- [x] DB_PATH boot smoke: file created at temp path (`/var/folders/.../tmp.4iAKKh8sqq/data.db`); running line printed; cleanup done
- [x] `app/server.js` / `app/db.js` module exports unchanged (server still imports `db` handle)
- [x] `app/package.json`, `app/package-lock.json`, `app/public/*` byte-for-byte unchanged
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue remains in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/railway-r2-db-path-volume-contract-001.md
