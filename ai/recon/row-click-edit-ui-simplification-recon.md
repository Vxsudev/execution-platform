# Row Click Edit UI Simplification: Recon

**Feature Slug:** row-click-edit-ui-simplification  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** 2958b48 (access-control removal)

---

## 1. Recon Objective

Read-only recon of the table interaction model to (a) make a single row/cell click open the
**edit** form (the same form the Edit button opens), (b) remove the explicit Edit button from
row actions, (c) ensure normal row/cell click does NOT open Details, and (d) fix the modal
layering bug where the sticky table header bleeds over the modal. Frontend-only; no backend,
schema, or config change.

---

## 2. Files Read

| File | Purpose |
|------|---------|
| `app/public/app.js` (renderTable, bindRowActions, openForm, openDetails) | Row rendering + click handlers |
| `app/public/style.css` (lines 48-75) | Sticky header / modal z-index |
| `app/public/index.html` (prior recon) | No row-action markup (rows are JS-rendered) |

Local governance surfaces: only `ai/invariant-registry.md` present (as in prior capabilities).

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # adapter valid
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -1                  # clean; HEAD=2958b48
grep -n "z-index|sticky|modal-back|\.modal|thead|row-actions|icon-btn" app/public/style.css
```

---

## 4. Current Row/Cell Click Behavior (`app/public/app.js`)

`bindRowActions()` (lines 284-321):
- **Single click** on a row (line 307-311): guard skips clicks on `button, a, input, select,
  textarea`; otherwise a 200 ms `_rowClickTimer` fires **`openDetails(row)`**.
- **Double click** (line 312-316): clears the timer; `if (canEditRow(row)) openForm(row)`.
- **Enter key** (line 317-319): `openDetails(row)`.
- `_rowClickTimer` module var declared at line 10; used only here.

**Problem vs new model:** normal click opens Details; editing requires either the Edit button
or a double-click. The new product model (any authenticated user edits any row) wants a single
click to open the edit form directly.

---

## 5. Current Row Actions Rendering (`app/public/app.js:275-279`)

```js
<div class="row-actions">
  <button class="icon-btn" data-info="${r.id}">Details</button>
  ${canEditRow(r) ? `<button class="icon-btn" data-edit="${r.id}">Edit</button>` : ''}
  ${canDeleteRow() ? `<button class="icon-btn danger" data-del="${r.id}">Delete</button>` : ''}
</div>
```

- `data-info` → `openDetails` (bindRowActions:285-286) — **KEEP** (Details button remains)
- `data-edit` → `openForm` (bindRowActions:287-288) — **REMOVE button + binding**
- `data-del` → delete flow (bindRowActions:289-294) — **KEEP** (`canDeleteRow()` = admin-only, app.js:26)

`canEditRow(_row)` currently returns `true` for all authenticated users (set in the prior
access-control capability). After this change, edit is reached by clicking the row, not a button.

---

## 6. Current More/Less Toggle (`app/public/app.js:295-303`)

`data-cell-toggle` buttons call `e.stopPropagation()` then toggle `state.expandedCells`. The
row click guard also skips `button` targets, so the toggle is doubly protected — it will NOT
open the edit form. **KEEP unchanged.**

---

## 7. Modal Layering Bug Evidence (`app/public/style.css`)

| Selector | Line | z-index |
|----------|------|---------|
| `th` (sticky header) | 52 | `position:sticky;top:0;...;z-index:2` |
| `.icon-btn` (action buttons) | 69 | none (auto) |
| `.modal-back` (fixed backdrop) | 72 | **none (auto = 0)** |

`.modal-back` is `position:fixed` with **no z-index**, so it stacks at auto (0). The sticky
`<th>` has `z-index:2` within the table's scroll container, so header cells paint **over** the
modal backdrop/content. This is the reported "header/actions bleed over the edit modal" bug.

**Fix:** give `.modal-back` a high z-index (e.g. `1000`) so the backdrop + modal sit
unambiguously above the sticky header (`z-index:2`) and all action buttons.

---

## 8. Selected UI Mutation Plan

### `app/public/app.js`
1. **Remove the Edit button** — delete the `${canEditRow(r) ? '<button data-edit>...' : ''}`
   line in `renderTable` (line 277). Actions column keeps Details + (admin-only) Delete.
2. **Remove the `data-edit` binding** in `bindRowActions` (lines 287-288) — now dead.
3. **Single click opens edit** — replace the 200 ms `openDetails` timer (307-311) and the
   `dblclick`→`openForm` handler (312-316) with: row click (outside buttons/inputs) →
   `openForm(row)`. Keep the `closest('button, a, input, select, textarea')` guard so Details,
   Delete, and More/Less clicks never trigger edit.
4. **Enter key opens edit** (line 317-319) → `openForm(row)` (keyboard parity with click).
5. **Remove the now-unused `_rowClickTimer`** declaration (line 10).
6. Details button (`data-info` → `openDetails`) and Delete button behavior unchanged.

### `app/public/style.css`
7. Add `z-index:1000` to `.modal-back` (line 72) so the modal covers the sticky header + actions.

---

## 9. Surfaces NOT Modified

- `app/server.js` (no frontend call-contract change — `openForm` already PUTs `/api/rows/:id`,
  `openDetails` reads from `state.rows`; both unchanged)
- `app/db.js`, schema, DB_PATH, first-admin bootstrap, auth/session
- `app/public/index.html` (rows are JS-rendered; no markup change needed)
- `app/package.json`, `app/.nvmrc`, `app/.env.example`, `docs/railway-service-config.md`
- README: no change needed — the prior capability's README already documents open create/edit;
  this is an interaction refinement, not a permission change. (No usage note required.)

---

## 10. Verification Plan

1. `node --check` app/public/app.js, app/server.js, app/db.js
2. `cd app && npm run` → start = `node server.js`
3. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` untouched
4. Static assertions on `app/public/app.js`:
   - no `data-edit` attribute and no `>Edit<` button in `renderTable`
   - row `onclick` calls `openForm` (not `openDetails`)
   - `data-info`/`openDetails` still present (Details preserved)
   - `data-del`/delete flow preserved; `canDeleteRow` still `isAdmin()`
   - `data-cell-toggle` still calls `stopPropagation`
5. Static assertion on `app/public/style.css`: `.modal-back` has `z-index` > 2
6. API regression on a disposable temp DB: authenticated edit (`PUT /api/rows/:id`) → 200;
   create (`POST /api/rows`) → 201; unauthenticated mutation → 401 (frontend call contract intact)
7. `bash scripts/invariant-check.sh` → 5/5 PASS
8. `git status` → only allowed surfaces

Live `app/data.db` never mutated (temp DB only).

---

## 11. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Row click opens edit when user meant to read | Low | Edit form has Cancel; Details still available via its button |
| Removing timer/dblclick breaks an expected gesture | Low | Single click is now the primary, simplest gesture; directive allows dropping dblclick |
| Modal z-index too low still bleeds | Low | `1000` is far above the only competing context (`z-index:2`) |
| Details click accidentally opens edit | None | Row guard skips `button` targets; Details handler unchanged |
| More/Less toggle opens edit | None | `stopPropagation` + button-target guard (double-protected) |

---

## 12. Next Recommended Node

Railway redeploy smoke — redeploy and confirm the new click-to-edit interaction and modal
layering on the live deployment.
