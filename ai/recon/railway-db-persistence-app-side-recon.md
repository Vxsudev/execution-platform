# Railway DB Persistence — App-Side Recon

**Feature Slug:** railway-db-persistence-app-side-recon
**Date:** 2026-06-18
**Author:** AI Engineering OS (in-session worker)
**HEAD at recon:** 2516932
**Mode:** RECON + minimal proven safety guard (Verdict B)

---

## 1. Recon Objective

The operator reports a Railway persistence failure (volume attachment unstable / staged-looping).
Before further hosting changes, confirm whether **application code** contains any blocker that could
cause DB reset, ephemeral-DB fallback, bootstrap overwrite, destructive seed, or deploy-time wipe.
RECON ONLY unless a safe diagnostic hardening patch is proven necessary.

---

## 2. Files Inspected

| File | What was read |
|------|---------------|
| `app/db.js` | DB path resolution (9–14), prod guard (new 16–31), mkdir (33), SQLite open (34), schema (51–104), idempotent ALTERs (106–114), demo seed (118–122), prod bootstrap (125–147), no-user warning (148–150), role backfill (153–156), entries seed (159–168), audit backfill (171–172) |
| `app/server.js` | DB import (7), import preview `/api/import/preview` (446), import commit `/api/import/commit` (479–559), entry insert (177), user insert (240). No `DB_PATH`/mkdir/destructive SQL. |
| repo-wide grep | `drop table\|delete from\|truncate\|unlink\|rmSync\|rm -rf\|drop column\|reset` across `app/**/*.js` |

Local governance surfaces present: `.engineering-os/adapter.config.sh`, `ai/invariant-registry.md`.

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # 12 PASS / 0 FAIL — adapter valid
bash scripts/invariant-check.sh                          # 5/5 PASS
git log --oneline -1; git status --short                 # HEAD=2516932; clean
node --check app/db.js && node --check app/server.js     # both OK
grep -rniE "drop table|delete from|truncate|unlink|rmSync|rm -rf|drop column|reset" app/**/*.js  # none
```

---

## 4. Findings (mapped to recon objectives 1–8)

### 4.1 DB path resolution
`app/db.js:9–12`. Default = `path.join(__dirname, 'data.db')` (i.e. `app/data.db`).
`DB_PATH` overrides the default when set and non-blank (trimmed). So `/data/data.db` **is** used when
the env var is present. **Correct — honors `DB_PATH`.**

### 4.2 Directory creation
`app/db.js:33` (was line 13): `fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true })`.
**This masks a missing mount.** If `/data` is not actually mounted, `recursive:true` silently creates
`/data` on the container's *ephemeral* filesystem. No error is raised. This is the central risk.

### 4.3 SQLite open behavior
`app/db.js:34`: `new DatabaseSync(configuredDbPath)`. Opening a missing path **creates a fresh DB
file**. Combined with 4.2, a failed/absent volume mount produces a brand-new empty DB on ephemeral
storage that looks like a normal first boot. This fully explains "bootstrap recreation" / reset
symptoms on redeploy.

### 4.4 Bootstrap behavior
`app/db.js:125–147` (production only):
- Fails closed if exactly one of `BOOTSTRAP_ADMIN_USERNAME` / `BOOTSTRAP_ADMIN_PASSWORD` is set.
- Creates the admin **only when `SELECT COUNT(*) WHERE role='admin'` is 0**.
- If an admin already exists → logs `Bootstrap: admin already exists, skipping.` and does nothing.
- **Never overwrites an existing admin password.** Leaving `BOOTSTRAP_ADMIN_PASSWORD` set in Railway
  across redeploys **cannot** reset an existing admin. The runs-every-boot code path is a no-op once
  an admin row exists. **Not a reset cause.**

### 4.5 Seed / demo behavior
- Demo *users* (`admin`/`vasu`): `app/db.js:118` — guarded by `NODE_ENV !== 'production'`. Not seeded
  in production.
- Demo *entries* (`Sample experiment`, `Sample work item`): `app/db.js:159` — **not** `NODE_ENV`
  guarded, but only inserts when `entries` is empty (`COUNT(*)===0`). On a real persisted DB with rows,
  it is a no-op. It is **purely additive** (two illustrative rows on an empty DB); it never deletes or
  replaces. Minor cosmetic note only — see §7.
- Backfill UPDATEs (`151–172`) set audit columns / demo roles on rows lacking them; **non-destructive**.
- **No `DELETE`, `DROP`, `TRUNCATE`, reset, or destructive migration exists anywhere in `app/`** (grep
  clean). `ALTER TABLE ... ADD COLUMN` calls are wrapped in try/catch and idempotent — additive only.

### 4.6 Import behavior
`app/server.js:479–559` (`/api/import/commit`). Rows are written with synchronous
`INSERT INTO entries (...)` (line 532) directly against the SQLite handle; the imports ledger and
`import_observations` are likewise inserted (508, 547). **Import does not depend on in-memory state for
durability** — commit is a straight DB write. Imported rows **survive restart iff the DB file persists.**
Import is therefore a *victim* of the ephemeral-DB problem, not a cause.

### 4.7 Session / auth behavior
Sessions live in the `sessions` table (`app/db.js:58–62`; insert at `server.js:101`). Auth/session
logic touches only `users`/`sessions` rows and does **not** affect DB file location or persistence.
**No persistence impact.**

### 4.8 Railway-specific risk
Before this recon, the app **could not distinguish a real mounted `/data` from an app-created `/data`** —
`mkdirSync(recursive)` creates the directory either way, so a mount failure is indistinguishable from a
first boot. Production **should** fail fast when `DB_PATH=/data/...` but the volume is not present
*before* the mkdir. This is the proven-necessary hardening (see §6).

---

## 5. Direct Answers to Required Questions

| Question | Answer |
|----------|--------|
| Where does default DB path point? | `app/data.db` (`__dirname/data.db`). |
| How does `DB_PATH` override? | If set & non-blank (trimmed), replaces default. |
| Is `/data/data.db` used when env var exists? | Yes. |
| Does mkdir mask a missing mount? | **Yes** — `recursive:true` creates `/data` on ephemeral fs. |
| Does opening a missing DB create a fresh DB? | Yes (SQLite default). |
| Does bootstrap only create admin when none exists? | Yes (`role='admin'` count === 0). |
| Does bootstrap ever overwrite an existing admin password? | **No.** |
| Does bootstrap run every boot or only empty-admin boot? | Runs every prod boot but **no-ops** if admin exists. |
| Can leftover `BOOTSTRAP_ADMIN_PASSWORD` reset an existing admin? | **No.** |
| Are demo rows created in production? | Demo *users*: no. Demo *entries*: only when `entries` empty (additive, never on a populated persisted DB). |
| Can any startup seed wipe/replace rows? | **No.** |
| Any `DELETE`/`DROP`/reset/truncate/destructive migration? | **None.** |
| Does import write to DB normally? | Yes (synchronous `INSERT`). |
| Does import commit depend on in-memory state? | **No** (durability is a direct DB write). |
| Do imported rows survive restart if DB persists? | **Yes.** |
| Does auth/session affect DB persistence? | **No.** |
| Can the app distinguish real vs app-created `/data`? | **Not before this patch.** Now guarded in production. |
| Should prod fail fast if `/data` not mounted before mkdir? | **Yes — implemented.** |

---

## 6. Safe Hardening Patch (implemented — proven necessary)

**File:** `app/db.js`, inserted between path resolution and `mkdirSync`.

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

**Why proven necessary:** the operator reports an *active* persistence failure; §4.2–4.3 show the only
app-side mechanism that reproduces "reset on redeploy" is silent ephemeral-DB creation when the volume
is absent. The guard converts that silent data loss into a loud, diagnostic fatal error **before** any
directory or DB file is created, directly aiding the staged-loop mount diagnosis.

**Scope discipline — what the patch does NOT touch:** schema, bootstrap semantics, import behavior,
auth/session, frontend, Docker/Railway config, package files. Production-only; dev and non-`/data`
paths are completely unaffected (guard short-circuits). No secrets logged.

**Guard truth table (verified):**

| `NODE_ENV` | `DB_PATH` | `RAILWAY_VOLUME_MOUNT_PATH` | `/data` exists | Result |
|------------|-----------|----------------------------|----------------|--------|
| production | `/data/data.db` | unset | no | **FATAL exit 1** (verified) |
| production | `/data/data.db` | `/data` | no (staged loop) | **FATAL exit 1** (verified) |
| production | `/data/data.db` | `/data` | yes (healthy) | proceed (verified via branch sim) |
| production | `/tmp/.../data.db` | — | — | guard skipped, normal boot (verified) |
| development | any | — | — | guard skipped |

---

## 7. Non-blocking Observations (no change made)

- Demo *entries* seed (`db.js:159`) lacks a `NODE_ENV !== 'production'` guard. It is additive and only
  fires on an empty `entries` table, so it is **not** a reset cause and **not** in scope for this recon.
  If a future feature wants production DBs to start truly empty, add a prod guard there — tracked as a
  note, deliberately **not** changed here to honor "do not change seed/bootstrap semantics."

---

## 8. Verification Commands

```bash
node --check app/db.js          # OK
node --check app/server.js      # OK

# Success (guard skipped, non-/data path) — bootstrap runs, exit 0:
cd app && DB_PATH=/tmp/execution-platform-test/data.db NODE_ENV=production \
  SESSION_SECRET=12345678901234567890123456789012 \
  BOOTSTRAP_ADMIN_USERNAME=admin BOOTSTRAP_ADMIN_PASSWORD=1234567890123456 \
  node -e "require('./db')"; rm -rf /tmp/execution-platform-test

# Failure (no volume env) — FATAL, exit 1, /data NOT created:
cd app && DB_PATH=/data/data.db NODE_ENV=production \
  SESSION_SECRET=12345678901234567890123456789012 \
  BOOTSTRAP_ADMIN_USERNAME=admin BOOTSTRAP_ADMIN_PASSWORD=1234567890123456 \
  node -e "require('./db')"; ls -ld /data   # → "No such file or directory"

bash scripts/invariant-check.sh   # 5/5 PASS
```

All run with disposable DB paths only. Live `app/data.db` was **not** mutated.

---

## 9. Final Verdict

**Verdict B — App masks Railway mount failure.**

- DB path correctly honors `DB_PATH` (4.1).
- `fs.mkdirSync(..., { recursive: true })` creates `/data` when the volume is absent (4.2), then SQLite
  opens a **fresh** `/data/data.db` (4.3), making a Railway mount failure look like a normal DB startup
  and discarding data on redeploy.
- Bootstrap does **not** overwrite an existing admin (4.4); leftover `BOOTSTRAP_ADMIN_PASSWORD` cannot
  reset it.
- **No destructive startup code exists** (4.5) — no `DELETE`/`DROP`/`TRUNCATE`/reset.
- Import is durable and a victim, not a cause (4.6). Auth/session is irrelevant to persistence (4.7).

The reset is **not** caused by destructive application logic; it is the masked-mount mechanism (Verdict
B). The minimal production fail-fast guard (§6) is implemented to surface that failure loudly instead of
silently creating an ephemeral DB.

**Next recommended node:** Railway clean volume reset + persistence smoke (confirm
`RAILWAY_VOLUME_MOUNT_PATH=/data`, volume attached, then verify a row survives a redeploy).
