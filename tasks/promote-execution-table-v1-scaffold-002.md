# Task: Create app/server.js and app/README.md

## Parent Spec
specs/promote-execution-table-v1-scaffold.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Copy `prototypes/execution-table-app/server.js` to `app/server.js` with no
logic changes. The API surface is preserved exactly as in the prototype:

- POST /login — username/password → httpOnly session cookie
- POST /logout — clears session
- GET /api/entries — list all rows (auth required)
- POST /api/entries — create row (auth required)
- PUT /api/entries/:id — update row (auth required)
- DELETE /api/entries/:id — delete row (auth required)
- GET /api/fields — returns ROW_FIELDS schema for dynamic form
- Static file serving from public/ for all other routes

Do NOT modify `prototypes/execution-table-app/server.js`.

Create `app/README.md` identifying app/ as the active v1 scaffold:
- Node >= 22.5 runtime requirement
- Quick start: npm install && npm start
- Login credentials: admin/admin123, vasu/vasu123 (dev only)
- Scope: authenticated table editor, CRUD over entries (experiment/work_item/task)
- Architecture: Node/Express + built-in node:sqlite + vanilla HTML/CSS/JS
- Excel workbook is structure source only; runtime data persists in data.db
- Out of scope: escalation workflow, approval workflow, dashboard, agents
- Promoted from prototypes/execution-table-app/ with seed cleanup

## Acceptance Criteria
- [ ] `app/server.js` exists and contains valid JS.
- [ ] `app/README.md` exists with Node version requirement and quick start.
- [ ] `prototypes/execution-table-app/server.js` is unmodified.

## Files Likely Affected
- `app/server.js` (new)
- `app/README.md` (new)

## Blocked By
- tasks/promote-execution-table-v1-scaffold-001.md
