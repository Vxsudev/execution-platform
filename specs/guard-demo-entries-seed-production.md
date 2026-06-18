# Spec: Guard Demo Entries Seed in Production

## Status
approved

## Phase
phase-build

## Feature Slug
guard-demo-entries-seed-production

## Depends On
Recon: ai/recon/guard-demo-entries-seed-production-recon.md. Preserves admin bootstrap (R3),
demo-users dev seed, MySQL/DB connection logic, auth, import parser, schema, DB_PATH (R2).

---

## Summary

A fresh production boot of the app inserts 2 demo `entries` rows because the demo-entries seed in
`app/db.js` (the `if (SELECT COUNT(*) FROM entries == 0)` block) has **no environment guard** —
unlike the demo-**users** seed directly above it, which is already gated on
`process.env.NODE_ENV !== 'production'`. Add the same guard to the entries seed so production starts
with **zero** entries while local/dev keeps seeding demo rows. One-line condition edit; nothing else
changes.

---

## Background

`app/db.js` has four `NODE_ENV` guards already (demo-users seed, bootstrap admin, no-users warning,
dev role backfill). The demo-**entries** seed is the lone seed that runs unconditionally, so a clean
production database gets demo rows. Operator wants production to start empty. Dev/local demo seed is
useful and should remain.

---

## Data Model Changes

none

---

## API Surface

Backend-only change in `app/db.js`: gate the demo-entries seed on `process.env.NODE_ENV !==
'production'` (the exact predicate the demo-users seed already uses), so the seed runs only outside
production. No HTTP routes change. Bootstrap admin (production-only, presence/partial-config
fail-closed, create-only-if-no-admin, bcrypt) is unchanged. Demo-users seed unchanged. The
audit-column backfill UPDATEs are unchanged (harmless no-ops on an empty production `entries` table).
DB connection logic, auth, and the import parser are untouched.

---

## Frontend Surface

none

---

## Non-Scope

- No change to bootstrap admin behavior
- No change to the demo-users seed (already dev-only)
- No change to auth/session, user create/update
- No change to the import parser or import behavior
- No change to schema, migrations, DB_PATH, or DB connection logic
- No `app/public/*`, package, or deploy/Railway change; no Docker/MySQL/Postgres change

---

## Implementation Plan

### Task 1 — Backend: guard demo-entries seed on non-production (backend)

In `app/db.js`, change the demo-entries seed condition from:
```js
if (db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
```
to:
```js
if (process.env.NODE_ENV !== 'production' && db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
```
Leave the seed body and every other block (bootstrap, demo-users seed, audit backfill) unchanged.

### Task 2 — Verification

Disposable DBs only (live `app/data.db` untouched): production empty DB → bootstrap admin present +
`entries` 0 rows; dev empty DB → demo entries (2) + demo users seeded; import 64 still works;
`node --check`; invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | Add `process.env.NODE_ENV !== 'production' &&` to the demo-entries seed condition |
| `ai/recon/...` , `specs/...` , `tasks/...` , `ai/state_registry.json` , `ai/engineering-journal.md` | OS artifacts |

---

## Verification Plan

See recon §6. Key assertions: production empty DB → bootstrap admin only, `entries` 0 rows; dev
empty DB → demo entries + demo users seeded; import 64 unaffected; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — confirm a fresh production volume boots with the
bootstrap admin and an empty `entries` table.
