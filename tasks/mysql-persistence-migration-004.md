# Task: Preserve entry CRUD + import commit/batch-delete

## Parent Spec
specs/mysql-persistence-migration.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Group 4: entry CRUD + import commit preservation. Ensure rows CRUD, import preview (read-only), import
commit (writes all previewed importable rows; duplicate detection + `allow_duplicates`; import history
+ observations), and batch delete (entries + observations + evidence-based legacy-orphan recovery,
inside `dba.tx()`) behave identically on MySQL. Verify `insertId` is used for `import_batch_id` linkage
and entry ids, and `changes`/`affectedRows` drive the delete counts.

## Acceptance Criteria
- [ ] Create/read/update/delete row parity
- [ ] Preview writes nothing
- [ ] Commit inserts every previewed importable row; counts match
- [ ] Duplicate detection + observations + history preserved
- [ ] Batch delete removes entries + observations transactionally; counts correct
- [ ] Legacy-orphan recovery preserved

## Files Likely Affected
- app/server.js

## Blocked By
- mysql-persistence-migration-002
