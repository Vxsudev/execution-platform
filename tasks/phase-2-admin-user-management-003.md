# Task: Implement admin users UI in app.js, style.css, and README

## Parent Spec
specs/phase-2-admin-user-management.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Add admin-only user management panel to the frontend. Three files to modify:
`app/public/app.js`, `app/public/style.css`, `app/README.md`.
Do NOT modify app/public/index.html or app/server.js.

Summary of changes from current P2-2 app.js:
- state: add `page: 'rows', users: []`
- new function: `loadUsers()`
- renderApp(): add Users button for admin, conditional users panel vs rows panel
- new function: `renderUsersTable()`
- new function: `bindUserActions()`
- new function: `openUserForm(user)`
- style.css: append 2 more rules
- README: add Admin User Management section

---

### File 1: Write `app/public/app.js`

Write the following content VERBATIM to `/Users/vasudevarao/execution-platform/app/public/app.js`:

```
// Frontend SPA: login, dense Excel-like table, search/filter, create/edit rows.
const $app = document.getElementById('app');
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [],
};

const TYPE_LABEL = { experiment: 'Experiment', work_item: 'Work Item', task: 'Task' };
const AUDIT_LABELS = { created_at: 'Created', updated_at: 'Updated', created_by: 'Created by', updated_by: 'Updated by' };

function userScope() {
  return Array.isArray(state.user && state.user.track_scope) ? state.user.track_scope : [];
}
function isAdmin()      { return !!(state.user && state.user.role === 'admin'); }
function isTrackOwner() { return !!(state.user && state.user.role === 'track_owner'); }
function isViewer()     { return !isAdmin() && !isTrackOwner(); }
function canCreateInCurrentWorkspace() {
  if (isAdmin()) return true;
  if (isTrackOwner()) return state.workspace === 'my' && userScope().length > 0;
  return false;
}
function canEditRow(row)  {
  if (isAdmin()) return true;
  if (isTrackOwner()) return userScope().includes(row.track);
  return false;
}
function canDeleteRow()   { return isAdmin(); }
function visibleRowsForWorkspace(rows) {
  if (state.workspace === 'my') return rows.filter(r => userScope().includes(r.track));
  return rows;
}

// Table columns: 13 Sheet-2 contract columns in workbook order, then a compact Type tag column.
const LIST_COLS = [
  'owner', 'track', 'title', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'target_end_date', 'dependencies', 'outcome',
  'next_action', 'status', 'type',
];
// Long-text cells that get truncated with an ellipsis + full-text tooltip.
const TRUNC_COLS = new Set(['hypothesis', 'design', 'success_criteria', 'outcome']);
// Columns the search box scans (case-insensitive substring).
const SEARCH_COLS = [
  'title', 'owner', 'track', 'function_area', 'parent_item', 'hypothesis',
  'design', 'success_criteria', 'dependencies', 'outcome', 'next_action',
];

async function api(path, opts = {}) {
  const res = await fetch('/api' + path, {
    method: opts.method || 'GET',
    headers: opts.body ? { 'Content-Type': 'application/json' } : {},
    body: opts.body ? JSON.stringify(opts.body) : undefined,
    credentials: 'same-origin',
  });
  let data = null;
  try { data = await res.json(); } catch (_) {}
  if (!res.ok) throw new Error((data && data.error) || ('Request failed: ' + res.status));
  return data;
}

const esc = (s) => (s == null ? '' : String(s).replace(/[&<>"]/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c])));

// ---------- init ----------
init();
async function init() {
  try {
    const me = await api('/me');
    state.user = me.user;
    const schema = await api('/schema');
    state.fields = schema.fields; state.types = schema.types; state.statuses = schema.statuses;
    state.tracks = schema.tracks || [];
    await loadRows();
    renderApp();
  } catch (_) {
    renderLogin();
  }
}

async function loadRows() {
  const data = await api('/rows');
  state.rows = data.rows;
}

async function loadUsers() {
  const data = await api('/users');
  state.users = data.users;
}

// ---------- login ----------
function renderLogin(errMsg) {
  $app.innerHTML = `
    <div class="login-wrap">
      <div class="login-card">
        <h1>astraX — Team Experiment Summary</h1>
        <p>Sign in to view and edit rows.</p>
        <label>Username</label>
        <input id="u" autocomplete="username" />
        <label>Password</label>
        <input id="p" type="password" autocomplete="current-password" />
        <button id="loginBtn">Sign in</button>
        <div class="error" id="loginErr">${errMsg ? esc(errMsg) : ''}</div>
        <div class="hint">Demo: admin / admin123</div>
      </div>
    </div>`;
  const submit = async () => {
    const username = document.getElementById('u').value;
    const password = document.getElementById('p').value;
    try {
      await api('/login', { method: 'POST', body: { username, password } });
      await init();
    } catch (e) { renderLogin(e.message); }
  };
  document.getElementById('loginBtn').onclick = submit;
  document.getElementById('p').addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
}

// ---------- app ----------
function colLabel(key) { return AUDIT_LABELS[key] || (state.fields.find((f) => f.key === key) || {}).label || key; }


function optionTags(values, current, labelFn) {
  return ['<option value="">All</option>'].concat(values.map((v) =>
    `<option value="${esc(v)}" ${current === v ? 'selected' : ''}>${esc(labelFn ? labelFn(v) : v)}</option>`
  )).join('');
}

function renderApp() {
  const isUsersPage = state.page === 'users';
  $app.innerHTML = `
    <div class="topbar">
      <h1>astraX — Team Experiment Summary</h1>
      ${isTrackOwner() ? `
        <div class="ws-tabs">
          <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
          <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
        </div>` : ''}
      ${isAdmin() ? `<button class="ws-tab${isUsersPage ? ' active' : ''}" id="usersPageBtn">Users</button>` : ''}
      <span class="who" id="rowCount"></span>
      <div class="spacer"></div>
      <span class="who">Signed in as <strong>${esc(state.user.username)}</strong></span>
      ${!isUsersPage && canCreateInCurrentWorkspace() ? '<button class="btn primary" id="newBtn">+ New row</button>' : ''}
      <button class="btn ghost" id="logoutBtn">Log out</button>
    </div>
    ${isUsersPage ? `
      <div class="wrap">
        <div class="users-header">
          <h2 class="users-title">Users</h2>
          <button class="btn primary" id="newUserBtn">+ New user</button>
        </div>
        <div class="table-scroll">${renderUsersTable()}</div>
      </div>
    ` : `
      <div class="controls">
        <input id="searchInput" class="search" type="text" placeholder="Search…" value="${esc(state.search)}" />
        <select id="fStatus" title="Filter by status">${optionTags(state.statuses, state.filters.status)}</select>
        <select id="fTrack" title="Filter by track">${optionTags(state.tracks, state.filters.track)}</select>
        <select id="fType" title="Filter by type">${optionTags(state.types, state.filters.type, (t) => TYPE_LABEL[t] || t)}</select>
      </div>
      <div class="wrap">
        <div class="table-scroll" id="tableScroll"></div>
      </div>
    `}`;

  const newBtnEl = document.getElementById('newBtn');
  if (newBtnEl) newBtnEl.onclick = () => openForm(null);
  document.getElementById('logoutBtn').onclick = async () => {
    await api('/logout', { method: 'POST' }); state.user = null; renderLogin();
  };
  if (isTrackOwner()) {
    document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
    document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
  }
  if (isAdmin()) {
    document.getElementById('usersPageBtn').onclick = async () => {
      if (state.page === 'users') { state.page = 'rows'; renderApp(); return; }
      state.page = 'users';
      await loadUsers();
      renderApp();
    };
  }

  if (isUsersPage) {
    document.getElementById('rowCount').textContent = `${state.users.length} users`;
    document.getElementById('newUserBtn').onclick = () => openUserForm(null);
    bindUserActions();
  } else {
    document.getElementById('searchInput').oninput = (e) => { state.search = e.target.value; refreshTable(); };
    document.getElementById('fStatus').onchange = (e) => { state.filters.status = e.target.value; refreshTable(); };
    document.getElementById('fTrack').onchange = (e) => { state.filters.track = e.target.value; refreshTable(); };
    document.getElementById('fType').onchange = (e) => { state.filters.type = e.target.value; refreshTable(); };
    refreshTable();
  }
}

function filteredRows() {
  const q = state.search.trim().toLowerCase();
  const { status, track, type } = state.filters;
  return visibleRowsForWorkspace(state.rows).filter((r) => {
    if (status && r.status !== status) return false;
    if (track && r.track !== track) return false;
    if (type && r.type !== type) return false;
    if (q) {
      const hay = SEARCH_COLS.map((k) => r[k] || '').join(' ').toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });
}

function refreshTable() {
  const rows = filteredRows();
  document.getElementById('rowCount').textContent = `${rows.length} of ${state.rows.length} rows`;
  document.getElementById('tableScroll').innerHTML = renderTable(rows);
  bindRowActions();
}

function renderTable(rows) {
  if (!state.rows.length) return `<div class="empty">No rows yet. Click <strong>+ New row</strong> to add one.</div>`;
  if (!rows.length) {
    if (state.workspace === 'my' && isTrackOwner()) {
      if (userScope().length === 0) {
        return `<div class="empty">No assigned track scope. Ask admin to assign tracks.</div>`;
      }
      return `<div class="empty">No rows in your assigned track scope yet.</div>`;
    }
    return `<div class="empty">No rows match the current search / filters.</div>`;
  }
  const head = LIST_COLS.map((k) => `<th>${esc(colLabel(k))}</th>`).join('') + '<th>Actions</th>';
  const body = rows.map((r) => {
    const cells = LIST_COLS.map((k) => {
      if (k === 'type') return `<td><span class="tag type-${esc(r.type)}">${esc(TYPE_LABEL[r.type] || r.type)}</span></td>`;
      if (k === 'status') return `<td><span class="status s-${esc((r.status || '').replace(/\s/g, '.'))}">${esc(r.status)}</span></td>`;
      if (TRUNC_COLS.has(k)) {
        const v = r[k] || '';
        return `<td class="trunc" title="${esc(v)}">${esc(v)}</td>`;
      }
      return `<td>${esc(r[k])}</td>`;
    }).join('');
    return `<tr>${cells}<td><div class="row-actions">
      <button class="icon-btn" data-info="${r.id}">Details</button>
      ${canEditRow(r) ? `<button class="icon-btn" data-edit="${r.id}">Edit</button>` : ''}
      ${canDeleteRow() ? `<button class="icon-btn danger" data-del="${r.id}">Delete</button>` : ''}
    </div></td></tr>`;
  }).join('');
  return `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function bindRowActions() {
  document.querySelectorAll('[data-info]').forEach((b) =>
    b.onclick = () => openDetails(state.rows.find((r) => r.id == b.dataset.info)));
  document.querySelectorAll('[data-edit]').forEach((b) =>
    b.onclick = () => openForm(state.rows.find((r) => r.id == b.dataset.edit)));
  document.querySelectorAll('[data-del]').forEach((b) =>
    b.onclick = async () => {
      if (!confirm('Delete this row?')) return;
      await api('/rows/' + b.dataset.del, { method: 'DELETE' });
      await loadRows(); renderApp();
    });
}

// ---------- users panel ----------
function renderUsersTable() {
  if (!state.users.length) return `<div class="empty">No users yet.</div>`;
  const head = ['Username', 'Role', 'Track Scope', 'Created', 'Actions']
    .map(h => `<th>${esc(h)}</th>`).join('');
  const body = state.users.map(u => {
    const isSelf = state.user && state.user.id === u.id;
    const scope = Array.isArray(u.track_scope) && u.track_scope.length ? u.track_scope.join(', ') : '—';
    return `<tr>
      <td>${esc(u.username)}</td>
      <td>${esc(u.role)}</td>
      <td class="trunc" title="${esc(scope)}">${esc(scope)}</td>
      <td>${esc((u.created_at || '').slice(0, 10))}</td>
      <td><div class="row-actions">
        <button class="icon-btn" data-user-edit="${u.id}">Edit</button>
        ${!isSelf ? `<button class="icon-btn danger" data-user-del="${u.id}">Delete</button>` : ''}
      </div></td>
    </tr>`;
  }).join('');
  return `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function bindUserActions() {
  document.querySelectorAll('[data-user-edit]').forEach(b =>
    b.onclick = () => openUserForm(state.users.find(u => u.id == b.dataset.userEdit)));
  document.querySelectorAll('[data-user-del]').forEach(b =>
    b.onclick = async () => {
      const u = state.users.find(u => u.id == b.dataset.userDel);
      if (!confirm(`Delete user "${u ? u.username : ''}"? This cannot be undone.`)) return;
      await api('/users/' + b.dataset.userDel, { method: 'DELETE' });
      await loadUsers(); renderApp();
    });
}

function openUserForm(user) {
  const isEdit = !!user;
  const val = (k) => (user && user[k] != null) ? user[k] : '';
  const currentRole = val('role') || 'viewer';
  const currentScope = Array.isArray(val('track_scope')) ? val('track_scope') : [];
  const back = document.createElement('div');
  back.className = 'modal-back';
  back.innerHTML = `
    <div class="modal">
      <h2>${isEdit ? 'Edit user' : 'New user'}</h2>
      <div class="form-grid">
        <div class="field full">
          <label>Username${!isEdit ? ' *' : ''}</label>
          <input id="uf-username" type="text" value="${esc(val('username'))}"${isEdit ? ' disabled' : ''} autocomplete="off" />
        </div>
        <div class="field full">
          <label>Password${isEdit ? ' (leave blank to keep current)' : ' *'}</label>
          <input id="uf-password" type="password" autocomplete="new-password" />
        </div>
        <div class="field full">
          <label>Role *</label>
          <select id="uf-role">
            ${['admin','track_owner','viewer'].map(r =>
              `<option value="${r}" ${currentRole === r ? 'selected' : ''}>${r}</option>`).join('')}
          </select>
        </div>
        <div class="field full" id="uf-scope-wrap"${currentRole !== 'track_owner' ? ' style="display:none"' : ''}>
          <label>Track Scope <small class="help">(required for track_owner — hold Ctrl/Cmd for multi-select)</small></label>
          <select id="uf-scope" multiple style="height:110px">
            ${state.tracks.map(t =>
              `<option value="${esc(t)}"${currentScope.includes(t) ? ' selected' : ''}>${esc(t)}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="error" id="ufErr"></div>
      <div class="modal-actions">
        <button class="btn ghost" id="uf-cancel">Cancel</button>
        <button class="btn primary" id="uf-save">${isEdit ? 'Save changes' : 'Create user'}</button>
      </div>
    </div>`;
  document.body.appendChild(back);
  back.addEventListener('mousedown', e => { if (e.target === back) back.remove(); });
  back.querySelector('#uf-cancel').onclick = () => back.remove();
  back.querySelector('#uf-role').onchange = (e) => {
    back.querySelector('#uf-scope-wrap').style.display = e.target.value === 'track_owner' ? '' : 'none';
  };
  back.querySelector('#uf-save').onclick = async () => {
    const role = back.querySelector('#uf-role').value;
    const password = back.querySelector('#uf-password').value;
    const scopeEl = back.querySelector('#uf-scope');
    const track_scope = role === 'track_owner'
      ? Array.from(scopeEl.selectedOptions).map(o => o.value)
      : [];
    const payload = { role, track_scope };
    if (!isEdit) payload.username = back.querySelector('#uf-username').value.trim();
    if (password) payload.password = password;
    try {
      if (isEdit) await api('/users/' + user.id, { method: 'PUT', body: payload });
      else await api('/users', { method: 'POST', body: payload });
      back.remove();
      await loadUsers(); renderApp();
    } catch (e) { back.querySelector('#ufErr').textContent = e.message; }
  };
}

// ---------- details modal ----------
function openDetails(row) {
  const fields = [
    ['Created by', row.created_by || '—'],
    ['Updated by', row.updated_by || '—'],
    ['Created',    row.created_at || '—'],
    ['Updated',    row.updated_at || '—'],
  ];
  const back = document.createElement('div');
  back.className = 'modal-back';
  back.innerHTML = `
    <div class="modal modal-sm">
      <h2>${esc(row.title || 'Row details')}</h2>
      <dl class="detail-list">
        ${fields.map(([l, v]) => `<dt>${esc(l)}</dt><dd>${esc(v)}</dd>`).join('')}
      </dl>
      <div class="modal-actions">
        <button class="btn ghost" id="closeDetailsBtn">Close</button>
      </div>
    </div>`;
  document.body.appendChild(back);
  back.addEventListener('mousedown', (e) => { if (e.target === back) back.remove(); });
  back.querySelector('#closeDetailsBtn').onclick = () => back.remove();
}

// ---------- create / edit form ----------
function openForm(row) {
  const isEdit = !!row;
  const val = (k) => {
    if (row && row[k] != null) return row[k];
    if (!isEdit && k === 'status') return 'Not Started'; // new-row default
    return '';
  };
  const fieldHtml = state.fields.map((f) => {
    const full = f.input === 'textarea' ? ' full' : '';
    let control;
    if (f.input === 'select') {
      const options = (f.key === 'track' && isTrackOwner()) ? userScope() : f.options;
      const currentVal = (f.key === 'track' && isTrackOwner() && !val(f.key) && options.length > 0)
        ? options[0]
        : val(f.key);
      const opts = options.map((o) =>
        `<option value="${esc(o)}" ${currentVal === o ? 'selected' : ''}>${esc(TYPE_LABEL[o] || o)}</option>`).join('');
      control = `<select data-k="${f.key}">${opts}</select>`;
    } else if (f.input === 'textarea') {
      control = `<textarea data-k="${f.key}">${esc(val(f.key))}</textarea>`;
    } else {
      control = `<input type="${f.input}" data-k="${f.key}" value="${esc(val(f.key))}" />`;
    }
    const help = f.help ? `<small class="help">${esc(f.help)}</small>` : '';
    return `<div class="field${full}"><label>${esc(f.label)}${f.required ? ' *' : ''}</label>${control}${help}</div>`;
  }).join('');

  const back = document.createElement('div');
  back.className = 'modal-back';
  back.innerHTML = `
    <div class="modal">
      <h2>${isEdit ? 'Edit row' : 'New row'}</h2>
      <div class="form-grid">${fieldHtml}</div>
      <div class="error" id="formErr"></div>
      <div class="modal-actions">
        <button class="btn ghost" id="cancelBtn">Cancel</button>
        <button class="btn primary" id="saveBtn">${isEdit ? 'Save changes' : 'Create row'}</button>
      </div>
    </div>`;
  document.body.appendChild(back);
  back.addEventListener('mousedown', (e) => { if (e.target === back) back.remove(); });
  back.querySelector('#cancelBtn').onclick = () => back.remove();
  back.querySelector('#saveBtn').onclick = async () => {
    const payload = {};
    back.querySelectorAll('[data-k]').forEach((el) => { payload[el.dataset.k] = el.value; });
    // Client-side required-field enforcement (title, owner, track, status).
    const missing = state.fields
      .filter((f) => f.required && !String(payload[f.key] || '').trim())
      .map((f) => f.label);
    if (missing.length) {
      back.querySelector('#formErr').textContent = 'Required: ' + missing.join(', ');
      return;
    }
    try {
      if (isEdit) await api('/rows/' + row.id, { method: 'PUT', body: payload });
      else await api('/rows', { method: 'POST', body: payload });
      back.remove();
      await loadRows(); renderApp();
    } catch (e) { back.querySelector('#formErr').textContent = e.message; }
  };
}
```

---

### File 2: Append to `app/public/style.css`

Append the following 2 lines to the END of `/Users/vasudevarao/execution-platform/app/public/style.css`:

```
.users-header{display:flex;align-items:center;justify-content:space-between;padding:12px 0 10px}
.users-title{margin:0;font-size:15px;font-weight:600}
```

---

### File 3: Edit `app/README.md` — add Admin User Management section

Insert the following block BEFORE the `## Workspaces (Phase 2)` section.

Use the Edit tool. old_string:

```
## Workspaces (Phase 2)
```

Replace with:

```
## Admin User Management (Phase 2)

All user accounts are created and managed by the admin. There is no public signup, no email
invite, and no password reset flow.

### Account creation

Admin logs in → clicks **Users** in the topbar → clicks **+ New user** → fills in
username, password, role, and (for track_owner) track scope → submits.

### Roles

| Role | Row access | User management |
|------|-----------|-----------------|
| admin | Full CRUD across all tracks | Full user management |
| track_owner | Create/edit own track rows; read all | None |
| viewer | Read all rows | None |

### Password handling

Passwords are hashed server-side with bcryptjs (cost 10). The password_hash is never
returned by any API endpoint. Admin can reset any user's password via the edit form.

### Demo users (non-production only)

`admin` (admin123) and `vasu` (vasu123) are seeded only when `NODE_ENV !== 'production'`.
In production, create users via the Users panel after bootstrapping the first admin account
directly in the database.

## Workspaces (Phase 2)
```

---

### Verification after writing

```bash
cd /Users/vasudevarao/execution-platform/app
node -e "const fs=require('fs'); const src=fs.readFileSync('public/app.js','utf8'); new Function(src); console.log('app.js: syntax OK');"
grep -c 'page:' public/app.js         # should be >= 1
grep -c 'loadUsers' public/app.js     # should be >= 1
grep -c 'renderUsersTable' public/app.js  # should be >= 1
grep -c 'openUserForm' public/app.js  # should be >= 1
grep -c 'users-header' public/style.css  # should be 1
```

## Acceptance Criteria
- [ ] app/public/app.js written with page/users state, loadUsers, renderUsersTable, bindUserActions, openUserForm
- [ ] renderApp() has usersPageBtn for admin, conditional users panel vs rows panel
- [ ] openUserForm: track_scope shown/required only for track_owner role
- [ ] Delete button hidden in users list for currently logged-in user (self)
- [ ] style.css has .users-header and .users-title rules
- [ ] README has Admin User Management section
- [ ] app/public/index.html NOT modified
- [ ] app/server.js NOT modified
- [ ] app/db.js NOT modified
- [ ] node syntax check passes

## Files Likely Affected
- app/public/app.js
- app/public/style.css
- app/README.md

## Blocked By
- tasks/phase-2-admin-user-management-002.md
