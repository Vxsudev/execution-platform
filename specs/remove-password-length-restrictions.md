# Spec: Remove Password Length Restrictions

## Status
approved

## Phase
phase-build

## Feature Slug
remove-password-length-restrictions

## Depends On
Recon: ai/recon/remove-password-length-restrictions-recon.md. Preserves auth/session, bcrypt hashing, admin bootstrap (R3), DB_PATH (R2), Railway config (R4), access-control removal, row-click edit.

---

## Summary

Remove all application-level password **length** restrictions. Recon found exactly one: the
`BOOTSTRAP_ADMIN_PASSWORD` 12-character minimum in `app/db.js`. Remove that check and sync the
"12-char" wording in `.env.example`, `README.md`, and the Railway runbook. Preserve bcrypt
hashing, login, password comparison, missing/empty-password rejection, the bootstrap flow, and
the production `SESSION_SECRET` 32-char guard (a session-key rule, not a password rule).

---

## Background

Operator requirement changed: no minimum password length. The only length rule on a password is
`app/db.js` bootstrap (`_bPass.trim().length < 12` → FATAL). User-creation passwords
(`app/server.js`) already have no length rule (presence-only). `SESSION_SECRET.length < 32`
(`app/server.js:45`) is the session signing key — explicitly out of scope and preserved.

---

## Data Model Changes

none

---

## API Surface

Backend bootstrap change in `app/db.js`: remove the `BOOTSTRAP_ADMIN_PASSWORD` minimum-length
guard so any non-empty bootstrap password is accepted (still bcrypt-hashed; still production-only;
still create-only-if-no-admin; still fails closed on partial config). No HTTP routes change. User
create/update password handling is unchanged (presence-only, already no length rule). Login and
`bcrypt.compareSync` unchanged. `SESSION_SECRET` production requirement and 32-char minimum
unchanged.

---

## Frontend Surface

none — password fields in `app/public/app.js` have no `minlength`/length validation.

---

## Non-Scope

- No change to bcrypt hashing, login, or password comparison
- No change to missing/empty-password rejection (kept)
- No change to `SESSION_SECRET` requirement or its 32-char minimum
- No change to roles, imports, access-control removal, row-click edit, DB_PATH, schema
- No `app/public/*`, `app/package.json`, `app/package-lock.json`, `app/.nvmrc` change
- No Railway service-config change beyond removing obsolete password-minimum wording
- No Docker, Postgres, deployment; no plaintext storage; no password logging

---

## Implementation Plan

### Task 1 — Backend: remove bootstrap password minimum + sync docs (backend)

- `app/db.js`: delete the `if (_bPass.trim().length < 12) { FATAL; process.exit(1); }` block
  inside the bootstrap path. Keep the presence check (`_hasPass`), partial-config fail-closed,
  admin-exists check, and `bcrypt.hashSync`.
- `app/.env.example`: change the bootstrap-password placeholder to a neutral value (no "12-plus-char").
- `app/README.md`: drop "12+ char" / "(min 12 chars)" from the two `BOOTSTRAP_ADMIN_PASSWORD`
  rows (keep "strong"/"bcrypt-hashed"/"remove after" guidance and the SESSION_SECRET 32-char text).
- `docs/railway-service-config.md`: drop "12+ char" from the `BOOTSTRAP_ADMIN_PASSWORD` row.

### Task 2 — Verification

Disposable DBs only (live `app/data.db` untouched): bootstrap + login with a short non-empty
password; user-create + login with a short non-empty password; missing/empty password still
rejected (bootstrap partial-config FATAL; user-create 400); SESSION_SECRET missing/short still
FATAL; bcrypt storage + no password logging; `node --check`; dev boot smoke; invariants 5/5;
git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/db.js` | Remove `BOOTSTRAP_ADMIN_PASSWORD` 12-char minimum block |
| `app/.env.example` | Neutral bootstrap-password placeholder |
| `app/README.md` | Drop "12+ char"/"min 12 chars" (2 rows) |
| `docs/railway-service-config.md` | Drop "12+ char" (1 row) |
| `ai/recon/...` , `specs/...` , `tasks/...` , `ai/state_registry.json` , `ai/engineering-journal.md` | OS artifacts |

---

## Verification Plan

See recon §9. Key assertions: short non-empty password accepted at bootstrap and user creation +
login works; missing/empty still rejected; SESSION_SECRET guard intact; bcrypt only; no password
logged; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — confirm bootstrap accepts the operator's chosen
password on the live deployment.
