# Task: Verify app scaffold boots and passes invariant gate

## Parent Spec
specs/promote-execution-table-v1-scaffold.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run the full verification sequence for the v1 app scaffold.

Step 1 — Install dependencies:
  cd app && npm install

Step 2 — Boot test:
  Start the server (npm start), confirm it logs
  "execution-table-app running on http://localhost:3000", then stop it.

Step 3 — Invariant check:
  Run `bash scripts/invariant-check.sh` from repo root.
  Must exit 0 (INV-002 retired in task 001; all remaining invariants must pass).

Step 4 — File surface audit:
  Confirm the following mutations and ONLY these occurred:
  - `.engineering-os/invariants/_legacy/INV-002-no-app-code-pre-build.sh` created
  - `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh` removed
  - `app/` directory created with: db.js, server.js, README.md, package.json,
    package-lock.json, .gitignore, public/index.html, public/app.js, public/style.css
  - `ai/recon/promote-execution-table-v1-scaffold-recon.md` created
  - `specs/promote-execution-table-v1-scaffold.md` created
  - `tasks/promote-execution-table-v1-scaffold-*.md` created
  - `ai/engineering-journal.md` appended
  No other mutations outside declared surfaces.

Step 5 — Prototype integrity:
  Confirm `prototypes/execution-table-app/` is unmodified.
  Run: git diff prototypes/ — should show no changes (prototype was never committed,
  but file content must match original).

Step 6 — Smoke test:
  Simulate user flow:
  (a) Server boots at :3000.
  (b) Login with admin/admin123 succeeds (session cookie set).
  (c) GET /api/entries returns valid JSON array.
  (d) POST /api/entries with valid row body returns 201.
  (e) GET /api/entries includes the new row.
  (f) PUT /api/entries/:id with update returns 200.
  (g) GET /api/entries confirms update persisted.
  (h) Stop and restart server; GET /api/entries still returns rows (SQLite persistence).
  (i) No response body contains escalation, approval, dashboard, or agent references.

## Acceptance Criteria
- [ ] `npm install` from `app/` exits 0.
- [ ] `npm start` from `app/` boots and logs the port message.
- [ ] `bash scripts/invariant-check.sh` exits 0.
- [ ] No files mutated outside the declared surfaces.
- [ ] `prototypes/execution-table-app/` files are unmodified.
- [ ] Smoke test steps (a)–(i) all pass.
- [ ] `ai/engineering-journal.md` has been appended with this capability's entry.

## Files Likely Affected
- `app/node_modules/` (npm install output — gitignored)
- `app/data.db`, `app/data.db-shm`, `app/data.db-wal` (runtime — gitignored)
- `ai/engineering-journal.md` (append only)

## Blocked By
- tasks/promote-execution-table-v1-scaffold-003.md
