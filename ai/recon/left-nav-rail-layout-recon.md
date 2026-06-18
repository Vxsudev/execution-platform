# Left Navigation Rail Layout: Recon

**Feature Slug:** left-nav-rail-layout  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** 83851b0

---

## 1. Recon Objective

Read-only recon for the left-nav-rail-layout frontend refactor. Inspect actual frontend code to
understand current top-nav structure, role visibility, CSS, and produce the exact change list
needed to move primary navigation from the top bar to a left rail without changing any backend,
data, auth, role, or semantic behavior.

---

## 2. Files Inspected

| File | Lines | Finding |
|------|-------|---------|
| `app/public/index.html` | 13 | Minimal shell. `<body><div id="app"></div><script src="/app.js"></script></body>`. Everything is JS-rendered. |
| `app/public/app.js` | 908 | Pure vanilla JS SPA. `renderApp()` owns all layout rendering. |
| `app/public/style.css` | 168 | CSS variables + component styles. `.topbar` is current nav. No left-rail styles exist. |

---

## 3. Current Render Structure (`renderApp()` — lines 126–218)

`renderApp()` writes the full page into `$app.innerHTML`. Current structure:

```
$app
└── .topbar  (full-width flex strip, border-bottom, var(--panel) background)
    ├── h1 "astraX — Team Experiment Summary"
    ├── .ws-tabs → [Rows] [Dashboard]                  (always)
    ├── .ws-tabs → [All Tracks] [My Track]              (track_owner only, on rows+dashboard pages)
    ├── <button> Users                                  (admin only)
    ├── <button> Import                                 (admin only)
    ├── <span id="rowCount">                            (row count / user count / empty)
    ├── .spacer (flex:1)
    ├── <span class="who"> "Signed in as <user>"
    ├── <button id="newBtn"> + New row                  (rows page + canCreateInCurrentWorkspace())
    └── <button id="logoutBtn"> Log out

then page content:
├── (users page)  .wrap > .users-header + .table-scroll
├── (import page) .wrap > renderImportPanel()
├── (dashboard)   .wrap > renderDashboard()
└── (rows page)   .controls > search+filters, .wrap > .table-scroll#tableScroll
```

---

## 4. Current Role Visibility Logic

All role checks happen in `renderApp()` and helpers in `app.js`:

| Function | Returns |
|----------|---------|
| `isAdmin()` | `state.user.role === 'admin'` |
| `isTrackOwner()` | `state.user.role === 'track_owner'` |
| `isViewer()` | `!isAdmin() && !isTrackOwner()` |
| `canCreateInCurrentWorkspace()` | always `true` (open to all authenticated users) |
| `canDeleteRow()` | `isAdmin()` only |

Current visibility by role:

| Element | Admin | Track Owner | Viewer |
|---------|-------|-------------|--------|
| Rows | ✓ | ✓ | ✓ |
| Dashboard | ✓ | ✓ | ✓ |
| Users | ✓ | ✗ | ✗ |
| Import | ✓ | ✗ | ✗ |
| All Tracks / My Track | ✗ | ✓ (rows+dash pages) | ✗ |
| + New row | ✓ | ✓ | ✓ |
| Delete | ✓ | ✗ | ✗ |

---

## 5. How the App Knows Current User Role

`state.user` is populated from `await api('/me')` at init. `state.user.role` is checked by
`isAdmin()`, `isTrackOwner()`, `isViewer()`. No separate auth call on each render — state is
in-memory. Role visibility is a client-side render decision based on `state.user.role`.

---

## 6. Element-by-Element Navigation Map

### Q1: Where is the current top navigation rendered?
`renderApp()` line ~131-150. The `.topbar` div contains all navigation.

### Q2: Where are role-based visibility decisions made?
In `renderApp()` template literals: `${isAdmin() ? '...' : ''}` and `${isTrackOwner() ? '...' : ''}`.

### Q3: How does the app know current user role?
`state.user.role` populated once at init via `/api/me`.

### Q4: Where are Rows, Dashboard, Users, Import buttons rendered?
All in `.topbar` in `renderApp()`, lines 135-144.
- IDs: `rowsPageBtn`, `dashPageBtn`, `usersPageBtn`, `importPageBtn`
- Event handlers: lines 180-200

### Q5: Where are All Tracks / My Track rendered?
Inside `.topbar` in a `.ws-tabs` group, lines 138-142.
- Condition: `isTrackOwner() && (isRowsPage || isDashPage)`
- IDs: `wsAll`, `wsMy`

### Q6: Where is + New row rendered?
Inside `.topbar`, line 148. Condition: `isRowsPage && canCreateInCurrentWorkspace()`.

### Q7: Where is signed-in/logout rendered?
Inside `.topbar`, lines 147-149.
- "Signed in as" text: `<span class="who">`
- Logout: `<button id="logoutBtn">`

### Q8: Which CSS classes control top nav layout?
- `.topbar { display:flex; align-items:center; gap:12px; padding:12px 16px; border-bottom:1px solid var(--line); background:var(--panel) }`
- `.topbar h1`, `.topbar .spacer`, `.topbar .who`
- `.ws-tabs { display:flex; gap:4px }`
- `.ws-tab`, `.ws-tab.active`

---

## 7. Proposed Layout Changes

### App Shell (new)
Replace the `.topbar` + flat page structure with:
```
.app-shell (display:flex; height:100vh; overflow:hidden)
├── .nav-rail (210px fixed, dark column, var(--panel) background)
│   ├── .nav-logo "astraX"
│   ├── .nav-items  (flex:1, scrollable)
│   │   ├── <button class="nav-item" id="navRows">Rows</button>
│   │   ├── <button class="nav-item" id="navDash">Dashboard</button>
│   │   ├── <button class="nav-item" id="navUsers">Users</button>   (admin only)
│   │   └── <button class="nav-item" id="navImport">Import</button> (admin only)
│   └── .nav-foot
│       ├── .nav-user "Signed in as <user>"
│       └── <button id="logoutBtn">Log out</button>
└── .main-pane (flex:1, overflow:auto)
    └── [page-specific content]
```

### Rows Page (inside .main-pane)
```
.page-header
  h2.page-title "Rows" | span#rowCount | .spacer | button#newBtn "+ New row"
.page-ws  (track_owner only)
  [All Tracks] [My Track]
.controls
  search | status-filter | track-filter | type-filter
.wrap
  .table-scroll#tableScroll
```

### Dashboard Page (inside .main-pane)
```
.page-header
  h2.page-title "Dashboard" | span#rowCount
.page-ws  (track_owner only, same state.workspace semantics)
  [All Tracks] [My Track]
.wrap
  renderDashboard()
```

### Users Page (inside .main-pane)
```
.page-header
  h2.page-title "Users" | span#rowCount | .spacer | button#newUserBtn "+ New user"
.wrap
  .table-scroll > renderUsersTable()
```

### Import Page (inside .main-pane)
```
span#rowCount (display:none — set to '' by existing code)
.wrap
  renderImportPanel()  (has its own internal h2)
```

---

## 8. Exact Elements To Move

| Element | From | To |
|---------|------|----|
| App title "astraX" | `.topbar h1` | `.nav-logo` in `.nav-rail` |
| Rows nav button | `.topbar` (`id="rowsPageBtn"`) | `.nav-items` (`id="navRows"`) |
| Dashboard nav button | `.topbar` (`id="dashPageBtn"`) | `.nav-items` (`id="navDash"`) |
| Users nav button | `.topbar` (`id="usersPageBtn"`) | `.nav-items` (`id="navUsers"`) |
| Import nav button | `.topbar` (`id="importPageBtn"`) | `.nav-items` (`id="navImport"`) |
| "Signed in as" | `.topbar .who` | `.nav-foot .nav-user` |
| Log out button | `.topbar` | `.nav-foot` |
| All Tracks / My Track | `.topbar .ws-tabs` | `.page-ws` inside rows+dashboard pages |
| + New row button | `.topbar` | `.page-header` inside rows page |
| Row count | `.topbar #rowCount` | `.page-header #rowCount` inside each page |

---

## 9. Exact Elements NOT To Change

- `renderDashboard()` — function body unchanged
- `renderUsersTable()` — function body unchanged
- `bindUserActions()` — unchanged
- `renderImportPanel()` — function body unchanged (has its own `<h2>`) 
- `bindImportActions()` — unchanged
- `renderTable()` — unchanged
- `bindRowActions()` — unchanged (row click, cell highlight, Details, Delete, More/Less all intact)
- `openForm()` — unchanged (clicked-cell field highlight logic intact)
- `openDetails()` — unchanged
- `openUserForm()` — unchanged
- `filteredRows()`, `refreshTable()` — unchanged
- `state.workspace` semantics — unchanged (`visibleRowsForWorkspace`, `dashboardRows`)
- All API calls — unchanged
- All role check functions — unchanged
- Login page (`renderLogin()`) — unchanged
- All modals (`modal-back`, `modal`) — unchanged, still append to `document.body`
- `app/server.js`, `app/db.js` — NOT touched
- `.table-scroll` horizontal scroll behavior — preserved
- `.field-highlight` clicked-cell animation — untouched

---

## 10. Mutation Plan

### `app/public/app.js`

Replace the single `renderApp()` function body (lines 126–218, from the opening
`$app.innerHTML = \`` to the end of the function) with the new structure described in §7.

Key changes:
1. `$app.innerHTML` becomes `.app-shell > (.nav-rail + .main-pane)` instead of `.topbar + content`
2. Nav button IDs change: `rowsPageBtn→navRows`, `dashPageBtn→navDash`, `usersPageBtn→navUsers`, `importPageBtn→navImport`
3. All Tracks / My Track move into page-specific sections (rows page, dashboard page)
4. `+ New row` moves into rows page-header
5. `#rowCount` moves into page-header of each page (hidden span for import)
6. All OTHER code in renderApp() (rowCount textContent, searchInput, filter bindings, refreshTable) — unchanged logic, just referencing elements in their new locations

### `app/public/style.css`

Append ~18 new rules for the rail shell. DO NOT remove existing rules (`.topbar` becomes
dead code after the refactor but removing it has no effect on behavior).

---

## 11. Risk List

| Risk | Severity | Mitigation |
|------|----------|------------|
| `id="rowCount"` missing for import page | Low | Add `<span id="rowCount" style="display:none">` — sets to '' as before |
| `.table-scroll max-height` with new chrome | Low | Keep at `calc(100vh - 170px)` — same overhead as before; main-pane overflow:auto handles edge cases |
| Track owner workspace toggle on Dashboard | Low | Explicitly add `.page-ws` section to Dashboard page (Option A, operator-approved) |
| nav-item toggle behavior (click active Users → go back to Rows) | Low | Preserve existing toggle logic in event handlers |
| Wide table horizontal scroll lost | None | `.table-scroll { overflow:auto }` unchanged |
| Modal z-index | None | Modals append to `document.body`, z-index:1000, unaffected |
| Login page | None | `renderLogin()` sets `$app.innerHTML` directly, no dependency on `.app-shell` |

---

## 12. Verification Plan

1. `node --check app/public/app.js` (syntax).
2. `bash scripts/invariant-check.sh` → 5/5.
3. Start app: `cd app && npm start`.
4. **Admin smoke** (login as admin/admin123):
   - Left rail shows: Rows ✓ Dashboard ✓ Users ✓ Import ✓
   - Active state highlights on each nav click
   - Rows page: page-header shows "Rows" + count + "+ New row", filters work, table intact
   - Dashboard: shows data, row count in header
   - Users: shows user list, "+ New user" in header
   - Import: shows import panel, file upload works
5. **Track owner smoke** (login as vasu/vasu123):
   - Left rail shows: Rows ✓ Dashboard ✓ (no Users, no Import)
   - All Tracks / My Track appears on Rows page header
   - All Tracks / My Track appears on Dashboard page header
   - My Track filters correctly
6. **Viewer smoke** (if viewer user exists):
   - Rail shows only Rows + Dashboard
   - No Users/Import in rail
7. **Behavior checks**:
   - Row click opens edit form ✓
   - Clicked-cell field highlight animation ✓
   - Details modal opens ✓
   - Delete (admin) works ✓
   - Import file select + commit ✓
   - Log out redirects to login ✓
8. `git status` → only `app/public/app.js`, `app/public/style.css`, OS artifacts.
