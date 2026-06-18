# Spec: Row Click Edit UI Simplification

## Status
approved

## Phase
phase-build

## Feature Slug
row-click-edit-ui-simplification

## Depends On
Recon: ai/recon/row-click-edit-ui-simplification-recon.md. Builds on remove-task-edit-access-controls (@ 2958b48). Preserves all auth/session/Railway/DB behavior.

---

## Summary

After live Railway smoke, the UI must match the new edit-anything model. Make a single
row/cell click open the **edit** form (the same form the Edit button currently opens), remove
the explicit Edit button from row actions, ensure normal row/cell click does NOT open Details
(Details stays available via its own button), and fix the modal layering bug where the sticky
table header bleeds over the modal. Frontend-only.

---

## Background

Currently a single row click opens Details (200 ms timer) and editing requires the Edit button
or a double-click (`app/public/app.js:284-321`). With any authenticated user able to edit any
row, direct click-to-edit is the natural interaction. Separately, `.modal-back`
(`app/public/style.css:72`) has no `z-index`, so the sticky `<th>` (`z-index:2`) paints over
the modal — the reported layering bug.

---

## Data Model Changes

none

---

## API Surface

none

---

## Frontend Surface

`app/public/app.js`:
- Remove the Edit button from `renderTable` row actions and its `data-edit` binding in
  `bindRowActions`.
- Single row/cell click (outside `button/a/input/select/textarea`) opens `openForm(row)` — the
  same edit modal the Edit button opened. Enter key on a focused row also opens `openForm(row)`.
- Remove the now-unused `_rowClickTimer` and the `dblclick`→edit handler (double-click no longer
  required).
- Preserve: Details button (`data-info` → `openDetails`), Delete button (admin-only via
  `canDeleteRow`), More/Less `data-cell-toggle` (`stopPropagation`, must not open edit).

`app/public/style.css`:
- Add `z-index:1000` to `.modal-back` so the backdrop and modal sit above the sticky header
  (`z-index:2`) and all action buttons.

---

## Non-Scope

- No backend access-control change (`app/server.js` untouched — frontend call contract unchanged)
- No `app/db.js`, schema, DB_PATH, first-admin bootstrap, or auth/session change
- No Railway config / `docs/railway-service-config.md` change
- No `app/package.json` / `app/.nvmrc` / `app/.env.example` change
- No Docker, Postgres, or deployment
- No broad UI redesign; Edit is removed, not replaced with another edit control
- My Track vs All remains a view/filter only (unchanged)

---

## Implementation Plan

### Task 1 — Frontend: click-to-edit + remove Edit button + modal layering (frontend)

`app/public/app.js`:
1. `renderTable` (line 277): remove the Edit button line.
2. `bindRowActions` (287-288): remove the `data-edit` binding.
3. `bindRowActions` row handlers (304-320): row `onclick` (outside interactive targets) →
   `openForm(row)`; remove the 200 ms `openDetails` timer and the `dblclick` handler; Enter →
   `openForm(row)`.
4. Remove the unused `_rowClickTimer` declaration (line 10).
5. Keep `data-info`/Details, `data-del`/Delete, and `data-cell-toggle`/More-Less unchanged.

`app/public/style.css`:
6. `.modal-back` (line 72): add `z-index:1000`.

### Task 2 — Verification

Per recon §10: syntax checks; dev boot smoke (live DB untouched); static assertions (no Edit
button/`data-edit`; row click → `openForm`; Details/Delete/More-Less preserved; `.modal-back`
z-index > 2); API regression on disposable temp DB (edit 200, create 201, unauth 401);
invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/public/app.js` | Remove Edit button + binding; row/cell click + Enter → edit form; drop timer/dblclick |
| `app/public/style.css` | `.modal-back` z-index:1000 |
| `ai/recon/row-click-edit-ui-simplification-recon.md` | Recon artifact |
| `specs/row-click-edit-ui-simplification.md` | This spec |
| `tasks/row-click-edit-ui-simplification-*.md` | OS-generated task graph |
| `ai/state_registry.json` | Lifecycle state |
| `ai/engineering-journal.md` | Journal entry |

---

## Verification Plan

See recon §10. Key assertions: single row/cell click opens the edit modal; Edit button absent;
Details button still opens Details; Delete unchanged (admin-only); More/Less does not open edit;
modal covers the sticky header; auth/session/create/edit/API contract intact; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — confirm click-to-edit and modal layering on the
live deployment.
