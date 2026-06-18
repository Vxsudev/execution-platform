# Task: Remove BOOTSTRAP_ADMIN_PASSWORD length minimum and sync docs

## Parent Spec
specs/remove-password-length-restrictions.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Remove the only application-level password length restriction and update obsolete
password-minimum documentation.

`app/db.js` (bootstrap block): delete the length check
```js
if (_bPass.trim().length < 12) {
  console.error('FATAL: BOOTSTRAP_ADMIN_PASSWORD must be at least 12 characters.');
  process.exit(1);
}
```
Keep everything else in the bootstrap path: the presence check (`_hasPass`), the partial-config
fail-closed (`_hasUser !== _hasPass` → FATAL), the create-only-if-no-admin guard, production-only
gate, and `bcrypt.hashSync(_bPass.trim(), 10)`. Do NOT touch `SESSION_SECRET` (server.js:45, the
32-char guard is a session-key rule and stays).

Docs sync (remove "12-char" password-minimum wording; keep SESSION_SECRET 32-char text):
- `app/.env.example`: change `# BOOTSTRAP_ADMIN_PASSWORD=replace-with-12-plus-char-password` to a
  neutral placeholder with no minimum claim.
- `app/README.md`: drop "12+ char" (bootstrap table row ~74) and "(min 12 chars)" (env-vars table
  row ~273) from the `BOOTSTRAP_ADMIN_PASSWORD` descriptions; keep "strong"/"bcrypt"/"remove after".
- `docs/railway-service-config.md`: drop "12+ char" from the `BOOTSTRAP_ADMIN_PASSWORD` row (~91).

Do NOT change `app/server.js` user-create/update (presence-only, already no length rule), schema,
`app/public/*`, package/config files.

## Acceptance Criteria
- [ ] `app/db.js` no longer contains the `_bPass.trim().length < 12` FATAL block
- [ ] Bootstrap still: production-only, presence-checked, partial-config fail-closed, create-only-if-no-admin, bcrypt-hashed
- [ ] `app/server.js` SESSION_SECRET 32-char guard unchanged
- [ ] `app/.env.example`, `app/README.md` (×2), `docs/railway-service-config.md` no longer state a 12-char password minimum
- [ ] No new password logging; no plaintext storage; no schema change
- [ ] `node --check app/db.js` passes

## Files Likely Affected
- app/db.js (remove length block)
- app/.env.example, app/README.md, docs/railway-service-config.md (doc sync)

## Blocked By
- none
