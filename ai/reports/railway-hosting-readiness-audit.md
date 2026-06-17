# Railway Hosting Readiness Audit — execution-platform

**Date:** 2026-06-17 · **Branch:** `main` · **Scope:** recon/audit only — no deployment, no code changes
**Full recon:** `ai/recon/railway-hosting-readiness-recon.md`

---

## Verdict

**READY WITH BLOCKERS.**

- **Demo on Railway — deployable now** as a single Node web service, once two *configuration* gates are set (Root Directory + Node version). Data is ephemeral.
- **Production on Railway — not yet.** Two *code-level* blockers (durable DB path, first-admin bootstrap) must be solved first. This audit does not patch them.

The app is a single Express process serving an API + static UI, backed by SQLite (`node:sqlite`). No worker, Redis, object storage, or managed database is needed for the MVP.

---

## Recommended Railway Architecture

```
Internet ──HTTPS──> Railway edge ──> [ Node web service ]
                                      Root Directory: app
                                      Express + static UI
                                      SQLite (node:sqlite)
                                        └─ (prod) persistent volume at /data  ← needs code change (B3)
```

One service. One volume (production only). Nothing else.

---

## Service-wise Requirement

| Service | Needed? | Notes |
|---------|---------|-------|
| Node web service | **Yes** | Root Directory `app`, build `npm ci`, start `npm start` |
| Persistent volume | **Prod only** | Blocked today by hardcoded DB path (B3) |
| Worker | No | No background jobs |
| Redis | No | Sessions stored in SQLite |
| Object storage | No | XLSX parsed in-memory, never written to disk |
| Managed Postgres | No (now) | SQLite fine for internal PM scale; revisit for HA/multi-instance |

---

## Monthly Cost Posture

- Exact Railway pricing not invented here. Footprint = **one small web service** + (prod) **one small volume**.
- Cost depends on Railway plan/usage; **Hobby plan is sufficient** if the client already approved a ~$20/month plan.
- **No managed DB cost** unless Postgres is added later.

---

## Required Env Vars

| Var | When | Notes |
|-----|------|-------|
| `SESSION_SECRET` | **Required in production**, ≥32 chars | Boot fails if missing/short. Optional in demo. |
| `NODE_ENV` | Set `production` for prod | **Leave unset/`development` for demo** so login is seeded (`admin/admin123`). |
| `PORT` | Auto-injected by Railway | App honors it; defaults 3000. |

No database URL or `DB_PATH` is read today (DB path is hardcoded — see blockers).

---

## Required Railway Settings

1. **Root Directory = `app`** (dependencies + lockfile live there; the repo-root `package.json` is untracked and has no deps).
2. **Pin Node ≥ 23.4 (recommend 24 LTS)** via `NIXPACKS_NODE_VERSION` / `.nvmrc` / `engines` — the app uses experimental `node:sqlite`, which throws on Node 22.5–23.3 without a flag.
3. Build `npm ci`, start `npm start`. No build step.
4. (Prod) attach a volume + introduce a configurable DB path (code change).

---

## Readiness Blockers

| ID | Gates | Blocker | Fix |
|----|-------|---------|-----|
| **B1** | Any deploy | Deps live in `app/`; repo-root `package.json` is untracked & depless | **Config:** Root Directory = `app` |
| **B2** | Any deploy | `node:sqlite` throws on Node 22.5–23.3; start command has no flag | **Config:** pin Node ≥23.4/24 (or add `--experimental-sqlite`) |
| **B3** | Prod durability | DB path hardcoded inside source tree (`app/db.js:8`); volume can't mount cleanly | **Code:** add `DB_PATH` env, mount volume at `/data` |
| **B4** | Prod login | Production seeds no users; user creation needs an existing admin | **Code/ops:** seed/bootstrap first admin |

B1+B2 block even the demo (config-only). B3+B4 block production only (require code).

---

## Risks

- `node:sqlite` is experimental — pin Node to avoid breakage across versions.
- SQLite single-writer/single-process → **cannot horizontally scale**; >1 instance forces Postgres.
- No automated backup — relies on volume durability (snapshot/copy needed).
- No dedicated healthcheck route (port check suffices; `/healthz` would harden).
- Demo mode exposes well-known credentials over HTTPS — short-lived/controlled demos only.

---

## Recommended Next Steps

1. **Demo (today):** R0→R1→R4→R5 — service with Root Directory `app`, Node pinned, ephemeral SQLite, log in as `admin/admin123`, smoke-test CRUD + import.
2. **Production:** add `DB_PATH` + volume (B3), add first-admin bootstrap (B4), set `NODE_ENV=production` + `SESSION_SECRET`, then full smoke (R5), backups (R6), client handoff (R7).

Deployment DAG R0–R7 is detailed in the recon (§19).

---

## What Is NOT Being Done Yet

- No deployment, no Railway project/service creation, no Railway CLI run.
- No app-code change (B3/B4 documented, **not patched**).
- No DB migration, no `.env`/package/config change, no generated secrets.
- No volume provisioned, no managed DB added.

---

## Managed DB Note

SQLite via `node:sqlite` is **acceptable for this internal PM-tool MVP**. Managed Postgres is **not required now**. Consider it **later** only if the app needs high availability, multiple instances, or stronger backup/restore guarantees — that would be a DB-layer rewrite, not a config change.

---

## Decision Summary

- **Can we deploy to Railway now?** Yes — for a **demo** (after B1+B2 config). **Not** for production yet.
- **Must change before production:** B3 (durable DB path + volume), B4 (admin bootstrap).
- **Can wait:** managed Postgres, `/healthz`, automated backups.
- **Demo-ready:** ✅  **Production-ready:** ❌ (pending B3, B4).
