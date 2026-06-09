# Task: Verify the Excel-like Team Summary view boots, filters, and persists

## Parent Spec
specs/excel-like-team-summary-view.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Run the verification sequence for the Excel-like Team Summary view.

Step 1 — Reset runtime DB:
  Delete `app/data.db`, `app/data.db-shm`, `app/data.db-wal` (gitignored) so the
  clean generic seed applies on next boot. Removes stale verification rows.

Step 2 — Install + boot:
  cd app && npm install
  Start server; confirm it logs "running on http://localhost:3000"; keep it up
  for API checks; stop when done.

Step 3 — Schema check:
  GET /api/schema (authenticated) returns ROW_FIELDS in contract order
  (owner first, type last), title label "Experiment Title", required flags on
  owner/track/title/status, and `help` strings present.

Step 4 — Invariant gate:
  Run `bash scripts/invariant-check.sh` from repo root — must exit 0.

Step 5 — Smoke test (API-level, mirrors user flow):
  (a) Server boots at :3000.
  (b) Login admin/admin123 → 200, session cookie set.
  (c) GET /api/rows → 200, returns seed rows.
  (d) POST /api/rows missing owner/track → 400 (required enforcement).
  (e) POST /api/rows with title+owner+track (experiment) → 201.
  (f) GET /api/rows includes the new row.
  (g) PUT /api/rows/:id setting status "In Progress" → 200.
  (h) GET /api/rows confirms status persisted.
  (i) Stop + restart server; GET /api/rows still returns the row (persistence).
  (j) No response references escalation / approval / dashboard / agent.

Step 6 — Frontend asset checks (static inspection):
  Confirm app.js renders all 13 columns + Type + Actions, has search + Status +
  Track + Type filters, and modal helper text; style.css has dense grid + sticky
  header + horizontal scroll. (Grep for column keys, filter ids, help rendering.)

Step 7 — Surface audit:
  git status — confirm mutations only in: app/db.js, app/server.js,
  app/public/app.js, app/public/style.css, app/public/index.html,
  ai/recon/excel-like-team-summary-view-recon.md, specs/, tasks/,
  ai/engineering-journal.md, ai/state_registry.json. prototypes/ unmodified.

## Acceptance Criteria
- [ ] npm install exits 0; npm start boots and logs the port.
- [ ] GET /api/schema reflects contract order, labels, required flags, help.
- [ ] bash scripts/invariant-check.sh exits 0.
- [ ] Smoke test steps (a)–(j) pass, including required-field 400 and persistence.
- [ ] Frontend assets contain full columns, all three filters + search, helper text.
- [ ] No mutations outside declared surfaces; prototypes/ unmodified.
- [ ] ai/engineering-journal.md appended with this capability's entry.

## Files Likely Affected
- `app/data.db*` (reset — gitignored)
- `app/node_modules/` (npm install — gitignored)
- `ai/engineering-journal.md` (append)

## Blocked By
- tasks/excel-like-team-summary-view-003.md
