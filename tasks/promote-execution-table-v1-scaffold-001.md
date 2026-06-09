# Task: Retire INV-002 and create app/db.js with schema and seed

## Parent Spec
specs/promote-execution-table-v1-scaffold.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
This task has two parts that must run in order.

Part 1 — Retire INV-002:
Move `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh` to
`.engineering-os/invariants/_legacy/INV-002-no-app-code-pre-build.sh`.
Create `_legacy/` directory if absent. Verify `scripts/invariant-check.sh`
still exits 0 after retirement (the engine skips files in `_legacy/`).
This step must complete before any `app/` file is written.

Part 2 — Create app/db.js:
Create the `app/` directory.
Copy `prototypes/execution-table-app/db.js` to `app/db.js`.
Apply these changes in app/db.js:
- Retain all three tables: users, sessions, entries (schema unchanged).
- Retain ROW_FIELDS exactly as in prototype (11 workbook-matched fields plus
  `type` classifier field; cosmetic label differences are intentional and
  documented in the recon).
- Retain WAL try/catch fallback (already present in prototype post-cleanup).
- Replace the three live-team seed rows in the entries seeding block with
  generic illustrative placeholders:
    type=experiment, title="Sample experiment", owner="demo", track="T1",
    function_area="Engineering", success_criteria="Baseline metric improves",
    status="Not Started"
  — or remove entries seeding entirely; the users seed must be retained.
- Do NOT modify any other logic.
- Do NOT modify `prototypes/execution-table-app/db.js`.

Create `app/package.json` as a copy of
`prototypes/execution-table-app/package.json`.

Create `app/package-lock.json` as a copy of
`prototypes/execution-table-app/package-lock.json`.

Create `app/.gitignore`:
```
node_modules/
data.db
data.db-journal
data.db-wal
data.db-shm
.env
.DS_Store
```

## Acceptance Criteria
- [ ] `.engineering-os/invariants/_legacy/INV-002-no-app-code-pre-build.sh` exists.
- [ ] `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh` no longer exists in parent dir.
- [ ] `bash scripts/invariant-check.sh` exits 0 after retirement.
- [ ] `app/db.js` exists and contains valid JS.
- [ ] `app/package.json` exists.
- [ ] `app/package-lock.json` exists.
- [ ] `app/.gitignore` exists.
- [ ] No real team experiment data in seed rows.
- [ ] `prototypes/execution-table-app/db.js` is unmodified (git diff shows no changes to that path).

## Files Likely Affected
- `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh` (moved, not deleted)
- `.engineering-os/invariants/_legacy/INV-002-no-app-code-pre-build.sh` (new)
- `app/db.js` (new)
- `app/package.json` (new)
- `app/package-lock.json` (new)
- `app/.gitignore` (new)

## Blocked By
- none
