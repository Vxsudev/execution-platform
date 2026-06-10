// Backend API: auth + rows CRUD. Serves the static frontend from /public.
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const bcrypt = require('bcryptjs');
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const SID = 'sid';
const FIELD_KEYS = ROW_FIELDS.map(f => f.key);
const REQUIRED_FIELDS = ROW_FIELDS.filter(f => f.required).map(f => f.key);

function parseScope(user) {
  try { return JSON.parse(user.track_scope || '[]'); } catch (_) { return []; }
}
function canCreateRow(user, track) {
  if (user.role === 'admin') return true;
  if (user.role === 'track_owner') return parseScope(user).includes(track);
  return false;
}
function canEditRow(user, existingRow, nextTrack) {
  if (user.role === 'admin') return true;
  if (user.role !== 'track_owner') return false;
  const scope = parseScope(user);
  if (!scope.includes(existingRow.track)) return false;
  if (nextTrack !== undefined && nextTrack !== existingRow.track && !scope.includes(nextTrack)) return false;
  return true;
}
function canDeleteRow(user)   { return user.role === 'admin'; }
function canImport(user)      { return user.role === 'admin'; }
function canManageUsers(user) { return user.role === 'admin'; }

const SESSION_SECRET = process.env.SESSION_SECRET ||
  (process.env.NODE_ENV === 'production' ? null : 'dev-insecure-fallback-do-not-use-in-production');
if (!SESSION_SECRET) {
  console.error('FATAL: SESSION_SECRET environment variable is required in production mode.');
  process.exit(1);
}
if (process.env.NODE_ENV === 'production' && SESSION_SECRET.length < 32) {
  console.error('FATAL: SESSION_SECRET must be at least 32 characters in production mode.');
  process.exit(1);
}

function signToken(token) {
  return token + '.' + crypto.createHmac('sha256', SESSION_SECRET).update(token).digest('hex');
}
function verifyToken(signed) {
  if (typeof signed !== 'string') return null;
  const dot = signed.lastIndexOf('.');
  if (dot < 0) return null;
  const token = signed.slice(0, dot);
  const sig = signed.slice(dot + 1);
  const expected = crypto.createHmac('sha256', SESSION_SECRET).update(token).digest('hex');
  if (sig.length !== 64) return null;
  try {
    if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  } catch (_) { return null; }
  return token;
}

function parseCookies(req) {
  const out = {};
  const h = req.headers.cookie;
  if (!h) return out;
  for (const part of h.split(';')) {
    const i = part.indexOf('=');
    if (i > -1) out[part.slice(0, i).trim()] = decodeURIComponent(part.slice(i + 1).trim());
  }
  return out;
}
function currentUser(req) {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (!token) return null;
  return db.prepare(
    'SELECT u.id, u.username, u.role, u.track_scope FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
  ).get(token) || null;
}
function requireAuth(req, res, next) {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: 'Not authenticated' });
  req.user = u;
  next();
}

// ---- auth ----
app.post('/api/login', (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'username and password required' });
  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(String(username).trim());
  if (!user || !bcrypt.compareSync(String(password), user.password_hash)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  const token = crypto.randomBytes(32).toString('hex');
  db.prepare('INSERT INTO sessions (token, user_id) VALUES (?, ?)').run(token, user.id);
  res.cookie(SID, signToken(token), {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 7 * 24 * 3600 * 1000,
    secure: process.env.NODE_ENV === 'production',
  });
  res.json({ user: { id: user.id, username: user.username } });
});
app.post('/api/logout', (req, res) => {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.clearCookie(SID, { path: '/' });
  res.json({ ok: true });
});
app.get('/api/me', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: 'Not authenticated' });
  res.json({ user: { ...u, track_scope: parseScope(u) } });
});
app.get('/api/schema', requireAuth, (req, res) => {
  res.json({ fields: ROW_FIELDS, types: ROW_TYPES, statuses: STATUSES, tracks: TRACKS });
});

// ---- rows ----
function sanitize(body) {
  const out = {};
  for (const k of FIELD_KEYS) {
    if (body[k] !== undefined) out[k] = body[k] === null ? null : String(body[k]);
  }
  return out;
}
function validate(data, partial, existingRow) {
  if (!partial) {
    for (const field of REQUIRED_FIELDS) {
      if (!data[field] || !String(data[field]).trim()) return `${field} is required`;
    }
  } else {
    for (const field of REQUIRED_FIELDS) {
      if (data[field] !== undefined && !String(data[field] || '').trim())
        return `${field} cannot be empty`;
    }
    if (existingRow) {
      const merged = { ...existingRow, ...data };
      for (const field of REQUIRED_FIELDS) {
        if (!merged[field] || !String(merged[field]).trim()) return `${field} is required`;
      }
      if (merged.track !== undefined && !TRACKS.includes(String(merged.track || '')))
        return 'invalid track';
    }
  }
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
  if (data.track !== undefined && !TRACKS.includes(data.track)) return 'invalid track';
  return null;
}

app.get('/api/rows', requireAuth, (req, res) => {
  res.json({ rows: db.prepare('SELECT * FROM entries ORDER BY updated_at DESC, id DESC').all() });
});
app.get('/api/rows/:id', requireAuth, (req, res) => {
  const row = db.prepare('SELECT * FROM entries WHERE id = ?').get(req.params.id);
  if (!row) return res.status(404).json({ error: 'Not found' });
  res.json({ row });
});
app.post('/api/rows', requireAuth, (req, res) => {
  const data = sanitize(req.body || {});
  if (!data.type) data.type = 'experiment';
  const err = validate(data, false, null);
  if (err) return res.status(400).json({ error: err });
  if (!canCreateRow(req.user, data.track)) return res.status(403).json({ error: 'Forbidden' });
  data.created_by = req.user.username;
  data.updated_by = req.user.username;
  const keys = Object.keys(data);
  const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
    .run(...keys.map(k => data[k]));
  res.status(201).json({ row: db.prepare('SELECT * FROM entries WHERE id = ?').get(Number(info.lastInsertRowid)) });
});
app.put('/api/rows/:id', requireAuth, (req, res) => {
  const existing = db.prepare('SELECT * FROM entries WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Not found' });
  const data = sanitize(req.body || {});
  const nextTrack = (data.track !== undefined && data.track !== existing.track) ? data.track : undefined;
  if (!canEditRow(req.user, existing, nextTrack)) return res.status(403).json({ error: 'Forbidden' });
  const err = validate(data, true, existing);
  if (err) return res.status(400).json({ error: err });
  const keys = Object.keys(data);
  if (keys.length) {
    const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now'), updated_by = ?";
    db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.user.username, req.params.id);
  }
  res.json({ row: db.prepare('SELECT * FROM entries WHERE id = ?').get(req.params.id) });
});
app.delete('/api/rows/:id', requireAuth, (req, res) => {
  if (!canDeleteRow(req.user)) return res.status(403).json({ error: 'Forbidden' });
  db.prepare('DELETE FROM entries WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

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
