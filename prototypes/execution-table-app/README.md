# Execution Table

A simple full-stack table-editor app. The column/row structure is derived from the
`astraX` experiment tracking spreadsheet; the spreadsheet is **only** the source of
structure. All runtime data is persisted in a database — the Excel file is never used
as the production store.

## Stack
- **Backend / API:** Node + Express
- **Database:** SQLite via Node's built-in `node:sqlite` (no native build, no external DB server)
- **Frontend:** vanilla HTML/CSS/JS single-page UI that consumes the API
- **Auth:** username/password login with a hashed password (bcryptjs) and an httpOnly session cookie

## Requirements
- Node.js **>= 22.5** (uses the built-in SQLite module)

## Run
```bash
npm install
npm start
# open http://localhost:3000
```
Set a different port with `PORT=4000 npm start`.

> Node prints `ExperimentalWarning: SQLite is an experimental feature` on start — that
> is expected and harmless; `node:sqlite` is built in and stable enough for this app.

## Demo logins
| username | password |
|----------|----------|
| `admin`  | `admin123` |
| `vasu`   | `vasu123`  |

Change these before any real use (edit the seed block in `db.js`, delete `data.db`, restart).

## Row types
Every row has a `type`: **experiment**, **work_item**, or **task**. The columns are the
same across all three (taken from the sheet); the type is a label/discriminator. The
experiment frame fields (Hypothesis, Experiment Design, Success Criteria) are simply
left blank for work items and tasks.

## Columns (row shape, from the sheet)
Type, Title, Owner, Track, Function, Parent Item, Description / Hypothesis,
Experiment Design, Success Criteria, Target End Date, Dependencies, Outcome / Finding,
Next Action, Status (`Not Started | In Progress | Complete | Blocked | Inconclusive`).

## API
All `/api/rows*` routes require an authenticated session cookie.

| Method | Path | Purpose |
|--------|------|---------|
| POST   | `/api/login`     | `{username,password}` → sets session cookie |
| POST   | `/api/logout`    | clears the session |
| GET    | `/api/me`        | current user (401 if not logged in) |
| GET    | `/api/schema`    | field/type/status definitions (single source of truth) |
| GET    | `/api/rows`      | list all rows |
| GET    | `/api/rows/:id`  | one row |
| POST   | `/api/rows`      | create a row |
| PUT    | `/api/rows/:id`  | update a row |
| DELETE | `/api/rows/:id`  | delete a row |

## Files
```
server.js        Express app: auth + rows CRUD, serves the frontend
db.js            SQLite schema, field config, seed (users + demo rows)
public/
  index.html     app shell
  app.js         SPA: login, table list, create/edit form
  style.css      styling
data.db          created on first run (git-ignore this)
```

## Notes on scope
Intentionally excluded (per spec): approval workflow, escalation workflow, dashboards,
agents, IoT/digital-twin. This is a focused login + table CRUD editor.
