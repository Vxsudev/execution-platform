# Spec: Remove Task/Experiment Edit Access Controls

## Status
approved

## Phase
phase-build

## Feature Slug
remove-task-edit-access-controls

## Depends On
Recon: ai/recon/remove-task-edit-access-controls-recon.md. Preserves railway-r2/r3 hardening (DB_PATH, first-admin bootstrap), railway-r4 service config, and all auth/session security.

---

## Summary

Client requirement changed: access controls are no longer required for task/experiment
editing. Every authenticated user must be able to create and edit task/experiment rows for
all owners and tracks. "My Track vs All" is retained only as a dashboard/filter/view
convenience — never as an edit-permission boundary. Login, sessions, production
SESSION_SECRET guard, first-admin bootstrap, DB_PATH, Railway config, and
delete/import/user-management admin gating are all preserved.

---

## Background

The app currently enforces role/track-scoped authorization on row create/edit in two
layers (backend `app/server.js` predicates + frontend `app/public/app.js` predicates).
The recon artifact maps every check. This capability surgically opens create/edit to any
authenticated user and removes the track-scope restriction on the create/edit form's track
dropdown, while leaving delete/import/user-management admin-only and the My Track view
intact.

---

## Data Model Changes

none

---

## API Surface

Backend authorization change only — no HTTP routes added, modified, or removed. The
predicate helpers `canCreateRow` and `canEditRow` in `app/server.js` are opened so any
authenticated request (already gated by `requireAuth`) may create or edit any row,
including assigning any canonical owner/track/status/title/field. `canDeleteRow`,
`canImport`, and `canManageUsers` remain admin-only. Canonical track-value validation in
`validate()` is unchanged (data integrity, not access control). Unauthenticated requests
remain rejected with 401 by `requireAuth`.

---

## Frontend Surface

`app/public/app.js` permission helpers `canCreateInCurrentWorkspace()` and
`canEditRow(row)` are opened so all authenticated users see the New row button, the Edit
button, and can double-click to edit any row. The create/edit form's track dropdown shows
all canonical tracks for every user (the track_owner scope restriction is removed).
`canDeleteRow()` stays admin-only. The My Track vs All toggle, `visibleRowsForWorkspace`,
and `dashboardRows` are unchanged — My Track remains a pure view/filter. No UI redesign;
no markup/CSS changes.

---

## Non-Scope

- No change to login, sessions, cookies, or SESSION_SECRET guard
- No change to first-admin bootstrap (R3), DB_PATH (R2), or Railway config (R4)
- No change to delete-row, import, or user-management permissions (stay admin-only)
- No schema change
- No role deletion (roles still gate tab/toggle visibility + user management)
- No `app/db.js`, `app/public/index.html`, `app/public/style.css` change
- No `app/package.json` / `app/.nvmrc` / `app/.env.example` change
- No Docker, no Postgres, no deployment

---

## Implementation Plan

### Task 1 — Backend: open create/edit authorization (backend)

In `app/server.js`, change `canCreateRow` and `canEditRow` to return true for any
authenticated user (routes are already behind `requireAuth`). Add a comment citing the
client requirement. Keep signatures so call sites at lines 179/192 are unchanged. Do not
touch `canDeleteRow`, `canImport`, `canManageUsers`, `parseScope`, or `validate()`.

### Task 2 — Frontend: open create/edit UI + track dropdown (frontend)

In `app/public/app.js`:
- `canCreateInCurrentWorkspace()` → return true (any authenticated user)
- `canEditRow(row)` → return true (any authenticated user)
- Create/edit form track dropdown (lines 821-822): show all `f.options` tracks for everyone;
  remove the track_owner `userScope()` restriction and auto-select-first-scoped-track logic
- Keep `canDeleteRow()` admin-only; keep My Track toggle / `visibleRowsForWorkspace` /
  `dashboardRows` unchanged

### Task 3 — Docs: README accuracy (frontend/docs)

In `app/README.md`, update the Roles table, "My Track Workspace", and "Frontend control
visibility" sections so they describe: any authenticated user can create/edit any row; My
Track is a view/filter only; delete/import/user-management remain admin-only.

### Task 4 — Verification

Per recon §10: syntax checks; dev + production boot smoke on disposable DB; unauthenticated
mutation rejected (401); authenticated non-admin create/edit across tracks succeeds; My
Track toggle still works; invariants 5/5; git status only allowed surfaces. Live
`app/data.db` never mutated.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/server.js` | `canCreateRow` + `canEditRow` → permissive |
| `app/public/app.js` | `canCreateInCurrentWorkspace` + `canEditRow` → permissive; track dropdown all tracks |
| `app/README.md` | Roles / My Track / control-visibility sections updated |
| `ai/recon/remove-task-edit-access-controls-recon.md` | Recon artifact |
| `specs/remove-task-edit-access-controls.md` | This spec |
| `tasks/remove-task-edit-access-controls-*.md` | OS-generated task graph |
| `ai/state_registry.json` | Lifecycle state |
| `ai/engineering-journal.md` | Journal entry |

---

## Verification Plan

See recon §10. Key assertions: unauthenticated mutation → 401; authenticated track_owner
and viewer can create/edit any row across tracks; delete remains admin-only; My Track vs
All renders and filters; auth/session/bootstrap unchanged; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke (R5) — redeploy and re-run the critical-path
smoke from `docs/railway-service-config.md` confirming open create/edit for any
authenticated user.
