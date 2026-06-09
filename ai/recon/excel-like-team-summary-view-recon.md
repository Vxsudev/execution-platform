# Recon — excel-like-team-summary-view

## Status
recon-complete

## Layer
Recon (pre-spec)

## Upstream Authority
- Directive: RAYSTRAT EXECUTION DIRECTIVE (DIRECTIVE_V3) — Excel Like Team Summary View
- source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx
- specs/promote-execution-table-v1-scaffold.md (predecessor capability)
- ai/engineering-journal.md

## Downstream Consumers
- specs/excel-like-team-summary-view.md

---

## 1. Environment

**Branch:** main
**Feature state:** RECON_READY (not yet in registry)
**Predecessor state:** promote-execution-table-v1-scaffold = RELEASE_APPROVED
**Adapter:** 12/12 PASS
**Invariant engine:** 5/5 PASS (INV-002 retired in predecessor capability)
**Workbook inspected with:** Python openpyxl 3.1.5 (actual .xlsx, not pasted text)
**Workbook copies:** repo `source-materials/workbooks/...xlsx` and `~/Downloads/astraX_JuneToNov_Experiment_All_Tracking.xlsx` are byte-size identical (31631 bytes); repo copy used as canonical.

---

## 2. Workbook Inspection (actual .xlsx)

### Sheet inventory
| # | Name | Dims | Role |
|---|------|------|------|
| 1 | Sample Experiment Log | A1:J25 | Personal log template (reference) |
| 2 | All Experiment Summary | A1:Q62 | **Primary app table source** |
| 3 | How To Use | A1:B20 | **Field-definition / help source** |

### Sheet 2 — "All Experiment Summary" header (row 4, cols A–M)
Header is on **row 4** (rows 1–2 are title/how-to banner, row 3 blank):

| Col | Header |
|-----|--------|
| A | Owner |
| B | Track |
| C | Experiment Title |
| D | Function |
| E | Parent Item |
| F | Description / Hypothesis |
| G | Experiment Design |
| H | Success Criteria |
| I | Target End Date |
| J | Dependencies |
| K | Test outcome / Finding |
| L | Next Action |
| M | Status |

Cols **P–Q** hold a derived stats panel (`STATUS SUMMARY`, `Count`) — not editable data, excluded from the app table.

Sample data rows (5–12) contain **real team data** (owners: Vijay, Sreekar, Gopinath, Ravi, Aditya; real device experiments). This is reference-only and will **NOT** be seeded into the DB.

### Sheet 3 — "How To Use" field guidance (rows 4–13)
| Field | Guidance (verbatim, condensed) |
|-------|-------------------------------|
| Track | Select from dropdown: T1 Device through T6 Sales. Links experiment to the Jun–Nov roadmap. |
| Experiment Title | Short scannable name. Use in standups. Any atomic experiment is NOT bigger than 2 weeks. |
| Description / Hypothesis | Write as: 'If we do X, then Y will happen, because Z.' Be specific. |
| Experiment Design | How will you run it? Materials/samples, steps, number of runs, measurement method. |
| Success Criteria | WRITE THIS BEFORE YOU START. What does 'pass' look like? Must be measurable. |
| Target End Date | Pick a realistic date. If it slips, update it and note why in Dependencies. |
| Dependencies | What must be true before this can start/finish? Surface blockers during standup. |
| Outcome / Finding | Fill in AFTER. State the actual result in one sentence, then what it means. |
| Next Action | What does this result trigger? Must be actionable. |
| Status | Not Started → In Progress → Complete / Blocked / Inconclusive. Update every Friday. |

No guidance rows exist for Owner, Function, or Parent Item (self-evident).

---

## 3. Current App State

### 3.1 Current table view columns (app/public/app.js `LIST_COLS`)
Only **6** columns shown: `type, title, owner, track, status, target_end_date`.
Missing from table: function_area, parent_item, hypothesis, design, success_criteria, dependencies, outcome, next_action.

### 3.2 Current editable fields (app/db.js `ROW_FIELDS`)
All **14** fields present and editable in the modal (13 Sheet-2 columns + `type`), BUT:
- Order leads with `type` (should follow Sheet 2 order, type demoted).
- `title` label is `Title` (Sheet 2 = `Experiment Title`).
- Only `title` is marked `required` (directive requires title, owner, track, status).
- No Sheet-3 helper text on any field.

### 3.3 Current DB schema (app/db.js `entries` table)
**All 14 columns already exist** with correct names:
`type, title, owner, track, function_area, parent_item, hypothesis, design, success_criteria, target_end_date, dependencies, outcome, next_action, status` (+ id, created_at, updated_at).

→ **No DB column add/rename required.** Only field metadata (order, labels, required, help) changes.

### 3.4 Current seed data
Seed logic (app/db.js) is **client-safe**: one generic row
`{type:experiment, title:'Sample experiment', owner:'demo', track:'T1', function_area:'Engineering', success_criteria:'Baseline metric improves', status:'Not Started'}`.
No smoke-test rows in seed logic. (The live `app/data.db` contains runtime rows from prior verification — gitignored; will be reset before this capability's verification so the clean seed applies.)

### 3.5 Current styling (app/public/style.css)
Dark theme, generous padding (10–12px cells), `min-width:760px` table, sticky header already present. Not dense, not Excel-like, only 6 columns so no meaningful horizontal scroll. No grid lines between columns.

---

## 4. Schema / Column Gap Analysis

| Aspect | Current | Required (Sheet 2 contract) | Action |
|--------|---------|------------------------------|--------|
| DB columns | all 14 present | all 14 | none |
| Field order | type first | Sheet 2 order, type last | reorder ROW_FIELDS |
| title label | "Title" | "Experiment Title" | relabel |
| Required fields | title | title, owner, track, status | add required flags + backend validate |
| Table columns | 6 | 13 + Actions | expand LIST_COLS |
| Helper text | none | Sheet 3 guidance | add `help` to ROW_FIELDS |
| Styling | spacious dark | dense Excel-like, grid lines, h-scroll | rewrite table CSS |
| Filters/search | none | search + status + track + type | add controls |

**No missing or misnamed DB columns.** The gap is presentation + field metadata, not data model structure.

---

## 5. Column Contract (for spec)

DB/display order (Sheet 2 + type discriminator last):
```
owner, track, title, function_area, parent_item, hypothesis, design,
success_criteria, target_end_date, dependencies, outcome, next_action, status, type
```

Table column order (directive requirement #2):
```
Owner → Track → Experiment Title → Function → Parent Item →
Description / Hypothesis → Experiment Design → Success Criteria →
Target End Date → Dependencies → Outcome / Finding → Next Action →
Status → Actions
```
(`type` shown as a compact tag, not a dominating leading column.)

Required: title, owner, track, status. Default status: Not Started.
Track options: T1 Device … T6 Sales (free-text retained; dropdown hint from Sheet 3).

---

## 6. Risks

1. **Real team data in workbook** — must not leak into seed or repo. Mitigated: reference-only; seed stays generic.
2. **Live data.db has prior test rows** — reset before verification so clean seed applies (gitignored, no repo impact).
3. **Backend required-field tightening** — adding owner/track/status as required on POST could reject minimal API clients. Acceptable: matches directive; PUT remains partial; seed bypasses API.
4. **Track dropdown vs free-text** — Sheet 3 implies a fixed T1–T6 list, but exact labels vary ("T1 Device" vs "T1-Device" in data). Keep `track` free-text to avoid over-constraining; filter derives options from live data.
5. **No DB migration framework** — column set unchanged, so no migration needed; existing rows remain valid.

---

## 7. Out-of-Scope Confirmation
Confirmed excluded and absent: escalation workflow, approval workflow, dashboard, agents, IoT/digital-twin, NDT-SaaS reuse. No product code outside `app/`. `prototypes/` untouched.

---

## 8. Next Step
State RECON_READY → spec generation.
Create `specs/excel-like-team-summary-view.md`, then
`bash scripts/compile-spec.sh specs/excel-like-team-summary-view.md`.
