# Spec: Clicked Cell Field Highlight

## Status
approved

## Phase
phase-build

## Feature Slug
clicked-cell-field-highlight

## Depends On
Recon: ai/recon/clicked-cell-field-highlight-recon.md. Builds on row-click-edit-ui-simplification. Frontend-only; preserves backend, import, access control, auth/session.

---

## Summary

When a user clicks a table cell to open the edit form, subtly highlight the corresponding form
field so they can find it quickly. Frontend-only: tag each data cell with its column key, derive
the clicked column in the row click handler, pass it to `openForm(row, focusKey)`, and add a
subtle fading highlight (accent border + tint) plus scroll-into-view and focus to the matching
`.field`. Row-click-to-edit, Details, Delete, More/Less, and all backend behavior are unchanged.

---

## Background

`bindRowActions` opens `openForm(row)` on a plain row/cell click. The table `<td>` cells carry no
column key, so the form can't indicate which field the clicked cell maps to. `LIST_COLS` keys are
identical to `state.fields[].key`, and `openForm` renders each control with `data-k="${f.key}"`,
so the matching field is found by `[data-k="${col}"]`. All 14 list columns map to an editable
field (including the `type` select).

---

## Data Model Changes

none

---

## API Surface

none — `app/server.js` and `app/db.js` are unchanged. Highlight is a pure client-side affordance.

---

## Frontend Surface

`app/public/app.js`:
- `renderTable`: add `data-col="${k}"` to each data `<td>` (text, trunc, status, type branches).
- `bindRowActions`: in the row `onclick`, after the existing `button/a/input/select/textarea`
  guard, read `e.target.closest('td[data-col]')` and call `openForm(row, cell?.dataset.col)`.
  The Enter-key path stays `openForm(row)` (no highlight).
- `openForm(row, focusKey)`: when `focusKey` resolves to a `[data-k="${focusKey}"]` control, add
  `.field-highlight` to its `.field` group, `scrollIntoView({block:'center', behavior:'smooth'})`,
  and `focus({preventScroll:true})`. No match / no key → open unchanged.

`app/public/style.css`: add a subtle `.field-highlight` (one-shot `@keyframes fieldFlash` ~2.4s
fading tint + accent label/border) using `--accent`; dark-mode friendly; never obscures text.

---

## Non-Scope

- No change to row-click-to-edit behavior; Edit button stays removed
- No change to Details, Delete, or More/Less behavior; modal layering unchanged
- No backend / import / duplicate / batch-delete / access-control / auth change
- No `app/server.js`, `app/db.js`, schema, `index.html`, package, config, or Railway change
- No Docker/Postgres/deploy; no live `app/data.db` mutation

---

## Implementation Plan

### Task 1 — Frontend: cell column keys + clicked-cell highlight (frontend)

`app/public/app.js`: add `data-col` to data cells; derive the clicked column and pass to
`openForm(row, focusKey)`; in `openForm`, highlight + scroll + focus the matching field group.
`app/public/style.css`: add the subtle `.field-highlight` rule + `@keyframes fieldFlash`.

### Task 2 — Frontend: confirm preserved interactions (frontend)

Confirm Details (`data-info`), Delete (`data-del`), More/Less (`data-cell-toggle` stopPropagation),
Enter-key open, Save, and the `.modal-back` z-index layering are unchanged.

### Task 3 — Verification

Per recon §8: syntax checks; dev boot smoke (live DB untouched); static assertions (data-col on
cells; row onclick derives `td[data-col]` → `openForm(row,col)`; `openForm` highlights/scrolls/
focuses; `.field-highlight` + keyframes in CSS); column→field mapping holds for all `LIST_COLS`;
preserved behaviors; invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/public/app.js` | `data-col` cells; clicked-column derivation; `openForm(row, focusKey)` highlight |
| `app/public/style.css` | `.field-highlight` + `@keyframes fieldFlash` |
| `ai/recon/...`, `specs/...`, `tasks/...`, `ai/state_registry.json`, `ai/engineering-journal.md` | OS artifacts |

---

## Verification Plan

See recon §8. Key assertions: clicking a cell opens edit and highlights the matching field; no
highlight on Details/More-Less; Delete/Save/modal-layering preserved; backend untouched;
invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — confirm clicked-cell field highlight live.
