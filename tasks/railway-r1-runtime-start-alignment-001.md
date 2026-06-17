# Task: Pin Node runtime and align package/start for Railway source deploy

## Parent Spec
specs/railway-r1-runtime-start-alignment.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Resolve Railway readiness blockers B1 (deploy topology) and B2 (Node version /
`node:sqlite` flag) via config + docs only — no app behavior change.

1. **Node pin (B2):** set `app/package.json` `engines.node` to `">=24"` and add
   `app/.nvmrc` containing `24`. The app requires the built-in `node:sqlite`
   module (`app/db.js:5`), which throws on Node 22.5–23.3 without
   `--experimental-sqlite` and is unflagged from 23.4. Node 24 (LTS) is safe.
   `.nvmrc` is the operative Nixpacks pin in the app root; `engines` documents
   the floor. The `--experimental-sqlite` flag is intentionally NOT added.
2. **Start/topology (B1):** confirm `app/package.json` `start` is `node server.js`
   (unchanged) and that it launches the real entrypoint, binds `process.env.PORT`
   (`app/server.js:601`), listens on all interfaces (`:602`), and serves the
   static UI from `public/` (`:19`). Document Railway Root Directory = `app`
   (deps + lockfile live there; the untracked repo-root `package.json` is inert
   under that setting and is left as-is).
3. **Docs:** update `app/README.md` Runtime Requirement to Node >= 24 and add a
   short "Railway Deployment (R1)" section (Root Directory `app`, Build `npm ci`,
   Start `npm start`, Node 24), noting R2 (DB persistence) and R3 (admin/env)
   remain before production.

Do NOT modify `app/server.js`, `app/db.js`, `app/public/*`, the DB path, schema,
or `app/package-lock.json` (engines is not locked).

## Acceptance Criteria
- [x] `app/package.json` `engines.node` === `">=24"`
- [x] `app/.nvmrc` exists and contains `24`
- [x] `app/package.json` `start` unchanged (`node server.js`); `npm start` lists/launches it
- [x] `app/README.md` documents Railway Root Directory `app`, Build `npm ci`, Start `npm start`, Node 24, and R2/R3 caveats
- [x] `app/package-lock.json` unchanged; `app/server.js`/`app/db.js`/`app/public/*` byte-for-byte unchanged
- [x] No `DB_PATH`, no schema change, no admin bootstrap, no Docker, no new dependency

## Files Likely Affected
- app/package.json (engines.node)
- app/.nvmrc (new)
- app/README.md (runtime requirement + Railway deploy note)

## Blocked By
- none
