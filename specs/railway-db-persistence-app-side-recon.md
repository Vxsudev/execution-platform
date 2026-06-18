# Spec: Railway DB Persistence — App-Side Recon

## Status
approved

## Phase
phase-build

## Feature Slug
railway-db-persistence-app-side-recon

## Depends On
Recon: ai/recon/railway-db-persistence-app-side-recon.md. Follows railway-r2-db-path-volume-contract
and railway-r3-env-session-admin-bootstrap. Backend-only diagnostic guard; preserves schema,
bootstrap semantics, import behavior, auth/session, and Railway/Docker config.

---

## Summary

Confirm whether application code can cause Railway DB reset behavior, and — proven necessary by the
operator's active persistence failure — add one minimal production fail-fast guard in `app/db.js`.
Recon verdict is **B (app masks Railway mount failure)**: `fs.mkdirSync(..., { recursive: true })`
silently creates `/data` on ephemeral storage when the volume is absent, then SQLite opens a fresh DB
there, making a failed mount look like a normal first boot. The guard refuses to create an ephemeral
production database when `DB_PATH` targets `/data/...` but the Railway volume is not present, turning
silent data loss into a loud diagnostic error.

---

## Background

`app/db.js` resolves `DB_PATH` (default `app/data.db`), creates the parent dir with `recursive:true`,
then opens SQLite (creating a fresh file if missing). Bootstrap (`125–147`) only creates an admin when
none exists and never overwrites a password. No `DELETE`/`DROP`/`TRUNCATE`/reset exists anywhere in
`app/`. Import commit writes synchronously to the DB and is durable if the file persists. The only
app-side mechanism that reproduces "reset on redeploy" is the masked-mount path.

---

## Data Model Changes

none — schema, columns, and migrations are untouched.

---

## API Surface

none — `app/server.js` is unchanged. Import, auth, and entry routes are untouched.

---

## Frontend Surface

none.

---

## Backend Surface

`app/db.js` only. Insert a production guard between `DB_PATH` resolution and `fs.mkdirSync`:

```js
if (process.env.NODE_ENV === 'production' && configuredDbPath.startsWith('/data/')) {
  const volumeMount = process.env.RAILWAY_VOLUME_MOUNT_PATH;
  const volumeConfigured = Boolean(volumeMount && volumeMount.trim());
  const volumePresent = volumeConfigured && fs.existsSync('/data');
  if (!volumePresent) {
    console.error('FATAL: DB_PATH points to /data/data.db but Railway volume mount /data is not present. Refusing to create an ephemeral production database.');
    process.exit(1);
  }
}
```

Guard is production-only and short-circuits for dev and for any non-`/data` `DB_PATH`. No secrets
logged. Bootstrap, seed, and import semantics are unchanged.

---

## Out of Scope

Railway/Docker config, Postgres migration, schema changes, bootstrap/seed semantics, import parser,
auth/session, frontend, package files. No deploy. No live `app/data.db` mutation. The unguarded demo
*entries* seed (additive, empty-table-only) is documented in recon §7 but deliberately not changed.

---

## Verification

```bash
node --check app/db.js && node --check app/server.js
# success (non-/data, guard skipped): exit 0
cd app && DB_PATH=/tmp/eptest/data.db NODE_ENV=production SESSION_SECRET=12345678901234567890123456789012 BOOTSTRAP_ADMIN_USERNAME=admin BOOTSTRAP_ADMIN_PASSWORD=1234567890123456 node -e "require('./db')"; rm -rf /tmp/eptest
# failure (/data, no volume env): FATAL exit 1, /data NOT created
cd app && DB_PATH=/data/data.db NODE_ENV=production SESSION_SECRET=12345678901234567890123456789012 BOOTSTRAP_ADMIN_USERNAME=admin BOOTSTRAP_ADMIN_PASSWORD=1234567890123456 node -e "require('./db')"; ls -ld /data
bash scripts/invariant-check.sh   # 5/5 PASS
```
