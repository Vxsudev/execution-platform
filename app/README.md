# execution-table-app — v1 Scaffold

Active v1 scaffold promoted from `prototypes/execution-table-app/`.

## Runtime Requirement

Node >= 22.5

## Quick Start

```bash
npm install
npm start
```

Server starts on http://localhost:3000 (or `PORT` env var).

## Dev Login Credentials

| Username | Password  |
|----------|-----------|
| admin    | admin123  |
| vasu     | vasu123   |

**Dev only — do not use in production.**

## Scope

Authenticated table editor with full CRUD over execution entries.

Entry types: `experiment`, `work_item`, `task`

## Architecture

- Runtime: Node/Express
- Database: built-in `node:sqlite` (persists to `data.db`)
- Frontend: vanilla HTML/CSS/JS (served from `public/`)

## Data Source

The Excel workbook is the structure source only. Runtime data persists in `data.db` and is not synced back to the workbook.

## API Validation

- **POST `/api/rows`** — required fields: `title`, `owner`, `track`, `status` (all must be non-blank). Missing or blank required field returns HTTP 400.
- **PUT `/api/rows/:id`** — partial updates are allowed; supplying a blank value for a required field returns HTTP 400. After merging with the existing row, all required fields must remain non-blank.
- Error responses: `{ "error": "field is required" }` HTTP 400.

## Out of Scope (v1)

- Escalation workflow
- Approval workflow
- Dashboard
- Agents

## Provenance

Promoted from `prototypes/execution-table-app/` with seed cleanup.
