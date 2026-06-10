# Task: Add SESSION_SECRET gate, HMAC token signing, secure cookie, .env.example, README

## Parent Spec
specs/auth-hardening-v1.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description

Edit `app/server.js`, create `app/.env.example`, and update `app/README.md`.
Do NOT modify app/db.js, app/public/, prototypes/, sdlc/.

### Change 1 — SESSION_SECRET boot gate (app/server.js)

After `const REQUIRED_FIELDS = ROW_FIELDS.filter(f => f.required).map(f => f.key);` add:

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

### Change 2 — signToken and verifyToken helpers (app/server.js)

Add immediately after the SESSION_SECRET block (before parseCookies):

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

### Change 3 — currentUser: use verifyToken (app/server.js)

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

### Change 4 — login: signToken + secure cookie (app/server.js)

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

### Change 5 — logout: use verifyToken (app/server.js)

Change from:
```javascript
app.post('/api/logout', (req, res) => {
  const token = parseCookies(req)[SID];
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
```

To:
```javascript
app.post('/api/logout', (req, res) => {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
```

### Change 6 — Create app/.env.example

```
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

### Change 7 — README: add Production Environment section

Add a new "## Production Environment" section to `app/README.md` after "## Audit Metadata":

```markdown
## Production Environment

### Environment Variables

| Variable | Required in Production | Description |
|----------|----------------------|-------------|
| `SESSION_SECRET` | **Yes** | Cryptographic signing key for session tokens. Min 32 chars. Boot fails if absent. |
| `NODE_ENV` | Yes (set to `production`) | Controls demo seed, cookie security, and startup checks. |
| `PORT` | No | Server port. Defaults to 3000. |

Generate a secret:

    node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

Copy `app/.env.example` to `app/.env` and fill in values. Load before starting the server.

### Production Safety

- `NODE_ENV=production` + missing or weak `SESSION_SECRET` → boot refuses immediately.
- Demo credentials (`admin/admin123`, `vasu/vasu123`) are **not seeded** in production.
  If the database has no users, a warning is logged. Create users before accepting connections.
- Session cookies use `Secure` flag in production (HTTPS only).
- Session cookies are always `HttpOnly` and `SameSite=Lax`.

### Local Development

No env vars required for local development. Demo credentials are seeded automatically on
first boot. Run `npm start` from the `app/` directory.
```

### Preservation requirements

- `parseCookies()` — unchanged
- `requireAuth()` — unchanged
- `validate()` — unchanged
- `sanitize()` — unchanged
- All CRUD routes — unchanged
- Audit stamping via `req.user.username` — unchanged
- API error format `{ "error": "..." }` — unchanged

## Acceptance Criteria
- [ ] SESSION_SECRET constant defined with production gate.
- [ ] Boot fails with FATAL message if NODE_ENV=production and SESSION_SECRET missing.
- [ ] Boot fails with FATAL message if NODE_ENV=production and SESSION_SECRET < 32 chars.
- [ ] signToken() function: returns `${token}.${hmac}`.
- [ ] verifyToken() function: returns raw token if HMAC valid; null otherwise.
- [ ] currentUser() uses verifyToken() instead of raw cookie value.
- [ ] Login cookie value is signToken(token), not raw token.
- [ ] Login cookie has `secure: NODE_ENV === 'production'`.
- [ ] Logout uses verifyToken() before DB delete.
- [ ] app/.env.example created with SESSION_SECRET, NODE_ENV, PORT.
- [ ] README has Production Environment section.
- [ ] validate(), sanitize(), requireAuth(), parseCookies() unchanged.
- [ ] All CRUD routes unchanged.
- [ ] Local dev boot works without env vars.

## Files Likely Affected
- `app/server.js`
- `app/.env.example`
- `app/README.md`

## Blocked By
- tasks/auth-hardening-v1-001.md
