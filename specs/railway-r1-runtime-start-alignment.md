# Spec: R1 Railway Runtime / Start Alignment

## Status
approved

## Phase
phase-build

## Layer
L5-Build

## Upstream
- ai/recon/railway-hosting-readiness-recon.md (R0 — Railway hosting readiness recon; blockers B1, B2)
- ai/recon/railway-r1-runtime-start-alignment-recon.md (R1 implementation recon)

## Downstream
- R2 railway DB persistence / volume contract (DB_PATH + Railway volume) — depends on a deterministic runtime + correct deploy root established here
- R3 railway env + secret + first-admin bootstrap contract

## Capability

Before R1, the app cannot be safely deployed via Railway source deploy:
- **B1 (topology):** dependencies + lockfile live in `app/`; the repo-root `package.json` is untracked and dependency-less, so a repo-root deploy fails with `Cannot find module 'express'`.
- **B2 (runtime):** the app requires the experimental `node:sqlite` module (`app/db.js:5`), which throws on Node 22.5–23.3 without `--experimental-sqlite`; `engines.node` is `">=22.5"` and the start command carries no flag, so Railway/Nixpacks may select a Node version that crashes at boot.

After R1:
- The Railway deploy contract is **Root Directory = `app`**, Build `npm ci`, Start `npm start` — documented in `app/README.md`. (Root Directory is a Railway setting; no code change needed for B1.)
- Node is pinned to a safe major (**24**) via `app/.nvmrc` (operative Nixpacks pin) and `engines.node ">=24"` (documented floor), resolving B2.
- The start script, port binding, static serving, DB path, schema, and all HTTP behavior are **unchanged**.
- The untracked repo-root `package.json` is left as-is (inert under Root Directory = `app`; see recon §6).

R1 does **not** deploy, create Railway services/volumes, add `DB_PATH`, implement admin bootstrap, or change app behavior.

## Data Model Changes
none

## API Surface

R1 changes the backend service's **runtime / start surface** only. **No HTTP endpoint is added, removed, or modified.** No request/response shape changes. No route, auth, validation, or business logic changes.

Runtime/start surface changes:

1. **`app/package.json` `engines.node`**: `">=22.5"` → `">=24"`. Documents the minimum Node major. Not present in the lockfile, so `app/package-lock.json` is unaffected.
2. **`app/.nvmrc`** (new file): `24`. The deterministic Node-major pin honored by Railway/Nixpacks in the app root (resolution order: `NIXPACKS_NODE_VERSION` → `.nvmrc` → `engines.node`).
3. **Start command**: unchanged — `npm start` → `node server.js` (`app/package.json:11`). Verified to launch the real entrypoint, bind `process.env.PORT` (`app/server.js:601`), listen on all interfaces (`:602`), and serve static UI from `public/` (`:19`).
4. **`--experimental-sqlite` flag**: NOT added. Pinning Node ≥24 makes it unnecessary (the flag was removed at 23.4.0).

Rationale: the OS build-tier layer model maps service-runtime configuration to the **backend** layer; this section drives generation of a backend task. It is explicitly not an HTTP API surface.

## Frontend Surface
none

## Documentation Surface

`app/README.md`:
- Update "## Runtime Requirement" from `Node >= 22.5` to `Node >= 24`.
- Add a short "Railway Deployment (R1)" subsection: Root Directory `app`, Build `npm ci`, Start `npm start`, Node 24 (`.nvmrc`). Note that **R2** (DB persistence/volume) and **R3** (env + first-admin bootstrap) are still required before production. Keep it lean.

## Dependencies

- R0 recon: `ai/recon/railway-hosting-readiness-recon.md` (committed `3ca17f0`)
- R1 recon: `ai/recon/railway-r1-runtime-start-alignment-recon.md`
- No new npm packages. No native build. No Docker.

## Acceptance Criteria

1. `app/package.json` `engines.node` equals `">=24"`.
2. `app/.nvmrc` exists and contains `24`.
3. `app/package-lock.json` is unchanged (engines not locked).
4. Start script unchanged: `app/package.json` `start` = `node server.js`; `npm start` launches the server from `app/`.
5. Boot smoke: `node server.js` (high `PORT`) prints `execution-table-app running on http://localhost:<PORT>`, then is stopped. No DB rows created.
6. `app/README.md` documents Railway Root Directory `app`, Build `npm ci`, Start `npm start`, Node 24, and the R2/R3 caveats.
7. Repo-root `package.json` decision recorded (left as-is; inert under Root Directory `app`).
8. `app/server.js`, `app/db.js`, `app/public/*` are **byte-for-byte unchanged** (verified via `git diff`).
9. No `DB_PATH`, no schema change, no admin bootstrap, no Docker, no new dependency.
10. `node --check` passes on `app/server.js`, `app/db.js`, `app/public/app.js`.
11. Invariants 5/5 PASS (enforced by the supervisor's invariant gate).
12. No `[FILL:]` residue in task files.
13. Final state = `RELEASE_APPROVED`.
14. Git status shows only allowed surfaces modified.

## Out of Scope

- Any Railway deployment, project/service creation, or volume provisioning (R4/R5).
- `DB_PATH` env var and DB-path relocation (R2 — blocker B3).
- Railway persistent volume mount (R2).
- First-admin bootstrap and production env/secret contract (R3 — blocker B4).
- Any change to `app/server.js`, `app/db.js`, `app/public/*`.
- Any HTTP API, auth, validation, role, dashboard, table, import, or details behavior.
- Docker / containerization.
- Any new npm package.
- Deleting the untracked repo-root `package.json`.
