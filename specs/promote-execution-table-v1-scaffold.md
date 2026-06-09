# Spec — promote-execution-table-v1-scaffold

## Status
approved

## Phase
phase-build

## Layer
L5 (Build)

## Version
1.0.0

## Upstream Authority
- ai/recon/promote-execution-table-v1-scaffold-recon.md
- sdlc/02-intent/product-intent-brief.md
- architecture/decisions/ADR-000-product-v1-scope-and-boundaries.md
- prototypes/execution-table-app/ (source only — reference, not modified)

## Downstream Consumers
- tasks/promote-execution-table-v1-scaffold-*.md
- app/ (created by execution)
- ai/engineering-journal.md

---

## Capability

Promote the working execution-table prototype from `prototypes/execution-table-app/`
into the first real v1 app scaffold at `app/`. The prototype is preserved unchanged
as historical reference. The resulting `app/` runs locally with login, table list,
row create, row edit, and SQLite persistence. Excel is structure source only — no
runtime data flows through the workbook.

---

## System Behavior After Execution

- `app/` contains a running authenticated table editor.
- Login works with seeded credentials.
- Rows list, create, edit, and persist across restarts.
- `prototypes/execution-table-app/` is unmodified.
- INV-002 is retired to `_legacy/` because `app/` now legitimately contains code.
- The repository state machine advances to RELEASE_APPROVED for this feature.

---

## Invariant Gate Prerequisite

INV-002 (`no application code before L5 Build`) must be retired to
`.engineering-os/invariants/_legacy/INV-002-no-app-code-pre-build.sh` before any
`app/` files are written. This is the first action of the database task. Rationale:
INV-002 guards against accidental pre-L5 app code; once the L5 Build execution is
active, the invariant has served its purpose and must be graduated to prevent a
false-positive block at the pre-verification invariant gate.

---

## Data Model Changes

Retire INV-002 invariant rule file from `.engineering-os/invariants/` to
`.engineering-os/invariants/_legacy/` before writing any app/ files.

Create `app/db.js` from `prototypes/execution-table-app/db.js` with these changes:
- Retain full schema: users, sessions, entries tables.
- Retain ROW_FIELDS as-is (11 exact workbook matches; 2 minor label differences
  are cosmetic; `type` field retained for row classification).
- Retain WAL try/catch fallback (already applied in prototype-intake-cleanup).
- Remove demo seed rows with real team experiment data. Replace with one minimal
  illustrative row per type (experiment, work_item, task) using clearly generic
  placeholder values, or remove seeding entirely.
- Retain admin/vasu seeded users (prototype-only credentials, documented in README).

Create `app/.gitignore`:
- node_modules/, data.db, data.db-journal, data.db-wal, data.db-shm, .env, .DS_Store

Create `app/package.json` from `prototypes/execution-table-app/package.json` with
no version changes.

Create `app/package-lock.json` from prototype.

---

## API Surface

Create `app/server.js` from `prototypes/execution-table-app/server.js` with no
logic changes. The API surface is:

- `POST /login` — username/password → session cookie
- `POST /logout` — clears session
- `GET /api/entries` — list all rows
- `POST /api/entries` — create row
- `PUT /api/entries/:id` — update row
- `DELETE /api/entries/:id` — delete row
- `GET /api/fields` — returns ROW_FIELDS schema for dynamic form generation

Static file serving from `app/public/` on all other routes.

---

## Frontend Surface

Create `app/public/` from `prototypes/execution-table-app/public/` with no changes.
Frontend is vanilla HTML/CSS/JS consuming the API above.

---

## Operational Workflow

1. User navigates to `http://localhost:3000`.
2. Login form with username/password.
3. On success: table view showing all rows with column headers.
4. Create row: opens form with all ROW_FIELDS; submits to `POST /api/entries`.
5. Edit row: inline or modal; submits to `PUT /api/entries/:id`.
6. Delete row: `DELETE /api/entries/:id`.
7. Logout: `POST /logout`.
8. Refresh preserves DB state (SQLite persistence).

---

## Dependencies

- Node >= 22.5 (built-in `node:sqlite`).
- No external DB server.
- `prototypes/execution-table-app/` must remain unmodified (reference only).

---

## Out of Scope

- Escalation workflow
- Approval workflow
- Dashboard
- Agents
- IoT/digital twin
- NDT-SaaS architecture reuse
- Password reset, lockout, rate limiting, CSRF, secure cookie for HTTPS
- Session pruning
- DB migrations
- Column changes beyond what is described above

---

## Acceptance Criteria

- [ ] `app/` directory exists with all required files.
- [ ] `npm install && npm start` from `app/` runs without error.
- [ ] `http://localhost:3000` serves the login page.
- [ ] Login with `admin/admin123` succeeds.
- [ ] Table loads with correct column headers.
- [ ] Create row persists to SQLite.
- [ ] Edit row persists to SQLite.
- [ ] Browser refresh preserves all rows.
- [ ] No escalation, approval, dashboard, or agent UI exists.
- [ ] `prototypes/execution-table-app/` is unmodified.
- [ ] INV-002 is retired to `_legacy/`.
- [ ] `scripts/invariant-check.sh` exits 0 post-execution.
- [ ] Pre-commit gate passes on commit.

---

## Verification Plan

Run `npm install && npm start` from `app/`.
Verify login, row create, row edit, refresh persistence.
Run `bash scripts/invariant-check.sh` — must exit 0.
Run `git status` — confirm no unintended mutations outside declared surfaces.

---

## Rollback / Stop Conditions

**Stop immediately if:**
- `prototypes/execution-table-app/` is modified.
- Any file outside the declared surfaces is mutated.
- `scripts/invariant-check.sh` exits non-zero post INV-002 retirement (unexpected violation).
- `npm start` fails to boot after copying prototype files.
