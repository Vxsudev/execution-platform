# Clicked Cell Field Highlight: Recon

**Feature Slug:** clicked-cell-field-highlight  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** f6f3440

---

## 1. Recon Objective

Read-only recon of the table→form flow to subtly highlight the form field matching the clicked
table cell when the edit form opens. Frontend-only; no backend/import/access-control change.

---

## 2. Files Read

| File | Finding |
|------|---------|
| `app/public/app.js` | `renderTable` (256-279), `bindRowActions` (282-314), `openForm` (838-898) |
| `app/public/style.css` | `:root` vars (`--accent:#6ea8fe`), `.field` (76-81), focus rules (156,161) |
| `app/public/index.html` (prior recon) | form is JS-rendered, not static |

Local governance surfaces: only `ai/invariant-registry.md` present.

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # adapter valid
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -1                  # clean; HEAD=f6f3440
```

---

## 4. Current Row/Cell Click Behavior

`bindRowActions` (282-314): row `onclick` (310 area) — if the click target is inside
`button/a/input/select/textarea` it returns (so Details/Delete/More-Less keep their behavior);
otherwise `openForm(row)`. Enter key also calls `openForm(row)`. The data `<td>` cells
(`renderTable:258-273`) carry **no column key**, so the handler cannot currently tell which
column was clicked.

`More/Less` toggle (`data-cell-toggle`, 291-299) calls `e.stopPropagation()` and is a `<button>`
(doubly guarded) — never opens the form. Details (`data-info`) and Delete (`data-del`) unchanged.

---

## 5. Table Column → Form Field Mapping

`LIST_COLS` (table columns) keys are identical to `state.fields[].key` (form field keys):
`owner, track, title, function_area, parent_item, hypothesis, design, success_criteria,
target_end_date, dependencies, outcome, next_action, status, type`.

`openForm` (838-863) renders each field control with `data-k="${f.key}"` inside a
`<div class="field">` wrapper. So the form field for a clicked column `k` is located by
`[data-k="${k}"]`, and its group by `.closest('.field')`. **All 14 list columns map to an
editable form field** (including `type`, an editable select), so every data cell has a highlight
target. The Actions column has no `data-col` and is already guarded.

---

## 6. Selected Highlight Behavior (frontend-only)

1. `renderTable`: add `data-col="${k}"` to each data `<td>` (all branches: text, trunc, status,
   type).
2. `bindRowActions` row `onclick`: after the existing interactive-target guard, read the clicked
   cell via `e.target.closest('td[data-col]')` and pass its `dataset.col` to `openForm(row, col)`.
   Enter-key path stays `openForm(row)` (no specific cell → no highlight).
3. `openForm(row, focusKey)`: after the modal is appended, if `focusKey` resolves to a
   `[data-k="${focusKey}"]` control, add a `.field-highlight` class to its `.field` group,
   `scrollIntoView({block:'center', behavior:'smooth'})`, and `focus({preventScroll:true})` the
   control. If no match (or no focusKey), open the form unchanged.
4. `app/public/style.css`: add a subtle `.field-highlight` — a one-shot fading background tint
   (`@keyframes fieldFlash` ~2.4s) plus an accent label color and accent control border. Uses
   `--accent` (#6ea8fe) so it reads well on the dark panels and never obscures text.

This alters data (no), submits (no), blocks typing (no — it focuses for editing). New modal is
created per open, so the flash replays on each click.

---

## 7. Surfaces to Modify

| File | Change |
|------|--------|
| `app/public/app.js` | `data-col` on cells; clicked-column derivation in row `onclick`; `openForm(row, focusKey)` highlight/scroll/focus |
| `app/public/style.css` | `.field-highlight` + `@keyframes fieldFlash` (subtle, dark-mode) |

**No change to** `app/server.js`, `app/db.js`, `index.html`, schema, or any non-edit-form behavior.

---

## 8. Verification Plan

Disposable DB only; live `app/data.db` never mutated.
1. `node --check` app.js, server.js, db.js; `npm run`; dev boot smoke (live DB untouched)
2. Static assertions: each data `<td>` has `data-col`; row `onclick` derives `td[data-col]` and
   calls `openForm(row, col)`; `openForm` accepts a focus key and adds `.field-highlight` +
   `scrollIntoView` + `focus`; `.field-highlight` rule + keyframes exist in CSS
3. Mapping check: every `LIST_COLS` key has a matching `state.fields[].key` (so each cell maps)
4. Preserved: Details opens details (no highlight), Delete unchanged, More/Less toggles only,
   row click still opens edit, Save still works, modal layering (`.modal-back` z-index) intact
5. Invariants 5/5; git status only allowed surfaces (app.js + style.css)

(DOM click simulation isn't available headless; behavior is verified by static structure + the
mapping guarantee. App boot + API unaffected.)

---

## 9. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Highlight too loud / obscures text | Low | Subtle fading tint + accent border only; `--accent` on dark panel |
| Focus/scroll disrupts the modal | Low | `focus({preventScroll:true})` + smooth `scrollIntoView` inside the scrollable modal |
| Clicked cell maps to no field | Low | Guarded: open form without highlight |
| Breaks Details/Delete/More-Less | None | Existing interactive-target guard + `stopPropagation` unchanged |

---

## 10. Non-Scope

Row-click-to-edit behavior (kept), Edit button (stays removed), backend, import, access-control,
auth/session, DB_PATH, bootstrap, Railway config, schema. No `app/server.js`/`app/db.js`/
`index.html` change; no Docker/Postgres/deploy; no live `app/data.db` mutation.

---

## 11. Next Recommended Node

Railway redeploy smoke — confirm clicked-cell field highlight on the live deployment.
