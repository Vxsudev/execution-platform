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

## Admin User Management (Phase 2)

All user accounts are created and managed by the admin. There is no public signup, no email
invite, and no password reset flow.

### Account creation

Admin logs in → clicks **Users** in the topbar → clicks **+ New user** → fills in
username, password, role, and (for track_owner) track scope → submits.

### Roles

| Role | Row access | User management |
|------|-----------|-----------------|
| admin | Full CRUD across all tracks | Full user management |
| track_owner | Create/edit own track rows; read all | None |
| viewer | Read all rows | None |

### Password handling

Passwords are hashed server-side with bcryptjs (cost 10). The password_hash is never
returned by any API endpoint. Admin can reset any user's password via the edit form.

### Demo users (non-production only)

`admin` (admin123) and `vasu` (vasu123) are seeded only when `NODE_ENV !== 'production'`.
In production, create users via the Users panel after bootstrapping the first admin account
directly in the database.

## XLSX Import (Phase 2)

Admins can bulk-import experiment rows from the astraX workbook via the **Import**
tab (admin only; track owners and viewers never see it).

- **Capture-first ("open mode").** Whatever the workbook contains is imported. The
  importer **warns** about imperfect data instead of **blocking** it. The only thing
  that makes a row unimportable is a **blank title** — every row with a title imports.
- **Two-step, never destructive.** *Preview* parses the workbook and classifies
  every row but writes nothing. *Commit Import* re-classifies server-side and inserts
  the importable rows. The button is disabled until a preview yields importable rows.
- **Source sheet:** `All Experiment Summary` (header row 4). The side
  STATUS SUMMARY / Count panel is ignored.
- **Coercions (shown as warnings, not blockers):**
  - Blank `Owner` → `Unassigned`.
  - Blank `Track` → `Unassigned Track`. Non-canonical tracks are imported **as-is**
    (the `track` column is free text), with a warning.
  - Blank or unrecognized `Status` → `Not Started`. Status is **coerced** rather than
    stored verbatim because the database constrains `status` to its five canonical
    values via a `CHECK`; arbitrary status text cannot be stored. The preview discloses
    the coercion.
  - `type` defaults to `experiment` unless a valid type value is supplied.
- **Only a blank title skips a row.** Skipped rows are listed with their spreadsheet
  row number and the reason (`title is required`). Importable rows are previewed with a
  **Warnings** column so issues are visible before commit.
- **Imported rows** are stamped `created_by` / `updated_by` = the importing admin.
- The SQLite database is the runtime source of truth; the workbook is a one-time
  import source, not a continuous sync. No multipart upload, no dedupe, and no track
  normalization/aliasing in Phase 2.
- **Manual row creation is unchanged.** Creating or editing rows through the UI still
  uses the strict canonical dropdowns and `POST`/`PUT /api/rows` validation — open mode
  applies to import only.

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

## Basic Dashboard (Phase 2)

A **Dashboard** view sits alongside the **Rows** view via universal topbar tabs.

- **Computed in the browser.** The dashboard is derived entirely from `state.rows` —
  the rows already loaded via `GET /api/rows`. There is no new endpoint, no DB change,
  and no package change. Opening the tab reloads rows first for freshness.
- **Visible to everyone authenticated.** All roles — admin, track_owner, and viewer —
  can view the dashboard. It is not gated.
- **Preserves real imported data.** Grouping (by status, track, owner) uses the **actual
  stored labels**, including imported shorthand track names (e.g. `T1-Device` is shown
  as-is). The dashboard does **not** normalize or canonicalize the taxonomy, and it
  tolerates blank or malformed `target_end_date` values without crashing.
- **Read-only execution-health surface.** It surfaces totals, status/track/owner
  breakdowns, blocked items, overdue/target-risk items, recently updated rows, and open
  next actions. It does **not** create any workflow, approval, or escalation state.

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

## Import Batch Ledger (Phase 3)

Every import commit creates a permanent record in the `imports` table:

| Column | Description |
|--------|-------------|
| `id` | Auto-increment batch identifier |
| `filename` | Original `.xlsx` filename |
| `imported_by` | Admin username who ran the commit |
| `imported_at` | Server UTC timestamp of the commit |
| `total_rows` | Total rows received in the commit payload |
| `importable_rows` | Rows successfully inserted |
| `skipped_rows` | Rows rejected (blank title) |
| `warning_count` | Total warnings across all rows |
| `status` | Always `complete` for now |

### Entry provenance fields

Imported entries carry three extra columns that link them back to the originating batch:

| Column | Description |
|--------|-------------|
| `import_batch_id` | FK to `imports.id`; `NULL` for manually created rows |
| `import_source_sheet` | Worksheet name from the workbook |
| `import_source_row` | 1-indexed spreadsheet row number |

**Manual entries** created via `POST /api/rows` always have `import_batch_id = NULL`. Old entries (created before Phase 3) also retain `import_batch_id = NULL` — no backfill is performed.

### Import History (admin only)

`GET /api/imports` — returns the full batch list, newest first. Only admins can call this endpoint; track owners and viewers receive `403 Forbidden`.

The **Import tab** in the UI shows the Import History table below the upload form after any imports have been committed.

### Delete import batch

Admins can delete an import batch via the **Delete** button in the Import History table.

- Deletion permanently removes all entries tagged to that batch (`import_batch_id = <id>`).
- Manual rows (`import_batch_id = NULL`) are never touched by a batch delete.
- Double-delete returns `404` (idempotent-safe).
- Non-admin attempts return `403`; unauthenticated attempts return `401`.
- The UI refreshes Import History and Rows after deletion and shows the count of deleted entries.

### Duplicate Detection (Phase 3)

The import pipeline detects probable duplicate rows before and during commit.

**Detection strategy — two layers run for every importable row:**

1. **Source-position match** — if the incoming row has a `source_sheet` and `source_row`, the system queries for any existing entry with the same `import_source_sheet` and `import_source_row`. Catches re-importing the same workbook at unchanged row positions.

2. **Logical match** — normalized `title + owner + track` comparison (trimmed, collapsed whitespace, case-insensitive). Catches duplicates even when the workbook row positions shifted or source metadata is absent.

**Preview behavior:**
- Every importable row in the preview response carries `duplicate`, `duplicate_reason`, and `duplicate_entry_id` fields.
- The preview summary includes `duplicate_count`.
- The Import tab shows a **Duplicate** badge on affected rows and a duplicate count in the summary line.
- Preview never writes to the database.

**Commit behavior (default — skip duplicates):**
- Duplicate rows are skipped by default and reported as `duplicate_skipped_count` in the commit response.
- A batch record is always created, even if `inserted_count = 0` (all rows were duplicates). This preserves import attempt history.

**Admin override:**
- If duplicates exist, an **"Import duplicates anyway"** checkbox appears below the Commit button.
- Checking it and committing sends `allow_duplicates: true`; the server imports all importable rows regardless of duplicate status, and they receive full `import_batch_id` / source metadata.

**Safety guarantees:**
- Duplicate detection is non-destructive — no existing data is modified or deleted.
- The **Delete batch** button (P3-2) remains the rollback mechanism for unwanted imports.
- Manual rows (`import_batch_id = NULL`) are never affected.

**Planned future work:**
- True workbook capture (`import_observations` table) is planned for P3-4 and is **not** implemented here.

## Out of Scope (v1)

- Escalation workflow
- Approval workflow
- Dashboard
- Agents

## Provenance

Promoted from `prototypes/execution-table-app/` with seed cleanup.
