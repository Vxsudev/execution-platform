# Recon: P3 DAG Map — Import Management, True Capture, Table UX, Dashboard Relevance

Feature Slug: phase-3-recon-dag-map
Date: 2026-06-12
Mode: Read-only. No app code modified.

---

## 1. Environment Validation

| Check | Result |
|---|---|
| OS mode | OS-ENABLED |
| Adapter check | 12/12 PASS |
| Pre-recon invariants | 5/5 PASS |
| Working tree | Clean (commit 93154aa) |
| Latest commit | feat: add phase 2 review checkpoint (P2-6) |
| Phase 2 state | All 6 feature slugs = RELEASE_APPROVED |
| Uncommitted app changes | None |

---

## 2. Database Schema Findings

### Tables (confirmed via PRAGMA)

```
users, sqlite_sequence, sessions, entries
```

**No `imports` table exists. No `import_observations` table exists.**

### entries schema (18 columns)

```
id              INTEGER PRIMARY KEY AUTOINCREMENT
type            TEXT NOT NULL DEFAULT 'experiment' CHECK(type IN ('experiment','work_item','task'))
title           TEXT NOT NULL
owner           TEXT (nullable)
track           TEXT (nullable, free TEXT — no CHECK)
function_area   TEXT (nullable)
parent_item     TEXT (nullable)
hypothesis      TEXT (nullable)
design          TEXT (nullable)
success_criteria TEXT (nullable)
target_end_date TEXT (nullable)
dependencies    TEXT (nullable)
outcome         TEXT (nullable)
next_action     TEXT (nullable)
status          TEXT NOT NULL DEFAULT 'Not Started' CHECK(status IN ('Not Started','In Progress','Complete','Blocked','Inconclusive'))
created_at      TEXT NOT NULL DEFAULT datetime('now')
updated_at      TEXT NOT NULL DEFAULT datetime('now')
created_by      TEXT (nullable, additive ALTER TABLE)
updated_by      TEXT (nullable, additive ALTER TABLE)
```

**Absent columns (P3 targets):** `import_batch_id`, `import_source_sheet`, `import_source_row`

### Current data provenance

| created_by | row count | origin |
|---|---|---|
| admin | 60 | imported (P2-4A) + manual |
| vasu | 2 | manual |
| system | 2 | seed rows (db.js backfill) |
| smoke_owner | 1 | leftover from P2-3 audit smoke test (NOT cleaned up) |

**Critical gap:** imported rows and manual rows are INDISTINGUISHABLE by schema today. Both have `created_by = 'admin'`. No import_batch_id exists. The 60 admin-created rows cannot be separated into "came from workbook" vs "admin typed this in manually."

---

## 3. Import Pipeline Findings

### Sheet selection (app/server.js lines 326–329)

```javascript
const IMPORT_SHEET = 'All Experiment Summary';
function resolveImportSheet(wb) {
  if (wb.SheetNames.includes(IMPORT_SHEET)) return IMPORT_SHEET;
  return wb.SheetNames.find((n) => /summary/i.test(n)) || null;
}
```

**Only ONE sheet is ever processed.** The function returns on the first match. There is no multi-sheet iteration.

### Header detection (lines 357–362)

```javascript
for (let i = 0; i < matrix.length; i++) {
  const cells = (matrix[i] || []).map((c) => (c == null ? '' : String(c).trim()));
  if (cells.includes('Owner') && cells.includes('Track') && cells.includes('Experiment Title')) {
    headerIdx = i; break;
  }
}
```

Requires all three: **Owner + Track + Experiment Title** in the same row.

### Empty-row filter (line 371)

```javascript
if (Object.values(data).every((v) => v === '')) continue;
```

A row where all 13 mapped columns are empty is silently skipped. Zero information about it is retained.

### classifyImportRow (lines 384–401)

- title blank → `{ importable: false, reason: 'title is required' }` — only this causes a skip
- owner blank → `'Unassigned'` (warn)
- track blank → `'Unassigned Track'` (warn)
- non-canonical track → imported as-is (warn)
- status blank/non-canonical → coerced to `'Not Started'` (warn)
- type defaulted to `'experiment'`

No skipped row is stored anywhere. No batch record is created.

### Import commit (lines 439–461)

Inserts rows directly into `entries` with `created_by = req.user.username`. No batch record, no source tracking, no observations table.

---

## 4. Workbook Structure Findings

### Sheets confirmed: 3

| Sheet | Rows | Importable? | Reason |
|---|---|---|---|
| All Experiment Summary | 62 matrix rows, 19 data rows | **YES** (current target) | Has Owner + Track + Experiment Title header at row 4 |
| Sample Experiment Log | 25 rows | **NO** (current) | Personal template — header at row 5 has Track + Experiment Title but **NO Owner column** — header detection fails |
| How To Use | 16 rows | NO | Documentation text — no tabular data header |

### All Experiment Summary — data distribution

```
T1-Device:      10 rows  (non-canonical track label)
T1 Device:       1 row   (non-canonical track label)
blank track:     8 rows  → becomes 'Unassigned Track'
T2, T3...T6:     0 rows
Total:          19 rows (19 importable, 0 skipped, 36 warnings)
```

### Sample Experiment Log — columns vs IMPORT_HEADER_MAP

| Column in sheet | In IMPORT_HEADER_MAP? |
|---|---|
| Track | YES (maps to `track`) |
| Experiment Title | YES (maps to `title`) |
| Description / Hypothesis | YES (maps to `hypothesis`) |
| Experiment Design | YES (maps to `design`) |
| Success Criteria | YES (maps to `success_criteria`) |
| Owner | **MISSING** — header detection fails here |
| Target End Date | MISSING |
| Status | MISSING |

To import from 'Sample Experiment Log', the header detection algorithm would need to be relaxed to require only Title + at least one of {Owner, Track} — OR a separate mapping for this sheet format.

### How To Use — columns

Row 2: COLUMN | GUIDANCE (2-column guidance table). 16 rows of free-text guidance. Not parseable as experiment data.

---

## 5. Frontend Table UX Findings

### Table rendering (app.js lines 254–272, style.css lines 45–53)

```javascript
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);
// ...
if (TRUNC_COLS.has(k)) {
  const v = r[k] || '';
  return `<td class="trunc" title="${esc(v)}">${esc(v)}</td>`;
}
```

```css
td.trunc{max-width:260px;overflow:hidden;text-overflow:ellipsis}
```

**Truncation model:** 4 columns (hypothesis, design, success_criteria, outcome) use CSS ellipsis with the full text available only on hover via HTML `title` attribute tooltip. No click-to-expand, no inline expansion, no drawer.

**Table minimum width:** `min-width:1700px` — horizontal scroll is required on any viewport under 1700px. The Actions column (Details/Edit/Delete) is the LAST column — users must scroll right to find it.

### Row actions (lines 265–270)

```javascript
return `<tr>${cells}<td><div class="row-actions">
  <button class="icon-btn" data-info="${r.id}">Details</button>
  ${canEditRow(r) ? `<button class="icon-btn" data-edit="${r.id}">Edit</button>` : ''}
  ${canDeleteRow() ? `<button class="icon-btn danger" data-del="${r.id}">Delete</button>` : ''}
</div></td></tr>`;
```

**No row-level onclick.** The `<tr>` element has no click handler. Only the buttons inside the Actions column trigger actions. Finding them requires horizontal scroll.

### Row action binding (lines 274–284)

Uses `data-info`, `data-edit`, `data-del` attributes on buttons. Event binding is in `bindRowActions()`. A row click handler could be added to the `<tr>` using event delegation, checking `e.target.closest('button')` to avoid capturing button clicks.

### Details modal (lines 596–618)

```javascript
function openDetails(row) {
  const fields = [
    ['Created by', row.created_by || '—'],
    ['Updated by', row.updated_by || '—'],
    ['Created',    row.created_at || '—'],
    ['Updated',    row.updated_at || '—'],
  ];
```

**Shows only 4 fields:** created_by, updated_by, created_at, updated_at. Does NOT show:
- Any of the 13 content fields (title, owner, track, hypothesis, design, etc.)
- import_batch_id, filename, source_sheet, source_row (not in schema yet)
- Full text of truncated fields

**The details modal is currently a minimal audit trail viewer, not a full row view.**

---

## 6. Dashboard Findings

### Data source (app.js lines 374–401)

```javascript
function renderDashboard() {
  const s = dashStats();   // uses state.rows (ALL rows)
```

```javascript
function dashStats() {
  const rows = state.rows;  // state.rows — ALL rows, no workspace filter
```

```javascript
function blockedRows() { return state.rows.filter(...); }
function overdueRows()  { return state.rows.filter(...); }
function recentRows()   { return [...state.rows].sort(...).slice(0, 8); }
function openNextActions() { return state.rows.filter(...); }
```

**Critical finding:** ALL dashboard functions read `state.rows` directly. `state.workspace` (which tracks 'all' vs 'my') is **never consulted by any dashboard function**. A track_owner signed in as "My Track" workspace mode, then clicking Dashboard, sees the SAME data as admin.

### Workspace awareness check

The workspace toggle tabs (`wsAll` / `wsMy` buttons) bind in `renderApp()` only when `isTrackOwner() && isRowsPage`. When `isDashPage` is true, no workspace tabs render for the dashboard at all.

`visibleRowsForWorkspace(rows)` exists and correctly filters by `userScope()` — but it is called ONLY in `filteredRows()`, which is the Rows table filter. The dashboard does not call it.

---

## 7. Dependency Analysis — P3 Criteria

### Import stream dependencies

```
P3-1 (Batch Ledger)
  ├─→ P3-2 (Delete Batch)        — can't delete a batch that has no ID
  ├─→ P3-3 (Duplicate Detection) — best dedup key uses import_source_row from P3-1 schema
  ├─→ P3-4 (True Capture)        — observations table references imports.id as FK
  └─→ P3-5 (Import Provenance)   — details modal shows import_batch_id (needs entries column from P3-1)
P3-2 must precede P3-4 in-build because DELETE /api/imports/:id must cascade observations too
P3-3 can come before P3-4 since dedup at preview/commit doesn't require an observations table
```

### UX stream dependencies

```
P3-7 (Row/Cell Click)            — independent of import stream
P3-6 (Dense Content Reveal)      — logically follows P3-7: a proper details modal (P3-7)
                                   that shows all 14 fields partially solves content reveal
                                   Inline expansion (P3-6 full goal) can be treated as a polish slice
P3-8 (Dashboard Relevance)       — fully independent; uses existing state.rows + userScope()
```

### Cross-stream dependencies

- P3-5 depends on P3-1 (import_batch_id must exist in entries)
- P3-6/P3-7 are independent of all import criteria — safe to parallelize if needed
- P3-8 is independent of all import criteria — safe to run in parallel with P3-4/P3-5 if needed
- P3-9 (review checkpoint) depends on all prior P3 nodes

---

## 8. P3 Criteria — Per-Criterion Analysis

### P3-1: Import Batch Ledger

**Current state:** No batch tracking. `created_by = 'admin'` is the only import trace. 60 admin-created rows cannot be distinguished as imported vs manual.

**Required schema additions (additive, safe via try/catch ALTER TABLE pattern):**

```sql
CREATE TABLE IF NOT EXISTS imports (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  filename      TEXT NOT NULL,
  imported_by   TEXT NOT NULL,
  imported_at   TEXT NOT NULL DEFAULT (datetime('now')),
  total_rows    INTEGER,
  importable_rows INTEGER,
  skipped_rows  INTEGER,
  warning_count INTEGER,
  status        TEXT NOT NULL DEFAULT 'complete'
);
```

```sql
ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;
```

**Backend changes:**
- `POST /api/import/commit`: INSERT INTO imports first, then set `import_batch_id` on all inserted entries
- `GET /api/imports` (new, admin-only): list all import batches with row counts
- Response of commit includes `batch_id`

**Frontend changes:**
- Import panel: after commit, show "Batch #N imported — N rows, B warnings" 
- New Import History section in the Import tab (admin-only) listing batches

**Migration risk:** LOW — entries.import_batch_id is nullable (all existing rows get NULL = "manual or pre-batch import"). The try/catch ALTER TABLE pattern used in db.js is the correct approach.

**Allowed mutation surfaces:** app/server.js, app/db.js, app/public/app.js, app/public/style.css, app/README.md

**Verification focus:** commit response includes batch_id; GET /api/imports returns batch list; imported entries have import_batch_id set; manual CRUD rows have import_batch_id = NULL; non-admin → 403

---

### P3-2: Delete Import Batch

**Current state:** No DELETE route for imports. No way to undo an import.

**Dependency:** P3-1 (requires imports table + entries.import_batch_id)

**Backend changes:**
- `DELETE /api/imports/:id` (admin-only):
  1. Verify import exists
  2. DELETE FROM entries WHERE import_batch_id = :id
  3. DELETE FROM imports WHERE id = :id (or mark status='deleted')
  4. Return { ok, deleted_entry_count }

**Design decisions:**
- Hard-delete entries: YES — matches "DELETE /api/imports/:id" semantic
- Hard-delete import record: YES (idempotency not required per operator)
- If P3-4 (observations) is implemented, DELETE must also cascade to import_observations WHERE import_batch_id = :id
- Must NOT delete manual rows (entries WHERE import_batch_id IS NULL are untouched)
- Guard: if import not found → 404; if non-admin → 403

**Frontend changes:**
- Import History list has a Delete button per batch
- Confirmation dialog: "Delete import batch #N? This will permanently delete N rows from the database. This cannot be undone."
- After delete: reload import history + rows

**Allowed mutation surfaces:** app/server.js, app/public/app.js, app/public/style.css, app/README.md (no db.js change needed — existing entries schema handles this via import_batch_id)

**Verification focus:** admin can delete a batch; entries with that batch_id are removed; entries with NULL batch_id are untouched; non-admin → 403; double-delete → 404

---

### P3-3: Duplicate Detection

**Current state:** Zero dedup. Re-importing the same workbook creates exact duplicates.

**Dependency:** P3-1 (best dedup key uses import_source_sheet + import_source_row)

**Minimum viable dedup:** At preview time, check if (title + owner + track) combination already exists in DB. Warn if so.

**Better dedup (with P3-1):** At preview time, also check if (import_source_sheet + import_source_row) already exists from a prior import. This is more precise — the same spreadsheet row, regardless of title drift.

**Dedup behavior decision:**
- At preview: flag duplicates with a warning ("This row appears to already exist in DB")
- At commit: operator chooses (warn + import anyway OR skip duplicates)
- Recommended for P3: preview warns, commit SKIPS exact duplicates by default with option to override

**Implementation locations:**
- preview route: run dedup check after classifyImportRow; add `duplicate_warning` field to rows with hits
- commit route: re-run dedup check; skipped duplicates go into `skipped` array

**Frontend changes:**
- Import preview table: "Duplicate?" column with warning for suspected duplicates
- Commit confirmation: "N rows have possible duplicates — skip them? [Yes/Import anyway]"

**Allowed mutation surfaces:** app/server.js, app/public/app.js, app/public/style.css, app/README.md

**Verification focus:** re-importing same workbook triggers duplicate warnings; commit correctly skips or imports depending on user choice; first-time import is unaffected

---

### P3-4: True Workbook Capture / Observations

**Current state:** Only 'All Experiment Summary' is processed. Fully-empty rows are silently discarded. Zero information about skipped rows or non-importable sheets is retained beyond the in-memory preview response.

**Operator requirement:** "True capture must occur even when current operational sheet has zero executable rows. Do not treat '0 execution rows' as '0 captured workbook content.'"

**Design paths:**

**Path A (lightweight):** Import ledger (P3-1) records total_rows, importable_rows, skipped_rows, warning_count per batch. A skipped row is recorded as a count only, not as a full observation. Zero executable rows → batch record still created with importable_rows=0.

This is the minimum needed to satisfy "zero rows ≠ zero capture." The batch record proves capture happened even if nothing was inserted into entries.

**Path B (full observations):** Add `import_observations` table:
```sql
CREATE TABLE IF NOT EXISTS import_observations (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  import_batch_id INTEGER NOT NULL REFERENCES imports(id),
  source_sheet   TEXT,
  source_row     INTEGER,
  status         TEXT CHECK(status IN ('imported','skipped','skipped_empty','skipped_no_title','warning')),
  skip_reason    TEXT,
  raw_data       TEXT  -- JSON blob of all raw values
);
```
Every parsed row (importable OR skipped) gets an observation record. DELETE /api/imports/:id cascades to import_observations too.

**Multi-sheet capture decision:**
- 'How To Use' — documentation, not parseable as experiment data. Do NOT import.
- 'Sample Experiment Log' — has T1-T6 data but incompatible header (no Owner column). Importing requires a different header detection path.
  - Option A: Relax header detection to work with Track + Experiment Title (no Owner required). Owner defaults to 'Unassigned'.
  - Option B: Maintain strict Owner+Track+Title requirement; 'Sample Experiment Log' remains un-importable until owner column is added.
  - **Recommendation: Option B** — the personal template is a different format from the operational summary. Importing it without an Owner column produces low-quality data. The correct fix is for the team to add an Owner column to the personal template, not to weaken the importer.

**P3-4 recommendation:** Implement Path A (lightweight) first — it satisfies the zero-rows-≠-zero-capture requirement via the imports ledger. Path B (full observations) is a separate future slice if the operator needs row-level capture of skipped/non-executable content.

**Dependency:** P3-1 (batch ledger) — observations reference imports.id. P3-2 must precede P3-4 in-build since DELETE must cascade to observations.

**Allowed mutation surfaces (Path B):** app/server.js, app/db.js, app/public/app.js, app/README.md

**Verification focus (Path A):** import with zero-title rows → batch created with skipped_rows > 0, importable_rows = 0; batch record proves capture; DELETE cascades correctly

---

### P3-5: Import Provenance in Row Details

**Current state:**

```javascript
function openDetails(row) {
  const fields = [
    ['Created by', row.created_by || '—'],
    ['Updated by', row.updated_by || '—'],
    ['Created',    row.created_at || '—'],
    ['Updated',    row.updated_at || '—'],
  ];
```

The details modal (`.modal-sm`, 320px wide) shows only 4 audit fields. It does NOT show the 13 content fields. It cannot show import_batch_id, filename, source_sheet, source_row because those columns don't exist in entries yet (requires P3-1).

**Dependency:** P3-1 (entries.import_batch_id, import_source_sheet, import_source_row) + GET /api/imports for filename lookup.

**Proposed enriched details modal:**

Two sections:
1. **Row content** — all 14 ROW_FIELDS displayed read-only (so truncated cells can be fully read here)
2. **Provenance** — split by origin:
   - If import_batch_id is NOT NULL: "Imported from: [filename], sheet: [source_sheet], row: [source_row], by [imported_by] on [imported_at]"
   - If import_batch_id IS NULL: "Manually created by [created_by] on [created_at]"
   - Always: Updated by [updated_by] on [updated_at]

**Frontend changes:**
- openDetails() reads additional fields: import_batch_id, import_source_sheet, import_source_row
- For import rows: also fetch batch details from state (if batches are cached) or via a new GET /api/imports/:id route
- Modal size: increase from `.modal-sm` (320px) to full modal width (600px) to show all 14 fields
- Add "Full details" panel that shows all content fields in read-only mode (this also resolves the dense content reveal requirement from P3-6)

**Allowed mutation surfaces:** app/public/app.js, app/public/style.css, app/README.md

**Verification focus:** imported row shows batch info; manual row shows "Manual" origin; modal shows all 14 content fields; non-imported entries gracefully show 'Manual' (no crash on NULL import_batch_id)

---

### P3-6: Dense Table Content Reveal

**Current state:**

`TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome'])` — 4 columns truncated at 260px with CSS ellipsis. Full content available ONLY on hover via HTML `title` tooltip (unreliable on mobile; no keyboard access).

**Proposed patterns considered:**

| Pattern | Complexity | Fits current app? |
|---|---|---|
| Hover tooltip (current) | None | Already implemented; unreliable on touch |
| Click cell to expand inline | Low | Simple toggle, no new component; works in table |
| Click row to open full-detail modal | Medium | Shares implementation with P3-7 (row click) |
| Side drawer | High | Needs new overlay component |
| Inline row expansion (accordion) | Medium | Row doubles in height; breaks table layout |

**Recommendation:** After P3-7 (row click opens details modal), the full-content reveal is naturally achieved via the details modal showing all fields. A separate inline expansion is not needed.

**If P3-6 is built before P3-7 (standalone):** Add a click handler to `.trunc` cells that toggles `white-space: normal; max-width: none` inline. This is a 2-line CSS + a small JS event handler addition. Zero dependency on P3-1..P3-5.

**Allowed mutation surfaces:** app/public/app.js, app/public/style.css

**Verification focus:** clicking a truncated cell reveals full text; clicking again collapses; other non-truncated cells unaffected; keyboard accessible (focus + Enter); no regression in Actions column

---

### P3-7: Row/Cell Click Interaction

**Current state:**

`renderTable()` produces `<tr>` elements with NO onclick. The user must: scroll right → find Actions column → click Details or Edit button.

`bindRowActions()` uses data attribute selectors; no row-level binding exists.

**Proposed click model:**

| Click target | Action (admin/track_owner) | Action (viewer) |
|---|---|---|
| Single click on row | Open full details modal (read-only) | Open full details modal |
| Double click on editable row | Open edit form | N/A (no edit) |
| Click Details button (existing) | Open full details modal | Open full details modal |
| Click Edit button (existing) | Open edit form | N/A |
| Click Delete button (existing) | Delete with confirm | N/A |

**Implementation approach (event delegation on `<tbody>`):**

```javascript
// In bindRowActions(), add:
const tbody = document.querySelector('#tableScroll tbody');
if (tbody) {
  tbody.addEventListener('click', (e) => {
    if (e.target.closest('button')) return;  // button click — handled by existing handlers
    const tr = e.target.closest('tr');
    if (!tr) return;
    const id = tr.querySelector('[data-info]') && tr.querySelector('[data-info]').dataset.info;
    if (id) openDetails(state.rows.find((r) => r.id == id));
  });
  tbody.addEventListener('dblclick', (e) => {
    if (e.target.closest('button')) return;
    const tr = e.target.closest('tr');
    if (!tr) return;
    const editBtn = tr.querySelector('[data-edit]');
    if (editBtn) openForm(state.rows.find((r) => r.id == editBtn.dataset.edit));
  });
}
```

**Keyboard accessibility:** `<tr tabindex="0">` + Enter key handler.

**Risk:** Double click may fire two single-click events before the dblclick event. Use a debounce or timer pattern to distinguish.

**Permission correctness:** The existing `data-edit` attribute is only present when `canEditRow(r)` is true. Checking `tr.querySelector('[data-edit]')` before opening form ensures permission-aware behavior. Viewer rows won't have `[data-edit]` so double-click does nothing.

**Allowed mutation surfaces:** app/public/app.js, app/public/style.css (cursor:pointer on tr)

**Verification focus:** click row opens details; double-click opens edit for admin/track_owner; viewer double-click does nothing; button clicks are not intercepted; keyboard enter on focused row opens details; no regression in existing button behavior

---

### P3-8: Track-Owner Dashboard Relevance

**Current state:**

```javascript
// dashStats, blockedRows, overdueRows, recentRows, openNextActions — all read state.rows
function dashStats() {
  const rows = state.rows;  // ALL rows
```

`state.workspace` and `visibleRowsForWorkspace(rows)` exist but are NOT used by any dashboard function. A track_owner viewing the dashboard sees the same counts, blocked items, overdue items, and next actions as admin — including data from T1-T6 tracks they don't manage.

**Context:** `state.rows` loads from GET /api/rows which returns ALL entries (no server-side scope filtering). track_owner already sees all rows in the "All Tracks" workspace. The workspace filtering in "My Track" is a frontend filter via `visibleRowsForWorkspace()`.

**Proposed solution:** Add workspace-aware filtering to the dashboard.

```javascript
function dashboardRows() {
  // For track_owner in "my" workspace mode: filter to their tracks.
  // All other cases (admin, viewer, track_owner in "all"): use all rows.
  if (isTrackOwner() && state.workspace === 'my') {
    return visibleRowsForWorkspace(state.rows);  // already filters by userScope()
  }
  return state.rows;
}
```

Then replace all `state.rows` references in dashboard functions with `dashboardRows()`.

**Additionally:** Add workspace toggle tabs to the dashboard (All Tracks / My Track) for track_owner, matching the Rows view pattern. When track_owner switches workspace in Rows and then clicks Dashboard, the dashboard should inherit the same workspace mode.

**Alternative:** Show scoped summary at the top and full-context data below (two-tier dashboard). This is more complex but more informative. Start with the simpler single-filter approach for P3-8.

**Permission correctness:** This change does NOT restrict what data track_owner can see (they already can view all rows). It changes the default emphasis so their dashboard highlights their own track. All-Tracks mode still available.

**Allowed mutation surfaces:** app/public/app.js, app/public/style.css, app/README.md

**Verification focus:** track_owner in "My Track" workspace → dashboard counts/lists show only their track rows; track_owner in "All Tracks" → dashboard shows all rows; admin always sees all rows; viewer always sees all rows; no regression in Rows workspace behavior

---

## 9. Recommended Serialized P3 DAG

### Rationale for serialization

The import stream (P3-1 through P3-5) has a strict linear dependency chain:
- P3-1 (batch ledger) is the foundation; P3-2, P3-3, P3-4, P3-5 all depend on it
- P3-2 (delete batch) must precede P3-4 (true capture / observations) because the delete route must cascade to observations
- P3-3 (dedup) can come before P3-4 since dedup only needs import_source_row from P3-1

The UX stream (P3-6, P3-7, P3-8) is independent of the import stream. P3-7 logically precedes P3-6 because a proper full-details modal (P3-7) partially resolves the content-reveal problem (P3-6). P3-8 is independent.

**Parallelism opportunity:** P3-6/P3-7/P3-8 could run in parallel with the tail of the import stream (P3-4/P3-5), since they touch different mutation surfaces. The directive asks for a serialized DAG unless parallelism is proven safe — noted here but not recommended for the default plan.

### Final recommended DAG (serialized)

```
P3-0  ──► P3-1  ──► P3-2  ──► P3-3  ──► P3-4  ──► P3-5  ──► P3-7  ──► P3-6  ──► P3-8  ──► P3-9
```

| Node | Name | Criteria | Position rationale | Dependencies |
|---|---|---|---|---|
| P3-0 | P3 Recon + DAG Map | All 9 criteria recon | Foundation — must precede all | None |
| P3-1 | Import Batch Ledger | Criterion 1 | Foundation of all import management; schema changes must stabilize before build on top | P3-0 |
| P3-2 | Delete Import Batch | Criterion 2 | Depends on batch IDs from P3-1; builds while schema is fresh | P3-1 |
| P3-3 | Duplicate Detection | Criterion 4 | Depends on import_source_row from P3-1; simpler than observations; validates batch approach before committing to full observation model | P3-1 |
| P3-4 | True Workbook Capture | Criterion 3 + 6 (zero-rows) | Depends on stable batch schema (P3-1) and delete cascade (P3-2); complex schema — deferred until basic management works | P3-1, P3-2 |
| P3-5 | Import Provenance in Row Details | Criterion 5 | Depends on P3-1 columns in entries; also enriches details modal as full-row viewer (bridges to P3-7) | P3-1 |
| P3-7 | Row/Cell Click Interaction | Criterion 8 | Independent of import stream; opens first because full details modal (P3-7) is foundation for content reveal (P3-6) | P3-0 (code stable) |
| P3-6 | Dense Table Content Reveal | Criterion 7 | Follows P3-7 because a proper details modal showing all 14 fields partially solves content reveal; P3-6 then adds inline expansion as polish | P3-7 |
| P3-8 | Track-Owner Dashboard Relevance | Criterion 9 | Independent; minimal surface (app.js only); scheduled last in UX stream to allow workspace UX patterns from P3-7/P3-6 to stabilize | P3-0 (code stable) |
| P3-9 | P3 Review Checkpoint | All | Must follow all P3 nodes | All P3 nodes |

### Alternative DAG considered and rejected

**Alternative A: True capture before dedup (P3-3 = observations before P3-4 = dedup)**
- Rejected because duplicate detection is simpler and more immediately useful; starting with dedup validates the batch approach before committing to the full observations schema.

**Alternative B: UX stream (P3-6/P3-7/P3-8) before import stream**
- Rejected because import stream has higher business priority (operator's P2-6 finding explicitly calls out import batch management as HIGH priority).

**Alternative C: P3-5 (provenance) before P3-3 (dedup)**
- Viable. No hard dependency conflict. Chosen to put dedup before provenance since dedup is operationally more impactful (prevents data inflation) whereas provenance is informational.

**Alternative D: Parallelize UX stream with tail of import stream**
- Viable (no shared mutation surfaces between P3-7/P3-8 and P3-4/P3-5). Rejected for default plan because the operator's P2-6 checkpoint identified import batch management as HIGH priority — serializing keeps focus on one concern at a time and reduces cognitive overlap in verification.

---

## 10. Proposed Slice Names and Specs

| Node | Suggested spec slug | Suggested commit label |
|---|---|---|
| P3-1 | phase-3-import-batch-ledger | feat: add import batch ledger |
| P3-2 | phase-3-delete-import-batch | feat: add delete import batch |
| P3-3 | phase-3-duplicate-detection | feat: add import duplicate detection |
| P3-4 | phase-3-true-workbook-capture | feat: add true workbook capture and observations |
| P3-5 | phase-3-import-provenance | feat: add import provenance in row details |
| P3-7 | phase-3-row-click-interaction | feat: add row click to open details and edit |
| P3-6 | phase-3-dense-cell-reveal | feat: add inline dense cell content reveal |
| P3-8 | phase-3-dashboard-relevance | feat: add track-owner dashboard workspace filtering |
| P3-9 | phase-3-review-checkpoint | feat: add p3 review checkpoint |

---

## 11. Allowed Mutation Surfaces Per Slice

| Slice | app/server.js | app/db.js | app/public/app.js | app/public/style.css | app/README.md |
|---|---|---|---|---|---|
| P3-1: Batch Ledger | ✓ | ✓ (new table + ALTER) | ✓ | ✓ | ✓ |
| P3-2: Delete Batch | ✓ | — | ✓ | ✓ | ✓ |
| P3-3: Dedup | ✓ | — | ✓ | ✓ | ✓ |
| P3-4: True Capture | ✓ | ✓ (observations table) | ✓ | ✓ | ✓ |
| P3-5: Provenance | — | — | ✓ | ✓ | ✓ |
| P3-7: Row Click | — | — | ✓ | ✓ | ✓ |
| P3-6: Cell Reveal | — | — | ✓ | ✓ | ✓ |
| P3-8: Dash Relevance | — | — | ✓ | ✓ | ✓ |
| P3-9: Review CP | — | — | — | — | — |

**Never modify:** app/public/index.html, app/package-lock.json, prototypes/, sdlc/, vendor/

---

## 12. Verification Plan Per Slice

### P3-1: Import Batch Ledger
1. POST /api/import/commit returns batch_id in response
2. GET /api/imports returns batch list (admin only; non-admin → 403)
3. imported entries have import_batch_id, import_source_sheet, import_source_row set
4. manually-created rows have import_batch_id = NULL
5. batch record stores filename, imported_by, importable_rows, warning_count
6. existing P2 rows unaffected (import_batch_id = NULL, no regression)

### P3-2: Delete Import Batch
1. DELETE /api/imports/:id (admin) → deletes entries WHERE import_batch_id = id
2. manual rows (import_batch_id = NULL) are NOT deleted
3. double-delete → 404
4. non-admin → 403
5. GET /api/rows after delete shows reduced count
6. confirmation dialog appears before destructive action

### P3-3: Duplicate Detection
1. preview of a workbook already-imported once → duplicate warnings on matching rows
2. commit with skip-duplicates → skipped count reported
3. commit with import-anyway → all rows imported including duplicates
4. first-time import shows no duplicate warnings
5. dedup by (title + owner + track) works when import_source_row unavailable

### P3-4: True Workbook Capture
1. import workbook where all rows have blank titles → batch created with importable_rows=0, skipped_rows=N
2. observations table has N rows recording the skipped content
3. DELETE /api/imports/:id cascades to import_observations
4. observation records have source_sheet, source_row, skip_reason, raw_data

### P3-5: Import Provenance in Row Details
1. Details modal for imported row shows: filename, source_sheet, source_row, imported_by, imported_at
2. Details modal for manual row shows: "Manual creation" or no import fields
3. Details modal shows all 14 content fields (not just audit trail)
4. Existing Details button behavior is preserved
5. No password_hash or sensitive data exposed

### P3-7: Row/Cell Click Interaction
1. click on any table row opens details modal (all roles)
2. double-click on editable row opens edit form (admin, track_owner in-scope)
3. double-click by viewer does nothing (no edit form)
4. button clicks within row (Details/Edit/Delete) are NOT intercepted
5. keyboard: tr[tabindex=0] + Enter opens details
6. cursor: pointer on tr in CSS

### P3-6: Dense Cell Content Reveal
1. clicking truncated cell (hypothesis, design, success_criteria, outcome) reveals full text inline
2. clicking again collapses
3. other cells unaffected
4. keyboard accessible (focus + Enter)
5. full-details modal (P3-5/P3-7) also shows full content — regression-free

### P3-8: Track-Owner Dashboard Relevance
1. track_owner in "My Track" workspace → dashboard counts/lists filtered to their tracks
2. track_owner in "All Tracks" → dashboard shows all rows (unchanged from current)
3. admin always sees all rows
4. viewer always sees all rows
5. workspace tabs appear on dashboard for track_owner (matching Rows view pattern)
6. dashboard regression: all 8 widgets still render; no crash on empty sets

---

## 13. Implementation Risks

| Risk | Severity | Mitigation |
|---|---|---|
| P3-1 db.js change breaks existing entries | MEDIUM | try/catch ALTER TABLE pattern (existing convention); nullable columns |
| P3-2 delete cascade removes the wrong rows | HIGH | Strict WHERE import_batch_id = :id; never deletes NULL batch_id rows |
| P3-3 dedup false positives (same title different experiments) | MEDIUM | Use import_source_row as primary key; (title+owner+track) as secondary |
| P3-4 observations table grows very large on large workbooks | LOW | Considered acceptable for current scale |
| P3-5 details modal reads non-existent import_batch_id | LOW | Check null before rendering import provenance section |
| P3-7 row click fires before button click (event order) | MEDIUM | `e.target.closest('button')` guard prevents double-handling |
| P3-7 double click interference | MEDIUM | Single/double click disambiguation via timer (200ms) |
| P3-8 workspace state desync (Rows is "my", Dashboard is "all") | LOW | Dashboard inherits state.workspace; workspace tabs on dashboard keep them in sync |
| All P3 slices: left-behind test rows | LOW | Enforce cleanup in all verification tasks (lesson from smoke_owner row) |

---

## 14. Stop Conditions

This recon is complete when:

- [x] Recon artifact exists (`ai/recon/phase-3-recon-dag-map.md`)
- [x] All 9 P3 criteria covered (Sections 8.1–8.9)
- [x] Actual code/data findings cited (import pipeline, table rendering, dashboard, details modal, schema)
- [x] Serialized DAG proposed (Section 9)
- [x] Dependency reasons documented (Sections 7, 9)
- [x] Allowed mutation surfaces per slice documented (Section 11)
- [x] Verification plan per slice documented (Section 12)
- [x] Invariants 5/5 PASS (confirmed at session start)
- [x] No app code modified (git status clean)
- [x] Git status reported (clean, commit 93154aa)

---

## 15. Files Read / Commands Run

### Files read
- app/server.js — lines 1–464 (full)
- app/public/app.js — lines 1–681 (full)
- app/public/style.css — lines 1–118 (full)
- app/db.js — lines 1–116 (full)
- ai/state_registry.json
- ai/invariant-registry.md
- source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx (via XLSX.read)
- ai/recon/phase-2-review-checkpoint-recon.md (referenced for import findings)

### Commands run
```
bash vendor/engineering-os/scripts/os-adapter-check.sh
bash vendor/engineering-os/scripts/invariant-engine.sh
git status --short
git log --oneline -5
node -e "PRAGMA table_info(entries) ..."
node -e "SELECT created_by, COUNT(*) ..."
node -e "XLSX.read workbook — sheet list, All Experiment Summary structure, Sample Experiment Log structure, How To Use structure"
```
