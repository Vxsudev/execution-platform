# Spec: Phase 2 — Basic Dashboard (P2-5)

## Status
approved

## Phase
phase-build

## Feature Slug
phase-2-basic-dashboard

## Goal
Add a basic execution-health dashboard to the existing SPA, computed entirely in the
browser from `state.rows`. All authenticated users (admin, track_owner, viewer) can
view it. No backend route, no DB change, no package change, no chart library. The
dashboard preserves real imported data — it does NOT canonicalize track or status
labels and does NOT create any workflow state.

## Recon
ai/recon/phase-2-team-operating-model-full-spec-recon.md (§10 Dashboard Feasibility:
all widget data derivable from the `entries` rows already loaded; frontend-computed).

## Dependency
- P2-1 (role on `req.user` / `/api/me`), P2-2 (`state.page`, `state.workspace`, topbar tabs), P2-3 (Users tab), P2-4/P2-4A (Import tab + imported rows with shorthand track labels). All RELEASE_APPROVED and committed.

---

## Data Model Changes
No schema change. The dashboard is computed in the browser from `state.rows`, which is
already loaded via `GET /api/rows` at init and after mutations. The first task is a
preflight gate that verifies P2-5 requires NO database, backend route, or package
change — `app/server.js`, `app/db.js`, `app/package.json`, and `app/package-lock.json`
must remain untouched by this feature. This protects the directive's hard scope before
the frontend task runs.

---

## API Surface
none

---

## Frontend Surface

All changes in `app/public/app.js` + `app/public/style.css` (UX only).

- `state.page` extends to `'dashboard'` (alongside `rows`/`users`/`import`).
- Topbar: universal **Rows** / **Dashboard** view tabs (all roles). Track-owner
  **All Tracks / My Track** tabs render only within the Rows view. Admin **Users** /
  **Import** tabs unchanged. New-row button shows only in Rows view.
- `renderDashboard()` reads `state.rows`; the Dashboard tab reloads rows first for freshness.
- Helpers: `isClosed`/`isOpen` (closed = status ∈ {Complete, Inconclusive}), `byCount(rows,key)`
  (preserves actual stored values, blank→`—`, no canonicalization), `parseDateSafe(value)`
  (returns Date or null; never throws on blank/junk dates), `blockedRows`, `overdueRows`,
  `recentRows`, `openNextActions`, `dashStats`.

### Widgets (cards / count chips / small tables — no chart library)
1. **Execution health** — total, open, complete, blocked counts.
2. **Items by status** — grouped by actual `status`.
3. **Items by track** — grouped by actual `track` text (imported shorthand preserved).
4. **Owner load** — grouped by `owner`, top 10.
5. **Blocked items** — status = `Blocked`: title, owner, track, next_action.
6. **Overdue / target-risk** — `target_end_date` parses, is before today, status not Complete/Inconclusive: title, owner, track, target_end_date. Malformed dates skipped, never crash.
7. **Recently updated** — top 8 by `updated_at` desc: title, owner, track, updated_at.
8. **Open next actions** — `next_action` present and status not Complete/Inconclusive, limit 10: title, owner, track, next_action.

Every section renders even when empty (shows "None." / "No data.").

---

## Allowed Mutation Surfaces
- app/public/app.js
- app/public/style.css
- app/README.md
- specs/phase-2-basic-dashboard.md
- tasks/phase-2-basic-dashboard-001.md … 003.md
- ai/state_registry.json
- ai/engineering-journal.md

Do NOT modify: app/server.js, app/db.js, app/package.json, app/package-lock.json, app/public/index.html, prototypes/, sdlc/, vendor/, deployment files.

---

## Verification Plan
1. App boots; admin login; Dashboard tab visible; dashboard renders; can return to Rows; Users + Import tabs still work.
2. vasu login; Dashboard tab visible; All Tracks/My Track still works within Rows; no Users/Import tab.
3. Dashboard total count matches `state.rows.length`; status/track/owner groupings render; blocked/overdue/recent/next-action sections render even when empty.
4. Dashboard does not crash on blank/garbage dates; does NOT canonicalize imported track labels (e.g. `T1-Device` shown as-is).
5. Regression: row CRUD permissions, user-management routes, import routes all still work.
6. Invariants 5/5; no `[FILL:]` residue; only allowed surfaces modified (server.js/db.js/package*.json/index.html untouched).

## Verification Scripts
(none — no scripts/verification/ directory; verification via supervisor gates + the verification task + post-pipeline live checks.)

---

## Non-Scope
Backend routes · DB changes · package changes · chart library · separate HTML page ·
client routing · canonicalization of imported values · changing import / row CRUD /
user-management behavior · workflow/approval/escalation state · deployment · agents.
