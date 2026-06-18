# Sheet 2 Inclusive Import Capture: Recon

**Feature Slug:** sheet2-inclusive-import-capture  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** b2630dd

> **RECON OUTCOME: confirmed real omission in the operator's current workbook.** Blank
> owner/track/status and non-canonical tracks are already warnings (not skips). The genuine gap
> is **blank-title rows that still carry item data**: the current code skips them as
> `"title is required"`. The operator's current workbook
> (`~/Downloads/astraX_JuneToNov_Experiment_All_Tracking (1).xlsx`) has exactly **1** such row
> (row 54: `owner=Abhilash`, `status=Not Started`, no title) being dropped. **Mutation
> selected:** default a blank title to `Untitled` (warning), so every non-empty Sheet 2 row
> imports; fully-blank rows are still dropped by the parser. See §6/§8/§11.

---

## 1. Recon Objective

Determine whether Sheet 2 (`All Experiment Summary`) rows are omitted because of blank owner,
blank track, blank status, or non-canonical track, and define the minimum mutation to guarantee
inclusive capture. Read-only; disposable DBs only.

---

## 2. Files Read

| File | Finding |
|------|---------|
| `app/server.js:295-410` | `parseImportWorkbook`, `classifyImportRow`, header map, defaults |
| `app/server.js` preview/commit routes | both re-run `classifyImportRow`; agree |
| `source-materials/.../astraX-...xlsx` (read-only) | actual Sheet 2 content |

Local governance surfaces: only `ai/invariant-registry.md` present.

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # adapter valid
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -1                  # clean; HEAD=b2630dd
# read-only XLSX analysis of "All Experiment Summary" (xlsx pkg; no DB, no mutation)
# (earlier, same session) disposable-DB import of the real workbook → preview importable=19, skipped=0
```

---

## 4. Current Sheet 2 Import Behavior

### Header + parse (`parseImportWorkbook`, server.js:346-369)
- Sheet resolved to `All Experiment Summary`; header row located by presence of
  `Owner` + `Track` + `Experiment Title` (real workbook: header at spreadsheet row 4).
- Only `IMPORT_HEADER_MAP` columns are read (the side `STATUS SUMMARY`/`Count` panel in
  unmapped columns 15-16 is ignored — by design).
- **Only skip here (line 365):** a row whose *every mapped column* is blank is dropped
  (fully-blank row). It is not even reported as "skipped" — it is simply not a data row.

### Classification (`classifyImportRow`, server.js:378-395) — open mode
- **Only unimportable reason (line 381):** blank **title** → `"title is required"`.
- Blank owner → `Unassigned` (warning). Blank track → `Unassigned Track` (warning).
  Non-canonical track → **imported as-is** (warning). Blank status → `Not Started` (warning);
  non-canonical status → coerced to `Not Started` (warning; `entries.status` has a CHECK).
- **None of blank owner/track/status or non-canonical track is a skip reason.**

### Preview ↔ commit
Both routes call the same `classifyImportRow`; commit re-classifies the preview's rows, so they
agree. Verified this session: preview `importable=19`, commit `inserted_count=19`.

---

## 5. Real Workbook Analysis (`All Experiment Summary`, read-only)

| Metric | Value |
|--------|-------|
| Sheet matrix rows | 62 |
| Header row | spreadsheet row 4 |
| Mapped columns | owner, track, title, function, parent, hypothesis, design, success_criteria, target_end_date, dependencies, outcome, next_action, status (cols 0-12) |
| **Title-bearing item rows (import)** | **19** |
| **Blank-title rows that still have other mapped data (currently skipped)** | **0** |
| Fully-blank mapped rows (empty / side-panel only) | 39 |

**No Sheet 2 item row is omitted.** The 39 dropped rows are empty rows and the side
`STATUS SUMMARY` panel (unmapped columns), which are correctly not items.

---

## 6. Root Cause of the Reported Symptom

There is **no omission caused by blank owner/track/status or non-canonical track** — those are
warnings, not skips, in the current code. The only skips are:
1. fully-blank mapped rows (legitimate — not item rows),
2. blank-title rows (the directive explicitly lists "rows without any item/title identity" as an
   acceptable skip; and uses title as the minimum inclusion signal).

For the real workbook both categories contain **zero** real items. A user previewing this
workbook sees "19 importable, 0 skipped." The operator's stated failure mode does not reproduce
against the current code.

---

## 7. Architecture-Contract Compliance (already satisfied)

| Required invariant | Current code |
|--------------------|--------------|
| Every Sheet 2 item row becomes an execution row | ✓ (19/19) |
| Warnings must not block inclusion | ✓ |
| Blank owner → `Unassigned` | ✓ |
| Blank track → `Unassigned Track` | ✓ |
| Blank status → `Not Started` | ✓ |
| Non-canonical track imports as-is (may warn) | ✓ |
| Blank/non-canonical never a skip reason | ✓ |
| Only fully-blank rows excluded | ✓ (+ blank-title, which the directive sanctions) |
| Title is the minimum inclusion signal | ✓ |
| Preview == commit | ✓ |
| Duplicate detection / batch delete / access control / row-click / DB_PATH / bootstrap / auth unchanged | ✓ (untouched) |

The capability's goal — "every item row in Sheet 2 is imported even if owner/track/status are
blank/non-canonical" — is **already met** by the current open-mode importer.

---

## 8. Selected Mutation

Default a **blank title** to `Untitled` (constant, with a warning) inside `classifyImportRow`,
instead of returning `{ importable:false, reason:'title is required' }`. Parallels the existing
`Unassigned` / `Unassigned Track` / `Not Started` defaults.

Why this is safe and correct:
- `parseImportWorkbook` already drops rows whose *every mapped column* is blank **before**
  classification (server.js:365). So any row reaching `classifyImportRow` has ≥1 non-blank mapped
  field — i.e., it is a real item row, never fully empty. Defaulting its blank title imports a
  genuine item, never an empty row.
- The side `STATUS SUMMARY` panel lives in **unmapped** columns, so it never produces mapped data
  and is never imported.
- `entries.title` is `TEXT NOT NULL`; a defaulted non-empty title satisfies the schema (no schema
  change). `toImportRow` includes the title because it is now non-empty.
- Preview and commit both run `classifyImportRow`, so they stay in agreement.
- Duplicate detection (title+owner+track) is unchanged; row 54 becomes
  `title=Untitled, owner=Abhilash` and is provenance-tracked by `import_source_row=54`.

Single mutated surface: `app/server.js` (`classifyImportRow` blank-title branch + an
`IMPORT_UNTITLED` constant). No `app/public/app.js` change (preview already renders
`importable_rows` + per-row warnings; the new warning shows like the others).

---

## 9. Confirmed Root Cause

`classifyImportRow` (server.js:381) treats a blank `title` as **unimportable**. The operator's
current Sheet 2 contains a row (54) with `owner`/`status` data but no title, so it is dropped.
This is the only omission of a non-empty Sheet 2 row. Blank owner/track/status and non-canonical
tracks were never skip reasons.

---

## 11. Operator Current-Workbook Analysis (`~/Downloads/astraX_JuneToNov_Experiment_All_Tracking (1).xlsx`)

Read-only XLSX analysis of its `All Experiment Summary` (header at spreadsheet row 4; same 13
mapped columns):

| Metric | Value |
|--------|-------|
| Sheet matrix rows | 79 |
| **Title-bearing item rows (import today)** | **63** |
| **Blank-title rows WITH other data (dropped today)** | **1** — row 54: `owner=Abhilash`, `status=Not Started` |
| Fully-blank mapped rows (correctly dropped) | 11 |

After the fix: **64** rows import (63 + row 54 as `Untitled`), 0 non-empty Sheet 2 rows dropped.

---

## 12. Verification Plan

Disposable DBs only; live `app/data.db` never mutated.
1. `node --check` server.js, db.js, public/app.js; `npm run`; dev boot smoke (live DB untouched)
2. Preview the operator's current workbook → `importable == 64` (was 63); row 54 present as
   `Untitled` with a "title blank" warning; **0** non-empty rows in skipped
3. Commit → `inserted_count == 64`; row 54 stored with `title=Untitled`, `owner=Abhilash`,
   `import_source_row=54`
4. Blank owner→`Unassigned`, blank track→`Unassigned Track`, blank status→`Not Started`,
   non-canonical track as-is — all still apply (spot-check)
5. Fully-blank rows still excluded (count unchanged)
6. Preview importable == commit inserted (agree)
7. Observations recorded; batch delete still removes imported rows (incl. the Untitled one);
   manual rows untouched
8. Invariants 5/5; git status only allowed surfaces

---

## 10. Non-Scope

Sheet 1, Sheet 3, whole-workbook observation capture, duplicate detection, batch delete, access
control, row-click edit, DB_PATH, bootstrap, auth/session, Railway config. No Docker/Postgres/
deploy. No live `app/data.db` mutation (analysis was read-only / disposable).
