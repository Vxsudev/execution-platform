# Task: Add admin user management routes to server.js

## Parent Spec
specs/phase-2-admin-user-management.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Add admin-only user management routes and helpers to `app/server.js`.
Do NOT modify any other file. No changes to app/db.js, app/public/, README.

The existing file ends at line 201:
```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`));
```

All new code must be inserted BEFORE the PORT/listen lines.

### Step 1 — Add helpers and routes

Use the Edit tool to insert the following block into
`/Users/vasudevarao/execution-platform/app/server.js`

Old string to replace:
```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`));
```

New string (helpers + routes + PORT line):
```javascript
// ---- user management ----
const VALID_ROLES = ['admin', 'track_owner', 'viewer'];

function normalizeRole(role) {
  return VALID_ROLES.includes(role) ? role : null;
}

function normalizeTrackScope(role, scopeInput) {
  if (role !== 'track_owner') return JSON.stringify([]);
  const scope = Array.isArray(scopeInput) ? scopeInput : [];
  for (const t of scope) { if (!TRACKS.includes(t)) return null; }
  return JSON.stringify(scope);
}

function publicUser(u) {
  return { id: u.id, username: u.username, role: u.role, track_scope: parseScope(u), created_at: u.created_at };
}

app.get('/api/users', requireAuth, (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const users = db.prepare('SELECT id, username, role, track_scope, created_at FROM users ORDER BY id').all();
  res.json({ users: users.map(publicUser) });
});

app.post('/api/users', requireAuth, (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const { username, password, role, track_scope } = req.body || {};
  if (!username || !String(username).trim()) return res.status(400).json({ error: 'username is required' });
  if (!password || !String(password).trim()) return res.status(400).json({ error: 'password is required' });
  const normalizedRole = normalizeRole(role);
  if (!normalizedRole) return res.status(400).json({ error: 'invalid role' });
  if (normalizedRole === 'track_owner' && (!Array.isArray(track_scope) || track_scope.length === 0)) {
    return res.status(400).json({ error: 'track_scope required for track_owner' });
  }
  const normalizedScope = normalizeTrackScope(normalizedRole, track_scope);
  if (normalizedScope === null) return res.status(400).json({ error: 'invalid track_scope' });
  try {
    const hash = bcrypt.hashSync(String(password), 10);
    const info = db.prepare('INSERT INTO users (username, password_hash, role, track_scope) VALUES (?, ?, ?, ?)')
      .run(String(username).trim(), hash, normalizedRole, normalizedScope);
    const created = db.prepare('SELECT id, username, role, track_scope, created_at FROM users WHERE id = ?').get(info.lastInsertRowid);
    res.status(201).json({ user: publicUser(created) });
  } catch (e) {
    if (e.message && e.message.includes('UNIQUE constraint')) {
      return res.status(400).json({ error: 'username already exists' });
    }
    throw e;
  }
});

app.put('/api/users/:id', requireAuth, (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  const existing = db.prepare('SELECT id, username, role, track_scope, created_at FROM users WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'user not found' });
  const { role, track_scope, password } = req.body || {};
  if (req.user.id === id && role !== undefined && role !== 'admin') {
    return res.status(403).json({ error: 'cannot demote your own admin account' });
  }
  const updates = {};
  if (role !== undefined) {
    const normalizedRole = normalizeRole(role);
    if (!normalizedRole) return res.status(400).json({ error: 'invalid role' });
    if (normalizedRole === 'track_owner' && (!Array.isArray(track_scope) || track_scope.length === 0)) {
      return res.status(400).json({ error: 'track_scope required for track_owner' });
    }
    const normalizedScope = normalizeTrackScope(normalizedRole, track_scope);
    if (normalizedScope === null) return res.status(400).json({ error: 'invalid track_scope' });
    updates.role = normalizedRole;
    updates.track_scope = normalizedScope;
  }
  if (password !== undefined && String(password).trim()) {
    updates.password_hash = bcrypt.hashSync(String(password), 10);
  }
  if (Object.keys(updates).length) {
    const setClause = Object.keys(updates).map(k => `${k} = ?`).join(', ');
    db.prepare(`UPDATE users SET ${setClause} WHERE id = ?`).run(...Object.values(updates), id);
  }
  const updated = db.prepare('SELECT id, username, role, track_scope, created_at FROM users WHERE id = ?').get(id);
  res.json({ user: publicUser(updated) });
});

app.delete('/api/users/:id', requireAuth, (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  if (req.user.id === id) return res.status(403).json({ error: 'cannot delete your own account' });
  const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(id);
  if (!existing) return res.status(404).json({ error: 'user not found' });
  db.prepare('DELETE FROM sessions WHERE user_id = ?').run(id);
  db.prepare('DELETE FROM users WHERE id = ?').run(id);
  res.json({ ok: true });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`));
```

### Step 2 — Syntax check

```bash
cd /Users/vasudevarao/execution-platform/app
node -e "require('./server.js')" &
SERVER_PID=$!
sleep 1
kill $SERVER_PID 2>/dev/null || true
echo "Server loaded without syntax errors"
```

Or start and stop the server to confirm it loads clean.

### Step 3 — Quick API sanity check

```bash
cd /Users/vasudevarao/execution-platform/app
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js &
APP_PID=$!
sleep 1

ADMIN_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')

GET_USERS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/users --cookie "sid=$ADMIN_COOKIE")
echo "Admin GET /api/users: $GET_USERS (expected 200)"

VASU_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"vasu","password":"vasu123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
VASU_GET=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/users --cookie "sid=$VASU_COOKIE")
echo "Vasu GET /api/users: $VASU_GET (expected 403)"

kill $APP_PID 2>/dev/null || true
```

## Acceptance Criteria
- [ ] normalizeRole(), normalizeTrackScope(), publicUser() helpers added
- [ ] GET /api/users returns 200 for admin, 403 for non-admin
- [ ] POST /api/users creates user, returns 201, no password_hash in response
- [ ] POST /api/users with invalid role returns 400
- [ ] POST /api/users track_owner with empty scope returns 400
- [ ] POST /api/users duplicate username returns 400
- [ ] PUT /api/users/:id updates role/scope/password
- [ ] PUT /api/users/:id self-demotion returns 403
- [ ] DELETE /api/users/:id deletes user and sessions
- [ ] DELETE /api/users/:id self-delete returns 403
- [ ] app/public/ files NOT modified
- [ ] app/db.js NOT modified

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-2-admin-user-management-001.md
