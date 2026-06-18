# Task: Verify against disposable MySQL + SQLite smoke

## Parent Spec
specs/mysql-persistence-migration.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Group 5: verification with disposable/local MySQL. Boot the app against a throwaway `mysql:8` container
and run the 15 required smokes over HTTP (boot/schema-init idempotent; bootstrap creates admin on empty
DB; restart skips bootstrap; login; create user; create row; edit row; import preview; import commit
writes all previewed importable rows from `source-materials/workbooks/astraX-…xlsx`; import history
count; batch delete; restart preserves data; no `/data/data.db` dependency; no secrets logged). Also
run a SQLite-backed async smoke to prove path parity. Disposable DBs only; live `app/data.db` untouched;
no Railway mutation; no production data import; no deploy.

## Acceptance Criteria
- [ ] `node --check` both files; `npm install` clean
- [ ] App boots on MySQL; schema idempotent across restarts
- [ ] Bootstrap create + restart-skip verified
- [ ] Login / create user / create+edit row verified
- [ ] Import preview + commit (all importable rows) + history count verified
- [ ] Batch delete verified
- [ ] Restart preserves data
- [ ] No secrets in logs; no `/data` dependency in MySQL path
- [ ] SQLite async smoke passes (parity)

## Files Likely Affected
- (none — verification only; disposable DBs)

## Blocked By
- mysql-persistence-migration-002, mysql-persistence-migration-003, mysql-persistence-migration-004
