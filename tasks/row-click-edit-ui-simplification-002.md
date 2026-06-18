# Task: Verify click-to-edit interaction, preserved controls, and modal layering

## Parent Spec
specs/row-click-edit-ui-simplification.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the interaction change and confirm no regression to Details/Delete/More-Less, auth, or
the API call contract. API tests use a disposable temp DB; live `app/data.db` is never mutated.

Checks (in-session worker):
1. `node --check` app/public/app.js, app/server.js, app/db.js
2. `cd app && npm run` → start = `node server.js`
3. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` byte-for-byte unchanged
4. Static assertions on `app/public/app.js`:
   - no `data-edit` and no `>Edit<` button in renderTable
   - row `onclick` calls `openForm`; no `_rowClickTimer`; no `dblclick` edit handler
   - `data-info`/`openDetails` present; `data-del` present; `data-cell-toggle` stopPropagation present
5. Static assertion on `app/public/style.css`: `.modal-back` has `z-index` > 2
6. API regression on disposable temp DB (production mode, bootstrap admin):
   - authenticated `PUT /api/rows/:id` → 200 (edit form contract intact)
   - authenticated `POST /api/rows` → 201 (create intact)
   - unauthenticated `POST /api/rows` → 401
7. `bash scripts/invariant-check.sh` → 5/5 PASS
8. `git status` → only allowed surfaces

## Acceptance Criteria
- [x] `node --check` passes on app.js, server.js, db.js
- [x] Edit button + `data-edit` absent from row actions; row click → `openForm`; Enter → `openForm` (only remaining `>Edit<` is the separate admin Users-panel `data-user-edit`, out of scope)
- [x] Details / Delete / More-Less handlers preserved (`data-info`, `data-del`, `data-cell-toggle` present)
- [x] `.modal-back` z-index:1000 (> sticky header z-index:2)
- [x] Dev boot smoke prints running line; live `app/data.db` unchanged (90112 bytes)
- [x] API: edit 200, create 201, unauthenticated mutation 401 (4/4 assertions on temp DB)
- [x] `app/server.js`, `app/db.js`, `app/public/index.html`, package/config/Railway docs unchanged (diff = app.js + style.css only)
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces; final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/row-click-edit-ui-simplification-001.md
