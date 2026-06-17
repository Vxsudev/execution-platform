# execution-table-app — v1 Scaffold

Active v1 scaffold promoted from `prototypes/execution-table-app/`.

## Runtime Requirement

Node >= 24 — the app uses the built-in `node:sqlite` module, which is unflagged
since Node 23.4. Railway pins Node 24 via `app/.nvmrc`.

## Quick Start

```bash
npm install
npm start
```

Server starts on http://localhost:3000 (or `PORT` env var).

## Railway Deployment (R1)

Deploy as a single Railway web service (Railway source deploy, no Docker):

| Setting | Value |
|---------|-------|
| Root Directory | `app` (dependencies + lockfile live here; the repo-root `package.json` is not used) |
| Build command | `npm ci` |
| Start command | `npm start` (runs `node server.js`) |
| Node version | 24 (pinned via `app/.nvmrc`; `engines.node` is `>=24`) |
| Port | Railway injects `PORT`; the app honors it (defaults to 3000) |

R1 covers runtime/start alignment only. Before a **production** deploy, two
follow-ups are still required:

- **R2 — data persistence:** the SQLite file is hardcoded inside the app
  directory, so data is ephemeral on Railway. A configurable DB path + a Railway
  persistent volume are needed for durable data.
- **R3 — env + first admin:** set `SESSION_SECRET` (32+ chars) and
  `NODE_ENV=production`, and seed the first admin user (production seeds none).

For a throwaway **demo**, deploy with the settings above and `NODE_ENV` unset
(seeds `admin/admin123`); data resets on each redeploy.

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
- Richer per-row provenance in the row details modal is planned for P3-5.

### True Workbook Capture (Phase 3)

An import attempt now records **workbook reality** even when zero execution
rows are inserted. The system distinguishes two kinds of data:

- **Execution rows** live in `entries`. Only importable, non-duplicate (or
  explicitly overridden) rows that pass open-mode classification become
  entries. They carry `import_batch_id` / `import_source_sheet` /
  `import_source_row`.
- **Workbook observations** live in the `import_observations` table, linked by
  `import_batch_id`. Observations are an audit record of what the workbook
  contained — they are **never** execution rows and never appear in the table,
  dashboard, or row CRUD.

**Operator law:** *0 execution rows ≠ 0 captured workbook content.*

**Observation schema (`import_observations`):**

| Column | Meaning |
|--------|---------|
| `id` | Auto-increment observation id |
| `import_batch_id` | FK to `imports.id` |
| `source_sheet` / `source_row` | Workbook origin (row null for sheet-level) |
| `observation_type` | `workbook_sheet`, `imported_entry`, `duplicate_skipped`, `skipped_row` (flexible TEXT) |
| `status` | `captured`, `imported`, `skipped` |
| `reason` | Why skipped/captured (e.g. `duplicate`, `title is required`, `zero execution rows inserted`) |
| `raw_data` | JSON snapshot of the source row / sheet summary |
| `created_at` | Capture timestamp |

**Commit capture (every commit):**
- One `workbook_sheet` observation per commit (always), recording sheet name and
  count summary. If `inserted_count = 0`, its reason is `zero execution rows
  inserted` — proof the attempt was captured.
- One `imported_entry` observation per inserted execution row.
- One `duplicate_skipped` observation per duplicate-skipped row.
- One `skipped_row` observation per parse-skipped (e.g. blank-title) row the
  preview forwarded.
- The commit response includes `observation_count`.

**Preview** computes projected capture counts (`observed_sheet_count`,
`observation_count`) and now includes raw `data` on skipped rows so they can be
captured at commit — **preview still writes nothing**.

**Delete batch** cascades: `DELETE /api/imports/:id` removes the batch's
observations *and* entries *and* the ledger row inside one transaction, and
returns `deleted_observation_count`. Manual rows and other batches are untouched.

**Import History** shows an observation count per batch.

**Planned future work:**
- P3-5 will expose this provenance and observation detail more fully in the UI.

## Import Provenance (Phase 3)

Every row's **Details** button now opens a wide modal showing full provenance information.

### Row Content

The Details modal displays all 14 row content fields:
Type, Experiment Title, Owner, Track, Function, Parent Item, Description / Hypothesis,
Experiment Design, Success Criteria, Target End Date, Dependencies, Outcome / Finding,
Next Action, and Status. Long-text fields (Hypothesis, Design, Success Criteria, Outcome)
render in a scrollable block. Short fields appear in a 2-column label/value grid.

### Audit Section

Four server-controlled audit fields are always shown: Created by, Created at, Updated by,
Updated at. These are read-only and cannot be set by the client.

### Provenance Section

**Manual / Legacy rows** (`import_batch_id = NULL`) show a **Manual / Legacy** badge and
a note indicating the row was created or updated manually. No import batch fields are shown.

**Imported rows** (`import_batch_id IS NOT NULL`) show an **Imported** badge plus:
- Import Batch id
- Source Sheet (worksheet name from the workbook)
- Source Row (1-indexed spreadsheet row number)
- Filename, Imported by, Imported at, Batch status, and Observation count — loaded
  lazily from `GET /api/imports` the first time an imported row's details are opened.

Import provenance is read-only. It cannot be edited through the UI.

### Visibility

All authenticated roles (admin, track_owner, viewer) can open the Details modal for any
row they can see. The imports lazy-load runs only for admins and only for rows that have
an import_batch_id set.

## Row/Cell Click Interaction (Phase 3)

Every data row in the Rows table is now a clickable navigation target.

- **Clicking a row opens Details.** A 200 ms single-click timer fires `openDetails`. Clicking
  any interactive element inside the row (button, link, input) is ignored — only bare cell
  area triggers Details.
- **Double-clicking an editable row opens the Edit form.** The pending single-click timer is
  cancelled; `openForm` fires immediately. Editability follows the same role rules as the
  Edit button: admins can double-click any row; a `track_owner` can only double-click rows
  in their assigned track scope; viewers cannot edit via double-click.
- **Permissions unchanged.** `canEditRow()` is the single gating function for both the Edit
  button and double-click. Viewers and track owners outside their scope see Details, never the
  Edit form, regardless of click count.
- **More/Less cell reveal is independent.** Clicking the More or Less toggle expands or
  collapses the cell inline; the single-click timer is not started and Details does not open.
  Each toggle call uses `e.stopPropagation()` to prevent the row click from firing.
- **Keyboard accessible.** Tab to any row (`tabindex="0"`), then press Enter to open Details.
  A visible focus-visible ring confirms keyboard focus.

## Dense Cell Inline Reveal (Phase 3)

Long-text fields in the Rows table (`hypothesis`, `design`, `success_criteria`, `outcome`)
now have an inline expand/collapse toggle instead of a hover-only tooltip.

- **Threshold:** Cells longer than 80 characters show a **More** button below the truncated text.
  Cells at or under 80 characters and empty/null cells show no button — the tooltip alone suffices.
- **Expand/collapse:** Clicking **More** expands the cell inline to show the full text.
  The button label changes to **Less**. Clicking **Less** collapses back to the truncated ellipsis view.
- **Cell-scoped state:** Each cell tracks its expanded/collapsed state independently in
  `state.expandedCells` (a `Set` keyed by `rowId:fieldName`). Expanding one cell does not
  affect others. State resets on data refresh.
- **Keyboard-accessible:** The toggle is a native `<button>` element — Tab to reach it,
  Enter or Space to toggle. Focus ring is visible (2px accent outline).
- **Full row view unchanged:** The **Details** button on every row still opens the full
  P3-5 provenance modal with all 14 fields, audit metadata, and import origin.
- **Row click opens Details (P3-7).** Clicking outside the action buttons fires a 200 ms
  single-click timer that opens the Details modal. The toggle itself calls
  `e.stopPropagation()` so More/Less never triggers a Details open.

## Dashboard Relevance (Phase 3)

The dashboard scope adapts to the signed-in user's role, using a unified
`dashboardRows()` helper that gates all 8 dashboard widgets from a single source.
No backend changes, no permission model changes — frontend-only relevance.

### Admin dashboard
- All rows, no scope toggle.
- The workspace toggle is **not shown** in the topbar for admins on the Dashboard page.
- All 8 widgets (Execution health, Items by status, Items by track, Owner load, Blocked
  items, Overdue / target-risk, Recently updated, Open next actions) reflect the full row set.

### Viewer dashboard
- All rows, no scope toggle.
- Identical behavior to admin: all widgets show all rows; no toggle visible.

### Track owner dashboard
- **All Tracks / My Track workspace toggle** appears in the topbar when the track owner is
  on the Dashboard page (same toggle used on the Rows page).
- **All Tracks (default or explicit):** all widgets show all rows. Scope label reads
  `All Tracks`.
- **My Track:** all widgets scope to the track owner's assigned-track rows (same
  `track_scope` filter as the Rows page). Scope label reads `My Track (track1, track2, ...)`.
- Toggling between All Tracks and My Track updates all 8 widgets instantly (no reload).
- If the track owner has no rows in their assigned tracks, widgets show zeros — no crash.

### dashboardRows() helper
`dashboardRows()` is the single row-sourcing function for all dashboard widgets:
- For `track_owner` with `workspace === 'my'`: returns `visibleRowsForWorkspace(state.rows)` (assigned-track rows only).
- For all other roles (admin, viewer) and for `track_owner` with `workspace === 'all'`: returns `state.rows` (all rows).

All helper functions (`dashStats`, `blockedRows`, `overdueRows`, `recentRows`,
`openNextActions`, `byCount` calls in `renderDashboard`) call `dashboardRows()` rather
than `state.rows` directly.

### Scope label
A `dash-scope-label` element at the top of the dashboard panel shows the current scope:
- Track owner, My Track: `My Track (track1, ...)` (comma-separated assigned tracks)
- All other cases: `All Tracks`

## Out of Scope (v1)

- Escalation workflow
- Approval workflow
- Dashboard
- Agents

## Provenance

Promoted from `prototypes/execution-table-app/` with seed cleanup.
