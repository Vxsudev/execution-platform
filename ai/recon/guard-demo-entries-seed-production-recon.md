# Guard Demo Entries Seed in Production: Recon

**Feature Slug:** guard-demo-entries-seed-production  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** c3eb156

---

## 1. Recon Objective

Read-only recon to locate the demo **entries** seed that runs on an empty `entries` table and
determine the minimal guard so a fresh **production** boot starts with **zero** entries, while
preserving: the bootstrap admin flow, the local/dev demo seed (if desired), MySQL/connection
logic, auth, and the import parser.

---

## 2. Files Read

| File | Finding |
|------|---------|
| `app/db.js` | Demo **entries** seed (`SELECT COUNT(*) FROM entries == 0` → insert 2 rows) is **NOT** environment-guarded — runs in every environment, including production |
| `app/db.js` | Demo **users** seed directly above it (line 122) **is** guarded: `process.env.NODE_ENV !== 'production'` — this is the pattern to mirror |
| `app/db.js` | Bootstrap admin block (lines 129–151) is production-only, presence-checked, partial-config fail-closed, create-only-if-no-admin, bcrypt-hashed — must stay unchanged |
| `app/server.js` | Auth/login/session, user create/update, import routes — out of scope, not read for mutation |

---

## 3. Commands Run

```bash
bash scripts/invariant-check.sh           # 5/5 PASS (baseline)
git status --short; git log --oneline -1  # clean; HEAD=c3eb156
grep -n "NODE_ENV" app/db.js              # 4 guards: users seed, bootstrap, warn, dev role backfill
```

---

## 4. The Seed To Guard — `app/db.js:162-172`

```js
// Seed generic illustrative rows to show row shape (not production data).
if (db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
  const ins = db.prepare(`INSERT INTO entries ...`);
  ins.run({ type: 'experiment', title: 'Sample experiment', ... });
  ins.run({ type: 'work_item',  title: 'Sample work item',  ... });
}
```

This block has **no** `NODE_ENV` guard, so on a fresh production database (empty `entries` table)
it inserts 2 demo rows. This is the production-cleanup bug. **Add the same guard the demo-users
seed already uses:** `process.env.NODE_ENV !== 'production'`.

---

## 5. What Changes vs What Stays

### Changes
- Wrap the demo-entries seed condition with `process.env.NODE_ENV !== 'production' && ...` so it
  only runs outside production. One-line edit to the existing `if` condition.

### Stays (must NOT change)
- Bootstrap admin (production-only, presence/partial-config/create-only-if-no-admin, bcrypt) — unchanged.
- Demo **users** seed (already dev-only) — unchanged.
- Local/dev demo **entries** seed still runs when `NODE_ENV !== 'production'` (kept, per directive).
- Audit-column backfill (`UPDATE entries SET created_by/updated_by`) — unchanged; on a fresh prod
  DB the `entries` table is empty so these UPDATEs are harmless no-ops.
- MySQL / DB connection logic — unchanged (note: runtime store is `node:sqlite`, see §8).
- Auth (`app/server.js`) — unchanged.
- Import parser — unchanged.
- Schema / migrations — unchanged.

---

## 6. Verification Plan

Disposable DBs only; live `app/data.db` never mutated. Use a throwaway `DB_PATH`.
1. `node --check app/db.js`.
2. **Production empty DB:** `NODE_ENV=production` + `BOOTSTRAP_ADMIN_USERNAME/PASSWORD` set, fresh
   `DB_PATH` → load `app/db.js` → assert `users` has the bootstrap admin (role=admin) and
   `entries` has **0** rows.
3. **Dev empty DB:** `NODE_ENV` unset, fresh `DB_PATH` → load `app/db.js` → assert demo entries
   seeded (2 rows) and demo users seeded — dev fallback intact.
4. **Import 64 still works:** run the existing import path against the authoritative 64-row
   workbook fixture → 64 importable rows unaffected by the seed guard.
5. `bash scripts/invariant-check.sh` → 5/5; `git status` → only allowed surfaces.

---

## 7. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Guard accidentally suppresses dev seed too | Low | Mirror the exact existing demo-users guard (`!== 'production'`); dev path unchanged |
| Touching bootstrap/auth/import by mistake | Medium | Single-line condition edit; explicit non-scope; node --check + invariants |

---

## 8. Note: MySQL vs SQLite

The operator report frames this as a "clean MySQL boot," but the app's runtime store is
`node:sqlite` (`DatabaseSync`, `app/data.db` / `DB_PATH`). There is no MySQL layer in `app/db.js`.
The fix is store-agnostic (an environment guard on a seed `if`); verification uses the real SQLite
path with `NODE_ENV=production`. No connection logic is touched either way.

---

## 9. Non-Scope

Auth/session, user create/update, import parser, schema/migrations, bootstrap admin behavior,
DB connection logic, `app/public/*`, Railway/deploy. No Docker, no Postgres/MySQL change, no deploy.

---

## 10. Next Recommended Node

Railway redeploy smoke — confirm a fresh production volume boots with the bootstrap admin and an
empty `entries` table.
