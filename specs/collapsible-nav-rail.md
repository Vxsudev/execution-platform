# Spec: Collapsible Nav Rail

## Status
approved

## Phase
phase-build

## Feature Slug
collapsible-nav-rail

## Depends On
Recon: ai/recon/collapsible-nav-rail-recon.md. Builds on top of the left-nav-rail-layout
changes (same branch: feat/left-nav-rail-layout). No backend, DB, auth, or import changes.

---

## Summary

The left nav rail (210px) permanently consumes horizontal space. Add a collapse/expand toggle
that narrows the rail to 52px and shows text abbreviations instead of full labels. State persists
via `localStorage` (`astraX.navCollapsed`). The main-pane flex layout reclaims the recovered
width automatically — no explicit width calculation needed.

No icon library is added. Abbreviated labels (Ro/Da/Us/Im) plus the toggle characters `«`/`»`
provide compact navigation without any new dependencies.

---

## Data Model Changes

none

---

## API Surface

none

---

## Frontend Surface

Two files change: `app/public/app.js` and `app/public/style.css`. No other files.

### State addition

Add `navCollapsed` to the `state` initializer (line 3-8 of app.js):

```js
navCollapsed: localStorage.getItem('astraX.navCollapsed') === 'true',
```

This reads the persisted preference on every `init()` call. No server round-trip.

### renderApp() changes

1. **Read collapsed state at top of function:**
   ```js
   const navCollapsed = state.navCollapsed;
   ```

2. **Add `collapsed` class to `.nav-rail` when collapsed:**
   ```html
   <nav class="nav-rail${navCollapsed ? ' collapsed' : ''}">
   ```

3. **Nav-logo: add toggle button, wrap brand in span:**
   ```html
   <div class="nav-logo">
     <span class="nav-brand">astraX</span>
     <button class="nav-toggle" id="navToggle"
       title="${navCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}">${navCollapsed ? '»' : '«'}</button>
   </div>
   ```

4. **Each nav-item: add label and abbr spans (no ID or onclick changes):**
   ```html
   <button class="nav-item${isRowsPage ? ' active' : ''}" id="navRows">
     <span class="nav-item-label">Rows</span>
     <span class="nav-item-abbr" aria-hidden="true">Ro</span>
   </button>
   ```
   Abbreviations: Rows → Ro, Dashboard → Da, Users → Us, Import → Im

5. **Nav-foot: show both full and short user, add abbr to logout:**
   ```html
   <div class="nav-foot">
     <div class="nav-user">
       <span class="nav-user-full">Signed in as <strong>${esc(state.user.username)}</strong></span>
       <span class="nav-user-short" title="Signed in as ${esc(state.user.username)}">${esc(state.user.username[0].toUpperCase())}</span>
     </div>
     <button class="btn ghost" id="logoutBtn">
       <span class="nav-item-label">Log out</span>
       <span class="nav-item-abbr" aria-hidden="true">→</span>
     </button>
   </div>
   ```

6. **Toggle binding (add after `$app.innerHTML`, before logoutBtn binding):**
   ```js
   document.getElementById('navToggle').onclick = () => {
     state.navCollapsed = !state.navCollapsed;
     localStorage.setItem('astraX.navCollapsed', state.navCollapsed);
     renderApp();
   };
   ```

### CSS additions (append to `style.css` — do NOT remove or modify existing rules)

```css
/* --- collapsible nav rail --- */
.nav-logo{display:flex;align-items:center;gap:8px}
.nav-brand{flex:1;white-space:nowrap;overflow:hidden}
.nav-toggle{flex-shrink:0;background:transparent;border:0;color:var(--muted);cursor:pointer;padding:2px 6px;font-size:13px;line-height:1;border-radius:4px}
.nav-toggle:hover{color:var(--text);background:var(--panel2)}
.nav-item-label,.nav-user-full{display:inline}
.nav-item-abbr,.nav-user-short{display:none}
.nav-rail{transition:width .15s ease,flex-basis .15s ease}
.nav-rail.collapsed{width:52px;flex:0 0 52px}
.nav-rail.collapsed .nav-brand{display:none}
.nav-rail.collapsed .nav-logo{justify-content:center;padding:16px 0 14px}
.nav-rail.collapsed .nav-item{text-align:center;padding:8px 4px}
.nav-rail.collapsed .nav-item-label{display:none}
.nav-rail.collapsed .nav-item-abbr{display:inline}
.nav-rail.collapsed .nav-foot{align-items:center;padding:12px 4px}
.nav-rail.collapsed .nav-user{text-align:center}
.nav-rail.collapsed .nav-user-full{display:none}
.nav-rail.collapsed .nav-user-short{display:inline}
.nav-rail.collapsed #logoutBtn{text-align:center;padding:7px 4px;width:100%}
```

The double `.nav-logo` rule (one in the left-nav-rail-layout block, one here) merges via CSS
cascade — the second rule adds `display:flex;align-items:center;gap:8px` without removing the
existing `padding/font/color` properties.

### Role visibility — unchanged

Admin: all four nav items (Rows, Dashboard, Users, Import) visible in both states.
Track owner: Rows + Dashboard only, in both states.
Viewer: Rows + Dashboard only, in both states.
The `${isAdmin() ? ...}` conditionals are inside the same nav-items block; only the span
wrapping changes, not the conditional logic.

### Main pane — unchanged

`.main-pane{flex:1}` already reclaims available width. When the rail narrows from 210px to 52px,
the main pane automatically expands by 158px. No explicit width change to `.main-pane` needed.
Table scroll behavior unchanged; `.table-scroll{overflow:auto}` still handles wide tables.

---

## Non-Scope

- No change to page content templates (Rows, Dashboard, Users, Import pages inside .main-pane)
- No change to `filteredRows()`, `refreshTable()`, `renderTable()`, `bindRowActions()`
- No change to `renderDashboard()`, `renderUsersTable()`, `renderImportPanel()`
- No change to `openForm()` (cell-highlight), `openDetails()`, `openUserForm()`
- No change to role check functions, `state.workspace`, workspace toggle logic
- No change to `renderLogin()`
- No change to `app/db.js`, `app/server.js`, `app/package.json`, Railway config, import parser
- No new dependencies, no build tooling, no icon libraries

---

## Verification Plan

See recon §8. Key: `node --check`; invariant 5/5; browser smoke: collapse/expand toggle,
localStorage persistence across refresh, all nav items work in both states, workspace toggle
works, + New row works, row edit + cell highlight works, logout works from collapsed state.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/public/app.js` | (1) Add `navCollapsed` to `state`; (2) modify `renderApp()` — nav-rail class, nav-logo toggle, nav-item spans, nav-foot spans, toggle binding |
| `app/public/style.css` | Append ~18 collapsible-rail CSS rules |
| OS artifacts | `ai/recon/`, `specs/`, `tasks/`, `ai/state_registry.json`, `ai/engineering-journal.md` |

---

## Relationship to Next Node

Production smoke after deploy: verify localStorage persists across reload in production.
