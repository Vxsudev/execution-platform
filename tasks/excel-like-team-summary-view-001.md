# Task: Align ROW_FIELDS to Sheet 2 order with labels, required flags, and Sheet 3 help

## Parent Spec
specs/excel-like-team-summary-view.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
Edit `app/db.js` ONLY. The `entries` table schema is unchanged (all 14 columns
already exist) — modify the `ROW_FIELDS` metadata array and seed.

Reorder ROW_FIELDS to Sheet-2 contract order with `type` last:
1. owner            — label "Owner",                   input text,     required: true,  help: "Who owns this experiment."
2. track            — label "Track",                   input text,     required: true,  help: "Select from T1 Device through T6 Sales. Links to the Jun–Nov roadmap."
3. title            — label "Experiment Title",        input text,     required: true,  help: "Short scannable name used in standups. Keep each atomic experiment under ~2 weeks."
4. function_area    — label "Function",                input text
5. parent_item      — label "Parent Item",             input text
6. hypothesis       — label "Description / Hypothesis", input textarea, help: "Write as: 'If we do X, then Y will happen, because Z.' Be specific."
7. design           — label "Experiment Design",       input textarea, help: "How will you run it? Materials/samples, steps, number of runs, measurement method."
8. success_criteria — label "Success Criteria",        input textarea, help: "Write BEFORE you start. What does 'pass' look like? Must be measurable."
9. target_end_date  — label "Target End Date",         input date,     help: "Pick a realistic date. If it slips, update it and note why in Dependencies."
10. dependencies    — label "Dependencies",            input text,     help: "What must be true before this can start/finish? Surface blockers during standup."
11. outcome         — label "Outcome / Finding",       input textarea, help: "Fill in AFTER. State the result in one sentence, then what it means."
12. next_action     — label "Next Action",             input text,     help: "What does this result trigger? Must be actionable."
13. status          — label "Status",                  input select,   options STATUSES, required: true, help: "Not Started → In Progress → Complete / Blocked / Inconclusive."
14. type            — label "Type",                    input select,   options ROW_TYPES (discriminator, kept last)

Keep ROW_TYPES = ['experiment','work_item','task'] and STATUSES unchanged.
Keep the WAL try/catch fallback and the users seed unchanged.

Seed: keep generic and client-safe. Replace the single seed row with one or two
generic sample rows (no real team data, no smoke-test rows), e.g.:
- { type:'experiment', title:'Sample experiment', owner:'demo', track:'T1 Device', function_area:'Engineering', hypothesis:'If we do X then Y because Z.', success_criteria:'Baseline metric improves', status:'Not Started' }
- { type:'work_item', title:'Sample work item', owner:'demo', track:'T2 Cloud', function_area:'Software', status:'In Progress' }

Do NOT modify any file outside app/db.js in this task.

## Acceptance Criteria
- [ ] `app/db.js` ROW_FIELDS order is owner→track→title→…→status→type (type last).
- [ ] title label is "Experiment Title".
- [ ] owner, track, title, status all have `required: true`.
- [ ] Fields track, title, hypothesis, design, success_criteria, target_end_date, dependencies, outcome, next_action, status carry a `help` string.
- [ ] `type` field retained with experiment/work_item/task options.
- [ ] Seed rows are generic/client-safe; no real team data; no smoke-test rows.
- [ ] `node -e "require('./app/db.js')"` (or app boot) loads without error.

## Files Likely Affected
- `app/db.js`

## Blocked By
- none
