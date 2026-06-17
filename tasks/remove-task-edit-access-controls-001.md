# Task: Open backend row create/edit authorization to any authenticated user

## Parent Spec
specs/remove-task-edit-access-controls.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
In `app/server.js`, remove the role/track-scope restriction on row create and edit so any
authenticated user can create and edit any row. Both routes are already gated by
`requireAuth`, so "any authenticated user" is the new authorization floor.

Changes:
1. `canCreateRow` (lines 28-32) → return true. Add a comment citing the 2026-06-18 client
   requirement (create/edit open to all authenticated users; track ownership no longer an
   edit boundary).
2. `canEditRow` (lines 33-40) → return true (also drops the existing/next track-scope check).
3. Keep signatures so call sites at lines 179 (`POST /api/rows`) and 192 (`PUT /api/rows/:id`)
   are unchanged; the 403 guards remain as harmless defensive structure.

Do NOT change `canDeleteRow` (admin-only), `canImport` (admin-only), `canManageUsers`
(admin-only), `parseScope`, the SESSION_SECRET guard, auth/session code, or `validate()`
(canonical track-value validation is data integrity, not access control).

## Acceptance Criteria
- [ ] `canCreateRow` returns true for any authenticated user (admin, track_owner, viewer)
- [ ] `canEditRow` returns true for any authenticated user, for any row/track
- [ ] `canDeleteRow`, `canImport`, `canManageUsers` remain admin-only (unchanged)
- [ ] `validate()` still rejects non-canonical track values
- [ ] SESSION_SECRET guard, login/session/cookie code unchanged
- [ ] `app/db.js`, schema, DB_PATH, first-admin bootstrap untouched
- [ ] `node --check app/server.js` passes

## Files Likely Affected
- app/server.js (canCreateRow, canEditRow)

## Blocked By
- none
