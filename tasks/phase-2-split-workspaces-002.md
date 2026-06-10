# Task: Implement split workspaces frontend in app.js and style.css

## Parent Spec
specs/phase-2-split-workspaces.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Implement all P2-2 frontend changes. Two files to modify: `app/public/app.js` and
`app/public/style.css`. Do NOT touch any other file. The complete new content for both
files is specified below — use the Write tool to overwrite each file.

**Scope summary:**
- `state.workspace = 'all'` added to state object
- Frontend permission helpers added (isAdmin, isTrackOwner, isViewer, canCreateInCurrentWorkspace,
  canEditRow, canDeleteRow, visibleRowsForWorkspace, userScope)
- renderApp(): workspace tabs for track_owner, conditional New row button
- filteredRows(): workspace filter via visibleRowsForWorkspace
- renderTable(): conditional Edit/Delete buttons, workspace-specific empty states
- openForm(): track select constrained to userScope() for track_owner
- style.css: 3 new workspace tab rules appended

---

### File 1: Write `app/public/app.js`

Write the following content VERBATIM to `/Users/vasudevarao/execution-platform/app/public/app.js`:

```
// Frontend SPA: login, dense Excel-like table, search/filter, create/edit rows.
const $app = document.getElementById('app');
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
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
  $app.innerHTML = `
    <div class="topbar">
      <h1>astraX — Team Experiment Summary</h1>
      ${isTrackOwner() ? `
        <div class="ws-tabs">
          <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
          <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
        </div>` : ''}
      <span class="who" id="rowCount"></span>
      <div class="spacer"></div>
      <span class="who">Signed in as <strong>${esc(state.user.username)}</strong></span>
      ${canCreateInCurrentWorkspace() ? '<button class="btn primary" id="newBtn">+ New row</button>' : ''}
      <button class="btn ghost" id="logoutBtn">Log out</button>
    </div>
    <div class="controls">
      <input id="searchInput" class="search" type="text" placeholder="Search…" value="${esc(state.search)}" />
      <select id="fStatus" title="Filter by status">${optionTags(state.statuses, state.filters.status)}</select>
      <select id="fTrack" title="Filter by track">${optionTags(state.tracks, state.filters.track)}</select>
      <select id="fType" title="Filter by type">${optionTags(state.types, state.filters.type, (t) => TYPE_LABEL[t] || t)}</select>
    </div>
    <div class="wrap">
      <div class="table-scroll" id="tableScroll"></div>
    </div>`;

  const newBtnEl = document.getElementById('newBtn');
  if (newBtnEl) newBtnEl.onclick = () => openForm(null);
  document.getElementById('logoutBtn').onclick = async () => {
    await api('/logout', { method: 'POST' }); state.user = null; renderLogin();
  };
  if (isTrackOwner()) {
    document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
    document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
  }
  document.getElementById('searchInput').oninput = (e) => { state.search = e.target.value; refreshTable(); };
  document.getElementById('fStatus').onchange = (e) => { state.filters.status = e.target.value; refreshTable(); };
  document.getElementById('fTrack').onchange = (e) => { state.filters.track = e.target.value; refreshTable(); };
  document.getElementById('fType').onchange = (e) => { state.filters.type = e.target.value; refreshTable(); };

  refreshTable();
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

Append the following 3 lines to the END of `/Users/vasudevarao/execution-platform/app/public/style.css`:

```
.ws-tabs{display:flex;gap:4px}
.ws-tab{padding:5px 12px;border-radius:8px;border:1px solid var(--line);background:var(--panel2);color:var(--muted);font-size:12.5px}
.ws-tab.active{background:var(--accent2);border-color:var(--accent2);color:#fff;font-weight:600}
```

---

### File 3: Edit `app/README.md` — add Workspaces section

Insert the following block into `/Users/vasudevarao/execution-platform/app/README.md`
AFTER the `## API Validation` section (after the line ending with `HTTP 400.`) and BEFORE
the `## Audit Metadata` section.

Use the Edit tool. The old_string to replace is:

```
## Audit Metadata
```

Replace it with:

```
## Workspaces (Phase 2)

### All Tracks View
Available to all authenticated users. Shows all rows across all six tracks. Search and
filter controls apply across all rows.

### My Track Workspace
Available to `track_owner` role only. Shows only rows in the user's assigned track scope.
New row and Edit controls are enabled only for rows in assigned tracks. Delete is
admin-only regardless of workspace.

### Frontend control visibility

| Control | admin | track_owner (All Tracks) | track_owner (My Track) | viewer |
|---------|-------|--------------------------|------------------------|--------|
| New row | ✓ | — | ✓ (assigned tracks only) | — |
| Edit | ✓ all rows | — | ✓ assigned track rows | — |
| Delete | ✓ | — | — | — |
| Details | ✓ | ✓ | ✓ | ✓ |

**Note:** Frontend controls are UX convenience only. Backend route guards (P2-1) enforce
the same rules and will reject unauthorized raw API calls regardless of frontend state.

## Audit Metadata
```

---

### Verification after writing

After writing both files, run a quick syntax check:

```bash
cd /Users/vasudevarao/execution-platform/app
node -e "const fs=require('fs'); const src=fs.readFileSync('public/app.js','utf8'); Function(src)(); console.log('app.js: syntax OK');"
```

Expected output: `app.js: syntax OK`

Also verify the key patterns are present:
```bash
grep -c 'workspace:' app/public/app.js          # should be >= 1
grep -c 'isAdmin' app/public/app.js              # should be >= 1
grep -c 'ws-tabs' app/public/app.js              # should be >= 1
grep -c 'canEditRow' app/public/app.js           # should be >= 1
grep -c 'ws-tabs' app/public/style.css           # should be 1
```

## Acceptance Criteria
- [ ] app/public/app.js written with complete new content
- [ ] state object has workspace: 'all'
- [ ] Permission helpers (isAdmin, isTrackOwner, isViewer, userScope, canCreateInCurrentWorkspace, canEditRow, canDeleteRow, visibleRowsForWorkspace) all present
- [ ] renderApp() includes ws-tabs block conditional on isTrackOwner()
- [ ] New row button conditional on canCreateInCurrentWorkspace()
- [ ] filteredRows() calls visibleRowsForWorkspace(state.rows)
- [ ] renderTable() has conditional Edit/Delete and workspace-specific empty states
- [ ] openForm() constrains track select to userScope() for track_owner
- [ ] style.css has .ws-tabs, .ws-tab, .ws-tab.active rules appended
- [ ] app/public/index.html NOT modified
- [ ] app/server.js NOT modified
- [ ] app/db.js NOT modified
- [ ] node syntax check on app.js passes

## Files Likely Affected
- app/public/app.js
- app/public/style.css
- app/README.md

## Blocked By
- tasks/phase-2-split-workspaces-001.md
