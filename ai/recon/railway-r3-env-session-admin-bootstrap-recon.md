# Railway R3 — Env / Session / First-Admin Bootstrap: Recon

**Feature Slug:** railway-r3-env-session-admin-bootstrap  
**Date:** 2026-06-17  
**Author:** AI Engineering OS (in-session worker)  
**Depends on:** R0 (3ca17f0), R1 (b113f11), R2 (a3c1f55)

---

## 1. Recon Objective

Strict read-only recon for R3. Validate the current production login failure mode, SESSION_SECRET
guard, demo seed behavior, admin creation path, and design the first-admin bootstrap mechanism.
No app mutations, no Railway deployment, no volume provisioning.

---

## 2. Files Read

| File | Purpose |
|------|---------|
| `app/server.js` (full, 603 lines) | SESSION_SECRET guard, auth routes, user management routes, cookie config |
| `app/db.js` (full, ~150 lines after R2) | Demo seed, production seed warning, bcrypt usage, module exports |
| `app/.env.example` | Current env contract (now includes DB_PATH from R2) |
| `app/README.md` | R2 state; R3 caveat still listed |
| `app/package.json` | scripts: `"start": "node server.js"`; no bootstrap script |
| `ai/state_registry.json` | `railway-r3-env-session-admin-bootstrap` absent → fresh lifecycle |

Local governance surfaces checked:

| File | Status |
|------|--------|
| `ai/product-invariants.md` | Absent |
| `ai/runtime-contracts.md` | Absent |
| `ai/service-boundaries.md` | Absent |
| `ai/coding-patterns.md` | Absent |
| `ai/repo-index.md` | Absent |
| `ai/invariant-registry.md` | Present |

---

## 3. Commands Run

```bash
git status --short && git log --oneline -4
# → clean (2 pre-existing untracked files); HEAD=a3c1f55
bash vendor/engineering-os/scripts/os-adapter-check.sh  # → 12/12 PASS
bash scripts/invariant-check.sh                          # → 5/5 PASS
```

---

## 4. Blocker B4 Evidence

**B4 root cause — bootstrap deadlock:**

- `app/db.js:112-116`: demo seed runs only in NON-production (`NODE_ENV !== 'production'`).
- `app/db.js:117-119`: production finds zero users → logs WARNING, exits normally.
- `app/server.js:232`: `POST /api/users` requires `requireAuth` + `canManageUsers(user)` → admin role.
- `app/server.js:41`: `canManageUsers(user)` = `user.role === 'admin'`.

**In production with zero users:** no one can log in → no session → `requireAuth` → 401 on every route
including `POST /api/users`. There is no unauthenticated user-creation route. First admin cannot
be created through the API. Manual SQLite surgery is currently the only path — B4.

---

## 5. SESSION_SECRET Guard (app/server.js:45–54)

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

**Analysis:**
- `NODE_ENV=production` + `SESSION_SECRET` unset → `process.exit(1)` ✓ (already correct)
- `NODE_ENV=production` + `SESSION_SECRET` < 32 chars → `process.exit(1)` ✓ (already correct)
- `NODE_ENV` not production + `SESSION_SECRET` unset → dev fallback, no exit ✓ (dev convenience)
- `NODE_ENV=production` + `SESSION_SECRET` ≥ 32 chars → proceeds ✓

**R3 action:** SESSION_SECRET guard is already production-correct. No changes needed. Document only.

---

## 6. Demo Seed Behavior (app/db.js:111–125)

```javascript
// Seed demo users only in non-production environments.
if (process.env.NODE_ENV !== 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}
if (process.env.NODE_ENV === 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  console.warn('WARNING: No users exist in the database. ...');
}
// Backfill demo user roles after seed so the UPDATE finds existing rows on fresh boot.
if (process.env.NODE_ENV !== 'production') {
  db.exec("UPDATE users SET role = 'admin' WHERE username = 'admin' ...;");
  ...
}
```

**Analysis:**
- `NODE_ENV !== 'production'` + count=0 → seeds `admin/admin123` and `vasu/vasu123`
- `NODE_ENV === 'production'` + count=0 → logs warning only (no seed)
- Demo credentials never appear in production ✓
- R3 bootstrap is placed after the non-production seed, before the production warning check

---

## 7. Password Hashing (app/server.js:245, app/db.js:6,113-115)

- `bcrypt` imported via `bcryptjs` (line 6 in db.js; line 5 in server.js)
- Dev seed: `bcrypt.hashSync('admin123', 10)` at db.js:113-114
- User creation: `bcrypt.hashSync(String(password), 10)` at server.js:245
- User update: `bcrypt.hashSync(String(password), 10)` at server.js:280
- Password hash never returned by any API endpoint (`publicUser()` at server.js:222-224 returns `id, username, role, track_scope, created_at` only)
- `SELECT *` in `POST /api/login` uses password_hash for bcrypt.compareSync, does NOT return it

**R3 bootstrap:** must use `bcrypt.hashSync(bootstrapPass.trim(), 10)` — same pattern ✓

---

## 8. User Management Routes (app/server.js:208–299)

- `GET /api/users` — admin only (`requireAuth` + `canManageUsers`)
- `POST /api/users` — admin only; creates user with bcrypt hash; role validation; UNIQUE constraint catch
- `PUT /api/users/:id` — admin only; cannot demote own account
- `DELETE /api/users/:id` — admin only; cannot delete own account

**Key:** all routes behind `requireAuth` → admin cannot be created via API without an existing admin.

`VALID_ROLES = ['admin', 'track_owner', 'viewer']` at server.js:209.

`normalizeTrackScope('admin', ...)` returns `JSON.stringify([])` = `'[]'` for admin (line 216).

---

## 9. Cookie Security (app/server.js:108–114)

```javascript
res.cookie(SID, signToken(token), {
  httpOnly: true,
  sameSite: 'lax',
  path: '/',
  maxAge: 7 * 24 * 3600 * 1000,
  secure: process.env.NODE_ENV === 'production',
});
```

- `httpOnly: true` — JS cannot read cookie ✓
- `sameSite: 'lax'` — CSRF protection ✓
- `secure: NODE_ENV === 'production'` — HTTPS-only in production ✓
- Session tokens: 32-byte random hex, HMAC-SHA256 signed

**R3 action:** cookie security correct. No changes needed.

---

## 10. Selected First-Admin Bootstrap Design

**Design:** env-driven one-time bootstrap at DB module load time (`app/db.js`).

**Location rationale:** `db.js` already handles all DB setup and seeding; `bcrypt` is imported
there. Bootstrap runs synchronously at require-time (before Express listens), consistent with
existing seed pattern. `process.exit(1)` from db.js terminates the process before the server
starts, which is the correct fail-closed behavior.

**Environment variables:**
- `BOOTSTRAP_ADMIN_USERNAME` — desired admin username
- `BOOTSTRAP_ADMIN_PASSWORD` — admin password (min 12 chars; remove from env after first boot)

**Behavior:**

| Condition | Action |
|-----------|--------|
| `NODE_ENV !== 'production'` | Skip entirely (non-production uses demo seed) |
| `NODE_ENV=production`, both vars unset | Skip (normal boot if admin already exists) |
| `NODE_ENV=production`, only one var set | `process.exit(1)` — FATAL (partial config) |
| `NODE_ENV=production`, both vars set, password < 12 chars | `process.exit(1)` — FATAL |
| `NODE_ENV=production`, both vars set, admin already exists | Log "skipping", proceed |
| `NODE_ENV=production`, both vars set, no admin exists | Create admin with bcrypt hash, log username (NOT password) |

**Idempotency:** checks `WHERE role = 'admin'` count before inserting. Second boot with same
vars → finds admin → skips → no duplicate.

**Never logs password:** only `console.log` the username in the success message.

**Implementation in `app/db.js`** — insert between the non-production seed block (lines 112-116)
and the production zero-users warning (lines 117-119):

```javascript
// Bootstrap a first admin from env on initial production boot. No-op if admin exists.
// Fails closed if exactly one bootstrap var is set (partial config unsafe in production).
if (process.env.NODE_ENV === 'production') {
  const _bUser = process.env.BOOTSTRAP_ADMIN_USERNAME;
  const _bPass = process.env.BOOTSTRAP_ADMIN_PASSWORD;
  const _hasUser = Boolean(_bUser && _bUser.trim());
  const _hasPass = Boolean(_bPass && _bPass.trim());
  if (_hasUser !== _hasPass) {
    console.error('FATAL: BOOTSTRAP_ADMIN_USERNAME and BOOTSTRAP_ADMIN_PASSWORD must both be set or both be unset.');
    process.exit(1);
  }
  if (_hasUser && _hasPass) {
    if (_bPass.trim().length < 12) {
      console.error('FATAL: BOOTSTRAP_ADMIN_PASSWORD must be at least 12 characters.');
      process.exit(1);
    }
    const _adminCount = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'admin'").get().c;
    if (_adminCount === 0) {
      db.prepare("INSERT INTO users (username, password_hash, role, track_scope) VALUES (?, ?, 'admin', '[]')")
        .run(_bUser.trim(), bcrypt.hashSync(_bPass.trim(), 10));
      console.log(`Bootstrap: admin user '${_bUser.trim()}' created.`);
    } else {
      console.log('Bootstrap: admin already exists, skipping.');
    }
  }
}
```

---

## 11. Production Env Contract (complete)

| Variable | Required in Production | Notes |
|----------|----------------------|-------|
| `NODE_ENV` | Yes → `production` | Controls seed, cookie security, SESSION_SECRET guard |
| `SESSION_SECRET` | **Yes** | ≥ 32 chars; boot refuses if absent or short |
| `DB_PATH` | Yes (for durable data) | `/data/data.db`; falls back to `app/data.db` if unset |
| `PORT` | No | Defaults to 3000; Railway injects it |
| `BOOTSTRAP_ADMIN_USERNAME` | First boot only | Must pair with `BOOTSTRAP_ADMIN_PASSWORD` |
| `BOOTSTRAP_ADMIN_PASSWORD` | First boot only | ≥ 12 chars; remove from env after first admin created |

---

## 12. .env.example Gap

Current `app/.env.example` (post-R2) has no bootstrap var entries. Need to add:

```bash
# First production boot only. Remove BOOTSTRAP_ADMIN_PASSWORD after admin is created.
# BOOTSTRAP_ADMIN_USERNAME=admin
# BOOTSTRAP_ADMIN_PASSWORD=replace-with-12-plus-char-password
```

---

## 13. README Gap

`app/README.md` still has "R3 — env + first admin: ... still required" in the R2 section.
After R3, update to reflect:
- R3 addressed; R4 (Railway service config) is next
- Add "Railway Deployment (R3)" section with full production env contract
- Update the production env variables table to include bootstrap vars

---

## 14. Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | Add bootstrap block (~20 lines) between non-prod seed and production warning |
| `app/.env.example` | Add commented `BOOTSTRAP_ADMIN_USERNAME` / `BOOTSTRAP_ADMIN_PASSWORD` |
| `app/README.md` | Add R3 section; update production env table; update R4 remaining status |

**`app/server.js` — no change needed.** SESSION_SECRET guard is already correct. Cookie
security is already correct. No new routes needed. Server just imports `db` handle from db.js.

**`app/package.json` — no change needed.** Bootstrap is env-driven at boot, not a script command.

---

## 15. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Bootstrap fires repeatedly creating multiple admins | Low | `WHERE role = 'admin'` count check; no-op if > 0 |
| Bootstrap password leaked in logs | Low | Only log username, not password |
| Partial config (one var set) accepted silently | None | `process.exit(1)` on `hasUser !== hasPass` |
| Short password accepted | None | `process.exit(1)` if < 12 chars |
| Bootstrap runs in development | None | `NODE_ENV === 'production'` gate |
| Duplicate username (bootstrap username already exists as non-admin) | Low | UNIQUE constraint → INSERT fails with SQLite error → uncaught → process crash. Acceptable: operator chose a username already in use. Could add a friendlier message. |

**Note on duplicate username risk:** If `BOOTSTRAP_ADMIN_USERNAME` matches an existing non-admin
username, the INSERT fails with a UNIQUE constraint error (unhandled). This is an acceptable
edge case — the operator chose a username collision. The crash is fail-safe (server won't start
with a misconfigured bootstrap). A production operator should use a fresh username.

---

## 16. Verification Plan

1. `node --check app/db.js` — syntax OK
2. `node --check app/server.js` — no regression
3. `node --check app/public/app.js` — no regression
4. `cd app && npm run` → `start` = `node server.js`
5. **Dev boot smoke:** `PORT=3987 node server.js` (NODE_ENV unset) → running line → stop → `app/data.db` unchanged
6. **Prod: no SESSION_SECRET:** `NODE_ENV=production DB_PATH="$TMP/d.db" node server.js 2>&1` → FATAL, exit 1
7. **Prod: short SESSION_SECRET:** `NODE_ENV=production SESSION_SECRET="short" DB_PATH="$TMP/d.db" node server.js 2>&1` → FATAL, exit 1
8. **Prod: valid SECRET + bootstrap vars:** `DB_PATH="$TMP/data.db" NODE_ENV=production SESSION_SECRET="test-secret-32-chars-or-more-abc!" BOOTSTRAP_ADMIN_USERNAME="testadmin" BOOTSTRAP_ADMIN_PASSWORD="SecureTest123" PORT=3992 node server.js` → running line + "Bootstrap: admin user 'testadmin' created." → stop
9. **Verify bootstrap DB:** query temp DB: exactly 1 user, role=admin, password_hash starts with `$2` (bcrypt)
10. **Idempotent second boot:** same vars, same DB → "Bootstrap: admin already exists, skipping." → still 1 user
11. **Partial config fails closed:** `BOOTSTRAP_ADMIN_USERNAME="admin"` only (no PASSWORD) → FATAL exit 1
12. **Prod with no bootstrap vars + existing admin:** `NODE_ENV=production SESSION_SECRET=...` (no bootstrap vars, DB has admin) → running line
13. Invariants 5/5 PASS
14. `git status` → only allowed surfaces

---

## 17. Dependency on R4

R3 addresses B4 (first-admin bootstrap) and formalizes the full production env contract.
R4 (Railway service config) is the next Railway readiness node: finalize builder settings,
optional healthcheck route, and public domain confirmation. R4 is the last config gate
before the Railway deployment smoke (R5).
