# Task: Run full runtime regression smoke test for all Phase 2 flows

## Parent Spec
specs/phase-2-review-checkpoint.md

## Phase
phase-build

## Layer
backend

## Status
done

## Description
Boot the server (or confirm already running) and execute the full smoke test battery covering all Phase 2 capabilities. Leave no permanent test data. Report all results.

Admin flow:
- Login (200, user returned, no password_hash)
- GET /api/me (role=admin, track_scope=[], no password_hash)
- GET /api/rows (200, rows array, no password_hash in rows)
- GET /api/users (200, users array, no password_hash in users)
- POST /api/import/preview with empty body (400)
- PUT /api/users/1 role=viewer → 403 (self-demote blocked)
- DELETE /api/users/1 → 403 (self-delete blocked)

Track-owner flow (vasu):
- Login (200)
- GET /api/me (role=track_owner, track_scope=["T3 AstraX Ops Cloud"])
- GET /api/rows (200)
- GET /api/users (403)
- POST /api/import/preview (403)
- POST /api/import/commit (403)
- POST /api/rows with track="T3 AstraX Ops Cloud" (201) → DELETE cleanup
- POST /api/rows with track="T1 AstraX Device" (403)
- DELETE /api/rows/:id (403)

Anonymous flow:
- GET /api/rows (401)
- GET /api/users (401)

CRUD strict validation:
- POST /api/rows with track="T1-Device" (non-canonical) → 400

Frontend asset checks:
- GET /app.js contains "renderDashboard"
- GET /app.js contains "renderImportPanel"
- GET /app.js does NOT contain "password_hash"

## Acceptance Criteria
- [ ] All admin smoke checks pass (200/400/403 as expected)
- [ ] Self-demote and self-delete both return 403
- [ ] Vasu rows=200, users/import=403, T3 create=201, T1 create=403, delete=403
- [ ] Anon rows/users = 401
- [ ] Strict CRUD: non-canonical track = 400
- [ ] /app.js has renderDashboard and renderImportPanel
- [ ] No password_hash in any API response
- [ ] No permanent test data left in DB

## Files Likely Affected
- app/server.js (read-only during smoke test — must NOT be modified)

## Blocked By
- tasks/phase-2-review-checkpoint-001.md
