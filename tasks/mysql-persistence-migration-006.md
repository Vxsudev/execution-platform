# Task: Update env example + README DB-provider docs

## Parent Spec
specs/mysql-persistence-migration.md

## Phase
phase-build

## Status
done

## Layer
docs

## Description
Group 6: documentation/env update. Update `app/.env.example` and `app/README.md` for the MySQL
production contract: add `MYSQL_URL` (preferred) + `MYSQLHOST/PORT/USER/PASSWORD/DATABASE` fallback;
mark `DB_PATH` as local-dev SQLite only (retired from production); keep `SESSION_SECRET`, bootstrap
vars (first boot only). Document dual-backend selection and that production no longer depends on a
Railway volume. No secrets in examples (placeholders only).

## Acceptance Criteria
- [ ] `.env.example` documents MySQL vars + retired `DB_PATH`
- [ ] README DB-provider section + env table updated (MySQL prod, SQLite dev)
- [ ] No real credentials in docs
- [ ] Railway app-variable changes summarized for operator (not applied)

## Files Likely Affected
- app/.env.example, app/README.md

## Blocked By
- mysql-persistence-migration-001
