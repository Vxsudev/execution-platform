# Spec: Phase 2 — Split Workspaces Frontend

## Status
approved

## Phase
phase-build

## Feature Slug
phase-2-split-workspaces

## Goal
Add frontend workspace separation and permission-aware row controls to the execution table.
Introduces an All Tracks View (default) and a My Track Workspace (for track_owner), and
makes New/Edit/Delete controls conditional on role and track_scope returned by /api/me.
All permission enforcement remains in the backend (P2-1). Frontend changes are UX only.

## Recon
ai/recon/phase-2-team-operating-model-full-spec-recon.md

## Dependency
P2-1 Roles & Permissions Backend (RELEASE_APPROVED). /api/me now returns:
`{ user: { id, username, role, track_scope: [...] } }`

## Allowed Mutation Surfaces
- app/public/app.js
- app/public/style.css
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md
- specs/phase-2-split-workspaces.md
- tasks/phase-2-split-workspaces-001.md
- tasks/phase-2-split-workspaces-002.md

Do NOT modify: app/db.js, app/server.js, app/public/index.html, app/package.json,
prototypes/, sdlc/.

---

## Data Model Changes
none

---

## API Surface
none — reads from /api/me which was extended in P2-1.

---

## Frontend Surface

All changes are in `app/public/app.js` and `app/public/style.css`. No HTML or backend changes.

### 1. State update (app.js)

Add `workspace: 'all'` to the state object:

```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
};
```

### 2. Frontend permission helpers (app.js)

Add immediately after `const AUDIT_LABELS = { ... }`:

```javascript
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
```

### 3. renderApp() changes (app.js)

#### 3a. Add workspace tab controls after the topbar h1

Insert workspace tab markup into the topbar template only if `isTrackOwner()`.
Position: after the `<h1>astraX...</h1>` element, before `<span class="who" id="rowCount">`.

```html
${isTrackOwner() ? `
  <div class="ws-tabs">
    <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
    <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
  </div>` : ''}
```

Decision rationale (documented per directive):
- Admin: no workspace tabs — admin works across all tracks from All Tracks View
- track_owner: both tabs shown
- viewer: no workspace tabs — viewer sees All Tracks read-only

#### 3b. New row button: conditional on canCreateInCurrentWorkspace()

Replace:
```javascript
<button class="btn primary" id="newBtn">+ New row</button>
```

With:
```javascript
${canCreateInCurrentWorkspace() ? '<button class="btn primary" id="newBtn">+ New row</button>' : ''}
```

#### 3c. Bind workspace tab click handlers

After binding newBtn and logoutBtn, add:

```javascript
if (isTrackOwner()) {
  document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
  document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
}
```

#### 3d. Bind newBtn only if rendered

Change `document.getElementById('newBtn').onclick = ...` to guard against null:

```javascript
const newBtnEl = document.getElementById('newBtn');
if (newBtnEl) newBtnEl.onclick = () => openForm(null);
```

### 4. filteredRows() changes (app.js)

Add `visibleRowsForWorkspace()` as the first filter applied, before existing status/track/type/search filters:

```javascript
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
```

### 5. renderTable() changes — conditional Edit/Delete (app.js)

In the row action td (currently: Details / Edit / Delete buttons), make Edit and Delete conditional:

```javascript
return `<tr>${cells}<td><div class="row-actions">
  <button class="icon-btn" data-info="${r.id}">Details</button>
  ${canEditRow(r) ? `<button class="icon-btn" data-edit="${r.id}">Edit</button>` : ''}
  ${canDeleteRow()  ? `<button class="icon-btn danger" data-del="${r.id}">Delete</button>` : ''}
</div></td></tr>`;
```

### 6. Empty state for My Track Workspace (app.js)

In `renderTable()`, when `!state.rows.length`, the existing empty state is used.
For workspace-specific empty states, update the `if (!rows.length)` block:

```javascript
if (!rows.length) {
  if (state.workspace === 'my' && isTrackOwner()) {
    const scope = userScope();
    if (scope.length === 0) {
      return `<div class="empty">No assigned track scope. Ask admin to assign tracks.</div>`;
    }
    return `<div class="empty">No rows in your assigned track scope yet.</div>`;
  }
  return `<div class="empty">No rows match the current search / filters.</div>`;
}
```

### 7. openForm() track field constraint for track_owner (app.js)

In `openForm(row)`, in the `if (f.input === 'select')` block, add special handling for the `track` field when `isTrackOwner()`:

```javascript
if (f.input === 'select') {
  // For track field: constrain options to userScope() for track_owner
  const options = (f.key === 'track' && isTrackOwner())
    ? userScope()
    : f.options;
  // Default to first assigned track for new rows if track is empty
  const currentVal = (f.key === 'track' && isTrackOwner() && !val(f.key) && options.length > 0)
    ? options[0]
    : val(f.key);
  const opts = options.map((o) =>
    `<option value="${esc(o)}" ${currentVal === o ? 'selected' : ''}>${esc(TYPE_LABEL[o] || o)}</option>`).join('');
  control = `<select data-k="${f.key}">${opts}</select>`;
}
```

This ensures:
- track_owner sees only their assigned tracks in the track dropdown
- The first assigned track is pre-selected for new rows
- Admin sees the full TRACKS list (unchanged)
- Viewer never reaches the form (New/Edit hidden)

### 8. CSS additions (style.css)

Append to the end of `app/public/style.css`:

```css
.ws-tabs{display:flex;gap:4px}
.ws-tab{padding:5px 12px;border-radius:8px;border:1px solid var(--line);background:var(--panel2);color:var(--muted);font-size:12.5px}
.ws-tab.active{background:var(--accent2);border-color:var(--accent2);color:#fff;font-weight:600}
```

### 9. README update (app/README.md)

Add a new "## Workspaces (Phase 2)" section after the existing "## API Validation" section:

```markdown
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
```

---

## Operational Workflow

1. User logs in → `/api/me` returns role + track_scope.
2. `state.user` includes role and track_scope; `state.workspace` defaults to 'all'.
3. **admin:** sees full table, New/Edit/Delete on all rows. No workspace tabs.
4. **track_owner (vasu):** sees workspace tabs [All Tracks | My Track].
   - All Tracks tab: all rows visible, Edit only on T3 rows, Delete hidden.
   - My Track tab: only T3 rows visible, New row button appears, Edit on all visible rows, Delete hidden.
5. **viewer:** All Tracks view, no New/Edit/Delete, Details still visible.
6. track_owner creates a row: track select shows only T3 AstraX Ops Cloud.
7. track_owner edits a T3 row: track select shows only T3 AstraX Ops Cloud.
8. Switching workspace tab re-renders the table; filters and search carry over.

---

## Dependencies
- phase-2-roles-permissions (P2-1) — RELEASE_APPROVED — /api/me returns role + track_scope

---

## Verification Gate

### App and auth
1. App boots on :3000.
2. Login admin/admin123 → 200.
3. Login vasu/vasu123 → 200.

### Admin workspace
4. Admin sees All Tracks View with all rows.
5. Admin sees New row button.
6. Admin sees Edit and Delete buttons on every row.
7. Admin New row form shows full 6-track TRACKS list.
8. Admin can create, edit, delete rows across any track.
9. No workspace tabs visible for admin.

### track_owner workspace
10. Vasu sees workspace tabs [All Tracks | My Track].
11. Vasu All Tracks shows all rows.
12. Vasu All Tracks: Edit visible only on T3 rows; Delete not visible.
13. Vasu All Tracks: No New row button visible.
14. Vasu My Track tab: only T3 rows visible.
15. Vasu My Track: New row button visible.
16. Vasu My Track: All visible rows show Edit button.
17. Vasu My Track: Delete button not visible.
18. Vasu create form: track select shows only "T3 AstraX Ops Cloud".
19. Vasu edit T3 row form: track select shows only "T3 AstraX Ops Cloud".

### Viewer
20. Viewer (temp user) sees All Tracks with all rows.
21. Viewer sees no New row button.
22. Viewer sees no Edit or Delete buttons; Details only.
23. No workspace tabs visible for viewer.

### Regression
24. Details button still works for all roles.
25. Search still works across rows.
26. Track/status/type filter dropdowns still work.
27. Backend permission enforcement: Vasu raw POST to T1 still returns 403 (P2-1 regression).
28. Audit stamping still works.
29. Invariants: 5/5 PASS.
30. Git status: only app/public/app.js, app/public/style.css, app/README.md modified; app/server.js and app/db.js untouched.

---

## Out of Scope

This spec does not cover:

- Admin user management UI or routes — P2-3
- XLSX import — P2-4
- Dashboard — P2-5
- Deployment — excluded from Phase 2
- Public signup, email invite, password reset, SSO — excluded from Phase 2
- Approval/escalation workflow — excluded from Phase 2
- Agents, IoT/digital twin — excluded from Phase 2
- Multi-tenant SaaS — excluded from Phase 2
- Backend changes of any kind — this is a frontend-only spec
