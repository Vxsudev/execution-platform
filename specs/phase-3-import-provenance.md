---
Slug: phase-3-import-provenance
Layer: frontend
Upstream: specs/phase-3-import-batch-ledger.md, specs/phase-3-true-workbook-capture.md
Downstream: specs/phase-3-dense-cell-reveal.md, specs/phase-3-row-click-interaction.md
Status: approved
Phase: phase-build
---

## Status
approved

## Phase
phase-build

# Spec: P3-5 Import Provenance in Row Details

## Purpose

Enrich the row Details surface so users can understand the full row content and where
the row came from. Imported rows show import provenance using P3-1/P3-4 metadata.
Manual rows show manual creation/update provenance. This is a read-only details and
provenance slice only — not a table interaction slice.

## Dependencies

- P3-1 (import_batch_id, import_source_sheet, import_source_row on entries)
- P3-4 (import_observations, observation_count on imports)
- Existing GET /api/rows payload — already includes all three import provenance columns

## Row Content Display Model

The Details modal must show all 14 execution row fields in a readable form:

| Key | Label |
|---|---|
| type | Type |
| title | Experiment Title |
| owner | Owner |
| track | Track |
| function_area | Function |
| parent_item | Parent Item |
| hypothesis | Description / Hypothesis |
| design | Experiment Design |
| success_criteria | Success Criteria |
| target_end_date | Target End Date |
| dependencies | Dependencies |
| outcome | Outcome / Finding |
| next_action | Next Action |
| status | Status |

Long-text fields (hypothesis, design, success_criteria, outcome) render in a
full-width block with white-space: pre-wrap so multiline content is readable.

## Audit Section

Show: Created by, Created at, Updated by, Updated at.

## Provenance Section

If row.import_batch_id is not NULL:
- Origin badge: Imported
- Always show: Import Batch ID, Source Sheet (if present), Source Row (if present)
- If state.imports is loaded and the batch is found: Filename, Imported by,
  Imported at, Batch status, Observation count

If row.import_batch_id is NULL:
- Origin badge: Manual / Legacy
- Note: "Row was created or updated manually. No import batch."

Never crash on missing metadata. Fall back gracefully if state.imports is empty.

## Backend Payload / Lookup Design

Option A selected (client-side join). No backend changes required.

GET /api/rows already returns import_batch_id, import_source_sheet,
import_source_row on every entry row. GET /api/imports already returns
id, filename, imported_by, imported_at, status, observation_count.

Frontend joins row.import_batch_id → state.imports[].id for enrichment.

If row has import_batch_id and isAdmin() and state.imports is empty, call
loadImports() lazily inside openDetails() before rendering.

## Frontend Modal Design

### Changes to openDetails()
- Change from synchronous to async
- Lazy-load imports for admin on imported rows
- Replace .modal-sm with .modal-wide
- Render three labeled sections: Row Content, Audit, Provenance

### Modal width
.modal-wide = 760px (vs current .modal-sm = 320px)

### CSS classes introduced
- .modal-wide
- .detail-section (wrapper for a titled section)
- .detail-grid (2-col label/value grid)
- .detail-label (muted label)
- .detail-value (text value cell)
- .detail-long (full-width long text block with pre-wrap)
- .origin-badge (base pill)
- .origin-badge.imported (blue/accent)
- .origin-badge.manual (muted)

## Permission Model

- All authenticated users who can view a row can open its Details
- Basic provenance (batch id, source sheet, source row) visible to all roles
- Enriched provenance (filename, imported_by, imported_at) only visible to admin
  via state.imports which is admin-gated
- No new admin-only gates on the Details modal itself
- Details is read-only for all roles
- Existing Edit / Delete buttons remain unchanged

## Non-Scope

- No row/cell click to open Details (P3-7)
- No inline dense cell reveal in the table (P3-6)
- No dashboard changes (P3-8)
- No import commit / preview changes
- No duplicate detection changes
- No delete batch changes
- No observation capture changes
- No new API routes

## Verification Plan

1. node --check public/app.js → 0
2. bash scripts/invariant-check.sh → 5/5 PASS
3. Backend smoke: all import routes intact; no password_hash in row payload
4. Frontend smoke:
   - Admin clicks Details on manual row → Row Content + Audit + Manual origin
   - Admin clicks Details on imported row → Row Content + Audit + Imported origin with batch data
   - Track owner clicks Details → Row Content + Audit + basic provenance (no crash)
   - Viewer clicks Details → same as track owner
   - No row-click behavior
   - No inline cell reveal
   - Existing Edit/Delete buttons work
5. Regression smoke:
   - Import History renders
   - Delete Import Batch works
   - Duplicate badge/checkbox render
   - Dashboard renders
