# Task: Verify clicked-cell highlight and preserved table interactions

## Parent Spec
specs/clicked-cell-field-highlight.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the highlight wiring and confirm no regression. Static structure checks + boot smoke;
disposable DB only; live `app/data.db` never mutated. (Headless can't simulate DOM clicks, so the
behavior is verified via static structure + the column→field mapping guarantee.)

Checks (in-session worker):
1. `node --check` app/public/app.js, app/server.js, app/db.js; `cd app && npm run`
2. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` byte-for-byte unchanged
3. Static assertions on `app/public/app.js`:
   - every data cell branch emits `data-col` (count of `data-col=` ≥ number of LIST_COLS branches)
   - row `onclick` reads `td[data-col]` and calls `openForm(row, ...)`
   - `openForm` takes a focus key and adds `field-highlight` + `scrollIntoView` + `focus`
   - Details (`data-info`), Delete (`data-del`), More/Less (`data-cell-toggle`) handlers present/unchanged
4. Static assertion on `app/public/style.css`: `.field-highlight` + `@keyframes fieldFlash` present
5. Mapping: every `LIST_COLS` key exists in `state.fields[].key` (db.js ROW_FIELDS) → each cell maps
6. `.modal-back` z-index still present (layering preserved)
7. `bash scripts/invariant-check.sh` → 5/5; `git status` → only allowed surfaces (app.js + style.css)

## Acceptance Criteria
- [x] `node --check` passes on app.js, server.js, db.js
- [x] Dev boot smoke prints running line; live `app/data.db` byte-for-byte unchanged
- [x] Data cells carry `data-col` (all 6 render branches); row click derives `td[data-col]` and calls `openForm(row, col)`
- [x] `openForm(row, focusKey)` adds `.field-highlight` + `scrollIntoView` + `focus({preventScroll})`; no-match opens unchanged
- [x] `.field-highlight` + `@keyframes fieldFlash` present in style.css (subtle, accent, dark-mode)
- [x] Every `LIST_COLS` key (all 14) maps to a ROW_FIELDS form field
- [x] Details (`data-info`) / Delete (`data-del`) / More-Less (`data-cell-toggle`) / Enter-open / Save / modal layering (`.modal-back` z-index:1000) preserved
- [x] `app/server.js`, `app/db.js`, `index.html` unchanged (diff = app.js + style.css only)
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/clicked-cell-field-highlight-002.md
