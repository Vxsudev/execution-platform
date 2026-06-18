# Remove Password Length Restrictions: Recon

**Feature Slug:** remove-password-length-restrictions  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** 0976e87

---

## 1. Recon Objective

Read-only recon to find every application-level password **length** restriction and remove only
those, while preserving bcrypt hashing, login, sessions, admin bootstrap flow, missing/empty
password rejection, and the production `SESSION_SECRET` minimum-length guard (which is NOT a
password rule).

---

## 2. Files Read

| File | Finding |
|------|---------|
| `app/db.js` | Bootstrap block has the **only** password length check (`< 12`) |
| `app/server.js` | Password presence checks (login, user create/update) — no length; `SESSION_SECRET < 32` is separate |
| `app/public/app.js` | Password fields have **no** `minlength` / length validation |
| `app/public/index.html` | (rows/UI JS-rendered) no password length markup |
| `app/.env.example` | Comment claims "12-plus-char-password" |
| `app/README.md` | Two spots claim "12+ char" / "min 12 chars" for bootstrap password |
| `docs/railway-service-config.md` | One spot claims "Strong 12+ char password" |

Local governance surfaces: only `ai/invariant-registry.md` present (as before).

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # adapter valid
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -1                  # clean; HEAD=0976e87
grep -nE "length|password|BOOTSTRAP_ADMIN_PASSWORD|SESSION_SECRET|12|32" app/server.js app/db.js
grep -niE "minlength|password.*length|uf-password|type=.password" app/public/app.js app/public/index.html
grep -niE "12[ +-]?char|at least 12|min.*12|BOOTSTRAP_ADMIN_PASSWORD" app/README.md app/.env.example docs/railway-service-config.md
```

---

## 4. Password Validation Map

### THE password length restriction (to remove) — `app/db.js:135-138`
```js
if (_bPass.trim().length < 12) {
  console.error('FATAL: BOOTSTRAP_ADMIN_PASSWORD must be at least 12 characters.');
  process.exit(1);
}
```
This is the only application-level password length rule in the codebase. **REMOVE this block.**

### Password PRESENCE / non-empty checks (PRESERVE — not length rules)
| Location | Check | Disposition |
|----------|-------|-------------|
| `app/server.js:95` | login requires `username && password` present | KEEP |
| `app/server.js:230` | user create: `!password \|\| !trim()` → `'password is required'` | KEEP (presence) |
| `app/server.js:273` | user update: only re-hash if password provided & non-blank (leave-blank-to-keep) | KEEP |
| `app/db.js` bootstrap | `_hasPass = Boolean(_bPass && _bPass.trim())`; partial config (`_hasUser !== _hasPass`) → FATAL | KEEP (presence + fail-closed) |

These enforce "no missing/empty password," NOT a minimum length — preserved per directive.

### Hashing / login (PRESERVE)
- `app/server.js:97` `bcrypt.compareSync` (login); `:239`/`:274` `bcrypt.hashSync(...,10)`; `app/db.js:141` bootstrap `bcrypt.hashSync`. Unchanged.

### SESSION_SECRET length guard (PRESERVE — NOT a password rule)
- `app/server.js:45-46` `SESSION_SECRET.length < 32` → FATAL in production. This is the session
  signing key, not a user password. **KEEP unchanged.** (Recon explicitly distinguishes the two.)

### User-creation password length
- There is **no** length restriction on user-creation passwords (server.js:228-240 only checks
  presence). A short non-empty password already works there; nothing to remove. Verified by test.

---

## 5. Password-Minimum Documentation (to sync)

| File:line | Current text | Action |
|-----------|--------------|--------|
| `app/.env.example:20` | `# BOOTSTRAP_ADMIN_PASSWORD=replace-with-12-plus-char-password` | neutral placeholder (no minimum claim) |
| `app/README.md:74` | `\| BOOTSTRAP_ADMIN_PASSWORD \| 12+ char strong password \| ...` | drop "12+ char" |
| `app/README.md:273` | `Admin password (min 12 chars). ...` | drop "(min 12 chars)" |
| `docs/railway-service-config.md:91` | `\| Strong 12+ char password \| ...` | drop "12+ char" |

`SESSION_SECRET` 32-char language in these files stays (it documents the preserved guard).

---

## 6. What Is Removed vs What Remains

### Removed
- The `BOOTSTRAP_ADMIN_PASSWORD` 12-char minimum (`app/db.js`)
- "12-char password minimum" wording in `.env.example`, `README.md` (×2), Railway runbook

### Remains
- bcrypt hashing (create/update/bootstrap/compare)
- Login + password comparison
- Missing/empty password rejection (user create) + bootstrap presence + partial-config fail-closed
- Bootstrap production-only, create-only-if-no-admin, skip-if-admin-exists, username/password env vars
- `SESSION_SECRET` required in production + 32-char minimum (unchanged)
- No plaintext storage; no password logging; no hash exposure

---

## 7. Empty/Missing Password Decision (per directive)

Current code rejects missing/empty passwords (presence checks above). **Keep rejecting.** Only
the length minimum is removed. After the change: bootstrap with an empty/whitespace password is
still treated as "not set" (presence check) and, if the username is set, still fails closed as
partial config; user creation with empty password still returns 400.

---

## 8. Mutation Plan

| File | Change | Surface |
|------|--------|---------|
| `app/db.js` | Remove the `_bPass.trim().length < 12` FATAL block (lines 135-138) | backend |
| `app/.env.example` | Neutral bootstrap-password placeholder (no minimum) | docs |
| `app/README.md` | Drop "12+ char" / "min 12 chars" from the two bootstrap-password rows | docs |
| `docs/railway-service-config.md` | Drop "12+ char" from the bootstrap-password row | docs |

**No change to:** `app/server.js` (no password length rule; SESSION_SECRET guard preserved),
`app/public/*` (no minlength), schema, `app/package.json`, `app/.nvmrc`, DB_PATH, Railway config
(beyond the doc wording), imports, access control, row-click edit.

---

## 9. Verification Plan

Disposable DBs only; live `app/data.db` never mutated.
1. `node --check` server.js, db.js, public/app.js
2. `cd app && npm run`
3. Dev boot smoke (NODE_ENV unset) → running line; live DB untouched
4. **Bootstrap with a short (1-char) non-empty password** on temp DB → admin created; **login
   with that short password succeeds**
5. **User creation via API with a short non-empty password** → 201; login as that user succeeds
6. **Missing/empty password still rejected:** bootstrap username-only → FATAL partial config;
   user create with empty password → 400
7. **SESSION_SECRET preserved:** missing → FATAL; `<32` → FATAL (production)
8. Password stored as bcrypt (`$2...`), not plaintext; no password string in server logs
9. `bash scripts/invariant-check.sh` → 5/5; `git status` → only allowed surfaces

---

## 10. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Removing the minimum weakens admin password strength | Accepted (operator requirement) | Hashing/auth unchanged; operator chooses password strength |
| Confusing SESSION_SECRET guard with password rule | None | Recon explicitly separates them; SESSION_SECRET `<32` untouched |
| Empty password slips through | None | Presence checks + partial-config fail-closed preserved |

---

## 11. Non-Scope

Roles, import behavior, access-control removal, row-click edit, DB_PATH, schema, auth/session
mechanics, Railway service config (beyond obsolete password-minimum wording). No Docker, no
Postgres, no deploy. No `app/public/style.css`, `app/package.json`, `app/package-lock.json`,
`app/.nvmrc` change.

---

## 12. Next Recommended Node

Railway redeploy smoke — redeploy and confirm bootstrap accepts the operator's chosen password
and login works.
