# Railway Hosting Readiness Recon — execution-platform

- **Capability:** Railway Hosting Readiness Recon + Audit
- **Feature slug:** `railway-hosting-readiness-recon`
- **Mode:** STRICT RECON ONLY — no deployment, no Railway mutation, no app-code mutation, no DB mutation, no package/config/.env mutation
- **Branch:** `main`
- **Date:** 2026-06-17
- **OS mode:** OS-ENABLED (`vendor/engineering-os/` + `.engineering-os/` present)
- **OS gates at recon time:** adapter-check 12/12 PASS · invariant engine 5/5 PASS · `node --check` server.js/db.js/app.js OK

---

## 1. Executive Verdict

**READY WITH BLOCKERS.**

- **Demo on Railway: READY NOW** as a single Node web service, **provided** Railway is configured with **Root Directory = `app`** and **Node pinned to ≥ 23.4 (recommend 24 LTS)**. In demo posture the app runs in development mode (seeds `admin/admin123`), serves API + static UI from one process, and binds `process.env.PORT`. Data is **ephemeral** (acceptable for a throwaway demo).
- **Production on Railway: NOT READY** without code work. Two hard, code-level blockers exist that this recon is forbidden to patch:
  1. **Hardcoded SQLite path inside the source tree** (`app/db.js:8`) — a Railway persistent volume cannot be mounted cleanly without shadowing the application code. Durable data requires an env-configurable DB path. (Blocker **B3**.)
  2. **No production first-admin bootstrap** — production seeds no users (`app/db.js:117-119`) and user creation requires an already-authenticated admin (`app/server.js:232-233`). Chicken-and-egg; no login is possible. (Blocker **B4**.)
- Two further **deployment-config gates** (no app-code change needed, but mandatory to boot at all): correct **deploy topology** (deps live in `app/`, not repo root — Blocker **B1**) and **Node version / `node:sqlite` flag** alignment (Blocker **B2**).

No managed Postgres, Redis, worker, or object storage is required for the MVP. SQLite is acceptable for this internal PM tool's scale.

---

## 2. Current App Architecture Summary

Single-process full-stack Node app derived from the astraX experiment sheet:

- **Backend:** Express 4 (`app/server.js`) — auth (custom HMAC-signed cookie sessions), rows CRUD, user management, XLSX import/preview/commit, import ledger + observations.
- **Frontend:** static vanilla JS/CSS/HTML served by the same Node process from `app/public/` (`app/server.js:19`).
- **Database:** SQLite via the **built-in experimental `node:sqlite` module** (`DatabaseSync`), file `app/data.db`, WAL journal mode (`app/db.js:5,8,10`).
- **Sessions:** persisted in the SQLite `sessions` table (`app/server.js:107`, `app/db.js:52-56`) — session durability is tied to DB durability.
- **No build step**; dependencies are pure-JS (`express`, `bcryptjs`, `xlsx`) plus the built-in SQLite — no native compilation.

It is a **single deployable web service**.

---

## 3. Files Inspected

| File | Why |
|------|-----|
| `app/server.js` (603 lines, fully read) | Entrypoint, port binding, static serving, auth, session secret, cookies, all routes |
| `app/db.js` (143 lines, fully read) | DB engine, DB path, WAL, schema, boot migrations, seed/bootstrap logic |
| `app/package.json` | engines, start script, dependencies, type |
| `app/package-lock.json` (tracked) | reproducible install confirmed present |
| `app/.env.example` | required/optional env var contract |
| `app/.gitignore` | confirms `data.db*` and `.env` are not committed |
| `app/README.md` (runtime + Production Environment sections) | documented runtime requirement, env vars, production safety, bootstrap guidance |
| `package.json` (repo root, **untracked**) | delegating start script; no dependencies, no lockfile |
| `.gitignore` (repo root) | confirms `vendor/engineering-os/`, `data.db*`, `node_modules/` ignored |
| `ai/state_registry.json` | OS lifecycle state; no prior `railway-*` feature |
| `.engineering-os/adapter.config.sh`, `scripts/invariant-check.sh`, INV-003/INV-006 | OS gate scope (sdlc/ only) |
| `ai/recon/azure-migration-recon.md` | **Disregarded as evidence** — describes a different app (FastAPI/Postgres/worker/PDF), not this Express/`node:sqlite` app |

---

## 4. Commands Run (read-only)

```text
pwd; git status --short; git log --oneline -8; git branch --show-current
ls -la; find . -maxdepth 2 -type d (excl. node_modules/.git)
node --version            → v25.4.0
npm --version             → 11.7.0
node -e "require('node:sqlite')"  → loads, emits ExperimentalWarning (no flag needed on v25)
node --check app/server.js / app/db.js / app/public/app.js   → all OK
cd app && npm run         → only "start": node server.js
git ls-files package.json → (empty) i.e. UNTRACKED
git ls-files app/package-lock.json app/package.json → both tracked
bash vendor/engineering-os/scripts/os-adapter-check.sh   → 12 PASS / 0 FAIL, EXIT 0
bash scripts/invariant-check.sh                          → 5/5 PASS
grep -n process.env.PORT|listen|NODE_ENV|SESSION_SECRET|DatabaseSync|data.db app/*.js
```

The optional `node server.js` boot smoke was **not** run, to avoid mutating `app/data.db` / WAL files (recon is read-only).

---

## 5. Runtime Entrypoint Audit

- Entrypoint: `app/server.js`. Exports nothing; calls `app.listen` at the bottom (`app/server.js:601-602`).
- DB module `app/db.js` is `require`d at the top of `server.js` (`app/server.js:7`); **importing it executes schema creation, idempotent migrations, and seeding immediately** (`app/db.js:45-141`). So the entrypoint mutates the DB schema at boot (see §8).
- App-root start command that works **today**: from `app/`, `npm start` → `node server.js`. From repo root, `node app/server.js` works **only if `node_modules` is installed under `app/`** (see §6/§13).

---

## 6. Package / Script Audit

- **`app/package.json`** (`app/package.json:1-18`):
  - `"engines": { "node": ">=22.5" }` (`:7-9`)
  - `"type": "commonjs"`, `"start": "node server.js"` (`:5,11`)
  - deps: `bcryptjs ^2.4.3`, `express ^4.19.2`, `xlsx ^0.18.5` (`:13-17`) — **all pure JS, no native build**. SQLite is the built-in `node:sqlite`.
  - `app/package-lock.json` is **tracked** → reproducible `npm ci`.
- **Root `package.json`** (untracked, `package.json:1-9`): `"start": "node app/server.js"`, `"dev": "node app/server.js"`, **no `dependencies`, no lockfile**.
  - **Implication (Blocker B1):** this file is *untracked*, so it is **not** part of a git deploy at all; and even if present, installing from it pulls **zero** dependencies → `Cannot find module 'express'`. The real dependency manifest + lockfile live in `app/`. **Railway must deploy with Root Directory = `app`.**
- No `build` script anywhere → Nixpacks build is just dependency install. Good.

---

## 7. Port Binding Audit

- `const PORT = process.env.PORT || 3000;` (`app/server.js:601`) — **honors `process.env.PORT`** ✔ (Railway injects `PORT`).
- `app.listen(PORT, () => ...)` (`app/server.js:602`) — **no host argument**, so Node binds all interfaces (`0.0.0.0`/`::`), not localhost-only ✔ (reachable by Railway's proxy).
- No explicit `/health` route. `GET /` serves `index.html` (static) → 200; Railway's default check (port open) suffices. A dedicated healthcheck is optional (see risks).

---

## 8. Database / Storage Audit

- **Engine:** `node:sqlite` `DatabaseSync` (`app/db.js:5`) — **experimental built-in**, not `better-sqlite3`. Emits `ExperimentalWarning` and is version-sensitive (see §10/B2).
- **DB file path:** `new DatabaseSync(path.join(__dirname, 'data.db'))` (`app/db.js:8`). `__dirname` is the directory of `db.js`, i.e. always **`<app dir>/data.db`** regardless of CWD. **Hardcoded, no env override.**
- **WAL mode:** `PRAGMA journal_mode = WAL` (`app/db.js:10`) → sidecar files `data.db-wal`, `data.db-shm` (observed on disk) live in the **same directory** and must persist alongside `data.db`.
- **Ephemeral-FS safety:** Railway containers have an ephemeral filesystem. With the DB inside the image/source tree and no volume, **all data is lost on every redeploy/restart**. Acceptable for demo; not for production.
- **Volume requirement (Blocker B3):** A Railway persistent volume must mount at the directory that contains `data.db`. Because that directory **is the application source directory** (`app/`), mounting a volume there would shadow `server.js`, `db.js`, `public/`, `node_modules/`. There is **no env var or code path to relocate the DB** (path is hardcoded at `app/db.js:8`). Durable persistence therefore requires a code change (e.g. `DB_PATH` env → mount volume at `/data`), which this recon must not perform.
- **Boot mutates schema (idempotent):** `CREATE TABLE IF NOT EXISTS` for `users`, `sessions`, `entries`, `imports`, `import_observations` (`app/db.js:45-98`), plus additive `ALTER TABLE ... ADD COLUMN` wrapped in try/catch (`app/db.js:100-108`). **No destructive migrations; safe to run on every boot.** No migration framework.
- **Backup/export:** none in code. Backup = copy the `data.db*` files off the volume, or re-import the source XLSX. (See DAG R6.)

---

## 9. Auth / Session Audit

- **Passwords hashed:** `bcrypt.hashSync(..., 10)` on create/update (`app/server.js:245,280`); login compares with `bcrypt.compareSync` (`app/server.js:103`). ✔
- **Sessions:** opaque 32-byte random token (`app/server.js:106`), stored in `sessions` table, delivered as an **HMAC-SHA256-signed cookie** `sid` (`app/server.js:56-71,107-108`). Signature uses `SESSION_SECRET`. Verified with `crypto.timingSafeEqual` (`app/server.js:68`). ✔
- **`SESSION_SECRET` contract** (`app/server.js:45-54`): in production, **absent secret → `process.exit(1)`**; secret `< 32` chars → `process.exit(1)`. In non-production, falls back to a hardcoded insecure dev value. ✔ explicit, fail-closed.
- **Cookie flags** (`app/server.js:108-114`): `httpOnly: true`, `sameSite: 'lax'`, `path: '/'`, 7-day maxAge, `secure: NODE_ENV === 'production'`. The `Secure` attribute is set unconditionally in prod (no `req.secure`/trust-proxy dependency, because this is a custom cookie not `express-session`), so it works behind Railway's TLS-terminating edge. ✔
- **Demo users seeded only in non-production** (`app/db.js:112-116`): `admin/admin123`, `vasu/vasu123`, with role backfill (`app/db.js:122-125`). In production they are **not** seeded (`app/db.js:117-119` only logs a warning).
- **Production first-admin bootstrap gap (Blocker B4):** user creation (`POST /api/users`) requires `canManageUsers` = an authenticated admin (`app/server.js:226-233`). With no seeded users in production and no CLI/seed script, **there is no way to create the first admin** → no login possible. README acknowledges "create users before accepting connections" (`app/README.md:200-201`) but ships no mechanism.
- **Secrets committed?** No. `.env` is gitignored (`app/.gitignore:6`); `app/.env.example` contains only a placeholder (`app/.env.example:7`). ✔

---

## 10. Environment Variable Audit

| Var | Required | Source of truth | Notes |
|-----|----------|-----------------|-------|
| `SESSION_SECRET` | **Yes in production** (≥32 chars) | `app/server.js:45-54`, `app/.env.example:5-7`, `app/README.md:187` | Boot fails if missing/short in prod. Optional in dev (insecure fallback). |
| `NODE_ENV` | Yes — set `production` for prod | `app/server.js:46,51,113`; `app/db.js:112,117,122` | Controls seeding, cookie `Secure`, secret enforcement. **For demo, leave unset/`development` to get seeded login.** |
| `PORT` | No (Railway injects) | `app/server.js:601` | Defaults 3000. |

No other env vars are read by the app. No `DB_PATH`, no DB connection string (SQLite). **Node loads no `.env` automatically** (`app/.env.example:2-3`) — Railway env vars must be set in the service config.

**Node version (Blocker B2):** `engines.node = ">=22.5"` (`app/package.json:7-9`) and the start command carries **no `--experimental-sqlite` flag**. `node:sqlite` was introduced in **22.5.0 behind `--experimental-sqlite`** and was **unflagged at 23.4.0** (require works, still emits an experimental warning). On Node **22.5–23.3**, the bare `require('node:sqlite')` (`app/db.js:5`) **throws at boot**. Local Node is v25.4.0 (loads fine). **Exact behavior on the Node-22 LTS line is version-dependent and must be verified against whatever version Railway/Nixpacks selects.** Safe resolution: **pin Node ≥ 23.4 (recommend 24 LTS)** via `engines`/`.nvmrc`/`NIXPACKS_NODE_VERSION`, *or* add `--experimental-sqlite` to the start command.

---

## 11. Railway Service Mapping

| Concern | Mapping |
|---------|---------|
| Service type | **1 web service** (Node), Root Directory `app`, build `npm ci`, start `npm start` (`node server.js`) |
| Worker service | **Not needed** — no background jobs; import is synchronous in-request |
| Redis | **Not needed** — sessions live in SQLite |
| Object storage | **Not needed** — XLSX uploads are parsed in-memory (base64 in request body, `app/server.js:446-455`), never written to disk |
| Managed Postgres | **Not now** — SQLite is sufficient for an internal PM tool; consider later for HA/multi-instance |
| Persistent volume | **Required for production durability only** — blocked by hardcoded path (B3); not needed for ephemeral demo |
| Public URL | Railway auto-assigns an HTTPS domain; app serves both API and UI on it |

---

## 12. Railway Volume / Storage Requirement

- **Demo:** **no volume** — ephemeral SQLite, data resets per deploy. Acceptable.
- **Production:** **one volume** is required to persist `data.db` + `data.db-wal` + `data.db-shm` (all colocated). **But** the mount target equals the source directory (hardcoded `__dirname` path), so a clean mount is **not possible without a code change** (introduce `DB_PATH`, mount volume at e.g. `/data`, set `DB_PATH=/data/data.db`). Documented blocker B3 — **not patched in this recon**.
- WAL sidecars must share the same volume as the main DB file (they will, since they share the directory).

---

## 13. Railway Deployment Readiness

| Readiness item | Status |
|----------------|--------|
| `npm start` exists | ✔ (`app/package.json:11`); root delegate exists but untracked & depless |
| Binds `process.env.PORT` | ✔ (`app/server.js:601`) |
| Listens on all interfaces | ✔ (`app/server.js:602`, no host arg) |
| Serves static frontend from Node | ✔ (`app/server.js:19`) |
| No build step / native compile | ✔ (pure-JS deps + built-in SQLite) |
| Reproducible install | ✔ (`app/package-lock.json` tracked) → `npm ci` |
| Secrets not committed | ✔ |
| Single-service deployable | ✔ |
| Deploy topology correct out-of-box | ✖ **B1** — must set Root Directory `app` |
| Node version safe out-of-box | ✖ **B2** — must pin Node ≥23.4/24 (or add flag) |
| Durable data | ✖ **B3** — hardcoded DB path blocks clean volume |
| Production login possible | ✖ **B4** — no first-admin bootstrap |

**Demo-ready: YES** (after B1+B2 config). **Production-ready: NO** (B3+B4 are code/ops work).

---

## 14. Railway Blockers

| ID | Severity | Blocker | Surface | Fix class | This recon |
|----|----------|---------|---------|-----------|------------|
| **B1** | Hard (boot) | Deps + lockfile live in `app/`; root `package.json` is untracked & has no deps → deploying from repo root fails (`Cannot find module 'express'`) | `app/package.json`, root `package.json` | **Config** — set Railway Root Directory = `app` | Documented |
| **B2** | Hard (boot) | `engines >=22.5` + start command lacks `--experimental-sqlite`; `node:sqlite` throws on Node 22.5–23.3 | `app/db.js:5`, `app/package.json:7` | **Config** — pin Node ≥23.4/24 via Railway/Nixpacks; *or* code: add flag to start | Documented |
| **B3** | Hard (prod durability) | Hardcoded `__dirname/data.db`; volume can't mount without shadowing source; no env override | `app/db.js:8` | **Code** — add `DB_PATH` env, mount volume at `/data` | Documented, **not patched** |
| **B4** | Hard (prod login) | Production seeds no users; user creation needs an existing admin → no first login | `app/db.js:117-119`, `app/server.js:232-233` | **Code/ops** — seed script or env-driven first admin | Documented, **not patched** |

B1 and B2 gate **any** deploy (including demo). B3 and B4 gate **production** only.

---

## 15. Railway Risks

- **R-experimental:** `node:sqlite` is an experimental API that can change between Node majors — pin Node version to avoid surprise breakage.
- **R-WAL-on-volume:** WAL works on a real block-device volume (ext4); fine. Avoid networked/object FS for SQLite.
- **R-concurrency:** `DatabaseSync` is synchronous, single-process, single writer. Fine for a small internal team; horizontal scaling (>1 instance) is **not** supported with SQLite on a single volume → would force Postgres.
- **R-backup:** no automated backup; relies on volume durability. Snapshot/copy needed (DAG R6).
- **R-cold-start:** negligible — no heavy init beyond idempotent schema/migration on boot.
- **R-no-healthcheck:** no dedicated health route; default port check is adequate but a `/healthz` would harden deploy gating.
- **R-demo-creds:** running demo in development mode seeds well-known creds (`admin/admin123`) over a public HTTPS URL — acceptable only for a short-lived, access-controlled demo.

---

## 16. Cost Model Assumptions

Exact Railway pricing is not locally documented and is **not invented here**.

- Footprint for this app: **one small Node web service** plus (for production) **one small persistent volume**.
- "Cost depends on Railway plan/usage; for this app, expected footprint is one small web service plus persistent volume."
- "Use Railway Hobby plan if the client already approved a $20/month plan."
- "No managed DB cost unless Postgres is added later."
- No worker, no Redis, no object storage, no managed DB for MVP → no incremental service cost beyond the single service (+ volume in prod).

---

## 17. MVP Deployment Shape (Demo)

1. Railway service, **Root Directory = `app`**, builder Nixpacks, build `npm ci`, start `npm start`.
2. **Pin Node ≥ 23.4 (recommend 24 LTS)** (`NIXPACKS_NODE_VERSION` / `.nvmrc` / `engines`).
3. Env: leave `NODE_ENV` unset/`development` (seeds `admin/admin123`); optionally still set `SESSION_SECRET`. `PORT` auto-injected.
4. **No volume** → ephemeral SQLite (data resets per deploy; fine for demo).
5. Log in at the Railway HTTPS URL as `admin/admin123`; exercise CRUD + XLSX import.

Resolves B1+B2; accepts B3 (ephemeral) and side-steps B4 (dev seeding).

---

## 18. Production-Hardening Shape

1. **Code (B3):** introduce `DB_PATH` env (default current path); mount a Railway volume at `/data`; set `DB_PATH=/data/data.db`. Ensure WAL sidecars land on the volume.
2. **Code/ops (B4):** add a first-admin bootstrap (one-off seed script run via `railway run`, or env-driven `BOOTSTRAP_ADMIN_*` on empty DB).
3. **Config:** `NODE_ENV=production`, `SESSION_SECRET` ≥32 chars (generated, stored in Railway secrets), Node pinned.
4. **Ops:** scheduled volume snapshot / `data.db` copy-out (R6); optional `/healthz`.
5. **Later (optional):** migrate to Railway managed **Postgres** if HA / multi-instance / stronger durability is required — would require a DB-layer rewrite (currently SQLite-specific via `node:sqlite`).

---

## 19. Recommended Railway Deployment DAG

| Node | Name | Purpose | Depends on | Mutation surface | Verification focus | Stop condition |
|------|------|---------|-----------|------------------|--------------------|----------------|
| **R0** | Readiness recon | This artifact + audit | — | docs only (`ai/recon`, `ai/reports`) | recon complete, gates green | Recon + audit committed |
| **R1** | Runtime / start alignment | Root Directory=`app`, pin Node ≥23.4/24, confirm `npm start`, `PORT` | R0 | Railway service config (no app code) | service boots; `require('node:sqlite')` loads; port bound | Service starts, `/` returns 200 |
| **R2** | DB persistence / volume contract | Make DB path env-configurable (B3) + mount volume at `/data` | R1 | **`app/db.js` (code)** + Railway volume | data survives redeploy; WAL on volume | Row persists across a redeploy |
| **R3** | Env + secret contract | `SESSION_SECRET`, `NODE_ENV`; production admin bootstrap (B4) | R1 | Railway secrets + **bootstrap script (code/ops)** | prod boot passes secret gate; first admin can log in | Admin login succeeds in prod mode |
| **R4** | Railway service config | Finalize builder/healthcheck/domain | R1 | Railway config | healthcheck green; HTTPS domain serves UI | Public URL serves app over HTTPS |
| **R5** | Deployment smoke | Login → CRUD → XLSX import end-to-end | R2,R3,R4 | none (runtime test) | full critical path works on Railway | All smoke steps pass |
| **R6** | Backup / export procedure | Volume snapshot / `data.db` copy-out / XLSX re-import | R2 | ops runbook | restore verified from snapshot | Documented + test-restored |
| **R7** | Client handoff note | Operator/client doc: URL, creds, limits, costs | R5,R6 | docs | client can operate independently | Handoff doc delivered |

Demo path = **R0 → R1 → R4 → R5** (skips R2/R3-prod/R6). Production path = full **R0→R7**.

---

## 20. No-Go Conditions

- **Do not** deploy from repo root without Root Directory=`app` (B1) — guaranteed boot failure.
- **Do not** let Railway pick an arbitrary Node version while the start command lacks `--experimental-sqlite` (B2) — boot crash risk on Node 22.5–23.3.
- **Do not** run a production deployment expecting durable data on the current hardcoded DB path (B3) — data loss on redeploy, and no clean volume mount.
- **Do not** set `NODE_ENV=production` without first solving the admin bootstrap (B4) — the app will accept no logins.
- **Do not** scale beyond 1 instance with SQLite on a single volume.
- **Do not** patch any forbidden surface in this recon — if a real fix requires it, STOP and report (no such forbidden patch was made).

---

## 21. Stop Condition Status

| Required | Status |
|----------|--------|
| Railway readiness recon exists | ✔ this file |
| Railway audit report exists | ✔ `ai/reports/railway-hosting-readiness-audit.md` |
| Runtime entrypoint audited | ✔ §5 |
| Package scripts audited | ✔ §6 |
| Port binding audited | ✔ §7 |
| SQLite/storage audited | ✔ §8, §12 |
| Auth/session audited | ✔ §9 |
| Env vars audited | ✔ §10 |
| Railway service mapping | ✔ §11 |
| Cost posture | ✔ §16 |
| Blockers listed | ✔ §14 |
| Deployment DAG proposed | ✔ §19 |
| No app code modified | ✔ (verified `git status`) |
| Invariants pass | ✔ 5/5 |
| Git status reported | ✔ audit + final summary |

**STOP CONDITION MET — recon complete.**
