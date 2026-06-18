# Railway Service Configuration Runbook

**Internal operator runbook — not client-facing.**  
**Version:** R4 (2026-06-17) — pre-R5 deploy smoke

This runbook documents the exact Railway configuration required to deploy the
`execution-table-app`. Follow it in order for R5.

---

## 1. Deployment Target

| Setting | Value |
|---------|-------|
| Platform | Railway |
| Deploy style | Source deploy (no Docker, no Dockerfile) |
| Repository | This GitHub repository |
| Branch | `main` |
| Root Directory | `app` |
| Node version | 24 (pinned via `app/.nvmrc`; floor `engines.node >=24`) |
| Build command | `npm ci` (Nixpacks auto-detects from `package-lock.json`) |
| Start command | `npm start` (runs `node server.js`) |
| App port | Railway injects `PORT`; app honors `process.env.PORT || 3000` |
| Public URL | Railway-generated domain (confirmed in R5 smoke) |

**Configuration file note:** No `railway.toml` or `Dockerfile` needed. Nixpacks
auto-detects Node 24 from `app/.nvmrc`, builds with `npm ci`, and starts with
`npm start`. If Nixpacks fails to detect the correct settings at R5, add
`railway.toml` as a targeted fix at that time.

---

## 2. Railway Service Checklist

Steps to create the service in the Railway dashboard:

- [ ] Create a new Railway project
- [ ] Add a new service → "Deploy from GitHub repo"
- [ ] Connect the GitHub repository
- [ ] Select branch: `main`
- [ ] Set **Root Directory**: `app`
- [ ] Confirm build command: `npm ci` (or leave blank — Nixpacks detects it)
- [ ] Confirm start command: `npm start` (or leave blank — Nixpacks detects it)
- [ ] Confirm Railway shows Node 24 in build settings
- [ ] Do NOT add a worker service
- [ ] Do NOT add Redis
- [ ] Do NOT add object storage
- [ ] Do NOT add a managed Postgres database
- [ ] Do NOT upload a Dockerfile

---

## 3. Railway Volume Checklist

### Production deploy (durable data)

- [ ] In Railway project, add a **Persistent Volume**
- [ ] Attach the volume to the web service
- [ ] Set **Mount Path**: `/data`
- [ ] Set env var `DB_PATH=/data/data.db`
- [ ] Confirm WAL sidecars will colocate at `/data/data.db-wal`, `/data/data.db-shm` (SQLite does this automatically)

### Demo-only deploy (ephemeral data)

- [ ] Volume can be skipped
- [ ] Without a volume, data lives in `/app/data.db` inside the ephemeral container — reset on every redeploy
- [ ] Do not treat an ephemeral deploy as production; do not enter real data

---

## 4. Environment Variable Checklist

Set all variables in the Railway service's **Variables** panel.

### Required for production

| Variable | Value | Notes |
|----------|-------|-------|
| `NODE_ENV` | `production` | Controls demo seed, cookie security, SESSION_SECRET guard |
| `SESSION_SECRET` | 32+ char random string | Generate: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |
| `DB_PATH` | `/data/data.db` | Must match the volume mount path |

### First boot only

Set these **before** the first deploy. Remove `BOOTSTRAP_ADMIN_PASSWORD` after the first
admin is confirmed to exist.

| Variable | Value | Notes |
|----------|-------|-------|
| `BOOTSTRAP_ADMIN_USERNAME` | e.g. `admin` | Admin username; must pair with PASSWORD |
| `BOOTSTRAP_ADMIN_PASSWORD` | Strong password (no length minimum) | Bcrypt-hashed at boot; **remove after first admin created** |

### After first successful admin creation

- [ ] **Remove** `BOOTSTRAP_ADMIN_PASSWORD` from Railway env vars
- [ ] Optionally remove `BOOTSTRAP_ADMIN_USERNAME` (it is ignored after admin exists)
- [ ] Keep `SESSION_SECRET`, `NODE_ENV`, `DB_PATH`

### Railway also injects automatically

| Variable | Notes |
|----------|-------|
| `PORT` | Railway injects; no action needed |

---

## 5. First Boot Procedure

1. **Set all env vars** (including bootstrap vars and volume) before deploying.
2. **Deploy** the service.
3. **Watch build logs:** confirm Nixpacks selects Node 24 and `npm ci` succeeds.
4. **Watch deploy logs:** confirm these lines appear:
   - `Bootstrap: admin user '<username>' created.`
   - `execution-table-app running on http://localhost:<PORT>`
5. **Confirm no password appears in any log line.**
6. **Open the public URL** in a browser → login page loads over HTTPS.
7. **Log in** with the bootstrap admin credentials.
8. **Verify** you can access the dashboard, rows table, and Users panel.
9. **Remove `BOOTSTRAP_ADMIN_PASSWORD`** from Railway env vars.
10. **Redeploy** or restart the service.
11. **Watch logs:** confirm `Bootstrap: admin already exists, skipping.` (idempotent).
12. **Log in again** to confirm admin credentials still work.
13. **Optional:** create additional users (track_owner, viewer) via the Users panel.

---

## 6. R5 Smoke Checklist

Complete all items in order. Stop at any failure — see no-go conditions below.

### Boot

- [ ] Build logs: Nixpacks selects Node 24
- [ ] Build logs: `npm ci` exits 0
- [ ] Deploy logs: `Bootstrap: admin user '...' created.`
- [ ] Deploy logs: `execution-table-app running on http://localhost:PORT`
- [ ] No password visible in any log line

### Browser critical path

- [ ] Public Railway URL loads login page (HTTPS)
- [ ] `POST /api/login` with bootstrap admin → 200, `Secure` session cookie set
- [ ] Dashboard tab loads, all widgets render
- [ ] `POST /api/rows` — create a row → 201
- [ ] `PUT /api/rows/:id` — edit the row → 200
- [ ] `DELETE /api/rows/:id` — delete the row → 200
- [ ] XLSX import → select `.xlsx` file → Preview renders importable rows
- [ ] XLSX import → Commit → batch created, rows inserted
- [ ] `GET /api/imports` → batch listed in Import History
- [ ] Delete import batch → batch and rows removed
- [ ] Row details modal opens for a row
- [ ] Row/cell click opens Details
- [ ] Admin creates a `track_owner` user via Users panel
- [ ] Log out; log in as track_owner → dashboard and row table load

### Persistence smoke (volume-backed deploy)

- [ ] Note a row's `id` and `title`
- [ ] Trigger a Railway redeploy (not a volume delete)
- [ ] After redeploy: row is still present at the same `id`
- [ ] Railway volume UI shows `data.db` at `/data`

### Bootstrap cleanup smoke

- [ ] Remove `BOOTSTRAP_ADMIN_PASSWORD` from Railway env vars
- [ ] Redeploy / restart
- [ ] Deploy logs: `Bootstrap: admin already exists, skipping.`
- [ ] Admin login still works

---

## 7. No-Go Conditions

Stop R5 and do not proceed if any of the following occurs:

| Condition | Action |
|-----------|--------|
| Railway builds from repo root instead of `app` | Check Root Directory setting; fix to `app` |
| Nixpacks selects wrong Node version (not 24) | Add `NIXPACKS_NODE_VERSION=24` env var and retry |
| `node:sqlite` throws at boot (flag required) | Node version < 23.4; fix Node pin |
| `SESSION_SECRET` missing or < 32 chars → boot refuses | Set correct SESSION_SECRET |
| Bootstrap vars partially configured → boot refuses | Set both vars or unset both |
| Bootstrap password appears in any log line | Stop; review db.js; do not proceed |
| Demo user `admin/admin123` appears in production users table | NODE_ENV not set to `production`; fix and redeploy |
| After restart: data missing (volume-backed deploy) | Volume not mounted or wrong path; inspect before continuing |
| After bootstrap password removal: admin login fails | Data or hash corruption; investigate before continuing |
| Build fails with npm ci error | Check Node version, `package-lock.json` presence in `app/` |

---

## 8. Rollback Notes

| Scenario | Action |
|----------|--------|
| Deploy fails before any data entry | Destroy and recreate the Railway service |
| Env vars wrong (missing/typo) | Fix env vars in Railway dashboard, redeploy |
| Volume mount wrong, no real data yet | Recreate volume with correct `/data` mount path |
| Volume mount wrong, real data exists | **Do not delete volume.** Stop; inspect data; plan migration |
| bootstrap password still set and second deploy creates second admin | Cannot happen — bootstrap is idempotent (skips if admin exists) |
| Need to reset admin password | Use Railway shell or volume access to run: `node -e "const {DatabaseSync}=require('node:sqlite'); const bcrypt=require('bcryptjs'); const db=new DatabaseSync('/data/data.db'); db.prepare('UPDATE users SET password_hash=? WHERE username=?').run(bcrypt.hashSync('newpassword',10),'admin');"` |
| Do not run manual SQLite mutation unless explicitly authorized by the operator |
