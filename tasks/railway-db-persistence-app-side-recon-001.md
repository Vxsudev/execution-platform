# Task: App-side persistence recon (read-only)

## Parent Spec
specs/railway-db-persistence-app-side-recon.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Read-only inspection of `app/db.js` and `app/server.js` to answer the 8 recon objectives: DB path
resolution, directory creation/masking, SQLite open behavior, bootstrap overwrite risk, seed/demo
behavior, import persistence, auth/session impact, and Railway mount-distinguishability. Repo-wide grep
for destructive SQL (`DELETE`/`DROP`/`TRUNCATE`/reset/unlink). Produce
`ai/recon/railway-db-persistence-app-side-recon.md` with explicit verdict.

Outcome: **Verdict B** — app masks Railway mount failure via `mkdirSync(recursive:true)` + fresh SQLite
file; bootstrap never overwrites an existing admin; no destructive startup code; import is durable.

## Acceptance Criteria
- [x] DB path logic documented (`DB_PATH` honored; default `app/data.db`)
- [x] mkdir masking risk identified
- [x] Bootstrap overwrite risk answered (cannot overwrite existing admin)
- [x] Destructive startup code presence/absence answered (none)
- [x] Import persistence answered (durable, in-memory-independent)
- [x] Recon artifact written with verdict

## Files Likely Affected
- ai/recon/railway-db-persistence-app-side-recon.md (created)

## Blocked By
- none
