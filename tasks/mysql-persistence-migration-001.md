# Task: MySQL schema + async connection adapter (db.js)

## Parent Spec
specs/mysql-persistence-migration.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Build a thin async DB adapter in `app/db.js` (group 1: MySQL schema + connection adapter). Select MySQL
(`mysql2/promise` pool) when `MYSQL_URL`/`MYSQLHOST` present, else SQLite (`node:sqlite`). Expose
`dba.get/all/run/tx/init/isUniqueViolation` with normalized `{ insertId, changes }`. Pool uses
`dateStrings: true`. Create the 5 tables idempotently with MySQL-compatible types
(VARCHAR(255) for username/token, MEDIUMTEXT for raw_data, DATETIME DEFAULT CURRENT_TIMESTAMP),
type/status/role validation app-level. Safe logging only (provider/host/db/connection booleans; no
credentials/URLs). Keep `ROW_FIELDS/ROW_TYPES/STATUSES/TRACKS` exports.

## Acceptance Criteria
- [ ] Backend auto-selected by env; SQLite retained for local dev
- [ ] `dba.get/all/run/tx/init/isUniqueViolation` implemented, results normalized
- [ ] MySQL schema initializes idempotently (per-statement DDL; guarded ALTERs)
- [ ] `dateStrings: true`; timestamps return `'YYYY-MM-DD HH:MM:SS'`
- [ ] No credentials/URLs logged
- [ ] `node --check app/db.js` OK

## Files Likely Affected
- app/db.js, app/package.json, app/package-lock.json

## Blocked By
- none
