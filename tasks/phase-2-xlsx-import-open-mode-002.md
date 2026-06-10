# Task: Update Import UI to open-mode language and shape

## Parent Spec
specs/phase-2-xlsx-import-open-mode.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update the admin Import panel to the open-mode shape/language. Modify ONLY
`app/public/app.js`, `app/public/style.css`, and `app/README.md`. Do NOT modify
server.js, db.js, or index.html.

### Step 1 — Replace app/public/app.js with the exact content below
Use the Write tool to overwrite `/Users/vasudevarao/execution-platform/app/public/app.js`
with EXACTLY this content (only `renderImportPanel` and the commit handler in
`bindImportActions` changed vs the prior version — it now reads
`state.importPreview.{summary.importable_rows/skipped_rows/warning_count, rows[].{row_number,warnings,data}, skipped_rows[]}`
and posts `rows.map(r => r.data)` on commit; all other behavior is unchanged):

```javascript
// Frontend SPA: login, dense Excel-like table, search/filter, create/edit rows.
const $app = document.getElementById('app');
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [], importPreview: null,
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
  const isImportPage = state.page === 'import';
  $app.innerHTML = `
    <div class="topbar">
      <h1>astraX — Team Experiment Summary</h1>
      ${isTrackOwner() ? `
        <div class="ws-tabs">
          <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
          <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
        </div>` : ''}
      ${isAdmin() ? `<button class="ws-tab${isUsersPage ? ' active' : ''}" id="usersPageBtn">Users</button>` : ''}
      ${isAdmin() ? `<button class="ws-tab${isImportPage ? ' active' : ''}" id="importPageBtn">Import</button>` : ''}
      <span class="who" id="rowCount"></span>
      <div class="spacer"></div>
      <span class="who">Signed in as <strong>${esc(state.user.username)}</strong></span>
      ${!isUsersPage && !isImportPage && canCreateInCurrentWorkspace() ? '<button class="btn primary" id="newBtn">+ New row</button>' : ''}
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
    ` : isImportPage ? `
      <div class="wrap">${renderImportPanel()}</div>
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
    document.getElementById('importPageBtn').onclick = () => {
      if (state.page === 'import') { state.page = 'rows'; renderApp(); return; }
      state.page = 'import';
      state.importPreview = null;
      renderApp();
    };
  }

  if (isUsersPage) {
    document.getElementById('rowCount').textContent = `${state.users.length} users`;
    document.getElementById('newUserBtn').onclick = () => openUserForm(null);
    bindUserActions();
  } else if (isImportPage) {
    document.getElementById('rowCount').textContent = '';
    bindImportActions();
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

// ---------- import panel ----------
function renderImportPanel() {
  const p = state.importPreview;
  const summary = p ? `
    <div class="import-summary">
      <strong>${esc(p.summary.sheet)}</strong> —
      ${p.summary.total_rows} rows ·
      <span class="ok">${p.summary.importable_rows} importable</span> ·
      <span class="warn">${p.summary.warning_count} warning${p.summary.warning_count === 1 ? '' : 's'}</span> ·
      <span class="bad">${p.summary.skipped_rows} skipped</span>
    </div>` : '';
  const importable = (p && p.rows.length) ? `
    <h3 class="import-h">Importable rows preview (first 10 of ${p.rows.length})</h3>
    <div class="table-scroll"><table><thead><tr>
      <th>Row</th><th>Owner</th><th>Track</th><th>Title</th><th>Status</th><th>Type</th><th>Warnings</th>
    </tr></thead><tbody>
      ${p.rows.slice(0, 10).map(r => `<tr>
        <td>${r.row_number}</td>
        <td>${esc(r.data.owner)}</td><td>${esc(r.data.track)}</td><td>${esc(r.data.title)}</td>
        <td>${esc(r.data.status)}</td><td>${esc(r.data.type)}</td>
        <td class="trunc" title="${esc(r.warnings.join('; '))}">${esc(r.warnings.join('; ') || '\u2014')}</td>
      </tr>`).join('')}
    </tbody></table></div>` : '';
  const skipped = (p && p.skipped_rows.length) ? `
    <h3 class="import-h">Skipped rows (${p.skipped_rows.length}) — not imported</h3>
    <div class="table-scroll"><table><thead><tr><th>Row</th><th>Reason</th></tr></thead><tbody>
      ${p.skipped_rows.map(r => `<tr><td>${r.row_number}</td><td>${esc(r.reason)}</td></tr>`).join('')}
    </tbody></table></div>` : '';
  const commitDisabled = !(p && p.rows.length > 0) ? ' disabled' : '';
  return `
    <div class="import-panel">
      <h2 class="users-title">Import from XLSX</h2>
      <p class="import-note">Admin only. Capture-first import: every row with a title is imported. Blank owner becomes "Unassigned", blank track becomes "Unassigned Track", and blank or unrecognized status becomes "Not Started"; non-canonical tracks import as-is. Issues are shown as warnings, not blockers. Nothing is written until you commit. The database is the source of truth — a one-time import, not a sync.</p>
      <div class="import-controls">
        <input type="file" id="importFile" accept=".xlsx" />
        <button class="btn" id="importPreviewBtn">Preview</button>
        <button class="btn primary" id="importCommitBtn"${commitDisabled}>Commit Import</button>
      </div>
      <div class="error" id="importErr"></div>
      ${summary}
      ${importable}
      ${skipped}
    </div>`;
}

function fileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = String(reader.result || '');
      const comma = result.indexOf(',');
      resolve(comma >= 0 ? result.slice(comma + 1) : result);
    };
    reader.onerror = () => reject(new Error('could not read file'));
    reader.readAsDataURL(file);
  });
}

function bindImportActions() {
  const errEl = document.getElementById('importErr');
  const setErr = (m) => { if (errEl) errEl.textContent = m || ''; };
  document.getElementById('importPreviewBtn').onclick = async () => {
    setErr('');
    const fileEl = document.getElementById('importFile');
    const file = fileEl && fileEl.files && fileEl.files[0];
    if (!file) { setErr('Choose a .xlsx file first.'); return; }
    if (!/\.xlsx$/i.test(file.name)) { setErr('File must be a .xlsx workbook.'); return; }
    try {
      const content_base64 = await fileToBase64(file);
      const data = await api('/import/preview', { method: 'POST', body: { filename: file.name, content_base64 } });
      state.importPreview = data;
      renderApp();
    } catch (e) { setErr(e.message); }
  };
  const commitBtn = document.getElementById('importCommitBtn');
  if (commitBtn) commitBtn.onclick = async () => {
    setErr('');
    const p = state.importPreview;
    if (!p || !p.rows.length) { setErr('Nothing to import — run a preview with importable rows first.'); return; }
    if (!confirm(`Import ${p.rows.length} row(s) into the database?`)) return;
    try {
      const res = await api('/import/commit', { method: 'POST', body: { rows: p.rows.map(r => r.data) } });
      state.importPreview = null;
      state.page = 'rows';
      state.workspace = 'all';
      await loadRows();
      renderApp();
      alert(`Imported ${res.inserted_count} row(s)` + (res.skipped_count ? `, ${res.skipped_count} skipped` : '') + '.');
    } catch (e) { setErr(e.message); }
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

### Step 2 — Append an amber warning token to app/public/style.css
Append to the END of `app/public/style.css`:

```css
.import-summary .warn{color:#9a6700;font-weight:600}
```

### Step 3 — Update the README XLSX Import section
In `app/README.md`, replace the body of the `## XLSX Import (Phase 2)` section to
describe open mode. It must state: capture-first (every row with a title imports);
blank owner → Unassigned, blank track → Unassigned Track, blank/unrecognized status →
Not Started; non-canonical tracks import as-is; status is coerced (not stored arbitrary)
because the DB constrains status; issues are warnings not blockers; only a blank title
skips a row; preview before commit; DB remains source of truth; manual row creation
still uses strict canonical dropdowns/validation.

### Step 4 — Syntax check
```bash
cd /Users/vasudevarao/execution-platform/app
node --check public/app.js && echo "app.js syntax OK"
```

## Acceptance Criteria
- [ ] Import panel reads the open-mode preview shape and shows importable / warnings / skipped counts.
- [ ] Importable-rows preview includes a Warnings column; skipped-rows list shows row number + reason.
- [ ] Copy says importable/warnings/skipped (not valid/invalid); commit enabled when importable_rows > 0.
- [ ] Commit posts `rows.map(r => r.data)`.
- [ ] `node --check public/app.js` passes; users/rows/login behavior unchanged.
- [ ] Only `app/public/app.js`, `app/public/style.css`, `app/README.md` modified.

## Files Likely Affected
- app/public/app.js
- app/public/style.css
- app/README.md

## Blocked By
- tasks/phase-2-xlsx-import-open-mode-001.md
