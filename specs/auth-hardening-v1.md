# Spec: Auth Hardening V1

## Status
approved

## Phase
phase-build

## Feature Slug
auth-hardening-v1

## Goal
Harden the session/auth layer for client demo and deployment readiness. Introduce
SESSION_SECRET as a HMAC signing key and production boot gate, add secure cookie flag
in production, gate demo credential seeding on non-production environments, and document
all env requirements.

## Recon
ai/recon/auth-hardening-v1-recon.md

## Allowed Mutation Surfaces
- app/server.js
- app/db.js
- app/README.md
- app/package.json
- app/.env.example
- ai/recon/auth-hardening-v1-recon.md
- ai/engineering-journal.md
- ai/state_registry.json
- specs/auth-hardening-v1.md
- tasks/auth-hardening-v1-001.md
- tasks/auth-hardening-v1-002.md
- tasks/auth-hardening-v1-003.md
- tasks/auth-hardening-v1-004.md

Do NOT modify: app/public/app.js, app/public/style.css, app/public/index.html, prototypes/, sdlc/.

---

## Data Model Changes

Gate demo credential seeding on `NODE_ENV !== 'production'` in `app/db.js`.

### Current behavior (db.js lines 83–87)

```javascript
if (db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}
```

### Change: gate demo seed and add production warning

Replace with:

```javascript
// Seed demo users only in non-production environments.
if (process.env.NODE_ENV !== 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}
if (process.env.NODE_ENV === 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  console.warn('WARNING: No users exist in the database. See README for production setup instructions.');
}
```

**Why**: Prevents `admin/admin123` from silently existing on a fresh production DB.

---

## API Surface

All changes in `app/server.js`. Token signing changes affect login, logout, and currentUser.

### Change 1 — SESSION_SECRET boot gate (add near top, after imports)

Add after the existing constant definitions (after `const REQUIRED_FIELDS = ...`):

```javascript
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
```

**Why**: Ensures production deployments have an explicit cryptographic secret. Dev is unaffected.

### Change 2 — signToken and verifyToken helpers

Add immediately after the SESSION_SECRET block:

```javascript
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
```

**Why**: HMAC-signs the session token before placing in cookie. Verifies server-issued tokens
before touching the DB. Uses `timingSafeEqual` to prevent timing attacks.

### Change 3 — currentUser: use verifyToken

Change from:
```javascript
function currentUser(req) {
  const token = parseCookies(req)[SID];
  if (!token) return null;
  return db.prepare(
    'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
  ).get(token) || null;
}
```

To:
```javascript
function currentUser(req) {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (!token) return null;
  return db.prepare(
    'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
  ).get(token) || null;
}
```

### Change 4 — login: use signToken and add secure cookie

Change cookie line from:
```javascript
  res.cookie(SID, token, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 7 * 24 * 3600 * 1000 });
```

To:
```javascript
  res.cookie(SID, signToken(token), {
    httpOnly: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 7 * 24 * 3600 * 1000,
    secure: process.env.NODE_ENV === 'production',
  });
```

### Change 5 — logout: use verifyToken

Change from:
```javascript
app.post('/api/logout', (req, res) => {
  const token = parseCookies(req)[SID];
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.clearCookie(SID, { path: '/' });
  res.json({ ok: true });
});
```

To:
```javascript
app.post('/api/logout', (req, res) => {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.clearCookie(SID, { path: '/' });
  res.json({ ok: true });
});
```

### Add app/.env.example

Create `app/.env.example`:

```env
# Copy to .env and fill in values before deploying.
# Node does not load .env automatically — set env vars in your shell, docker-compose,
# or a process manager. Example: export SESSION_SECRET=... && npm start

# Required in production (NODE_ENV=production). Must be 32+ characters.
# Generate: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
SESSION_SECRET=replace-with-a-strong-random-secret-at-least-32-characters

# Set to "production" for production deployments.
NODE_ENV=development

# Port (optional, defaults to 3000).
# PORT=3000
```

### README update

Add a new "## Production Environment" section after the "## Audit Metadata" section in `app/README.md`.

Contents:
```markdown
## Production Environment

### Environment Variables

| Variable | Required in Production | Description |
|----------|----------------------|-------------|
| `SESSION_SECRET` | **Yes** | Cryptographic signing key for session tokens. Min 32 chars. Boot fails if absent. |
| `NODE_ENV` | Yes (set to `production`) | Controls demo seed, cookie security, and startup checks. |
| `PORT` | No | Server port. Defaults to 3000. |

Generate a secret:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copy `app/.env.example` to `app/.env` and fill in values. Load before starting the server.

### Production Safety

- `NODE_ENV=production` + missing or weak `SESSION_SECRET` → boot refuses immediately.
- Demo credentials (`admin/admin123`, `vasu/vasu123`) are **not seeded** in production.
  If the database has no users, a warning is logged. Create users via direct DB insert or
  a setup script before accepting connections.
- Session cookies use `Secure` flag in production (HTTPS only).
- Session cookies are always `HttpOnly` and `SameSite=Lax`.

### Local Development

No env vars required for local development. Demo credentials are seeded automatically on
first boot. Run `npm start` from the `app/` directory.
```

### Preservation requirements

- `parseCookies()` — unchanged
- `requireAuth()` — unchanged (calls `currentUser()` which now verifies HMAC first)
- `validate()` — unchanged
- `sanitize()` — unchanged
- All CRUD routes — unchanged
- Audit stamping `req.user.username` — unchanged
- Port / listen logic — unchanged
- API error format `{ "error": "..." }` — unchanged

---

## Frontend Surface
none

---

## Verification Gate

**Local development (no SESSION_SECRET env var set):**
1. Server boots (default dev fallback applies).
2. Login admin/admin123 → 200; cookie `sid` is set (now contains `token.hmac`).
3. GET /api/me with cookie → 200 `{ user: { id, username } }`.
4. GET /api/rows with cookie → 200.
5. POST valid row → 201; audit stamp `created_by = 'admin'`.
6. Logout → 200; subsequent GET /api/me → 401.
7. GET /api/rows after logout → 401.
8. Required-field validation: POST without owner → 400 "owner is required".
9. Track enum: POST bad track → 400 "invalid track".

**Production mode:**
10. `NODE_ENV=production npm start` without SESSION_SECRET → boot fails with FATAL error message.
11. `NODE_ENV=production SESSION_SECRET=short npm start` → boot fails (weak secret).
12. `NODE_ENV=production SESSION_SECRET=<64-char-hex> npm start` → boots successfully.
13. `secure` cookie is set (confirmed from login response headers in production mode).

**Invariants:**
14. 5/5 PASS.

**Surface audit:**
15. Only app/server.js, app/db.js, app/README.md, app/.env.example modified.
    No frontend, index.html, style.css, prototypes/, or sdlc/ changes.
