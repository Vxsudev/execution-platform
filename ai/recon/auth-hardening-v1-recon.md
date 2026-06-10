# RECON: auth-hardening-v1

## Capability
Auth Hardening V1

## Date
2026-06-10

## State at Recon
RECON_READY

## Prior Work
- `data-model-audit-trail` (RELEASE_APPROVED) — added created_by/updated_by stamping; req.user.username drives audit metadata.
- `ux-table-hardening-v1` (RELEASE_APPROVED) — audit columns moved to Details modal.
- All capabilities RELEASE_APPROVED. Working tree clean.

---

## 1. Current Session/Auth Implementation (app/server.js)

### Session Token
Line 48:
```javascript
const token = crypto.randomBytes(32).toString('hex');
```
Random 64-character hex string. Cryptographically strong. Stored in the `sessions` DB table.

### Session Storage
Lines 29–31:
```javascript
return db.prepare(
  'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
).get(token) || null;
```
Token is looked up directly in the DB. No in-memory store. Logout invalidates by deleting the row.

### Cookie Settings (line 50)
```javascript
res.cookie(SID, token, { httpOnly: true, sameSite: 'lax', path: '/', maxAge: 7 * 24 * 3600 * 1000 });
```

| Setting | Current | Issue |
|---------|---------|-------|
| `httpOnly` | true | ✅ |
| `sameSite` | 'lax' | ✅ |
| `path` | '/' | ✅ |
| `maxAge` | 7 days | ✅ |
| `secure` | **ABSENT** | ❌ — cookie sent over HTTP in production |

### No HMAC Signing
The raw token (same string stored in DB) is placed directly in the cookie. If an attacker obtains the cookie value, they can query the DB directly. No signature validates that the token was issued by this server's secret key. This is mitigated by the 64-character random token (brute-force infeasible), but token tampering/theft isn't detected before a DB round-trip.

### No Session Secret
No `process.env.SESSION_SECRET` or any cryptographic key is used. The `crypto` module is used only for `randomBytes`. No HMAC, no signing.

### No express-session
`package.json` dependencies: express, bcryptjs only. No express-session. Session is entirely custom.

---

## 2. Demo Credential Seeding (app/db.js lines 83–87)

```javascript
if (db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}
```

**Problem**: Demo credentials are seeded regardless of `NODE_ENV`. A production deployment on a fresh DB will silently create `admin/admin123`.

**Comment on line 82**: `// Seed users (change these in production).` — this comment is the only warning; it's not enforced.

---

## 3. Dependencies
```json
{
  "express": "^4.19.2",
  "bcryptjs": "^2.4.3"
}
```
No `dotenv` — env vars must be set externally (OS env, `.env` file loaded by tooling, docker-compose, etc.). This is fine for V1 — dotenv is optional since Node can read `process.env` directly from the shell environment.

---

## 4. Production Risk Summary

| Risk | Current State | Severity |
|------|--------------|----------|
| `secure` cookie not set | Cookie transmitted over HTTP | HIGH for production |
| Demo users seeded in production | admin/admin123 on fresh prod DB | HIGH |
| No SESSION_SECRET | No server-identity gate | MEDIUM |
| No HMAC cookie signing | Token integrity unverified pre-DB | LOW (mitigated by randomness) |
| Comment "change in production" not enforced | Human relies on noticing comment | HIGH |

---

## 5. Recommended Implementation

### SESSION_SECRET Pattern

Since the app uses a custom token-in-DB session (not express-session), SESSION_SECRET is used as:
1. **Production gate**: fail boot if absent or weak (< 32 chars) in production.
2. **HMAC signing key**: sign the session token before placing in cookie.

HMAC signing flow:
- Login: generate `token = randomBytes(32).hex()`, store in DB, send `${token}.${hmac(token, secret)}` as cookie.
- Verification: parse cookie, split on last `.`, verify HMAC, then query DB with raw token.

This validates server-issued cookies before touching the DB, without breaking the existing session model.

### signToken / verifyToken helpers (server.js)

```javascript
const SESSION_SECRET = process.env.SESSION_SECRET || (process.env.NODE_ENV === 'production' ? null : 'dev-insecure-fallback-do-not-use-in-production');
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
```

### Cookie: add `secure` (server.js)

```javascript
res.cookie(SID, signToken(token), {
  httpOnly: true,
  sameSite: 'lax',
  path: '/',
  maxAge: 7 * 24 * 3600 * 1000,
  secure: process.env.NODE_ENV === 'production',
});
```

### currentUser: use verifyToken (server.js)

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

### logout: use verifyToken (server.js)

```javascript
app.post('/api/logout', (req, res) => {
  const signed = parseCookies(req)[SID];
  const token = verifyToken(signed);
  if (token) db.prepare('DELETE FROM sessions WHERE token = ?').run(token);
  res.clearCookie(SID, { path: '/' });
  res.json({ ok: true });
});
```

### Demo seed gate (db.js)

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

### .env.example (app/.env.example)

```env
# Copy to .env and fill in values before running in production.

# Required in production (NODE_ENV=production). Min 32 chars.
# Generate with: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
SESSION_SECRET=replace-with-a-strong-random-secret-at-least-32-characters

# Set to "production" for production deployments.
NODE_ENV=development

# Port (optional, defaults to 3000).
# PORT=3000
```

---

## 6. Compatibility Notes

- Existing sessions (unsigned raw tokens in DB) will be invalidated on server restart. Users log in again. Acceptable for auth hardening.
- Local development: `SESSION_SECRET` defaults to dev fallback string. No env var setup required.
- `NODE_ENV` defaults to undefined (not 'production') in local dev. All current behavior preserved.
- No frontend change needed — login/logout UX is unchanged; audit stamping via `req.user.username` is unchanged.

---

## 7. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Existing logged-in users are signed out on restart | LOW | Expected behavior for auth hardening |
| No dotenv package — .env file not auto-loaded | LOW | Document that `.env` must be loaded externally or use `source .env && npm start` |
| Production fresh DB has no users | LOW | Document manual user creation or env-var seed |
| HMAC sig comparison in verifyToken | NONE | timingSafeEqual used |

---

## 8. Recommended Mutation Surfaces

| File | Change |
|------|--------|
| `app/server.js` | SESSION_SECRET boot check; signToken/verifyToken; cookie secure; logout uses verifyToken |
| `app/db.js` | Gate demo seed on `NODE_ENV !== 'production'`; warn if production + no users |
| `app/.env.example` | New file: env var documentation |
| `app/README.md` | Auth hardening, production env docs, SESSION_SECRET docs |

No frontend, index.html, style.css, or schema changes needed.
