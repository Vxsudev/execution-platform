// Backend API: auth + rows CRUD. Serves the static frontend from /public.
// DB access goes through the async adapter `dba` (MySQL in production, SQLite for local
// dev) — every handler that touches the DB is async and wrapped for Express-4 error
// forwarding via wrap().
const path = require('path');
const crypto = require('crypto');
const express = require('express');
const bcrypt = require('bcryptjs');
const XLSX = require('xlsx');
const { dba, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');

const app = express();
const defaultJsonParser = express.json();
const importJsonParser = express.json({ limit: '25mb' });
app.use((req, res, next) => {
  // Import routes carry base64 workbook payloads exceeding the default 100kb
  // limit; defer them to a route-level large-limit parser. All other routes
  // keep the default parser unchanged.
  if (req.path === '/api/import/preview' || req.path === '/api/import/commit') return next();
  return defaultJsonParser(req, res, next);
});
app.use(express.static(path.join(__dirname, 'public')));

// Express 4 does not forward async-handler rejections to the error middleware;
// wrap() does it so every async route surfaces failures as a 500 JSON response.
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const SID = 'sid';
const FIELD_KEYS = ROW_FIELDS.map(f => f.key);
const REQUIRED_FIELDS = ROW_FIELDS.filter(f => f.required).map(f => f.key);

function parseScope(user) {
  try { return JSON.parse(user.track_scope || '[]'); } catch (_) { return []; }
}
// Client requirement (2026-06-18): task/experiment create+edit is open to every
// authenticated user, for all owners/tracks. Track ownership is no longer an edit
// boundary (it remains a dashboard/filter view only). Both call sites are behind
// requireAuth, so "any authenticated user" is the floor. Signatures are kept so the
// route guards (and the 403 fallback) stay structurally intact.
function canCreateRow(_user, _track) { return true; }
function canEditRow(_user, _existingRow, _nextTrack) { return true; }
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
async function currentUser(req) {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (!token) return null;
  return (await dba.get(
    'SELECT u.id, u.username, u.role, u.track_scope FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?',
    token
  )) || null;
}
const requireAuth = wrap(async (req, res, next) => {
  const u = await currentUser(req);
  if (!u) return res.status(401).json({ error: 'Not authenticated' });
  req.user = u;
  next();
});

// ---- auth ----
app.post('/api/login', wrap(async (req, res) => {
  const { username, password } = req.body || {};
  if (!username || !password) return res.status(400).json({ error: 'username and password required' });
  const user = await dba.get('SELECT * FROM users WHERE username = ?', String(username).trim());
  if (!user || !bcrypt.compareSync(String(password), user.password_hash)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }
  const token = crypto.randomBytes(32).toString('hex');
  await dba.run('INSERT INTO sessions (token, user_id) VALUES (?, ?)', token, user.id);
  res.cookie(SID, signToken(token), {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 7 * 24 * 3600 * 1000,
    secure: process.env.NODE_ENV === 'production',
  });
  res.json({ user: { id: user.id, username: user.username } });
}));
app.post('/api/logout', wrap(async (req, res) => {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (token) await dba.run('DELETE FROM sessions WHERE token = ?', token);
  res.clearCookie(SID, { path: '/' });
  res.json({ ok: true });
}));
app.get('/api/me', wrap(async (req, res) => {
  const u = await currentUser(req);
  if (!u) return res.status(401).json({ error: 'Not authenticated' });
  res.json({ user: { ...u, track_scope: parseScope(u) } });
}));
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

app.get('/api/rows', requireAuth, wrap(async (req, res) => {
  res.json({ rows: await dba.all('SELECT * FROM entries ORDER BY updated_at DESC, id DESC') });
}));
app.get('/api/rows/:id', requireAuth, wrap(async (req, res) => {
  const row = await dba.get('SELECT * FROM entries WHERE id = ?', req.params.id);
  if (!row) return res.status(404).json({ error: 'Not found' });
  res.json({ row });
}));
app.post('/api/rows', requireAuth, wrap(async (req, res) => {
  const data = sanitize(req.body || {});
  if (!data.type) data.type = 'experiment';
  const err = validate(data, false, null);
  if (err) return res.status(400).json({ error: err });
  if (!canCreateRow(req.user, data.track)) return res.status(403).json({ error: 'Forbidden' });
  data.created_by = req.user.username;
  data.updated_by = req.user.username;
  const keys = Object.keys(data);
  const info = await dba.run(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`,
    ...keys.map(k => data[k]));
  res.status(201).json({ row: await dba.get('SELECT * FROM entries WHERE id = ?', info.insertId) });
}));
app.put('/api/rows/:id', requireAuth, wrap(async (req, res) => {
  const existing = await dba.get('SELECT * FROM entries WHERE id = ?', req.params.id);
  if (!existing) return res.status(404).json({ error: 'Not found' });
  const data = sanitize(req.body || {});
  const nextTrack = (data.track !== undefined && data.track !== existing.track) ? data.track : undefined;
  if (!canEditRow(req.user, existing, nextTrack)) return res.status(403).json({ error: 'Forbidden' });
  const err = validate(data, true, existing);
  if (err) return res.status(400).json({ error: err });
  const keys = Object.keys(data);
  if (keys.length) {
    const setSql = keys.map(k => `${k} = ?`).join(', ') + ', updated_at = ?, updated_by = ?';
    await dba.run(`UPDATE entries SET ${setSql} WHERE id = ?`,
      ...keys.map(k => data[k]), dba.nowStamp(), req.user.username, req.params.id);
  }
  res.json({ row: await dba.get('SELECT * FROM entries WHERE id = ?', req.params.id) });
}));
app.delete('/api/rows/:id', requireAuth, wrap(async (req, res) => {
  if (!canDeleteRow(req.user)) return res.status(403).json({ error: 'Forbidden' });
  await dba.run('DELETE FROM entries WHERE id = ?', req.params.id);
  res.json({ ok: true });
}));

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

app.get('/api/users', requireAuth, wrap(async (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const users = await dba.all('SELECT id, username, role, track_scope, created_at FROM users ORDER BY id');
  res.json({ users: users.map(publicUser) });
}));

app.post('/api/users', requireAuth, wrap(async (req, res) => {
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
    const info = await dba.run('INSERT INTO users (username, password_hash, role, track_scope) VALUES (?, ?, ?, ?)',
      String(username).trim(), hash, normalizedRole, normalizedScope);
    const created = await dba.get('SELECT id, username, role, track_scope, created_at FROM users WHERE id = ?', info.insertId);
    res.status(201).json({ user: publicUser(created) });
  } catch (e) {
    if (dba.isUniqueViolation(e)) {
      return res.status(400).json({ error: 'username already exists' });
    }
    throw e;
  }
}));

app.put('/api/users/:id', requireAuth, wrap(async (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  const existing = await dba.get('SELECT id, username, role, track_scope, created_at FROM users WHERE id = ?', id);
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
    await dba.run(`UPDATE users SET ${setClause} WHERE id = ?`, ...Object.values(updates), id);
  }
  const updated = await dba.get('SELECT id, username, role, track_scope, created_at FROM users WHERE id = ?', id);
  res.json({ user: publicUser(updated) });
}));

app.delete('/api/users/:id', requireAuth, wrap(async (req, res) => {
  if (!canManageUsers(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  if (req.user.id === id) return res.status(403).json({ error: 'cannot delete your own account' });
  const existing = await dba.get('SELECT id FROM users WHERE id = ?', id);
  if (!existing) return res.status(404).json({ error: 'user not found' });
  await dba.run('DELETE FROM sessions WHERE user_id = ?', id);
  await dba.run('DELETE FROM users WHERE id = ?', id);
  res.json({ ok: true });
}));

// ---- xlsx import (admin only) ----
const IMPORT_SHEET = 'All Experiment Summary';
// Workbook header label (summary sheet, row 4) → entries DB column. Only these
// labels are read, so the side STATUS SUMMARY / Count stats panel is ignored.
const IMPORT_HEADER_MAP = {
  'Owner': 'owner',
  'Track': 'track',
  'Experiment Title': 'title',
  'Function': 'function_area',
  'Parent Item': 'parent_item',
  'Description / Hypothesis': 'hypothesis',
  'Experiment Design': 'design',
  'Success Criteria': 'success_criteria',
  'Target End Date': 'target_end_date',
  'Dependencies': 'dependencies',
  'Test outcome / Finding': 'outcome',
  'Next Action': 'next_action',
  'Status': 'status',
};

// Open-mode (capture-first) defaults. Every non-empty Sheet 2 row imports; blank fields are
// defaulted, never skipped (fully-blank rows are dropped by parseImportWorkbook).
const IMPORT_UNASSIGNED_OWNER = 'Unassigned';
const IMPORT_UNASSIGNED_TRACK = 'Unassigned Track';
const IMPORT_DEFAULT_STATUS = 'Not Started';
const IMPORT_UNTITLED = 'Untitled';

function resolveImportSheet(wb) {
  if (wb.SheetNames.includes(IMPORT_SHEET)) return IMPORT_SHEET;
  return wb.SheetNames.find((n) => /summary/i.test(n)) || null;
}

function pad2(n) { return String(n).padStart(2, '0'); }
function normalizeImportValue(field, value) {
  if (value === null || value === undefined) return '';
  if (field === 'target_end_date') {
    // Excel date cells arrive as serial numbers; SSF.parse_date_code is pure and
    // timezone-safe (a JS Date would drift a calendar day under TZ behind UTC).
    if (typeof value === 'number' && isFinite(value)) {
      const d = XLSX.SSF.parse_date_code(value);
      if (d && d.y) return `${d.y}-${pad2(d.m)}-${pad2(d.d)}`;
    }
    if (value instanceof Date && !isNaN(value.getTime())) {
      return `${value.getUTCFullYear()}-${pad2(value.getUTCMonth() + 1)}-${pad2(value.getUTCDate())}`;
    }
  }
  return String(value).trim();
}

// Parse a decoded XLSX buffer → { sheet, rows: [{ row_number, data }] } or { error }.
// row_number is the 1-indexed spreadsheet row; fully-empty mapped rows are skipped.
// Read WITHOUT cellDates so date cells stay as Excel serials and are converted
// via XLSX.SSF (pure, timezone-immune) — JS Date drifts a day under non-UTC TZ.
function parseImportWorkbook(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' });
  const sheet = resolveImportSheet(wb);
  if (!sheet) return { error: 'summary sheet not found' };
  const matrix = XLSX.utils.sheet_to_json(wb.Sheets[sheet], { header: 1, defval: null, blankrows: true });
  let headerIdx = -1;
  for (let i = 0; i < matrix.length; i++) {
    const cells = (matrix[i] || []).map((c) => (c == null ? '' : String(c).trim()));
    if (cells.includes('Owner') && cells.includes('Track') && cells.includes('Experiment Title')) { headerIdx = i; break; }
  }
  if (headerIdx < 0) return { error: `header row not found in sheet "${sheet}"` };
  const header = (matrix[headerIdx] || []).map((c) => (c == null ? '' : String(c).trim()));
  const colToField = {};
  header.forEach((label, idx) => { if (IMPORT_HEADER_MAP[label]) colToField[idx] = IMPORT_HEADER_MAP[label]; });
  const rows = [];
  for (let i = headerIdx + 1; i < matrix.length; i++) {
    const raw = matrix[i] || [];
    const data = {};
    for (const idx of Object.keys(colToField)) data[colToField[idx]] = normalizeImportValue(colToField[idx], raw[idx]);
    if (Object.values(data).every((v) => v === '')) continue;
    rows.push({ row_number: i + 1, data });
  }
  return { sheet, rows };
}

// Open-mode classification (capture-first). Every row reaching this point has real data
// (parseImportWorkbook drops fully-blank rows), so all are importable; blank title/owner/track/
// status are defaulted and/or warned, never blocking:
//   - blank owner  → "Unassigned"          (warn)
//   - blank track  → "Unassigned Track"     (warn);  non-canonical track imports AS-IS (warn) — track is free TEXT
//   - blank status → "Not Started"          (warn);  non-canonical status COERCED to "Not Started" (warn)
// status is coerced because entries.status is validated to its five canonical values;
// type is coerced to a canonical value for the same reason. Returns normalized data + warnings.
function classifyImportRow(data) {
  const d = data && typeof data === 'object' ? (data.data && typeof data.data === 'object' ? data.data : data) : {};
  const title = d.title == null ? '' : String(d.title).trim();
  const out = {};
  for (const k of FIELD_KEYS) {
    if (d[k] !== undefined && d[k] !== null) out[k] = String(d[k]).trim();
  }
  const warnings = [];
  // Inclusive capture: a blank Experiment Title is defaulted (like owner/track/status) rather
  // than skipped, so every non-empty Sheet 2 row imports. Fully-blank rows are dropped earlier
  // by parseImportWorkbook, so this never imports an empty row.
  if (title) { out.title = title; }
  else { out.title = IMPORT_UNTITLED; warnings.push('title blank; set to Untitled'); }
  if (!out.owner) { out.owner = IMPORT_UNASSIGNED_OWNER; warnings.push('owner blank; set to Unassigned'); }
  if (!out.track) { out.track = IMPORT_UNASSIGNED_TRACK; warnings.push('track blank; set to Unassigned Track'); }
  else if (!TRACKS.includes(out.track)) { warnings.push(`non-canonical track "${out.track}" imported as-is`); }
  if (!out.status) { out.status = IMPORT_DEFAULT_STATUS; warnings.push('status blank; set to Not Started'); }
  else if (!STATUSES.includes(out.status)) { warnings.push(`status "${out.status}" not a canonical status; stored as Not Started`); out.status = IMPORT_DEFAULT_STATUS; }
  out.type = (out.type && ROW_TYPES.includes(out.type)) ? out.type : 'experiment';
  return { importable: true, warnings, data: out };
}

function toImportRow(data) {
  const out = {};
  for (const k of FIELD_KEYS) {
    if (data[k] !== undefined && data[k] !== null && String(data[k]) !== '') out[k] = String(data[k]);
  }
  out.type = (data.type && ROW_TYPES.includes(data.type)) ? data.type : 'experiment';
  return out;
}

function normalizeDupValue(v) {
  if (v == null || v === '') return '';
  return String(v).trim().replace(/\s+/g, ' ').toLowerCase();
}

function buildLogicalDupKey(data) {
  return [normalizeDupValue(data.title), normalizeDupValue(data.owner), normalizeDupValue(data.track)].join('|');
}

const DUP_LOGIC_SQL = "SELECT id FROM entries WHERE lower(trim(title))=? AND lower(trim(coalesce(owner,'')))=? AND lower(trim(coalesce(track,'')))=? LIMIT 1";

async function findDuplicateForImportRow(data, sourceSheet, sourceRow) {
  if (sourceSheet && sourceRow) {
    const byPos = await dba.get(
      'SELECT id FROM entries WHERE import_source_sheet = ? AND import_source_row = ? LIMIT 1',
      sourceSheet, sourceRow);
    if (byPos) {
      const byLogic = await dba.get(DUP_LOGIC_SQL,
        normalizeDupValue(data.title), normalizeDupValue(data.owner || ''), normalizeDupValue(data.track || ''));
      return {
        duplicate: true,
        duplicate_reason: byLogic ? 'source_and_logical_match' : 'source_row_match',
        duplicate_entry_id: byPos.id
      };
    }
  }
  const byLogic = await dba.get(DUP_LOGIC_SQL,
    normalizeDupValue(data.title), normalizeDupValue(data.owner || ''), normalizeDupValue(data.track || ''));
  if (byLogic) {
    return { duplicate: true, duplicate_reason: 'logical_match', duplicate_entry_id: byLogic.id };
  }
  return { duplicate: false };
}

app.post('/api/import/preview', importJsonParser, requireAuth, wrap(async (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const { filename, content_base64 } = req.body || {};
  if (!filename || !/\.xlsx$/i.test(String(filename))) return res.status(400).json({ error: 'filename must end in .xlsx' });
  if (!content_base64 || typeof content_base64 !== 'string') return res.status(400).json({ error: 'content_base64 is required' });
  let parsed;
  try {
    const buffer = Buffer.from(content_base64, 'base64');
    parsed = parseImportWorkbook(buffer);
  } catch (_) { return res.status(400).json({ error: 'failed to parse workbook' }); }
  if (parsed.error) return res.status(400).json({ error: parsed.error });
  const rows = [];
  const skipped_rows = [];
  let warning_count = 0;
  let duplicate_count = 0;
  for (const { row_number, data } of parsed.rows) {
    const c = classifyImportRow(data);
    if (!c.importable) { skipped_rows.push({ row_number, reason: c.reason, data }); continue; }
    warning_count += c.warnings.length;
    const dupResult = await findDuplicateForImportRow(c.data, parsed.sheet, row_number);
    if (dupResult.duplicate) duplicate_count++;
    rows.push({ row_number, warnings: c.warnings, data: c.data, duplicate: dupResult.duplicate, duplicate_reason: dupResult.duplicate_reason, duplicate_entry_id: dupResult.duplicate_entry_id });
  }
  // Projected true-capture counts (P3-4). Estimates only — preview writes nothing.
  const observed_sheet_count = parsed.sheet ? 1 : 0;
  const observation_count = rows.length + skipped_rows.length + observed_sheet_count;
  res.json({
    summary: { sheet: parsed.sheet, total_rows: parsed.rows.length, importable_rows: rows.length, skipped_rows: skipped_rows.length, warning_count, duplicate_count, observed_sheet_count, observation_count },
    rows,
    skipped_rows,
  });
}));

app.post('/api/import/commit', importJsonParser, requireAuth, wrap(async (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const { filename, sheet, rows } = req.body || {};
  if (!filename || typeof filename !== 'string' || !filename.trim() || !/\.xlsx$/i.test(filename))
    return res.status(400).json({ error: 'filename must be a non-empty string ending in .xlsx' });
  const sheetName = typeof sheet === 'string' ? sheet : '';
  if (!Array.isArray(rows)) return res.status(400).json({ error: 'rows array is required' });
  const allow_duplicates = req.body.allow_duplicates === true;
  // P3-4: optional parse-skipped rows forwarded from the preview, captured as
  // observations (never inserted into entries). Backward compatible — defaults to [].
  const payloadSkipped = Array.isArray(req.body.skipped_rows) ? req.body.skipped_rows : [];

  // First pass: classify + detect duplicates, compute all counts before INSERT.
  let importable_rows = 0, parse_skipped = 0, warning_count = 0, duplicate_count = 0;
  const classified = [];
  for (let i = 0; i < rows.length; i++) {
    const { data, row_number } = rows[i] || {};
    const c = classifyImportRow(data || {});
    if (!c.importable) { parse_skipped++; classified.push({ index: i, c, row_number, dupResult: null }); continue; }
    importable_rows++;
    warning_count += c.warnings.length;
    const dupResult = await findDuplicateForImportRow(c.data, sheetName, row_number);
    if (dupResult.duplicate) duplicate_count++;
    classified.push({ index: i, c, row_number, dupResult });
  }

  const dup_skipped = allow_duplicates ? 0 : duplicate_count;
  const total_skipped = parse_skipped + dup_skipped;

  const batchInfo = await dba.run(
    'INSERT INTO imports (filename, imported_by, total_rows, importable_rows, skipped_rows, warning_count, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
    filename, req.user.username, rows.length, importable_rows, total_skipped, warning_count, 'complete');
  const batch_id = Number(batchInfo.insertId);

  const ids = [];
  const skipped = [];
  // P3-4: collect per-row outcomes to build workbook observations after the loop.
  const insertedObs = [];   // { source_row, entry_id, data }
  const dupObs = [];        // { source_row, data, duplicate_entry_id }
  for (const { index: i, c, row_number, dupResult } of classified) {
    if (!c.importable) { skipped.push({ index: i, reason: c.reason }); continue; }
    if (!allow_duplicates && dupResult && dupResult.duplicate) {
      skipped.push({ index: i, reason: 'duplicate' });
      dupObs.push({ source_row: typeof row_number === 'number' ? row_number : null, data: c.data, duplicate_entry_id: dupResult.duplicate_entry_id });
      continue;
    }
    const row = toImportRow(c.data);
    row.created_by = req.user.username;
    row.updated_by = req.user.username;
    row.import_batch_id = batch_id;
    row.import_source_sheet = sheetName;
    row.import_source_row = typeof row_number === 'number' ? row_number : null;
    try {
      const keys = Object.keys(row);
      const info = await dba.run(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`,
        ...keys.map((k) => row[k]));
      const entry_id = Number(info.insertId);
      ids.push(entry_id);
      insertedObs.push({ source_row: row.import_source_row, entry_id, data: c.data });
    } catch (e) {
      skipped.push({ index: i, reason: 'insert failed: ' + (e && e.message ? e.message : 'unknown error') });
    }
  }

  // P3-4 true workbook capture: record observations linked to the batch. These
  // are audit/source reality — never execution rows. A batch always carries at
  // least the workbook_sheet observation, so a zero-insert attempt still proves
  // captured workbook content.
  let observation_count = 0;
  const addObs = async (source_row, observation_type, status, reason, rawObj) => {
    await dba.run(
      'INSERT INTO import_observations (import_batch_id, source_sheet, source_row, observation_type, status, reason, raw_data) VALUES (?, ?, ?, ?, ?, ?, ?)',
      batch_id, sheetName || null, source_row, observation_type, status, reason, rawObj == null ? null : JSON.stringify(rawObj));
    observation_count++;
  };
  // 1) Always: one workbook_sheet observation capturing the attempt + counts.
  await addObs(null, 'workbook_sheet', 'captured', ids.length === 0 ? 'zero execution rows inserted' : null, {
    total_rows: rows.length, importable_rows, inserted: ids.length, duplicate_skipped: dup_skipped, parse_skipped,
  });
  // 2) One per inserted execution row.
  for (const o of insertedObs) await addObs(o.source_row, 'imported_entry', 'imported', null, { ...o.data, entry_id: o.entry_id });
  // 3) One per duplicate-skipped row.
  for (const o of dupObs) await addObs(o.source_row, 'duplicate_skipped', 'skipped', 'duplicate', { ...o.data, duplicate_entry_id: o.duplicate_entry_id });
  // 4) One per parse-skipped row forwarded from the preview.
  for (const s of payloadSkipped) {
    if (!s || typeof s !== 'object') continue;
    const sr = typeof s.row_number === 'number' ? s.row_number : null;
    await addObs(sr, 'skipped_row', 'skipped', typeof s.reason === 'string' ? s.reason : 'skipped', s.data != null ? s.data : null);
  }

  res.json({ ok: true, batch_id, inserted_count: ids.length, ids, skipped_count: skipped.length, skipped, duplicate_count, duplicate_skipped_count: dup_skipped, observation_count });
}));

app.get('/api/imports', requireAuth, wrap(async (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const imports = await dba.all(
    'SELECT id, filename, imported_by, imported_at, total_rows, importable_rows, skipped_rows, warning_count, status, ' +
    '(SELECT COUNT(*) FROM import_observations o WHERE o.import_batch_id = imports.id) AS observation_count ' +
    'FROM imports ORDER BY id DESC'
  );
  res.json({ imports });
}));

app.delete('/api/imports/:id', requireAuth, wrap(async (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) return res.status(400).json({ error: 'invalid import id' });
  const existing = await dba.get('SELECT id FROM imports WHERE id = ?', id);
  if (!existing) return res.status(404).json({ error: 'import batch not found' });
  try {
    const result = await dba.tx(async (t) => {
      // Evidence-based legacy recovery: entries created by this batch under an older code
      // version were not stamped with import_batch_id, but this batch's imported_entry
      // observations recorded their entry_id in raw_data. Collect those ids (before deleting
      // the observations) so the batch delete removes them too. Batch-scoped and evidence-based
      // only — no heuristic matching and no global orphan sweep, so manual rows (never named in
      // any observation) are never touched.
      const legacyIds = [];
      for (const o of await t.all(
        "SELECT raw_data FROM import_observations WHERE import_batch_id = ? AND observation_type = 'imported_entry'", id)) {
        if (!o.raw_data) continue;
        let parsed; try { parsed = JSON.parse(o.raw_data); } catch (_) { continue; }
        const eid = parsed && parsed.entry_id;
        if (Number.isInteger(eid) && eid > 0) legacyIds.push(eid);
      }

      const deleted_observation_count = (await t.run('DELETE FROM import_observations WHERE import_batch_id = ?', id)).changes;
      let deleted_entry_count = (await t.run('DELETE FROM entries WHERE import_batch_id = ?', id)).changes;

      // Remove any entries this batch's observations name that weren't already deleted above
      // (legacy orphans whose import_batch_id was NULL). Current imports' rows were removed by
      // the import_batch_id delete, so they are not double-counted here.
      let deleted_legacy_count = 0;
      if (legacyIds.length) {
        const placeholders = legacyIds.map(() => '?').join(',');
        deleted_legacy_count = (await t.run(`DELETE FROM entries WHERE id IN (${placeholders})`, ...legacyIds)).changes;
        deleted_entry_count += deleted_legacy_count;
      }

      await t.run('DELETE FROM imports WHERE id = ?', id);
      return { deleted_observation_count, deleted_entry_count, deleted_legacy_count };
    });
    res.json({ ok: true, ...result, deleted_import_id: id });
  } catch (e) {
    res.status(500).json({ error: 'delete failed: ' + (e && e.message ? e.message : 'unknown error') });
  }
}));

// Catch-all error handler: surfaces async-handler rejections forwarded by wrap().
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('Unhandled route error:', err && err.message ? err.message : 'unknown error');
  if (res.headersSent) return next(err);
  res.status(500).json({ error: 'internal error' });
});

const PORT = process.env.PORT || 3000;
dba.init()
  .then(() => app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`)))
  .catch((err) => {
    // Safe-log policy: never print credentials or the connection URL — code only.
    console.error('FATAL: database initialization failed:', err && err.code ? err.code : 'unknown error');
    process.exit(1);
  });

module.exports = app;
