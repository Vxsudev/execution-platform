# Task: Create docs/railway-service-config.md operator runbook

## Parent Spec
specs/railway-r4-service-config-runbook.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Create `docs/railway-service-config.md` — the full Railway service configuration runbook
for R5 deploy smoke. All facts derived from R1/R2/R3 code analysis and existing docs;
no app code changes.

Sections required:
1. Deployment target (platform, source deploy, branch, Root Directory=app, Node=24, build/start, PORT)
2. Railway service checklist (create service, connect repo, configure settings)
3. Railway volume checklist (production: /data mount + DB_PATH; demo-only: skip volume)
4. Environment variable checklist (production required, first-boot only, post-bootstrap cleanup)
5. First boot procedure (deploy → log confirm → login → remove PASSWORD → verify idempotent)
6. R5 smoke checklist (boot, critical-path browser, persistence, bootstrap cleanup)
7. No-go conditions (abort conditions for R5)
8. Rollback notes

Also: optionally add one-line link from `app/README.md` bottom of Railway Deployment (R3)
section pointing operators to `docs/railway-service-config.md`.

Do NOT create railway.toml, Dockerfile, or any config file in app/.

## Acceptance Criteria
- [ ] `docs/railway-service-config.md` exists with all 8 sections
- [ ] Root Directory=app, Node=24, build=`npm ci`, start=`npm start` documented
- [ ] DB_PATH=/data/data.db, volume mount=/data, NODE_ENV=production, SESSION_SECRET documented
- [ ] Bootstrap vars documented as first-boot only; removal instruction present
- [ ] R5 smoke checklist covers boot, critical-path, persistence, bootstrap cleanup
- [ ] No-go conditions documented (≥8 conditions)
- [ ] No real secrets in the runbook
- [ ] No `railway.toml`, no `Dockerfile`

## Files Likely Affected
- docs/railway-service-config.md (new file, requires new docs/ directory)
- app/README.md (optional one-line link to runbook)

## Blocked By
- none
