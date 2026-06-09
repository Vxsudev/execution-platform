# Prototype Intake — Execution Table App

## Prototype source
Claude-generated app produced from an Excel / table-editor prompt. The column/row
structure was derived from the `astraX` experiment-tracking spreadsheet; the
spreadsheet served **only** as the source of column structure, never as a data store.

## Status
**Prototype only.** Imported as-is into `prototypes/execution-table-app/`. Not
production, not promoted, not wired into any SDLC pipeline.

## Stack
- **Backend / API:** Node + Express
- **Database:** SQLite via Node's built-in `node:sqlite` (no native build, no external DB server)
- **Frontend:** vanilla HTML / CSS / JS single-page UI consuming the API
- **Auth:** username/password login, bcryptjs-hashed passwords, httpOnly session cookie
- **Runtime requirement:** Node >= 22.5 (built-in SQLite module)

## Scope alignment
- Simple table editor (CRUD over a single `entries` table).
- DB persistence in local SQLite (`data.db`, created on first run).
- Login / access control via session cookie.
- Row types: `experiment`, `work_item`, `task` — same columns across all three.
- **Explicitly excluded:** escalation workflow, approval workflow, dashboards, agents,
  IoT / digital-twin. Matches the focused login + table CRUD scope.

## Risks
- **Hardcoded demo users** seeded in `db.js` (`admin/admin123`, `vasu/vasu123`) — not
  for any real use.
- **Local SQLite** file (`data.db`) — single-file local store, no migration or backup
  story, not a production datastore.
- **No production auth** — no password reset, lockout, rate limiting, CSRF protection,
  or secure cookie flag for HTTPS; session table never pruned.
- **Columns hardcoded, not verified against the workbook** — `ROW_FIELDS` /  schema were
  taken from the prompt, not validated against the actual `astraX` spreadsheet.
- **No OS / build pipeline yet** — no CI, lint, tests, containerization, or deployment
  path. `npm start` only.
- **Experimental SQLite API** — `node:sqlite` emits an ExperimentalWarning and its
  surface may change across Node versions.
- WAL fallback added because mounted filesystem may not support SQLite WAL locking.

## Mutation surfaces (allowed)
- `prototypes/execution-table-app/{package.json,server.js,db.js,README.md}`
- `prototypes/execution-table-app/public/{index.html,app.js,style.css}`
- `ai/recon/prototype-intake-execution-table-app.md`

No `src/` or `app/` production directories created. No existing SDLC artifacts modified.
