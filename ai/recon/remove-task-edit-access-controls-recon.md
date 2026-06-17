# Remove Task/Experiment Edit Access Controls: Recon

**Feature Slug:** remove-task-edit-access-controls  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** f623062

---

## 1. Recon Objective

Read-only recon to map every role/track-based access control on task/experiment
create/edit/delete/import/user-management, separate authentication from authorization,
and define the minimum surgical mutation to open create+edit to all authenticated users
while preserving login, session security, admin bootstrap, Railway hardening, and the
My Track vs All view convenience.

---

## 2. Files Read

| File | Purpose |
|------|---------|
| `app/server.js` (full, 603 lines) | Backend authorization helpers + route guards |
| `app/public/app.js` (full, 871 lines) | Frontend permission helpers + UI gating |
| `app/public/index.html` (grep) | No role-based hiding present |
| `app/public/style.css` (grep) | No role-based rules present |
| `app/db.js` (R3 state, in context) | Role/track_scope seed + storage only — no edit-permission logic |

Local governance surfaces: only `ai/invariant-registry.md` present (as in R1–R4).

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # 12/12 PASS
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -3                  # clean; HEAD=f623062
grep -n "canCreateRow\|canEditRow\|canDeleteRow\|canImport\|canManageUsers" app/server.js
grep -in "role\|track_owner\|viewer" app/public/index.html app/public/style.css  # none
```

---

## 4. Authentication vs Authorization (separation)

**Authentication (PRESERVE — do not touch):**
- `app/server.js:45-54` — SESSION_SECRET guard (production fail-closed)
- `app/server.js:56-71` — HMAC-SHA256 signed session tokens
- `app/server.js:83-96` — `currentUser()` + `requireAuth` middleware
- `app/server.js:99-123` — login/logout; cookie `httpOnly`/`sameSite`/`secure`
- `app/db.js` — first-admin bootstrap (R3)

**Authorization (the access-control layer this capability targets):**
- Backend predicate helpers `app/server.js:28-43`
- Frontend predicate helpers `app/public/app.js:18-35`

Every mutation route is behind `requireAuth` — "any authenticated user" is the new
authorization floor for create/edit. Authentication is untouched.

---

## 5. Backend Access-Control Map (`app/server.js`)

| Helper | Lines | Current behavior | Disposition |
|--------|-------|------------------|-------------|
| `parseScope(user)` | 25-27 | Parse `track_scope` JSON | **KEEP** — used by currentUser response, publicUser, My Track |
| `canCreateRow(user, track)` | 28-32 | admin→true; track_owner→scope.includes(track); else false | **OPEN** → any authenticated user |
| `canEditRow(user, existingRow, nextTrack)` | 33-40 | admin→true; track_owner→existing.track in scope AND next track in scope; else false | **OPEN** → any authenticated user |
| `canDeleteRow(user)` | 41 | admin only | **KEEP** — delete not in client requirement; "do not expand scope" |
| `canImport(user)` | 42 | admin only | **KEEP** — import does not block task editing |
| `canManageUsers(user)` | 43 | admin only | **KEEP** — client did not ask everyone to manage users |

Route guards calling these:
- `POST /api/rows` line 179 → `canCreateRow` (becomes permissive)
- `PUT /api/rows/:id` line 192 → `canEditRow` (becomes permissive)
- `DELETE /api/rows/:id` line 203 → `canDeleteRow` (unchanged, admin-only)
- `POST/PUT/DELETE /api/users` lines 227/233/259/291 → `canManageUsers` (unchanged)
- import routes lines 447/480/573/583 → `canImport` (unchanged)

**Track-value validity is independent of permission:** `validate()` at
`app/server.js:156,162` rejects non-canonical track values (`!TRACKS.includes(...)` →
`'invalid track'`). This is data integrity, NOT access control — **KEEP unchanged**. Any
user can set any *canonical* track; junk track values are still rejected for everyone.

---

## 6. Frontend Access-Control Map (`app/public/app.js`)

| Helper / site | Lines | Current behavior | Disposition |
|---------------|-------|------------------|-------------|
| `isAdmin/isTrackOwner/isViewer` | 18-20 | Role predicates | **KEEP** — drive Users/Import tabs + My Track toggle visibility |
| `canCreateInCurrentWorkspace()` | 21-25 | admin→true; track_owner→workspace='my' & scoped; else false | **OPEN** → any authenticated user |
| `canEditRow(row)` | 26-30 | admin→true; track_owner→scope.includes(row.track); else false | **OPEN** → any authenticated user |
| `canDeleteRow()` | 31 | admin only | **KEEP** — mirrors backend; delete stays admin-only |
| `visibleRowsForWorkspace(rows)` | 32-35 | My Track filter (workspace='my' → scoped rows) | **KEEP** — this IS the My Track view convenience |
| `dashboardRows()` | 36-39 | track_owner+my → scoped; else all | **KEEP** — dashboard view convenience |
| New row button | 157 | `isRowsPage && canCreateInCurrentWorkspace()` | Opens to all once helper opens |
| Edit button | 282 | `canEditRow(r)` | Opens to all once helper opens |
| Double-click edit | 320 | `if (canEditRow(row)) openForm(row)` | Opens to all once helper opens |
| **Form track dropdown** | 821-822 | track_owner restricted to `userScope()` tracks; auto-selects first scoped track | **OPEN** → show all `f.options` tracks for everyone |
| My Track / All toggle | 147-151 | Shown only for `isTrackOwner()` | **KEEP as-is** — view convenience; not expanded (no UI redesign) |

---

## 7. What Stays vs What Is Removed

### Stays (preserved exactly)
- Login + session security + production SESSION_SECRET guard
- First-admin bootstrap (R3), DB_PATH (R2), Railway runbook (R4) — all untouched
- Role labels (`admin`, `track_owner`, `viewer`) — still used for tab visibility, toggle visibility, user management
- `canDeleteRow` admin-only (backend + frontend)
- `canImport` / `canManageUsers` admin-only
- My Track vs All toggle + filter + dashboard scoping (view convenience)
- Track-value canonical validation in `validate()` (data integrity, not access control)
- Required-field enforcement (backend + client)

### Removed (the access-control boundaries)
- `canCreateRow` track/role restriction → any authenticated user
- `canEditRow` track/role restriction → any authenticated user
- Frontend `canCreateInCurrentWorkspace` workspace/scope restriction → any authenticated user
- Frontend `canEditRow(row)` track restriction → any authenticated user
- Form track dropdown scope restriction → all tracks available to everyone

---

## 8. My Track vs All Preservation Plan

The toggle (app.js:147-151) and `visibleRowsForWorkspace`/`dashboardRows` are NOT touched.
After the change, "My Track" continues to filter the visible row set for a track_owner who
toggles to it — but it no longer gates editing. A track_owner can switch to "All Tracks",
see every row, and edit/create any of them. The toggle remains a pure view/filter. Its
visibility (track_owner only) is intentionally left as-is to avoid UI redesign.

---

## 9. Mutation Plan

| File | Change | Surface |
|------|--------|---------|
| `app/server.js` | `canCreateRow` + `canEditRow` → return true (any authenticated user); document client requirement; signatures kept so call sites unchanged | Backend |
| `app/public/app.js` | `canCreateInCurrentWorkspace` + `canEditRow(row)` → return true; form track dropdown (821-822) → all tracks for everyone | Frontend |
| `app/README.md` | Update Roles table, "My Track Workspace", and "Frontend control visibility" sections to reflect open create/edit; My Track = view-only; delete still admin-only | Docs (keep accurate) |

**No change to:** `app/db.js` (role/track_scope is seed/storage only — no edit-permission
logic), `app/public/index.html`, `app/public/style.css` (no role-based markup/styles),
`app/package.json`, `app/.nvmrc`, `app/.env.example`, `docs/railway-service-config.md`.

**Roles NOT deleted:** they are still used for non-edit purposes (tab/toggle visibility,
user management), so they are not "only used for access control" — keeping them is correct.

---

## 10. Verification Plan

1. `node --check` app/server.js, app/db.js, app/public/app.js
2. `cd app && npm run` → start = `node server.js`
3. Dev boot smoke (NODE_ENV unset) → running line; `app/data.db` untouched
4. Production boot smoke on temp DB (SESSION_SECRET valid) → boots; auth intact
5. **Unauthenticated mutation still rejected:** `POST /api/rows` with no cookie → 401
6. **Authenticated create/edit across tracks:** temp DB + seeded users of each role; assert `canCreateRow`/`canEditRow` now return true for track_owner and viewer for any track (predicate check + HTTP create/edit as a non-admin user against a disposable DB)
7. My Track / All toggle still renders for track_owner; filter still works
8. `bash scripts/invariant-check.sh` → 5/5 PASS
9. `git status` → only allowed surfaces

All HTTP behavior tests use a disposable temp DB (`DB_PATH=$(mktemp -d)/data.db`). Live
`app/data.db` is never mutated.

---

## 11. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Opening edit lets any user change any row's track/owner | Expected | This is the client requirement; track-value validity still enforced |
| Dead 403 guards remain (functions return true) | Low | Guards are harmless defensive structure; comment documents the permissive intent |
| Viewer role now equivalent to editor for rows | Expected | Client: "Everyone who can log in should be able to create and edit." Roles retained for tab/user-mgmt gating |
| README drift if not updated | Low | README updated in the mutation plan |
| Delete accidentally opened | None | `canDeleteRow` deliberately untouched (backend + frontend) |

---

## 12. Next Recommended Node

Railway redeploy smoke (R5) — deploy the updated app and re-run the critical-path smoke
from `docs/railway-service-config.md`, now confirming any authenticated user can create/edit.
