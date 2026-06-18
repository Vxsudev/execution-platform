# Import Preview UX Friction Fix: Recon

**Feature Slug:** import-preview-ux-friction-fix  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** bb2e17f

---

## 1. Recon Objective

Read-only recon of the JS-rendered Import tab to (a) replace the long explanatory paragraph with
minimal warning-meaning bullets, (b) auto-run preview on file selection and drop the Preview
button, and (c) paginate the importable-rows preview so all rows can be reviewed. Frontend-only;
no parser/commit/backend change.

---

## 2. Files Read

| File | Finding |
|------|---------|
| `app/public/app.js` | `renderImportPanel` (548-617) + `bindImportActions` (632-703); `state` (3-8) |
| `app/public/index.html` (grep) | Import UI is **not** static here — fully JS-rendered |
| `app/public/style.css` | Will add minimal pager/legend/status rules |
| `app/server.js` import routes | Preview response shape (used read-only for verification) |

Local governance surfaces: only `ai/invariant-registry.md` present.

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # adapter valid
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -1                  # clean; HEAD=bb2e17f
grep -nE "renderImportPanel|bindImportActions|importPreview|import-note|importFile|importPreviewBtn|slice\(0, 10\)" app/public/app.js
grep -niE "import|preview" app/public/index.html           # none (JS-rendered)
```

---

## 4. Current Import UX Behavior

- **Paragraph** (`app.js:604`): a long `<p class="import-note">Admin only. Capture-first
  import: …</p>` — the friction the operator flagged.
- **Controls** (`app.js:605-610`): `<input type="file" id="importFile">`, a **Preview** button
  (`#importPreviewBtn`), a **Commit Import** button (`#importCommitBtn`, disabled until preview),
  and an optional "Import duplicates anyway" checkbox.
- **Preview flow** (`bindImportActions:635-649`): the Preview button reads the file, base64-encodes
  it, POSTs `/api/import/preview`, stores `state.importPreview`, and re-renders. File selection
  alone does nothing.
- **Truncation** (`app.js:564,568`): heading says "(first 10 of N)" and the table renders
  `p.rows.slice(0, 10)` — only the first 10 importable rows are visible; the rest cannot be reviewed.
- **Commit** (`bindImportActions:653-681`): commits `p.rows` (ALL importable rows), independent of
  what's displayed.
- **Summary/skipped/history**: summary counts (553-562), skipped table (576-580), Import History
  (582-600) with per-batch Delete.
- `state` (3-8): has `importPreview`, `importFilename`, `allowDuplicates`; **no** `importPage`.

---

## 5. Root Cause of the Friction

1. Long paragraph instead of scannable warning bullets.
2. Preview requires a separate button click (extra step).
3. Hard `slice(0, 10)` cap — only the first 10 importable rows are ever shown; no pagination.

None of these are parser/commit issues; commit already inserts all `p.rows`. Pure display/UX.

---

## 6. Selected Mutation Plan (frontend-only)

`app/public/app.js`:
- **Bullets:** replace the `<p class="import-note">` paragraph (604) with a short
  `<ul class="import-legend">` explaining warning meanings (informational, non-blocking):
  blank owner→Unassigned, blank track→Unassigned Track, blank status→Not Started, blank title
  with data→Untitled, non-canonical track→as-is.
- **Auto-preview + remove Preview button:** delete `#importPreviewBtn` (607); move the preview
  logic into the file input's `onchange` so selecting an `.xlsx` runs preview automatically. Show
  a transient "Previewing…" status (`#importStatus`) and disable the input during the call.
  Selecting a different file clears prior preview state and re-previews. Commit stays disabled
  until `state.importPreview` has rows.
- **Pagination:** add `importPage` to `state`; render importable rows as a page of size **20**
  (`p.rows.slice(start, end)`); heading "Importable rows preview — showing X–Y of N"; add
  Previous/Next controls (`#importPrev`/`#importNext`) bound to adjust `state.importPage` and
  re-render. Page index is clamped to `[0, ceil(N/20)-1]`. Pagination affects display only;
  commit still sends `p.rows` (all). Reset `importPage` on new preview / on entering the Import tab.

`app/public/style.css`: minimal rules for `.import-legend`, `.import-pager`, `.import-status`.

**No change to** `app/server.js` (preview response already carries `summary.importable_rows`,
full `rows`, `skipped_rows` — frontend derives pagination locally), `app/db.js`, parser, commit,
schema, or `index.html`.

---

## 7. Verification Plan

Disposable DB only; live `app/data.db` never mutated.
1. `node --check` app.js, server.js, db.js; `npm run`; dev boot smoke (live DB untouched)
2. Selecting an `.xlsx` auto-runs preview (no Preview button present); Commit disabled before
   preview, enabled after
3. Warning bullets render in place of the paragraph
4. Preview pagination: page 1 shows rows 1–20; Next shows 21–40 …; last page shows remainder;
   Previous returns; "showing X–Y of N" accurate (operator workbook → N=64)
5. Commit imports ALL importable rows (e.g. 64), not just the visible page; preview == commit
6. Summary counts, skipped, Import History still present; batch delete still works
7. Invariants 5/5; git status only allowed surfaces

(API behavior is exercised the same way as prior import recon — preview/commit unchanged.)

---

## 8. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Auto-preview fires on a non-xlsx file | Low | guard `/\.xlsx$/i`; show error, no call |
| Pagination state leaks across files | Low | reset `importPage=0` on new preview / tab entry; clamp on render |
| Commit accidentally tied to current page | None | commit sends `p.rows` (all), never the slice |
| Re-render on Prev/Next is heavy | None | data is in `state`; re-render only reslices |

---

## 9. Non-Scope

Import parser, commit behavior, Sheet 2 inclusive import, batch delete integrity, duplicate
detection, observation capture, access-control removal, row-click edit, auth/session, DB_PATH,
bootstrap, Railway config, schema. No `app/server.js`/`app/db.js`/`index.html` change; no Docker/
Postgres/deploy; no live `app/data.db` mutation.

---

## 10. Next Recommended Node

Railway redeploy smoke — confirm the streamlined Import tab (auto-preview + pagination) on the
live deployment.
