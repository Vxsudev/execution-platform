// Frontend SPA: login, list rows, create/edit rows. Consumes the backend API.
const $app = document.getElementById('app');
const state = { user: null, fields: [], types: [], statuses: [], rows: [], editing: null };

const TYPE_LABEL = { experiment: 'Experiment', work_item: 'Work Item', task: 'Task' };
// Columns shown in the list view (the full set is editable in the form).
const LIST_COLS = ['type', 'title', 'owner', 'track', 'status', 'target_end_date'];

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

// ---------- login ----------
function renderLogin(errMsg) {
  $app.innerHTML = `
    <div class="login-wrap">
      <div class="login-card">
        <h1>Execution Table</h1>
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
function renderApp() {
  $app.innerHTML = `
    <div class="topbar">
      <h1>Execution Table</h1>
      <span class="who">${state.rows.length} row(s)</span>
      <div class="spacer"></div>
      <span class="who">Signed in as <strong>${esc(state.user.username)}</strong></span>
      <button class="btn primary" id="newBtn">+ New row</button>
      <button class="btn ghost" id="logoutBtn">Log out</button>
    </div>
    <div class="wrap">
      <div class="table-scroll">${renderTable()}</div>
    </div>`;
  document.getElementById('newBtn').onclick = () => openForm(null);
  document.getElementById('logoutBtn').onclick = async () => { await api('/logout', { method: 'POST' }); state.user = null; renderLogin(); };
  bindRowActions();
}

function colLabel(key) { return (state.fields.find((f) => f.key === key) || {}).label || key; }

function renderTable() {
  if (!state.rows.length) return `<div class="empty">No rows yet. Click <strong>+ New row</strong> to add one.</div>`;
  const head = LIST_COLS.map((k) => `<th>${esc(colLabel(k))}</th>`).join('') + '<th></th>';
  const body = state.rows.map((r) => {
    const cells = LIST_COLS.map((k) => {
      if (k === 'type') return `<td><span class="tag type-${esc(r.type)}">${esc(TYPE_LABEL[r.type] || r.type)}</span></td>`;
      if (k === 'status') return `<td><span class="status s-${esc((r.status || '').replace(/\s/g, '.'))}">${esc(r.status)}</span></td>`;
      if (k === 'title') return `<td><div class="title">${esc(r.title)}</div></td>`;
      return `<td>${esc(r[k])}</td>`;
    }).join('');
    return `<tr>${cells}<td><div class="row-actions">
      <button class="icon-btn" data-edit="${r.id}">Edit</button>
      <button class="icon-btn danger" data-del="${r.id}">Delete</button>
    </div></td></tr>`;
  }).join('');
  return `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

function bindRowActions() {
  document.querySelectorAll('[data-edit]').forEach((b) =>
    b.onclick = () => openForm(state.rows.find((r) => r.id == b.dataset.edit)));
  document.querySelectorAll('[data-del]').forEach((b) =>
    b.onclick = async () => {
      if (!confirm('Delete this row?')) return;
      await api('/rows/' + b.dataset.del, { method: 'DELETE' });
      await loadRows(); renderApp();
    });
}

// ---------- create / edit form ----------
function openForm(row) {
  const isEdit = !!row;
  const val = (k) => (row && row[k] != null ? row[k] : '');
  const fieldHtml = state.fields.map((f) => {
    const full = f.input === 'textarea' ? ' full' : '';
    let control;
    if (f.input === 'select') {
      const opts = f.options.map((o) =>
        `<option value="${esc(o)}" ${val(f.key) === o ? 'selected' : ''}>${esc(TYPE_LABEL[o] || o)}</option>`).join('');
      control = `<select data-k="${f.key}">${opts}</select>`;
    } else if (f.input === 'textarea') {
      control = `<textarea data-k="${f.key}">${esc(val(f.key))}</textarea>`;
    } else {
      control = `<input type="${f.input}" data-k="${f.key}" value="${esc(val(f.key))}" />`;
    }
    return `<div class="field${full}"><label>${esc(f.label)}${f.required ? ' *' : ''}</label>${control}</div>`;
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
    try {
      if (isEdit) await api('/rows/' + row.id, { method: 'PUT', body: payload });
      else await api('/rows', { method: 'POST', body: payload });
      back.remove();
      await loadRows(); renderApp();
    } catch (e) { back.querySelector('#formErr').textContent = e.message; }
  };
}
