# Collapsible Nav Rail: Recon

**Feature Slug:** collapsible-nav-rail
**Date:** 2026-06-18
**Author:** AI Engineering OS (in-session worker)
**HEAD at recon:** feat/left-nav-rail-layout (uncommitted left-nav-rail-layout changes applied)

---

## 1. Recon Objective

Read-only recon to understand how the left nav rail is currently implemented (post
left-nav-rail-layout changes, before this PR is committed) and design the minimal change set
needed to add collapse/expand behavior with localStorage persistence.

---

## 2. Files Inspected

| File | Lines | Finding |
|------|-------|---------|
| `app/public/app.js` | ~920 | `state` object at line 3-8. `renderApp()` lines 126-243. Nav rail rendered in template literal; no collapse logic exists. |
| `app/public/style.css` | 186 | Left-nav rules at lines 170-185. `.nav-rail` is `flex:0 0 210px`, no `transition`, no `.collapsed` class. |

---

## 3. Current Nav Rail Structure

```
state = {
  ..., workspace: 'all', page: 'rows', navCollapsed: [MISSING],
}

renderApp() → $app.innerHTML = `
  <div class="app-shell">
    <nav class="nav-rail">                     ← always 210px
      <div class="nav-logo">astraX</div>       ← plain text, no toggle
      <div class="nav-items">
        <button id="navRows">Rows</button>
        <button id="navDash">Dashboard</button>
        [admin] <button id="navUsers">Users</button>
        [admin] <button id="navImport">Import</button>
      </div>
      <div class="nav-foot">
        <div class="nav-user">Signed in as <strong>...</strong></div>
        <button id="logoutBtn">Log out</button>
      </div>
    </nav>
    <div class="main-pane">...</div>
  </div>`
```

No collapse state, no toggle button, no localStorage interaction.

---

## 4. Proposed Changes

### 4.1 State addition (`app/public/app.js` line 3-8)

Add `navCollapsed` to the `state` object, initialized from localStorage:

```js
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null, imports: [], importFilename: null,
  allowDuplicates: false, expandedCells: new Set(), importPage: 0,
  navCollapsed: localStorage.getItem('astraX.navCollapsed') === 'true',
};
```

### 4.2 renderApp() changes (lines 126–243)

1. Read `const navCollapsed = state.navCollapsed;` at top.
2. Nav-rail: add class `collapsed` when navCollapsed:
   `class="nav-rail${navCollapsed ? ' collapsed' : ''}"`
3. Nav-logo: add `«`/`»` toggle button + show/hide spans:
   ```html
   <div class="nav-logo">
     <span class="nav-brand">astraX</span>
     <button class="nav-toggle" id="navToggle"
       title="${navCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}">
       ${navCollapsed ? '»' : '«'}
     </button>
   </div>
   ```
4. Each nav-item: wrap text in a `nav-item-label` span, add a `nav-item-abbr` span:
   ```html
   <button class="nav-item..." id="navRows">
     <span class="nav-item-label">Rows</span>
     <span class="nav-item-abbr" aria-hidden="true">Ro</span>
   </button>
   ```
   Abbreviations: Rows→Ro, Dashboard→Da, Users→Us, Import→Im
5. nav-foot: show both full and short versions:
   ```html
   <div class="nav-user">
     <span class="nav-user-full">Signed in as <strong>${esc(state.user.username)}</strong></span>
     <span class="nav-user-short" title="Signed in as ${esc(state.user.username)}">
       ${esc(state.user.username[0].toUpperCase())}
     </span>
   </div>
   <button class="btn ghost" id="logoutBtn">
     <span class="nav-item-label">Log out</span>
     <span class="nav-item-abbr" aria-hidden="true">→</span>
   </button>
   ```
6. Add toggle binding BEFORE the existing logoutBtn binding:
   ```js
   document.getElementById('navToggle').onclick = () => {
     state.navCollapsed = !state.navCollapsed;
     localStorage.setItem('astraX.navCollapsed', state.navCollapsed);
     renderApp();
   };
   ```

### 4.3 CSS additions (`app/public/style.css` — append only)

Existing `.nav-logo` is a block element. Need `display:flex` to position toggle at right.
Since it appears later in the cascade with same specificity, this safely adds properties:

```css
/* --- collapsible nav rail --- */
.nav-logo{display:flex;align-items:center;gap:8px}
.nav-brand{flex:1;white-space:nowrap;overflow:hidden}
.nav-toggle{flex-shrink:0;background:transparent;border:0;color:var(--muted);
  cursor:pointer;padding:2px 6px;font-size:13px;line-height:1;border-radius:4px}
.nav-toggle:hover{color:var(--text);background:var(--panel2)}
.nav-item-label,.nav-user-full{display:inline}
.nav-item-abbr,.nav-user-short{display:none}
.nav-rail{transition:width .15s ease,flex-basis .15s ease}

/* Collapsed */
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

---

## 5. Elements NOT Changing

- All page templates inside `.main-pane` (Users, Import, Dashboard, Rows) — unchanged
- `filteredRows()`, `refreshTable()`, `renderTable()`, `bindRowActions()` — unchanged
- `renderDashboard()`, `renderUsersTable()`, `bindUserActions()` — unchanged
- `renderImportPanel()`, `bindImportActions()` — unchanged
- `openForm()` (cell-highlight), `openDetails()`, `openUserForm()` — unchanged
- Role checks (`isAdmin()`, `isTrackOwner()`, etc.) — unchanged
- `state.workspace` and workspace toggle logic — unchanged
- `renderLogin()` — unchanged
- All API calls, modals — unchanged
- `app/db.js`, `app/server.js`, any backend files — NOT touched

---

## 6. Behavior Contract

| Action | Result |
|--------|--------|
| Click `«` when expanded | Rail collapses to 52px, items show abbreviations, localStorage set to 'true' |
| Click `»` when collapsed | Rail expands to 210px, items show full labels, localStorage set to 'false' |
| Page refresh | `state.navCollapsed` reads localStorage; rail renders in last-known state |
| Click nav item when collapsed | Page changes normally (same `onclick` handlers) |
| Hover nav item when collapsed | Only `.nav-item:hover` fires — no tooltip needed (abbr is 2 chars) |
| Admin sees | navUsers + navImport in both states |
| Track owner sees | No navUsers, no navImport in both states |
| `.main-pane` width | `flex:1` already — adapts automatically as rail shrinks; no change needed |

---

## 7. Risk List

| Risk | Severity | Mitigation |
|------|----------|------------|
| `username[0]` access when username is empty string | Low | `state.user.username` is always non-empty (login requires username); `[0].toUpperCase()` safe |
| CSS specificity conflict on `.nav-logo` (two rules same selector) | Low | Cascade merges them; later rule adds `display:flex` without removing padding/font/color |
| 52px too narrow for some OS scroll decorations | Low | 52px is wide enough for 2-char abbr at 13.5px; table scroll unaffected |
| localStorage not available (private browsing / restrictive policy) | Low | Wrap in try/catch is overkill for internal tool; default is `false` on read failure |
| Transition on `flex-basis` in Safari | Low | Graceful degradation; instant collapse still works |

---

## 8. Verification Plan

1. `node --check app/public/app.js` → exit 0
2. `bash scripts/invariant-check.sh` → 5/5
3. Grep: `navToggle` in app.js, `collapsed` class, `nav-item-abbr`, `astraX.navCollapsed`
4. Browser smoke:
   - Expanded rail → click `«` → rail narrows, abbreviations shown
   - Click `»` → rail expands, labels restored
   - Refresh while collapsed → stays collapsed (localStorage persisting)
   - Navigation: Rows/Dashboard/Users/Import all work from collapsed state
   - Workspace toggle (All Tracks / My Track) still works
   - + New row still works
   - Row click → edit form, cell highlight preserved
   - Logout from collapsed state works
5. git diff: only `app.js`, `style.css`, OS artifacts
