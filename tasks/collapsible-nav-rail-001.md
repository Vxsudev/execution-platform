# Task: Add collapse/expand state, toggle button, and CSS to nav rail

## Parent Spec
specs/collapsible-nav-rail.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description

Three edits: (A) add `navCollapsed` to the `state` object in `app/public/app.js`, (B) replace
the `renderApp()` function body with the collapsible version, (C) append CSS to `style.css`.

---

### Part A — add `navCollapsed` to state (app.js lines 3-8)

**Old:**
```js
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null, imports: [], importFilename: null,
  allowDuplicates: false, expandedCells: new Set(), importPage: 0,
};
```

**New:**
```js
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null, imports: [], importFilename: null,
  allowDuplicates: false, expandedCells: new Set(), importPage: 0,
  navCollapsed: localStorage.getItem('astraX.navCollapsed') === 'true',
};
```

---

### Part B — replace renderApp() function body (app.js)

Replace the ENTIRE `renderApp()` function (from `function renderApp() {` through its closing `}`)
with the following. Every line matters — do not omit or paraphrase.

```js
function renderApp() {
  const isUsersPage = state.page === 'users';
  const isImportPage = state.page === 'import';
  const isDashPage = state.page === 'dashboard';
  const isRowsPage = state.page === 'rows';
  const navCollapsed = state.navCollapsed;
  $app.innerHTML = `
    <div class="app-shell">
      <nav class="nav-rail${navCollapsed ? ' collapsed' : ''}">
        <div class="nav-logo">
          <span class="nav-brand">astraX</span>
          <button class="nav-toggle" id="navToggle" title="${navCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}">${navCollapsed ? '»' : '«'}</button>
        </div>
        <div class="nav-items">
          <button class="nav-item${isRowsPage ? ' active' : ''}" id="navRows"><span class="nav-item-label">Rows</span><span class="nav-item-abbr" aria-hidden="true">Ro</span></button>
          <button class="nav-item${isDashPage ? ' active' : ''}" id="navDash"><span class="nav-item-label">Dashboard</span><span class="nav-item-abbr" aria-hidden="true">Da</span></button>
          ${isAdmin() ? `<button class="nav-item${isUsersPage ? ' active' : ''}" id="navUsers"><span class="nav-item-label">Users</span><span class="nav-item-abbr" aria-hidden="true">Us</span></button>` : ''}
          ${isAdmin() ? `<button class="nav-item${isImportPage ? ' active' : ''}" id="navImport"><span class="nav-item-label">Import</span><span class="nav-item-abbr" aria-hidden="true">Im</span></button>` : ''}
        </div>
        <div class="nav-foot">
          <div class="nav-user">
            <span class="nav-user-full">Signed in as <strong>${esc(state.user.username)}</strong></span>
            <span class="nav-user-short" title="Signed in as ${esc(state.user.username)}">${esc(state.user.username[0].toUpperCase())}</span>
          </div>
          <button class="btn ghost" id="logoutBtn"><span class="nav-item-label">Log out</span><span class="nav-item-abbr" aria-hidden="true">→</span></button>
        </div>
      </nav>
      <div class="main-pane">
        ${isUsersPage ? `
          <div class="page-header">
            <h2 class="page-title">Users</h2>
            <span class="page-count" id="rowCount"></span>
            <div class="spacer"></div>
            <button class="btn primary" id="newUserBtn">+ New user</button>
          </div>
          <div class="wrap">
            <div class="table-scroll">${renderUsersTable()}</div>
          </div>
        ` : isImportPage ? `
          <span id="rowCount" style="display:none"></span>
          <div class="wrap">${renderImportPanel()}</div>
        ` : isDashPage ? `
          <div class="page-header">
            <h2 class="page-title">Dashboard</h2>
            <span class="page-count" id="rowCount"></span>
          </div>
          ${isTrackOwner() ? `
            <div class="page-ws">
              <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
              <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
            </div>` : ''}
          <div class="wrap">${renderDashboard()}</div>
        ` : `
          <div class="page-header">
            <h2 class="page-title">Rows</h2>
            <span class="page-count" id="rowCount"></span>
            <div class="spacer"></div>
            ${canCreateInCurrentWorkspace() ? '<button class="btn primary" id="newBtn">+ New row</button>' : ''}
          </div>
          ${isTrackOwner() ? `
            <div class="page-ws">
              <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
              <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
            </div>` : ''}
          <div class="controls">
            <input id="searchInput" class="search" type="text" placeholder="Search…" value="${esc(state.search)}" />
            <select id="fStatus" title="Filter by status">${optionTags(state.statuses, state.filters.status)}</select>
            <select id="fTrack" title="Filter by track">${optionTags(state.tracks, state.filters.track)}</select>
            <select id="fType" title="Filter by type">${optionTags(state.types, state.filters.type, (t) => TYPE_LABEL[t] || t)}</select>
          </div>
          <div class="wrap">
            <div class="table-scroll" id="tableScroll"></div>
          </div>
        `}
      </div>
    </div>`;

  document.getElementById('navToggle').onclick = () => {
    state.navCollapsed = !state.navCollapsed;
    localStorage.setItem('astraX.navCollapsed', state.navCollapsed);
    renderApp();
  };
  const newBtnEl = document.getElementById('newBtn');
  if (newBtnEl) newBtnEl.onclick = () => openForm(null);
  document.getElementById('logoutBtn').onclick = async () => {
    await api('/logout', { method: 'POST' }); state.user = null; renderLogin();
  };
  document.getElementById('navRows').onclick = () => { state.page = 'rows'; renderApp(); };
  document.getElementById('navDash').onclick = async () => { state.page = 'dashboard'; await loadRows(); renderApp(); };
  if (isTrackOwner() && (isRowsPage || isDashPage)) {
    document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
    document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
  }
  if (isAdmin()) {
    document.getElementById('navUsers').onclick = async () => {
      if (state.page === 'users') { state.page = 'rows'; renderApp(); return; }
      state.page = 'users';
      await loadUsers();
      renderApp();
    };
    document.getElementById('navImport').onclick = () => {
      if (state.page === 'import') { state.page = 'rows'; renderApp(); return; }
      state.page = 'import';
      state.importPreview = null;
      state.importPage = 0;
      renderApp();
      loadImports().then(renderApp);
    };
  }

  if (isUsersPage) {
    document.getElementById('rowCount').textContent = `${state.users.length} users`;
    document.getElementById('newUserBtn').onclick = () => openUserForm(null);
    bindUserActions();
  } else if (isImportPage) {
    document.getElementById('rowCount').textContent = '';
    bindImportActions();
  } else if (isDashPage) {
    document.getElementById('rowCount').textContent = `${state.rows.length} rows`;
  } else {
    document.getElementById('searchInput').oninput = (e) => { state.search = e.target.value; refreshTable(); };
    document.getElementById('fStatus').onchange = (e) => { state.filters.status = e.target.value; refreshTable(); };
    document.getElementById('fTrack').onchange = (e) => { state.filters.track = e.target.value; refreshTable(); };
    document.getElementById('fType').onchange = (e) => { state.filters.type = e.target.value; refreshTable(); };
    refreshTable();
  }
}
```

**Exact edit target:** replace from `function renderApp() {` through its closing `}`. Everything
after (`filteredRows`, `refreshTable`, `renderTable`, `bindRowActions`, etc.) is UNTOUCHED.

---

### Part C — append CSS to app/public/style.css

Append at the very end of the file (after the last line). Do NOT remove or modify anything:

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

---

## Acceptance Criteria
- [ ] `node --check app/public/app.js` exits 0
- [ ] `state` object contains `navCollapsed: localStorage.getItem('astraX.navCollapsed') === 'true'`
- [ ] `renderApp()` reads `const navCollapsed = state.navCollapsed;`
- [ ] Template contains `nav-rail${navCollapsed ? ' collapsed' : ''}` and `id="navToggle"`
- [ ] Each nav-item has `.nav-item-label` + `.nav-item-abbr` spans (Ro/Da/Us/Im abbreviations)
- [ ] `navToggle` onclick sets `state.navCollapsed`, writes `localStorage`, calls `renderApp()`
- [ ] style.css ends with the collapsible-nav-rail block; existing rules unchanged
- [ ] `git diff --stat` shows only `app/public/app.js`, `app/public/style.css`, OS artifacts

## Files Likely Affected
- `app/public/app.js`
- `app/public/style.css`

## Blocked By
- none
