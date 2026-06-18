# Task: Confirm no backend change needed for import preview UX

## Parent Spec
specs/import-preview-ux-friction-fix.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Backend confirmation only (recon found nothing to change). The `POST /api/import/preview`
response already returns `summary.importable_rows`, the full `rows` array, and `skipped_rows`, so
the frontend can paginate the in-memory `rows` locally and show "X–Y of N" without any new
metadata. Auto-preview reuses the existing preview endpoint; commit is unchanged and already
sends all `p.rows`.

Outcome: **no change to `app/server.js` or `app/db.js`.** This task documents the deliberate
decision so the backend responsibility group is covered. Do not modify backend surfaces.

## Acceptance Criteria
- [ ] Confirmed preview response carries `importable_rows`, full `rows`, `skipped_rows`
- [ ] Pagination is derivable client-side; no new backend metadata required
- [ ] `app/server.js`, `app/db.js`, schema unchanged

## Files Likely Affected
- (none — confirmation only)

## Blocked By
- none
