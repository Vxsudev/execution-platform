# R1 — Railway Runtime / Start Alignment Recon

- **Capability:** R1 Railway Runtime / Start Alignment
- **Feature slug:** `railway-r1-runtime-start-alignment`
- **Upstream authority:** `ai/recon/railway-hosting-readiness-recon.md` (committed `3ca17f0`) — blockers **B1** (deploy topology) and **B2** (Node version / `node:sqlite` flag)
- **Mode:** OS-ENABLED · phase `phase-build`
- **Scope:** runtime/start alignment ONLY — no deploy, no Railway project/service/volume, no `DB_PATH`, no admin bootstrap, no app-behavior change, no Docker
- **Date:** 2026-06-17 · **Branch:** `main`

---

## 1. Executive Summary

R1 makes the app deployable via **Railway source deploy with Root Directory = `app`** and a **deterministic Node runtime**, resolving readiness blockers **B1** and **B2** from the hosting recon. The required mutation is **config-only and tiny**: bump `app/package.json` `engines.node`, add `app/.nvmrc`, and document Railway settings in `app/README.md`. The start command (`npm start` → `node server.js`) and port binding already work and need **no change**. R1 does **not** touch durability (R2) or admin bootstrap (R3).

---

## 2. Files Read (this recon)

| File | Lines / focus | Finding |
|------|---------------|---------|
| `app/package.json` | `:7-9` engines, `:10-12` start, `:13-17` deps | `engines.node ">=22.5"`; `start: node server.js`; pure-JS deps |
| `app/package-lock.json` | tracked | reproducible `npm ci`; engines not locked → engines bump won't modify it |
| `app/server.js` | `:601-602` PORT/listen; `:19` static | binds `process.env.PORT`, all interfaces; serves `public/` |
| `app/db.js` | `:5,8` `node:sqlite` `DatabaseSync` | runtime requires `node:sqlite` → Node-version-sensitive (B2 root cause) |
| `package.json` (repo root) | untracked; no deps; `start: node app/server.js` | B1 root cause — see §6 |
| `.gitignore` | root | `vendor/engineering-os/`, `data.db*`, `node_modules/` ignored |
| `app/README.md` | `:5-16` runtime/quick-start; `:181-208` production | documents Node >= 22.5; env contract |
| `specs/phases/phase-build.md` | `Phase: phase-build`, status approved | valid phase tag for compile-spec |
| OS runtime: `vendor/engineering-os/scripts/{compile-spec,generate-tasks,execution-supervisor,state-manager}.sh` | — | token flow + state machine understood (see §9) |

---

## 3. Commands Run (read-only recon)

```text
node --version            → v25.4.0
npm --version             → 11.7.0
node -e require('node:sqlite')  → loads w/ ExperimentalWarning (no flag on v25)
node --check app/server.js / app/db.js / app/public/app.js → all OK
cd app && npm run         → only "start": node server.js
git ls-files package.json → empty (root package.json UNTRACKED)
git ls-files app/package-lock.json app/package.json → both tracked
bash scripts/state-manager.sh get railway-r1-runtime-start-alignment → RECON_READY
bash vendor/engineering-os/scripts/os-adapter-check.sh → 12 PASS / 0 FAIL
bash scripts/invariant-check.sh → 5/5 PASS
command -v python3 (3.14.3); [ -d scripts/verification ] → ABSENT; command -v claude → present
```

---

## 4. Railway Readiness Blockers Addressed

- **B1 — Deploy topology.** Dependencies + lockfile live in `app/`, not repo root. Repo-root `package.json` is **untracked** and has **no dependencies**. Deploying from repo root → `Cannot find module 'express'`. **R1 fix: documented Railway setting Root Directory = `app`** (no code change needed; the manifest at `app/` is already correct).
- **B2 — Node version / `node:sqlite` flag.** `app/db.js:5` `require('node:sqlite')`. Introduced 22.5.0 behind `--experimental-sqlite`; **unflagged at 23.4.0**. On Node 22.5–23.3 the bare require throws → boot crash. Current `engines.node ">=22.5"` permits the dangerous range and the start command carries no flag. **R1 fix: pin Node to a safe major.**

R1 does **not** address B3 (DB durability) or B4 (admin bootstrap) — deferred to R2/R3.

---

## 5. Current Package / Script Findings

- `app/package.json:10-12` → `"start": "node server.js"` — **valid, runs the real entrypoint** (`app/server.js`). No build script; no separate frontend build; Express serves static UI (`app/server.js:19`). **No change required** to the start script.
- Build command can remain `npm ci` (lockfile tracked, pure-JS deps, no native compile).
- `engines.node` is currently `">=22.5"` (`app/package.json:7-9`) — **too low / ambiguous** for `node:sqlite` (B2). This is the one manifest field that must change.

## 6. Root `package.json` Finding & Decision

`package.json` at repo root is **untracked** (`git ls-files` empty) and depless (`scripts.start: node app/server.js`, no `dependencies`, no lockfile).

- It is **not** in git, so it will **not** be part of a Railway git/source deploy.
- With **Root Directory = `app`**, Railway never reads the repo root, so this file is **inert** for deployment.
- It is a harmless local convenience (lets a developer run `npm start` from the repo root).

**Decision: LEAVE AS-IS.** It is neither tracked nor harmful under the R1 deploy assumption (Root Directory = `app`). Deleting an operator-created untracked file is unnecessary and out of scope. (Optional-surface deletion in the directive is gated on "recon proves it harmful" — recon proves the opposite.)

## 7. Current Node / Runtime Findings

- Local Node: **v25.4.0** — satisfies any `>=24`/`>=22.5` floor; `node:sqlite` loads (experimental warning only).
- Risk is **on Railway**, where Nixpacks selects the Node version. Nixpacks resolves Node from (priority order) `NIXPACKS_NODE_VERSION` env → `.nvmrc` → `engines.node`. Without an explicit pin, Nixpacks may pick a major in the dangerous 22.5–23.3 range.
- Safe target: **Node 24 (current LTS)** — `node:sqlite` is unflagged and stable there.

## 8. Recommended Mutation Plan (R1)

All within allowed surfaces; **config/docs only**:

1. **`app/package.json`** — change `engines.node` `">=22.5"` → `">=24"`. (Engines is not in the lockfile, so `app/package-lock.json` is unchanged.)
2. **`app/.nvmrc`** (new) — contents `24`. This is the operative, deterministic pin Nixpacks respects in the app root; `engines` documents the floor. Both agree (≥24 / =24) → consistent, not harmful. Do **not** add `--experimental-sqlite` (pinning Node ≥24 makes it unnecessary).
3. **`app/README.md`** — update Runtime Requirement to `>= 24` and add a short "Railway Deployment (R1)" note: Root Directory `app`, Build `npm ci`, Start `npm start`, Node 24; R2 (DB persistence) and R3 (admin bootstrap/env) still required for production.

Explicitly **NOT** changed: `app/server.js`, `app/db.js`, `app/public/*`, the start script, the DB path, schema, any HTTP behavior, root `package.json`.

## 9. OS Pipeline Plan

`compile-spec.sh` (require `RECON_READY` → `SPEC_LOCKED`, write token) → `generate-tasks.sh` (require token + `SPEC_LOCKED`; derive layers from spec sections; → `TASK_GRAPH_LOCKED`) → implement in-session → `execution-supervisor.sh` (require `TASK_GRAPH_LOCKED`; invariant gate; → `EXECUTION_ACTIVE` → `VERIFICATION_REQUIRED` → `RELEASE_APPROVED`; append journal).

- **Task graph (deterministic):** spec declares `## API Surface` = the backend service's **runtime/start surface** (no HTTP endpoint change) and `## Data Model Changes` / `## Frontend Surface` = none → generator emits **2 tasks**: `-001` backend (engines pin + `.nvmrc` + start/root + README note) and `-002` verification. The directive's 5 responsibility groups are covered across these 2 tasks (the directive explicitly permits a generator count ≠ 4).
- **Execution model:** the supervisor normally spawns a nested `claude --dangerously-skip-permissions` worker per pending task. Because (a) launching an unsupervised skip-permissions agent is a heavyweight action and (b) the worker prompt depends on `ai/coding-patterns.md` + `ai/runtime-contracts.md` which **do not exist** in this repo, the R1 edits are performed **in-session** (I am the execution worker, with full B1/B2 context), tasks are marked `done`, and the supervisor is then run to enforce the invariant gate, traverse the remaining state transitions, run the (absent → skipped) verification gate, and write the canonical journal entry. This is faithful to the governance intent and deterministic.

## 10. Risks

- **Nixpacks pin precedence:** if a stray `NIXPACKS_NODE_VERSION` is set in the Railway service it overrides `.nvmrc`/`engines`. Mitigation: README documents Node 24 as the required setting; operator confirms no conflicting override.
- **`.nvmrc` + `engines` redundancy:** benign — both express ≥24/=24. `.nvmrc` is the deterministic major pin; `engines` is the documented floor. No conflict.
- **Local smoke is under v25, not Railway's Node:** a local boot proves the code starts but cannot prove Railway's selected version. The pin (≥24/.nvmrc 24) is the actual mitigation; verified by inspection, not local runtime.
- **No behavior change risk:** engines/.nvmrc/README do not affect runtime logic; `node --check` + boot smoke confirm no syntax/boot regressions.

## 11. Verification Plan

- `node --check app/server.js`, `app/db.js`, `app/public/app.js` → OK
- `cd app && npm run` lists `start`
- bounded `node server.js` boot smoke (high PORT) → confirm "running on http://localhost:PORT", then stop; **no DB rows created** (DB already populated; seed guards are count==0)
- `bash scripts/invariant-check.sh` → 5/5 PASS (also enforced by the supervisor's invariant gate)
- `git status` shows only allowed surfaces; `git diff` confirms `app/server.js`/`app/db.js`/`app/public/*` untouched
- final state = `RELEASE_APPROVED`

## 12. Dependency Relationship to R2 (DB_PATH / Volume Contract)

R1 is a **prerequisite** for R2 but is independent of it. R1 establishes a deterministic runtime + correct deploy root; **R2** will introduce an env-configurable DB path (`DB_PATH`) — a change to `app/db.js:8` — and a Railway persistent volume mounted at e.g. `/data`, so data survives redeploys. R1 deliberately leaves the hardcoded DB path untouched; production durability remains a **known open blocker (B3)** until R2. R1 alone yields a **demo-ready** (ephemeral-data) deploy.
