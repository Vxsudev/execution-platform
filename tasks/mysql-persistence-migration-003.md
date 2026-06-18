# Task: Preserve bootstrap, session, and user semantics

## Parent Spec
specs/mysql-persistence-migration.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Group 3: bootstrap/session/user preservation. Port the `db.js` boot logic to the async adapter without
semantic change: production `SESSION_SECRET` requirement stays in `server.js`; first admin created only
when no admin exists; existing admin password never overwritten; partial bootstrap env remains fatal;
no password length restriction. Demo user/role seed remains `NODE_ENV !== 'production'` only. Sessions
table + cookie/HMAC token flow unchanged (only the DB calls become async).

## Acceptance Criteria
- [ ] Bootstrap creates admin on empty DB; no-op when admin exists (verified in task 005)
- [ ] Existing admin password never overwritten
- [ ] Partial bootstrap env still fatal
- [ ] No password length restriction
- [ ] Demo seed gated to non-production
- [ ] Session create/lookup/delete work via async adapter

## Files Likely Affected
- app/db.js, app/server.js

## Blocked By
- mysql-persistence-migration-001
