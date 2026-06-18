# Spec: Left Navigation Rail Layout

## Status
approved

## Phase
phase-build

## Feature Slug
left-nav-rail-layout

## Depends On
Recon: ai/recon/left-nav-rail-layout-recon.md. Frontend-only refactor targeting current main
(83851b0). No backend, database, auth, import, or role-permission changes.

---

## Summary

Move the app's primary navigation from the current overloaded top bar into a left-side navigation
rail. The top bar currently contains primary nav, role-gated actions, page-mode toggles, row
creation, signed-in state, and logout — all competing in one horizontal strip. The left rail
separates concerns: navigation lives in the rail, page controls (count, workspace toggle, +New row,
filters) live in each page's own header area. All semantics, role visibility, and behavior are
preserved exactly.

---

## Background

The app is a pure vanilla JS SPA (no framework, no build). `renderApp()` in `app/public/app.js`
renders everything into `<div id="app">`. The CSS is in `app/public/style.css`. Both files are
the only surfaces being changed. `index.html` stays untouched (it is just `<div id="app">`).

---

## Data Model Changes

none

---

## API Surface

none

---

## Frontend Surface

Two files change: `app/public/app.js` (the `renderApp()` function only) and
`app/public/style.css` (new rail/shell rules appended, no existing rules removed).

### Shell restructure

Replace the flat `.topbar + page-content` layout with an app shell:

```
.app-shell  { display:flex; height:100vh; overflow:hidden }
├── .nav-rail   210px fixed column, var(--panel) bg, border-right
│   ├── .nav-logo    "astraX" title
│   ├── .nav-items   vertical stack of nav buttons
│   │   ├── Rows        (always visible, id="navRows")
│   │   ├── Dashboard   (always visible, id="navDash")
│   │   ├── Users       (admin only,     id="navUsers")
│   │   └── Import      (admin only,     id="navImport")
│   └── .nav-foot
│       ├── .nav-user  "Signed in as <username>"
│       └── Log out button (id="logoutBtn")
└── .main-pane   flex:1, overflow:auto
    └── [per-page content described below]
```

### Rows page (inside .main-pane)

```
.page-header
  h2.page-title "Rows"
  span.page-count id="rowCount"   (filled by refreshTable)
  .spacer
  button#newBtn "+ New row"       (all authenticated users — canCreateInCurrentWorkspace() is always true)

.page-ws                          (track_owner only; same condition as before)
  button#wsAll "All Tracks"
  button#wsMy  "My Track"

.controls  (unchanged — search, fStatus, fTrack, fType)

.wrap > .table-scroll#tableScroll  (unchanged)
```

### Dashboard page (inside .main-pane)

```
.page-header
  h2.page-title "Dashboard"
  span.page-count id="rowCount"   (set to "N rows" by existing code)

.page-ws                          (track_owner only — same behavior as current topbar; state.workspace
                                   still controls dashboardRows() — NO semantic change)
  button#wsAll "All Tracks"
  button#wsMy  "My Track"

.wrap > renderDashboard()         (unchanged)
```

### Users page (inside .main-pane)

```
.page-header
  h2.page-title "Users"
  span.page-count id="rowCount"   (set to "N users" by existing code)
  .spacer
  button#newUserBtn "+ New user"

.wrap > .table-scroll > renderUsersTable()  (unchanged)
```

### Import page (inside .main-pane)

```
span#rowCount style="display:none"   (set to '' by existing code; must exist in DOM)
.wrap > renderImportPanel()          (renderImportPanel() has its own internal h2, keep it)
```

### Role visibility contract (unchanged from current)

| Nav item | Admin | Track Owner | Viewer |
|----------|-------|-------------|--------|
| Rows     | ✓     | ✓           | ✓      |
| Dashboard| ✓     | ✓           | ✓      |
| Users    | ✓     | ✗           | ✗      |
| Import   | ✓     | ✗           | ✗      |

All Tracks / My Track workspace toggle: track_owner only, appears on both Rows page AND Dashboard
page (same condition as current topbar: `isTrackOwner() && (isRowsPage || isDashPage)`).

+ New row: all authenticated users (canCreateInCurrentWorkspace() returns true for everyone).

### CSS additions (append to `style.css`, do NOT remove existing rules)

```css
/* Left-nav rail shell */
.app-shell{display:flex;height:100vh;overflow:hidden}
.nav-rail{width:210px;flex:0 0 210px;background:var(--panel);border-right:1px solid var(--line);display:flex;flex-direction:column;overflow:hidden}
.nav-logo{padding:16px 16px 14px;font-size:15px;font-weight:700;color:var(--text);border-bottom:1px solid var(--line)}
.nav-items{flex:1;padding:8px;display:flex;flex-direction:column;gap:2px;overflow-y:auto}
.nav-item{display:block;width:100%;padding:8px 12px;border-radius:8px;border:0;background:transparent;color:var(--muted);font-size:13.5px;text-align:left;cursor:pointer;line-height:1.4}
.nav-item:hover{background:var(--panel2);color:var(--text)}
.nav-item.active{background:var(--panel2);color:var(--text);font-weight:600}
.nav-foot{padding:12px 16px;border-top:1px solid var(--line);display:flex;flex-direction:column;gap:8px}
.nav-user{font-size:12px;color:var(--muted);line-height:1.5}
.main-pane{flex:1;overflow:auto;min-width:0;display:flex;flex-direction:column}
.page-header{display:flex;align-items:center;gap:12px;padding:10px 16px;border-bottom:1px solid var(--line);flex:0 0 auto}
.page-title{margin:0;font-size:15px;font-weight:600;flex:none}
.page-count{color:var(--muted);font-size:13px;flex:none}
.page-ws{padding:8px 16px;display:flex;gap:6px;border-bottom:1px solid var(--line);flex:0 0 auto}
```

### Event binding changes (in `renderApp()`, post-innerHTML section)

The only changes are the renamed element IDs for nav buttons:
- `rowsPageBtn` → `navRows`
- `dashPageBtn` → `navDash`
- `usersPageBtn` → `navUsers`
- `importPageBtn` → `navImport`

All other bindings (`logoutBtn`, `wsAll`, `wsMy`, `newBtn`, `newUserBtn`, `rowCount`, `searchInput`,
`fStatus`, `fTrack`, `fType`, `tableScroll`) keep their existing IDs and logic unchanged.

---

## Responsive Behavior

Desktop layout is primary (current app is desktop-only). `.app-shell { height:100vh }` + fixed
rail works on desktop. No mobile redesign. No new breakpoints. If the viewport is narrow, the
table already has horizontal scroll; the rail remains.

---

## Non-Scope

- No change to `app/db.js`, `app/server.js`, `app/public/index.html`
- No change to `renderDashboard()`, `renderUsersTable()`, `renderImportPanel()`, `renderTable()`
- No change to `bindRowActions()`, `bindImportActions()`, `bindUserActions()`
- No change to `openForm()` (clicked-cell field highlight preserved), `openDetails()`, `openUserForm()`
- No change to `filteredRows()`, `refreshTable()`, `dashboardRows()`, `visibleRowsForWorkspace()`
- No change to role check functions (`isAdmin()`, `isTrackOwner()`, `canDeleteRow()`, etc.)
- No change to `state.workspace` semantics
- No change to table columns, row layout, table data, filters, or import parser
- No new dependencies, no build tooling, no external icon packages
- No deploy

---

## Verification Plan

See recon §12. Key: `node --check app/public/app.js`; invariants 5/5; admin smoke confirms all
four nav items work with correct role visibility; track owner smoke confirms workspace toggle on
both Rows and Dashboard; all existing behaviors (row click/edit, cell highlight, modals, import,
delete, logout) confirmed intact.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/public/app.js` | Replace `renderApp()` function body with new app-shell/rail/pane structure |
| `app/public/style.css` | Append ~14 rail/shell CSS rules (no existing rules removed) |
| `ai/recon/...`, `specs/...`, `tasks/...`, `ai/state_registry.json`, `ai/engineering-journal.md` | OS artifacts |

---

## Relationship to Next Node

Next recommended node: production UI smoke (admin + track owner + viewer roles) after merge/deploy.
