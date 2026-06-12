# Task: Verify row payload sufficiency and confirm no backend changes required

## Parent Spec
specs/phase-3-import-provenance.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Validate that GET /api/rows already returns all fields needed for P3-5 provenance
display — specifically import_batch_id, import_source_sheet, import_source_row —
and that GET /api/imports returns id, filename, imported_by, imported_at, status,
observation_count. No code changes are expected. Document the decision: Option A
(client-side join) is sufficient; app/server.js does not need to be modified.

### Checks to run

1. `node --check server.js` → 0 (baseline; no changes to make)
2. Confirm PRAGMA table_info(entries) includes import_batch_id, import_source_sheet, import_source_row
3. Confirm SELECT * FROM entries returns all three import columns in a sample row (manual row OK)
4. Confirm GET /api/imports SQL includes observation_count correlated subquery
5. Confirm no password_hash column in entries (security gate)

### Decision record

- Backend approach: **Option A — client-side join**
- No routes added
- No schema changes
- server.js: NOT modified

## Acceptance Criteria
- [ ] node --check server.js exits 0
- [ ] entries table has import_batch_id, import_source_sheet, import_source_row
- [ ] GET /api/imports includes id, filename, imported_by, imported_at, status, observation_count
- [ ] No password_hash in entries SELECT *
- [ ] Decision recorded: Option A, no backend changes

## Files Likely Affected
- none (read-only validation)

## Blocked By
- none
