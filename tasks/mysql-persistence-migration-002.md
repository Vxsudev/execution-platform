# Task: Migrate server.js routes to async DB adapter

## Parent Spec
specs/mysql-persistence-migration.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Group 2: server route migration to async DB adapter. Convert every `db.prepare(SQL).get/all/run(...)`
to `await dba.get/all/run(SQL, ...)`; make all DB-touching handlers and helpers (`currentUser`,
`requireAuth`) `async`. Add a `wrap(asyncFn)` helper so Express 4 forwards async rejections to a 500
JSON response. Replace the `datetime('now')` literal in the entries UPDATE with a JS-computed
`'YYYY-MM-DD HH:MM:SS'` bound param. Replace `db.exec('BEGIN'/'COMMIT'/'ROLLBACK')` (batch delete) with
`dba.tx()`. Use `dba.isUniqueViolation(e)` for the duplicate-username check.

## Acceptance Criteria
- [ ] No residual `db.prepare`/`db.exec` in `app/server.js` (grep clean)
- [ ] All DB-touching handlers async + `wrap()`ed; `currentUser`/`requireAuth` async
- [ ] `lastInsertRowid`→`insertId`, `.changes` handled via adapter shape
- [ ] UPDATE timestamp dialect-free
- [ ] Batch delete uses `dba.tx()`
- [ ] `node --check app/server.js` OK

## Files Likely Affected
- app/server.js

## Blocked By
- mysql-persistence-migration-001
