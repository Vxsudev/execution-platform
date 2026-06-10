# Spec: Phase 2 — Admin User Management

## Status
approved

## Phase
phase-build

## Feature Slug
phase-2-admin-user-management

## Goal
Add admin-only user management so an admin can create users, assign role, assign track
scope, update role/scope/password, and delete users. No public signup, no email invite,
no password reset, no external auth. Admin is the sole in-app account operator.

## Recon
ai/recon/phase-2-team-operating-model-full-spec-recon.md

## Dependency
- P2-1 Roles & Permissions Backend (RELEASE_APPROVED) — role/track_scope columns, canManageUsers helper
- P2-2 Split Workspaces Frontend (RELEASE_APPROVED) — state.workspace, isAdmin/isTrackOwner helpers

## Allowed Mutation Surfaces
- app/server.js
- app/public/app.js
- app/public/style.css
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md
- specs/phase-2-admin-user-management.md
- tasks/phase-2-admin-user-management-001.md
- tasks/phase-2-admin-user-management-002.md
- tasks/phase-2-admin-user-management-003.md

Do NOT modify: app/db.js, app/package.json, app/public/index.html, prototypes/, sdlc/.

---

## Data Model Changes
none — role and track_scope columns were added in P2-1.

---

## API Surface

All routes in app/server.js. All require requireAuth + canManageUsers(req.user).
Non-admin returns 403 { "error": "Forbidden" }. Unauthenticated returns existing 401.
password_hash is NEVER returned in any response.

### Helpers to add before routes

```javascript
const VALID_ROLES = ['admin', 'track_owner', 'viewer'];

function normalizeRole(role) {
  return VALID_ROLES.includes(role) ? role : null;
}

// Returns JSON string for DB storage, or null if any track is invalid.
function normalizeTrackScope(role, scopeInput) {
  if (role !== 'track_owner') return JSON.stringify([]);
  const scope = Array.isArray(scopeInput) ? scopeInput : [];
  for (const t of scope) { if (!TRACKS.includes(t)) return null; }
  return JSON.stringify(scope);
}

// Safe user object for API responses — never includes password_hash.
function publicUser(u) {
  return { id: u.id, username: u.username, role: u.role, track_scope: parseScope(u), created_at: u.created_at };
}
```

### GET /api/users

```
Returns list of users without password_hash.
Response: { "users": [ { id, username, role, track_scope: [...], created_at } ] }
Order by id ASC.
```

### POST /api/users

```
Input: { username, password, role, track_scope: [...] }
Validation:
  - username required, non-blank
  - password required, non-blank
  - role required, must be admin|track_owner|viewer
  - track_scope required and non-empty for track_owner
  - track_scope normalized to [] for admin/viewer
  - all track_scope values must be canonical TRACKS
  - duplicate username → 400 { "error": "username already exists" }
Password: bcrypt.hashSync(password, 10)
Success: 201 { "user": publicUser }
```

### PUT /api/users/:id

```
Input: { role?, track_scope?: [...], password? }
Validation:
  - role, if present, must be valid
  - if role changes to track_owner, track_scope must be non-empty and valid
  - track_scope normalized per role
  - password, if non-blank, re-hashed server-side
  - username is NOT editable in Phase 2
  - req.user.id === id AND role !== 'admin' → 403 { "error": "cannot demote your own admin account" }
  - user not found → 404
Success: 200 { "user": publicUser }
```

### DELETE /api/users/:id

```
Rules:
  - req.user.id === id → 403 { "error": "cannot delete your own account" }
  - user not found → 404
  - delete user's sessions before deleting user
  - hard delete (no disabled flag in Phase 2)
Success: 200 { "ok": true }
```

---

## Frontend Surface

All changes in app/public/app.js, app/public/style.css, app/README.md.
Do NOT modify app/public/index.html or app/server.js.

### State additions (app.js)

Add `page: 'rows'` and `users: []` to state:

```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
  page: 'rows', users: [],
};
```

### New async function: loadUsers()

```javascript
async function loadUsers() {
  const data = await api('/users');
  state.users = data.users;
}
```

### renderApp() additions

In the topbar:
- Admin only: render a "Users" button styled like ws-tab (active when state.page === 'users')
  - Clicking from rows page: set state.page = 'users', await loadUsers(), renderApp()
  - Clicking from users page: set state.page = 'rows', renderApp()
- newBtn: wrap in `!isUsersPage && canCreateInCurrentWorkspace()` condition

In the content area: conditionally render users panel OR controls+table based on state.page.

rowCount span: show user count on users page, row count on rows page.

After template injection:
- Bind usersPageBtn (admin only)
- If state.page === 'users': update rowCount, bind newUserBtn, call bindUserActions()
- If state.page === 'rows': bind search/filter handlers, call refreshTable()

### New function: renderUsersTable()

Returns HTML string of the user list table or empty state.

Columns: Username, Role, Track Scope, Created, Actions.

Track scope cell: join with ', ' or '—' if empty. Use class="trunc" with title tooltip.

Actions: Edit button (always), Delete button (hidden when u.id === state.user.id).

Include users-header div with Users heading and "+ New user" button (id="newUserBtn").

### New function: bindUserActions()

Binds [data-user-edit] and [data-user-del] buttons and the newUserBtn.

Delete handler: confirm dialog, call DELETE /api/users/:id, await loadUsers(), renderApp().

### New function: openUserForm(user)

user = null for create, user object for edit.

Create modal fields:
- username (text input, required on create, disabled display on edit)
- password (password input, required on create, optional on edit with "leave blank to keep" label)
- role (select: admin, track_owner, viewer)
- track_scope (multi-select of state.tracks, shown/required only when role === 'track_owner')

Behavior:
- role onchange: show/hide track_scope field
- Submit: collect payload (skip password if blank on edit, set track_scope=[] for non-track_owner)
- Call POST /api/users (create) or PUT /api/users/:id (edit)
- On success: back.remove(), await loadUsers(), renderApp()
- On error: show error in form error div

### CSS additions (style.css)

Append 2 rules:

```css
.users-header{display:flex;align-items:center;justify-content:space-between;padding:12px 0 10px}
.users-title{margin:0;font-size:15px;font-weight:600}
```

### README update

Add `## Admin User Management (Phase 2)` section documenting:
- admin-created accounts only
- no public signup
- roles summary
- password handling
- demo users note

---

## Architecture Invariants

- password_hash never returned by API
- admin cannot demote self
- admin cannot delete self
- track_owner creation requires non-empty valid track_scope
- backend enforces admin-only; frontend is UX only
- login/session behavior unchanged
- P2-1 row permission guards unchanged
- P2-2 workspace behavior unchanged

---

## Verification Gate

### App and auth
1. App boots on :3000.
2. Login admin/admin123 → 200 with cookie.
3. Vasu login (vasu/vasu123) → 200 with cookie.

### Admin GET /api/users
4. GET /api/users for admin → 200, users array returned.
5. Response contains no password_hash field on any user.
6. Users tab visible in topbar when logged in as admin.

### Admin create user
7. POST /api/users admin creates viewer user → 201, user in response.
8. POST /api/users admin creates track_owner with T3 scope → 201.
9. POST /api/users track_owner with empty scope → 400.
10. POST /api/users with invalid role → 400.
11. POST /api/users with invalid track → 400.
12. POST /api/users duplicate username → 400 "username already exists".

### Admin edit user
13. PUT /api/users/:id change role → 200, updated user returned.
14. PUT /api/users/:id change track_scope → 200.
15. PUT /api/users/:id reset password → 200, new password works for login.
16. PUT /api/users/:id demote own admin → 403.

### Admin delete user
17. DELETE /api/users/:id delete another user → 200 { ok: true }.
18. DELETE /api/users/:id self-delete → 403.
19. Deleted user cannot login after deletion.
20. Deleted user sessions invalidated.

### Non-admin access
21. Vasu GET /api/users → 403.
22. Vasu POST /api/users → 403.
23. Viewer GET /api/users → 403.
24. Vasu Users tab NOT visible in UI.

### Smoke test
25. Admin creates new track_owner user assigned T3 → user can login, POST T3 succeeds, POST T1 returns 403.
26. Admin edits new user to viewer → user's /api/me returns role: 'viewer', row write returns 403.
27. Admin deletes the new user → login fails.

### Regression
28. Existing All Tracks / My Track workspace behavior unchanged.
29. P2-1 route guards unchanged (Vasu POST T1 → 403).
30. Audit stamping unchanged.
31. Invariants: 5/5 PASS.
32. Git: only app/server.js, app/public/app.js, app/public/style.css, app/README.md modified.

---

## Out of Scope
- Public signup
- Email invite
- Password reset flow
- External auth (SSO, OAuth)
- Account disable flag (deferred to future)
- XLSX import — P2-4
- Dashboard — P2-5
- Deployment
- Approval/escalation workflows
- Agents
