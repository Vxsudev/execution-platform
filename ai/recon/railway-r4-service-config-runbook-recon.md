# Railway R4 — Service Config Runbook: Recon

**Feature Slug:** railway-r4-service-config-runbook  
**Date:** 2026-06-17  
**Author:** AI Engineering OS (in-session worker)  
**Depends on:** R0 (3ca17f0), R1 (b113f11), R2 (a3c1f55), R3 (9be3466)

---

## 1. Recon Objective

Read-only recon that consolidates all config facts derived from R1/R2/R3 into the exact
Railway service configuration contract needed for R5 deploy smoke. No app mutations, no
Railway deployment, no resource creation.

---

## 2. Files Read

| File | Key facts |
|------|-----------|
| `app/.nvmrc` | `24` — operative Nixpacks Node-major pin (R1) |
| `app/package.json` | `"start": "node server.js"`, `"engines": {"node": ">=24"}`, deps: bcryptjs/express/xlsx |
| `app/db.js` (R2+R3) | DB_PATH resolution + bootstrap block |
| `app/server.js:45-54,601-602` | SESSION_SECRET guard; `PORT = process.env.PORT || 3000`; `app.listen(PORT)` |
| `app/.env.example` | SESSION_SECRET, NODE_ENV, PORT (opt), DB_PATH, BOOTSTRAP_ vars |
| `app/README.md` (R3 state) | R1/R2/R3 Railway Deployment sections |
| `ai/state_registry.json` | `railway-r4-service-config-runbook` absent → fresh lifecycle |

Local governance surfaces: only `ai/invariant-registry.md` present (same as R1/R2/R3).

---

## 3. Commands Run

```bash
git status --short && git log --oneline -4
# → clean (2 pre-existing untracked); HEAD=9be3466
bash vendor/engineering-os/scripts/os-adapter-check.sh  # → 12/12 PASS
bash scripts/invariant-check.sh                          # → 5/5 PASS
ls docs/                                                  # → docs/ does not exist
```

---

## 4. Current Railway Readiness State

| Node | Commit | Blockers addressed | Status |
|------|--------|-------------------|--------|
| R0 Railway readiness recon | 3ca17f0 | B1/B2/B3/B4 identified | RELEASE_APPROVED |
| R1 Runtime/start alignment | b113f11 | B1 (topology), B2 (Node 24) | RELEASE_APPROVED |
| R2 DB_PATH + volume contract | a3c1f55 | B3 (hardcoded DB path) | RELEASE_APPROVED |
| R3 Env/session/admin bootstrap | 9be3466 | B4 (first-admin deadlock) | RELEASE_APPROVED |
| **R4 Service config runbook** | **this** | Config/docs gate before R5 | — |
| R5 Deploy smoke | — | First Railway deploy | pending |

All four blockers (B1-B4) are resolved. The codebase is deploy-ready pending R5.

---

## 5. Config Facts Derived from Code

### Runtime

| Fact | Source | Value |
|------|--------|-------|
| Node version pin | `app/.nvmrc:1` | `24` |
| Node floor | `app/package.json:8` | `>=24` |
| Start command | `app/package.json:11` | `node server.js` |
| npm script | `app/package.json:10-12` | `"start": "node server.js"` |
| Build command | standard Nixpacks | `npm ci` (Nixpacks detects package-lock.json) |
| Root Directory | R1 decision | `app` (deps + lockfile live there) |

### Server binding

| Fact | Source | Value |
|------|--------|-------|
| Port | `app/server.js:601` | `process.env.PORT || 3000` |
| Bind | `app/server.js:602` | `app.listen(PORT)` — all interfaces |
| Static files | `app/server.js:19` | `path.join(__dirname, 'public')` |

### Environment variables

| Var | Source | Required | Notes |
|-----|--------|----------|-------|
| `SESSION_SECRET` | `app/server.js:45-50` | Yes in production | ≥32 chars; boot refuses if missing/short |
| `NODE_ENV` | `app/server.js:46,51; app/db.js:112,117` | Yes in production | `production` |
| `PORT` | `app/server.js:601` | No | Railway injects; defaults 3000 |
| `DB_PATH` | `app/db.js:9-11` | Yes for durability | `/data/data.db` for Railway volume |
| `BOOTSTRAP_ADMIN_USERNAME` | `app/db.js` (R3 block) | First boot only | Must pair with PASSWORD |
| `BOOTSTRAP_ADMIN_PASSWORD` | `app/db.js` (R3 block) | First boot only | ≥12 chars; remove after first admin created |

### DB path + volume

| Fact | Source | Value |
|------|--------|-------|
| Default DB path | `app/db.js:9` | `path.join(__dirname, 'data.db')` → `app/data.db` |
| Configured DB path | `app/db.js:10-11` | `process.env.DB_PATH.trim()` if set |
| Parent dir creation | `app/db.js:12` | `fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true })` |
| WAL mode | `app/db.js:15-18` | `PRAGMA journal_mode = WAL;` applied to opened DB |
| Railway volume mount | R2 contract | `/data` |
| Railway DB_PATH | R2 contract | `/data/data.db` |
| WAL sidecars | SQLite logic | `/data/data.db-wal`, `/data/data.db-shm` (colocated) |

---

## 6. Docs Consistency Check

| Claim | README R1 section | README R2 section | README R3 section | .env.example | Code source |
|-------|------------------|------------------|------------------|-------------|-------------|
| Root Directory = `app` | ✓ | ✓ | ✓ | — | `app/package.json` location |
| Build = `npm ci` | ✓ | ✓ | — | — | `package-lock.json` present |
| Start = `npm start` | ✓ | ✓ | — | — | `app/package.json:11` |
| Node = 24 | ✓ | ✓ | — | — | `app/.nvmrc` |
| DB_PATH = `/data/data.db` | caveat → R2 | ✓ | ✓ | ✓ (commented) | `app/db.js` |
| SESSION_SECRET ≥32 | prod env table | prod env table | ✓ | ✓ | `app/server.js:51-54` |
| BOOTSTRAP_ vars | caveat → R3 | caveat → R3 | ✓ | ✓ (commented) | `app/db.js` (R3 block) |

No conflicts. All facts are consistent across README sections and code.

---

## 7. railway.toml Decision

**Explicit decision: Do NOT create `railway.toml` for R4.**

Rationale:
- Nixpacks detects `package-lock.json` in `app/` and runs `npm ci` automatically.
- Nixpacks detects `app/.nvmrc` (`24`) and selects the correct Node version without explicit override.
- The start command `npm start` is the `package.json` `start` script — Nixpacks would detect it anyway.
- Railway source deploy with Root Directory = `app` works with zero explicit config file.
- The directive says "Prefer Railway dashboard/manual config for first deployment. Keep source deploy boring."
- `railway.toml` adds complexity and a new file type to an otherwise config-file-free source deploy.

The only scenario where `railway.toml` would be needed: if Railway's auto-detection fails for some reason. In R5, if Nixpacks detection fails, `railway.toml` can be added as a targeted fix — but that decision belongs at R5 time with actual build logs. R4 does not pre-emptively add it.

**Dockerfile decision: Do NOT create Dockerfile.** (No containerization per directive and architectural invariant.)

---

## 8. Docs Gap — `docs/` directory

`docs/` does not currently exist in the repository. The allowed mutation surface
`docs/railway-service-config.md` requires creating the directory. This is a new
docs artifact, not an app code change — within R4 scope.

---

## 9. README Link Decision

The README already has three "Railway Deployment (Rn)" sections. A short link to
`docs/railway-service-config.md` in README would help operators navigate to the full
runbook. This is an "optional mutation if recon proves necessary" surface. Recon
confirms the runbook is a new artifact and a README link reduces operator confusion.
**Decision: add a brief link to `docs/railway-service-config.md` from README.**

---

## 10. R5 Smoke Test Design

R5 is the first actual Railway deploy smoke. It must verify the full critical path:

**Pre-deploy checks (R5 operator, before clicking Deploy):**
1. Railway service configured with all production env vars
2. Volume mounted at `/data`
3. Bootstrap vars set for first boot

**Boot confirmation:**
4. Build logs: Nixpacks selects Node 24
5. Build logs: `npm ci` installs dependencies
6. Deploy logs: "Bootstrap: admin user '...' created."
7. Deploy logs: "execution-table-app running on http://localhost:PORT"
8. No password in logs

**Critical-path smoke (browser):**
9. Public URL loads login page (HTTPS, Railway domain)
10. Login with bootstrap admin credentials → 200, session cookie with `Secure` flag
11. Dashboard tab loads
12. Create a new row (POST /api/rows) → 201
13. Edit the row (PUT /api/rows/:id) → 200
14. Delete the row (DELETE /api/rows/:id) → 200
15. XLSX import preview → 200
16. XLSX import commit → 200
17. Import history → batch listed
18. Delete import batch → 200
19. Row details modal → loads
20. Create a second user (track_owner) via Users panel
21. Log out; log in as track_owner

**Persistence smoke (volume):**
22. Note a row's content and ID
23. Trigger Railway redeploy (not data migration)
24. After redeploy: row still exists at same ID
25. DB file at `/data/data.db` confirmed in Railway volume UI

**Bootstrap cleanup:**
26. Remove `BOOTSTRAP_ADMIN_PASSWORD` from Railway env vars
27. Redeploy
28. Confirm "Bootstrap: admin already exists, skipping." in logs
29. Confirm admin login still works

**No-go conditions (abort R5):**
- Build fails or uses wrong Node version
- `SESSION_SECRET` missing → boot refuses
- Bootstrap vars partially configured → boot refuses
- Bootstrap password appears in any log line
- Demo user `admin/admin123` seeded in production (absent from users table)
- After restart: data missing from volume-backed deploy
- After bootstrap password removal: admin login fails (data corruption)

---

## 11. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Railway Nixpacks detects repo root package.json before app/ | Low | Root Directory = `app` in Railway dashboard overrides Nixpacks root; untracked root `package.json` is inert |
| Railway port injection not honored | None | `app/server.js:601` honors `process.env.PORT` |
| Volume not mounted at R5 for production deploy | Medium | R5 no-go condition; documented; ephemeral-only demo is OK if data expected ephemeral |
| bootstrap password still set after admin created; second admin created | None | bootstrap is idempotent (R3 verified) — skips if admin exists |
| SESSION_SECRET too short set in Railway | None | Boot refuses with FATAL (R3 verified) |

---

## 12. Dependency on R5

R4 is a docs/runbook gate. R5 is the first actual Railway deploy smoke, executed by a
human/operator following the runbook in `docs/railway-service-config.md`. R5 requires no
code changes — only Railway dashboard configuration and env var setup.
