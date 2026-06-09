# Task: Build the dense Excel-like Team Summary table view with search and filters

## Parent Spec
specs/excel-like-team-summary-view.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Edit `app/public/app.js`, `app/public/style.css`, and `app/public/index.html` ONLY.

app.js — table:
- Replace LIST_COLS with the full Sheet-2 contract column order:
  owner, track, title, function_area, parent_item, hypothesis, design,
  success_criteria, target_end_date, dependencies, outcome, next_action, status
  followed by a Type column (compact tag) and an Actions column.
- Use schema field labels for headers (title shows "Experiment Title").
- Render `type` as a compact tag (existing tag style) — not leading/dominating.
- Render `status` with the existing status color classes.
- Long text cells (hypothesis, design, success_criteria, outcome): truncate with
  ellipsis and set the full text as a `title` attribute tooltip; keep rows dense.

app.js — controls bar:
- Add a controls row above the table with:
  - a text search input (placeholder "Search…")
  - a Status filter <select> (All + STATUSES)
  - a Track filter <select> (All + distinct track values from loaded rows)
  - a Type filter <select> (All + ROW_TYPES, labelled via TYPE_LABEL)
- Maintain filter/search state in `state` (e.g. state.filters / state.search).
- Apply filtering client-side over state.rows with AND semantics: search matches
  case-insensitively across title, owner, track, function_area, parent_item,
  hypothesis, design, success_criteria, dependencies, outcome, next_action.
- Re-render table on input/change without refetching (data already loaded).
- Show the filtered count in the topbar (e.g. "N of M rows").

app.js — modal:
- Render all fields in schema order, with `f.help` shown as helper text beneath
  each control (small muted text). Mark required fields with the existing " *".
- New-row default status = "Not Started".
- Preserve create (POST /api/rows), edit (PUT /api/rows/:id), delete, and
  refresh-persistence behavior. Keep {rows}/{row} response handling.

style.css — Excel-like grid:
- Dense cells (reduced padding, ~28–32px row height), compact font size (~12–13px).
- Visible grid lines: borders on both columns and rows.
- Sticky header (keep), horizontal scroll on the table container, full-width layout.
- Constrain long-text columns with max-width + ellipsis (text-overflow).
- Style the controls bar (search input + selects).
- Remove oversized empty dark space; table fills viewport width.

index.html:
- Update <title> to "astraX — Team Experiment Summary" (cosmetic).

Do NOT modify db.js, server.js, or anything outside app/public/ in this task.

## Acceptance Criteria
- [ ] Table renders all 13 Sheet-2 columns in contract order + Type tag + Actions.
- [ ] Header is sticky; table has visible grid lines and horizontal scroll; full-width.
- [ ] Rows are dense (compact padding/typography).
- [ ] Search input filters rows across text columns (case-insensitive).
- [ ] Status, Track, and Type filters each narrow rows and combine (AND).
- [ ] Topbar shows filtered/total row count.
- [ ] Modal shows helper text from `f.help` and marks required fields; new rows default to Not Started.
- [ ] Create, edit, delete, and refresh persistence still work.
- [ ] No escalation / approval / dashboard / agent UI introduced.

## Files Likely Affected
- `app/public/app.js`
- `app/public/style.css`
- `app/public/index.html`

## Blocked By
- tasks/excel-like-team-summary-view-002.md
