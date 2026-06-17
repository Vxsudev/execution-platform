# Spec: Railway R4 — Service Config Runbook

## Status
approved

## Phase
phase-build

## Feature Slug
railway-r4-service-config-runbook

## Depends On
railway-hosting-readiness-recon (R0 @ 3ca17f0), railway-r1-runtime-start-alignment (R1 @ b113f11), railway-r2-db-path-volume-contract (R2 @ a3c1f55), railway-r3-env-session-admin-bootstrap (R3 @ 9be3466)

---

## Summary

Produce the exact Railway deployment configuration contract required for R5 deploy smoke.
Creates `docs/railway-service-config.md` — an internal operator runbook with service
settings, env var contract, volume contract, first-admin bootstrap procedure, R5 smoke
checklist, no-go conditions, and rollback notes. Explicitly decides against `railway.toml`
and Dockerfile. Leaves R5 as the first actual deploy/smoke node.

---

## Background

R1/R2/R3 resolved all four Railway readiness blockers. The codebase is deploy-ready.
R4 consolidates all config facts into a single operator runbook so R5 can proceed
without guessing at settings.

**railway.toml decision:** Not created. Nixpacks auto-detects Node 24 from `app/.nvmrc`,
`npm ci` from `package-lock.json`, and `npm start` from `package.json`. Railway dashboard
configuration is sufficient for first deployment. If auto-detection fails at R5, adding
`railway.toml` is the targeted fix at that time.

---

## Data Model Changes

none

---

## API Surface

Documentation surface: create `docs/railway-service-config.md` consolidating the Railway
service configuration contract derived from R1/R2/R3 code analysis. No HTTP endpoints
added, modified, or removed. No app behavior changed. Optionally add a link to the
runbook from `app/README.md`.

---

## Frontend Surface

none

---

## Non-Scope

- No Railway deployment
- No Railway project/service/volume creation
- No Railway CLI mutation
- No `railway.toml` creation
- No `Dockerfile` creation
- No app code changes (`app/db.js`, `app/server.js`, `app/public/*` unchanged)
- No `app/package.json`, `app/.nvmrc`, `app/.env.example` changes
- No secrets generated, no real passwords documented

---

## Implementation Plan

### Task 1 — Create docs/railway-service-config.md (backend)

Create `docs/railway-service-config.md` with all 8 required sections:

1. Deployment target (platform, style, branch, Root Directory, Node, build/start, port)
2. Railway service checklist (create service, connect repo, settings, confirmations)
3. Railway volume checklist (production path vs demo-only path)
4. Environment variable checklist (production required, first-boot, post-bootstrap)
5. First boot procedure (deploy → log confirm → login → remove PASSWORD → verify)
6. R5 smoke checklist (boot, critical-path, persistence, bootstrap cleanup)
7. No-go conditions (abort conditions for R5)
8. Rollback notes

Optionally add one-line link from `app/README.md` pointing to the runbook.

### Task 2 — Verification

Consistency checks (no boot, no deploy):
1. `node --check` on db.js, server.js, public/app.js
2. `cd app && npm run` → start = `node server.js`
3. Documentation consistency: Root Directory=app, Node=24, DB_PATH=/data/data.db, NODE_ENV=production, SESSION_SECRET required, bootstrap vars first-boot only
4. Invariants 5/5 PASS
5. git status — only allowed surfaces

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `docs/railway-service-config.md` | New file — full operator runbook |
| `app/README.md` | Optional: add one-line link to runbook |
| `ai/recon/railway-r4-service-config-runbook-recon.md` | Recon artifact |
| `specs/railway-r4-service-config-runbook.md` | This spec |
| `tasks/railway-r4-service-config-runbook-*.md` | OS-generated task graph |
| `ai/state_registry.json` | R4 lifecycle state |
| `ai/engineering-journal.md` | R4 journal entry |

---

## Verification Plan

No live boot or deploy. Documentation consistency only:
- All six config facts consistent across runbook, README sections, .env.example, and code
- No secrets in any committed artifact
- No forbidden surfaces modified
- Invariants 5/5 PASS

---

## Relationship to R5

R5 is the first actual Railway deploy smoke, executed by an operator following
`docs/railway-service-config.md`. R5 requires no code changes.
