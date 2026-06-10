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
- `track` must be one of: T1 AstraX Device, T2 AstraX Customer Cloud, T3 AstraX Ops Cloud, T4 Manufacturing partners, T5 Business, T6 Sales partner. Other values return HTTP 400.
- Error responses: `{ "error": "field is required" }` HTTP 400.

## Workspaces (Phase 2)

### All Tracks View
Available to all authenticated users. Shows all rows across all six tracks. Search and
filter controls apply across all rows.

### My Track Workspace
Available to `track_owner` role only. Shows only rows in the user's assigned track scope.
New row and Edit controls are enabled only for rows in assigned tracks. Delete is
admin-only regardless of workspace.

### Frontend control visibility

| Control | admin | track_owner (All Tracks) | track_owner (My Track) | viewer |
|---------|-------|--------------------------|------------------------|--------|
| New row | ✓ | — | ✓ (assigned tracks only) | — |
| Edit | ✓ all rows | — | ✓ assigned track rows | — |
| Delete | ✓ | — | — | — |
| Details | ✓ | ✓ | ✓ | ✓ |

**Note:** Frontend controls are UX convenience only. Backend route guards (P2-1) enforce
the same rules and will reject unauthorized raw API calls regardless of frontend state.

## Audit Metadata

Every row carries four server-controlled audit fields. The client cannot supply or override them.

| Field | When Set | Value |
|-------|----------|-------|
| `created_at` | On create | Server timestamp (UTC) |
| `created_by` | On create | Authenticated username from session |
| `updated_at` | On every update | Server timestamp (UTC) |
| `updated_by` | On every update | Authenticated username from session |

Audit fields are read-only. They are accessible via the **Details** button on each row,
which opens a small read-only panel. They do not appear as main table columns.

## Track Taxonomy

Track is a dropdown-only field (not free-text). The six canonical astraX tracks are:

| ID | Track |
|----|-------|
| T1 | T1 AstraX Device |
| T2 | T2 AstraX Customer Cloud |
| T3 | T3 AstraX Ops Cloud |
| T4 | T4 Manufacturing partners |
| T5 | T5 Business |
| T6 | T6 Sales partner |

These values are defined in `db.js` as `TRACKS`, exposed via `GET /api/schema` as `tracks`, and used by both the filter dropdown and the create/edit form. Free-text track entry is not supported.

## Production Environment

### Environment Variables

| Variable | Required in Production | Description |
|----------|----------------------|-------------|
| `SESSION_SECRET` | **Yes** | Cryptographic signing key for session tokens. Min 32 chars. Boot fails if absent. |
| `NODE_ENV` | Yes (set to `production`) | Controls demo seed, cookie security, and startup checks. |
| `PORT` | No | Server port. Defaults to 3000. |

Generate a secret:

    node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

Copy `app/.env.example` to `app/.env` and fill in values. Load before starting the server.

### Production Safety

- `NODE_ENV=production` + missing or weak `SESSION_SECRET` → boot refuses immediately.
- Demo credentials (`admin/admin123`, `vasu/vasu123`) are **not seeded** in production.
  If the database has no users, a warning is logged. Create users before accepting connections.
- Session cookies use `Secure` flag in production (HTTPS only).
- Session cookies are always `HttpOnly` and `SameSite=Lax`.

### Local Development

No env vars required for local development. Demo credentials are seeded automatically on
first boot. Run `npm start` from the `app/` directory.

## Out of Scope (v1)

- Escalation workflow
- Approval workflow
- Dashboard
- Agents

## Provenance

Promoted from `prototypes/execution-table-app/` with seed cleanup.
