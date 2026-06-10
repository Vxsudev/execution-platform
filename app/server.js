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
  const token = parseCookies(req)[SID];
  if (!token) return null;
  return db.prepare(
    'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
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
  res.cookie(SID, token, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 7 * 24 * 3600 * 1000 });
  res.json({ user: { id: user.id, username: user.username } });
});
app.post('/api/logout', (req, res) => {
  const token = parseCookies(req)[SID];
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.clearCookie(SID, { path: '/' });
  res.json({ ok: true });
});
app.get('/api/me', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: 'Not authenticated' });
  res.json({ user: u });
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
    }
  }
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
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
  const keys = Object.keys(data);
  const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
    .run(...keys.map(k => data[k]));
  res.status(201).json({ row: db.prepare('SELECT * FROM entries WHERE id = ?').get(Number(info.lastInsertRowid)) });
});
app.put('/api/rows/:id', requireAuth, (req, res) => {
  const existing = db.prepare('SELECT * FROM entries WHERE id = ?').get(req.params.id);
  if (!existing) return res.status(404).json({ error: 'Not found' });
  const data = sanitize(req.body || {});
  const err = validate(data, true, existing);
  if (err) return res.status(400).json({ error: err });
  const keys = Object.keys(data);
  if (keys.length) {
    const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now')";
    db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.params.id);
  }
  res.json({ row: db.prepare('SELECT * FROM entries WHERE id = ?').get(req.params.id) });
});
app.delete('/api/rows/:id', requireAuth, (req, res) => {
  db.prepare('DELETE FROM entries WHERE id = ?').run(req.params.id);
  res.json({ ok: true });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`));
