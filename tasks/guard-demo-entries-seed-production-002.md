# Task: Verify production starts with zero entries; dev seed and import 64 intact

## Parent Spec
specs/guard-demo-entries-seed-production.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify the demo-entries seed guard from task 001. Use disposable databases only (a throwaway
`DB_PATH`); never mutate the live `app/data.db`.

1. `node --check app/db.js` passes.
2. **Production empty DB:** with `NODE_ENV=production`, `BOOTSTRAP_ADMIN_USERNAME` and
   `BOOTSTRAP_ADMIN_PASSWORD` set, and a fresh `DB_PATH`, require `app/db.js`. Assert the `users`
   table contains the bootstrap admin (role = admin) and the `entries` table has **0** rows.
3. **Dev empty DB:** with `NODE_ENV` unset and a fresh `DB_PATH`, require `app/db.js`. Assert the
   demo entries seed ran (2 rows) and the demo users were seeded — the dev fallback is intact.
4. **Import 64 still works:** the import path against the authoritative 64-row workbook fixture is
   unaffected by the seed guard.
5. `bash scripts/invariant-check.sh` → 5/5 PASS; `git status` shows only allowed surfaces
   (`app/db.js`, OS artifacts).

## Acceptance Criteria
- [ ] Production empty DB → `users` has bootstrap admin, `entries` has 0 rows
- [ ] Dev empty DB → demo entries (2 rows) and demo users seeded (fallback preserved)
- [ ] Import of the 64-row workbook still yields 64 importable rows
- [ ] `node --check app/db.js` passes; invariants 5/5; git status only allowed surfaces

## Files Likely Affected
- (verification only — no application source changes)

## Blocked By
- tasks/guard-demo-entries-seed-production-001.md
