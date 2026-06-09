# Spec — excel-like-team-summary-view

## Status
approved

## Phase
phase-build

## Layer
L5 (Build)

## Version
1.0.0

## Upstream Authority
- ai/recon/excel-like-team-summary-view-recon.md
- source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx (Sheet 2 = table source, Sheet 3 = field help)
- specs/promote-execution-table-v1-scaffold.md (predecessor; established app/ scaffold)

## Downstream Consumers
- tasks/excel-like-team-summary-view-*.md
- app/ (active v1 scaffold)
- ai/engineering-journal.md

---

## Capability

Make the active `app/` table view match the actual workbook operating sheet
**astraX — Team Experiment Summary (Sheet 2)**: dense Excel-like grid, workbook
column order, all core columns visible via horizontal scroll, search + filter
controls, create/edit with Sheet-3 helper text, DB persistence, login access.
No escalation, approval, dashboard, or agent features.

---

## System Behavior After Execution

- Table renders all 13 Sheet-2 core columns in workbook order + an Actions column.
- `type` appears as a compact tag, not a dominating leading column.
- Dense rows, sticky header, visible grid lines, horizontal scroll, full-width layout.
- Search box filters across text columns; Status / Track / Type dropdown filters narrow rows.
- Create/Edit modal exposes all fields with Sheet-3 guidance as helper text.
- Required fields: title, owner, track, status. Default status: Not Started.
- CRUD (login, list, create, edit, delete) and SQLite persistence preserved.

---

## Column Contract

DB/display field order (Sheet 2, with `type` discriminator last):
```
owner, track, title, function_area, parent_item, hypothesis, design,
success_criteria, target_end_date, dependencies, outcome, next_action, status, type
```

Table column order:
```
Owner → Track → Experiment Title → Function → Parent Item →
Description / Hypothesis → Experiment Design → Success Criteria →
Target End Date → Dependencies → Outcome / Finding → Next Action →
Status → Actions
```

Labels: title = "Experiment Title"; outcome = "Outcome / Finding"; others per Sheet 2.

---

## Data Model Changes

No SQLite column add/rename — the `entries` table already holds all 14 columns.
Changes are confined to `app/db.js` field metadata (`ROW_FIELDS`):

- Reorder ROW_FIELDS to: owner, track, title, function_area, parent_item,
  hypothesis, design, success_criteria, target_end_date, dependencies, outcome,
  next_action, status, type.
- Relabel `title` → "Experiment Title".
- Add `required: true` to owner, track, status (title already required).
- Add a `help` property to fields carrying Sheet-3 guidance (track, title,
  hypothesis, design, success_criteria, target_end_date, dependencies, outcome,
  next_action, status), text drawn verbatim/condensed from Sheet 3.
- Keep `type` field (discriminator) with options experiment/work_item/task.
- Keep STATUSES and default 'Not Started'.
- Keep seed logic generic and client-safe (one or two sample rows max; no real
  team data, no smoke-test rows).

## API Surface

Update `app/server.js` validation only (routes unchanged):
- `validate()` on create (POST /api/rows) requires non-empty title, owner, track, status.
- PUT remains partial (only validates supplied fields).
- `GET /api/schema` continues to return ROW_FIELDS (now including `help` and new
  `required` flags) so the frontend renders helper text and required markers.
- No new routes. No auth changes. No response-shape changes ({rows}/{row}).

## Frontend Surface

Update `app/public/app.js`, `app/public/style.css`, `app/public/index.html`:

app.js:
- Expand the table to show all 13 Sheet-2 columns in contract order + Actions.
- Render `type` as a compact tag within its column (not leading/dominating).
- Add a controls bar: text search box + Status filter + Track filter + Type filter.
  Filters populate Status/Type from schema and Track from distinct values in loaded rows.
  Search matches across title, owner, track, hypothesis, design, etc. (case-insensitive).
  Filtering is client-side over the loaded row set; combine with AND.
- Truncate long cell text with ellipsis + title tooltip; keep rows dense.
- Modal: render all fields in contract order, show `help` text under each labelled
  control, mark required fields, default new-row status to "Not Started".
- Preserve create/edit/delete and refresh-persistence behavior.

style.css:
- Dense Excel-like grid: compact cell padding, smaller row height, visible grid
  lines (column + row borders), sticky header, full-width table with horizontal
  scroll, monospace-ish compact typography for data density.
- Controls bar styling (search + filter selects).
- Remove oversized empty dark space; table fills the viewport width.

index.html:
- Update <title> to reflect the Team Experiment Summary view (optional cosmetic).

## Operational Workflow

1. User logs in (admin/admin123).
2. Dense Excel-like table loads with all Sheet-2 columns; header sticky.
3. User searches / filters by Status, Track, Type.
4. User clicks "+ New row" → modal with all fields + helper text; required fields enforced.
5. Create → row persists, table refreshes.
6. Edit row → modal pre-filled → save → persists.
7. Delete row → confirm → removed.
8. Browser refresh preserves all rows (SQLite).

## Dependencies

- Node >= 22.5 (built-in node:sqlite).
- Existing app/ scaffold (predecessor capability, RELEASE_APPROVED).
- prototypes/ untouched (reference only).

## Out of Scope

Escalation workflow; approval workflow; dashboard; agents; IoT/digital-twin;
NDT-SaaS reuse; server-side pagination/sorting; column add/rename; DB migration
framework; product code outside app/.

## Acceptance Criteria

- [ ] ROW_FIELDS reordered to Sheet-2 order with `type` last; title label = "Experiment Title".
- [ ] owner, track, status marked required (with title).
- [ ] Fields carry Sheet-3 helper text where applicable.
- [ ] Table shows all 13 Sheet-2 columns + Actions in contract order.
- [ ] Table is dense, has sticky header, grid lines, horizontal scroll, full-width.
- [ ] Search box filters rows; Status / Track / Type filters work and combine.
- [ ] Create/edit modal shows helper text and enforces required fields; default status Not Started.
- [ ] Login, create, edit, delete, and refresh-persistence all work.
- [ ] No escalation / approval / dashboard / agent UI.
- [ ] Seed remains generic and client-safe; no real team data, no smoke-test rows.
- [ ] prototypes/ unmodified.
- [ ] scripts/invariant-check.sh exits 0.

## Verification Plan

Reset app/data.db (gitignored) so clean seed applies.
Run `npm install && npm start` from app/.
Verify login, dense table with all columns, horizontal scroll, search, all three
filters, create, edit, refresh persistence, absence of excluded UI.
Run `bash scripts/invariant-check.sh` — must exit 0.
Run `git status` — confirm mutations only within declared surfaces.

## Rollback / Stop Conditions

Stop immediately if:
- prototypes/execution-table-app/ is modified.
- Any file outside declared surfaces is mutated.
- npm start fails to boot.
- scripts/invariant-check.sh exits non-zero.
- Real team data would be written into seed or committed.
