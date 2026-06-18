# Task: Verify import preview UX (auto-preview, bullets, pagination) and preserved behavior

## Parent Spec
specs/import-preview-ux-friction-fix.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the UX changes and confirm no regression to import behavior. Static checks on the rendered
markup/logic + an API-level commit check on a disposable DB (live `app/data.db` never mutated).

Checks (in-session worker):
1. `node --check` app/public/app.js, app/server.js, app/db.js; `cd app && npm run`
2. Dev boot smoke (NODE_ENV unset) → running line; live `app/data.db` byte-for-byte unchanged
3. Static assertions on `app/public/app.js`:
   - no `importPreviewBtn`; file input `onchange` runs preview (`/import/preview`)
   - paragraph replaced by `import-legend` bullets; `import-status` present
   - importable render uses a page slice (size 20) + `importPrev`/`importNext`; heading shows
     "showing" range; no hardcoded `slice(0, 10)` for importable rows
   - `state.importPage` exists and resets on preview/commit/tab entry
   - commit still maps `p.rows` (all) — not a page slice
4. API parity on disposable DB (operator workbook): preview importable=64; commit inserted=64
   (preview==commit); batch delete removes all; manual rows untouched
5. `bash scripts/invariant-check.sh` → 5/5 PASS
6. `git status` → only allowed surfaces (app.js, style.css + OS artifacts)

## Acceptance Criteria
- [x] `node --check` passes on app.js, server.js, db.js
- [x] Dev boot smoke prints running line; live `app/data.db` byte-for-byte unchanged
- [x] No `importPreviewBtn`; file `onchange` → preview; `import-legend` bullets + `import-status` present
- [x] Importable rows paginated (size 20) with Prev/Next + "showing X–Y of N" (line 580); no importable `slice(0,10)` cap (remaining `slice(0,10)` are dashboard + date, not import)
- [x] Commit maps all `p.rows`; preview==commit (64==64 on operator workbook); batch delete removed 64; manual rows untouched
- [x] Pagination math covers all 64 rows across 4 pages (1–20, 21–40, 41–60, 61–64)
- [x] Summary/skipped/history preserved; backend (server.js/db.js/schema) unchanged
- [x] Invariants 5/5 PASS
- [x] No generated placeholder residue in task files
- [x] Git status shows only allowed surfaces (app.js + style.css); final state `RELEASE_APPROVED`

## Files Likely Affected
- (verification only — no source files modified)

## Blocked By
- tasks/import-preview-ux-friction-fix-002.md
