# Task: Replace renderApp() with app-shell/rail/pane layout and append CSS

## Parent Spec
specs/left-nav-rail-layout.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description

Replace the `renderApp()` function in `app/public/app.js` (currently lines 126–219) with the
new app-shell layout. Append CSS for the left-rail shell to `app/public/style.css`. No other
functions change.

### Part A — `app/public/app.js`

Replace the ENTIRE `renderApp()` function body (everything from the opening brace to the closing
brace, inclusive of the function declaration line) with:

```js
function renderApp() {
  const isUsersPage = state.page === 'users';
  const isImportPage = state.page === 'import';
  const isDashPage = state.page === 'dashboard';
  const isRowsPage = state.page === 'rows';
  $app.innerHTML = `
    <div class="app-shell">
      <nav class="nav-rail">
        <div class="nav-logo">astraX</div>
        <div class="nav-items">
          <button class="nav-item${isRowsPage ? ' active' : ''}" id="navRows">Rows</button>
          <button class="nav-item${isDashPage ? ' active' : ''}" id="navDash">Dashboard</button>
          ${isAdmin() ? `<button class="nav-item${isUsersPage ? ' active' : ''}" id="navUsers">Users</button>` : ''}
          ${isAdmin() ? `<button class="nav-item${isImportPage ? ' active' : ''}" id="navImport">Import</button>` : ''}
        </div>
        <div class="nav-foot">
          <div class="nav-user">Signed in as <strong>${esc(state.user.username)}</strong></div>
          <button class="btn ghost" id="logoutBtn">Log out</button>
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

**Exact Edit target in app.js:** replace from `function renderApp() {` (line 126) through the
closing `}` of that function (line 219). Everything between `// ---------- app ----------` and
`function filteredRows()` is the target — do NOT touch `colLabel`, `optionTags`, or anything
after `refreshTable`.

**Nothing else changes in app.js.** All functions below renderApp() (`filteredRows`,
`refreshTable`, `renderTable`, `bindRowActions`, `renderDashboard`, `renderUsersTable`,
`bindUserActions`, `renderImportPanel`, `bindImportActions`, `openForm`, `openDetails`,
`openUserForm`, etc.) are UNTOUCHED.

### Part B — `app/public/style.css`

Append these rules at the very end of the file (after the last existing rule). Do NOT remove or
modify any existing rules:

```css
/* ---- left-nav rail shell ---- */
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
.spacer{flex:1}
```

---

## Acceptance Criteria
- [ ] `node --check app/public/app.js` exits 0 (no syntax errors)
- [ ] `app.js` no longer contains `rowsPageBtn`, `dashPageBtn`, `usersPageBtn`, `importPageBtn`
- [ ] `app.js` contains `navRows`, `navDash`, `navUsers`, `navImport` as button IDs
- [ ] `app.js` contains `.app-shell` and `.nav-rail` in the template literal
- [ ] `style.css` contains `.app-shell`, `.nav-rail`, `.nav-item`, `.main-pane`, `.page-header`
- [ ] No existing CSS rules removed from `style.css` (`.topbar`, `.ws-tab`, etc. still present)
- [ ] `colLabel`, `optionTags`, `filteredRows`, `refreshTable`, `bindRowActions` and all functions
      after `renderApp()` are byte-for-byte identical to the pre-change state
- [ ] `git diff --stat` shows only `app/public/app.js` and `app/public/style.css` changed

## Files Likely Affected
- `app/public/app.js` (renderApp function body only — lines 126–219)
- `app/public/style.css` (append only — no existing rules removed)

## Blocked By
- none
