// Database setup, schema, seed, and async DB adapter.
// Dual backend behind one async interface:
//   - MySQL (mysql2/promise pool) when MYSQL_URL or MYSQLHOST is present (production).
//   - SQLite (node:sqlite) otherwise (local dev). SQLite support is retained, not removed.
// The Excel sheet is used ONLY as the source of column/row structure; runtime data lives
// in the database, never in the spreadsheet.
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

// MySQL-first backend selection: MySQL when MYSQL_URL or MYSQLHOST is present (production),
// SQLite as a local/dev fallback only. The old top-level DatabaseSync(configuredDbPath)
// startup block + DB_PATH diagnostic logs from main are intentionally dropped — DB open now
// happens per-backend inside buildSqliteBackend()/buildMysqlBackend(), gated by useMysql.
const useMysql = Boolean(
  (process.env.MYSQL_URL && process.env.MYSQL_URL.trim()) ||
  (process.env.MYSQLHOST && process.env.MYSQLHOST.trim())
);

const ROW_TYPES = ['experiment', 'work_item', 'task'];
const STATUSES = ['Not Started', 'In Progress', 'Complete', 'Blocked', 'Inconclusive'];
const TRACKS = [
  'T1 AstraX Device',
  'T2 AstraX Customer Cloud',
  'T3 AstraX Ops Cloud',
  'T4 Manufacturing partners',
  'T5 Business',
  'T6 Sales partner',
];

// field.key === DB column name. Order === display/form order (Sheet 2 contract,
// `type` discriminator kept last). `help` text is drawn from Sheet 3 guidance.
const ROW_FIELDS = [
  { key: 'owner',           label: 'Owner',                   input: 'text',     required: true,  help: 'Who owns this experiment.' },
  { key: 'track',           label: 'Track',                   input: 'select',   options: TRACKS, required: true,  help: 'Select the astraX track this experiment belongs to. Links to the Jun–Nov roadmap.' },
  { key: 'title',           label: 'Experiment Title',        input: 'text',     required: true,  help: 'Short scannable name used in standups. Keep each atomic experiment under ~2 weeks.' },
  { key: 'function_area',   label: 'Function',                input: 'text' },
  { key: 'parent_item',     label: 'Parent Item',             input: 'text' },
  { key: 'hypothesis',      label: 'Description / Hypothesis', input: 'textarea', help: "Write as: 'If we do X, then Y will happen, because Z.' Be specific." },
  { key: 'design',          label: 'Experiment Design',       input: 'textarea', help: 'How will you run it? Materials/samples, steps, number of runs, measurement method.' },
  { key: 'success_criteria',label: 'Success Criteria',        input: 'textarea', help: "Write BEFORE you start. What does 'pass' look like? Must be measurable." },
  { key: 'target_end_date', label: 'Target End Date',         input: 'date',     help: 'Pick a realistic date. If it slips, update it and note why in Dependencies.' },
  { key: 'dependencies',    label: 'Dependencies',            input: 'text',     help: 'What must be true before this can start/finish? Surface blockers during standup.' },
  { key: 'outcome',         label: 'Outcome / Finding',       input: 'textarea', help: 'Fill in AFTER. State the result in one sentence, then what it means.' },
  { key: 'next_action',     label: 'Next Action',             input: 'text',     help: 'What does this result trigger? Must be actionable.' },
  { key: 'status',          label: 'Status',                  input: 'select',   options: STATUSES, required: true, help: 'Not Started → In Progress → Complete / Blocked / Inconclusive.' },
  { key: 'type',            label: 'Type',                    input: 'select',   options: ROW_TYPES },
];

// ---- Schema DDL (one statement per array entry; executed individually so it works
// on both node:sqlite (db.exec) and mysql2 (pool.query, no multi-statement)). Type/
// status/role validation is enforced at the app layer (server.js), so MySQL uses plain
// VARCHAR instead of ENUM/CHECK for portability. username/token use utf8mb4_bin so
// uniqueness/lookups stay byte-exact, matching SQLite's BINARY default.
const SQLITE_DDL = [
  `CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS sessions (
    token      TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS entries (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    type             TEXT NOT NULL DEFAULT 'experiment' CHECK (type IN ('experiment','work_item','task')),
    title            TEXT NOT NULL,
    owner            TEXT,
    track            TEXT,
    function_area    TEXT,
    parent_item      TEXT,
    hypothesis       TEXT,
    design           TEXT,
    success_criteria TEXT,
    target_end_date  TEXT,
    dependencies     TEXT,
    outcome          TEXT,
    next_action      TEXT,
    status           TEXT NOT NULL DEFAULT 'Not Started' CHECK (status IN ('Not Started','In Progress','Complete','Blocked','Inconclusive')),
    created_at       TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
  `CREATE TABLE IF NOT EXISTS imports (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    filename        TEXT NOT NULL,
    imported_by     TEXT NOT NULL,
    imported_at     TEXT NOT NULL DEFAULT (datetime('now')),
    total_rows      INTEGER,
    importable_rows INTEGER,
    skipped_rows    INTEGER,
    warning_count   INTEGER,
    status          TEXT NOT NULL DEFAULT 'complete'
  )`,
  `CREATE TABLE IF NOT EXISTS import_observations (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    import_batch_id   INTEGER NOT NULL,
    source_sheet      TEXT,
    source_row        INTEGER,
    observation_type  TEXT NOT NULL,
    status            TEXT NOT NULL,
    reason            TEXT,
    raw_data          TEXT,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
  )`,
];

// SQLite-only idempotent column migrations for pre-existing dev databases. A fresh MySQL
// schema (below) already declares every column, so these are not run on MySQL.
const SQLITE_ALTERS = [
  "ALTER TABLE entries ADD COLUMN created_by TEXT",
  "ALTER TABLE entries ADD COLUMN updated_by TEXT",
  "ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer'",
  "ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL",
  "ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL",
  "ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL",
  "ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL",
];

const MYSQL_DDL = [
  `CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    role          VARCHAR(32) DEFAULT 'viewer',
    track_scope   TEXT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS sessions (
    token      VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin PRIMARY KEY,
    user_id    INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS entries (
    id                  INT AUTO_INCREMENT PRIMARY KEY,
    type                VARCHAR(32) NOT NULL DEFAULT 'experiment',
    title               TEXT NOT NULL,
    owner               TEXT,
    track               TEXT,
    function_area       TEXT,
    parent_item         TEXT,
    hypothesis          TEXT,
    design              TEXT,
    success_criteria    TEXT,
    target_end_date     TEXT,
    dependencies        TEXT,
    outcome             TEXT,
    next_action         TEXT,
    status              VARCHAR(32) NOT NULL DEFAULT 'Not Started',
    created_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by          TEXT,
    updated_by          TEXT,
    import_batch_id     INT DEFAULT NULL,
    import_source_sheet TEXT,
    import_source_row   INT DEFAULT NULL
  )`,
  `CREATE TABLE IF NOT EXISTS imports (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    filename        TEXT NOT NULL,
    imported_by     VARCHAR(255) NOT NULL,
    imported_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_rows      INT,
    importable_rows INT,
    skipped_rows    INT,
    warning_count   INT,
    status          VARCHAR(32) NOT NULL DEFAULT 'complete'
  )`,
  `CREATE TABLE IF NOT EXISTS import_observations (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    import_batch_id   INT NOT NULL,
    source_sheet      TEXT,
    source_row        INT,
    observation_type  VARCHAR(64) NOT NULL,
    status            VARCHAR(32) NOT NULL,
    reason            TEXT,
    raw_data          MEDIUMTEXT,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
  )`,
];

// ---- Backend implementations. Both expose the same async surface:
//   get(sql, ...params) -> first row | undefined
//   all(sql, ...params) -> row[]
//   run(sql, ...params) -> { insertId, changes }
//   exec(sql)           -> void (single DDL/DML statement)
//   tx(fn)              -> fn receives { get, all, run } bound to one transaction
let backend;

function buildSqliteBackend() {
  const { DatabaseSync } = require('node:sqlite');
  const defaultDbPath = path.join(__dirname, 'data.db');
  const configuredDbPath = process.env.DB_PATH && process.env.DB_PATH.trim()
    ? process.env.DB_PATH.trim()
    : defaultDbPath;
  // Volume-guard intent carried over from the railway DB-persistence recon: in production
  // the DB must be MySQL. Reaching the SQLite fallback in production means MySQL env is
  // absent; if that fallback would also target the Railway volume path (/data/...), refuse
  // rather than silently create an ephemeral SQLite DB on non-persistent storage. (No
  // Railway volume check is performed when MySQL is selected — this branch only runs when
  // useMysql is false.)
  if (process.env.NODE_ENV === 'production' && configuredDbPath.startsWith('/data/')) {
    console.error('FATAL: production has no MySQL env (MYSQL_URL/MYSQLHOST) and DB_PATH points to /data/. Refusing to create an ephemeral SQLite database. Configure the Railway MySQL service.');
    process.exit(1);
  }
  fs.mkdirSync(path.dirname(configuredDbPath), { recursive: true });
  const db = new DatabaseSync(configuredDbPath);
  try {
    db.exec('PRAGMA journal_mode = WAL;');
  } catch (err) {
    console.warn('SQLite WAL mode unavailable; continuing with default journal mode:', err.message);
  }
  const get = async (sql, ...params) => db.prepare(sql).get(...params);
  const all = async (sql, ...params) => db.prepare(sql).all(...params);
  const run = async (sql, ...params) => {
    const info = db.prepare(sql).run(...params);
    return { insertId: Number(info.lastInsertRowid), changes: info.changes };
  };
  const exec = async (sql) => { db.exec(sql); };
  const tx = async (fn) => {
    db.exec('BEGIN');
    try {
      const result = await fn({ get, all, run });
      db.exec('COMMIT');
      return result;
    } catch (e) {
      try { db.exec('ROLLBACK'); } catch (_) {}
      throw e;
    }
  };
  return { get, all, run, exec, tx, ddl: SQLITE_DDL, alters: SQLITE_ALTERS };
}

function mysqlConfig() {
  const base = { dateStrings: true, connectionLimit: 10, waitForConnections: true, queueLimit: 0 };
  const url = process.env.MYSQL_URL && process.env.MYSQL_URL.trim();
  if (url) {
    const u = new URL(url);
    return {
      ...base,
      host: u.hostname,
      port: u.port ? Number(u.port) : 3306,
      user: decodeURIComponent(u.username),
      password: decodeURIComponent(u.password),
      database: u.pathname.replace(/^\//, ''),
    };
  }
  return {
    ...base,
    host: process.env.MYSQLHOST,
    port: process.env.MYSQLPORT ? Number(process.env.MYSQLPORT) : 3306,
    user: process.env.MYSQLUSER,
    password: process.env.MYSQLPASSWORD,
    database: process.env.MYSQLDATABASE,
  };
}

function buildMysqlBackend() {
  const mysql = require('mysql2/promise');
  const pool = mysql.createPool(mysqlConfig());
  const get = async (sql, ...params) => {
    const [rows] = await pool.query(sql, params);
    return rows[0];
  };
  const all = async (sql, ...params) => {
    const [rows] = await pool.query(sql, params);
    return rows;
  };
  const run = async (sql, ...params) => {
    const [result] = await pool.query(sql, params);
    return { insertId: result.insertId, changes: result.affectedRows };
  };
  const exec = async (sql) => { await pool.query(sql); };
  const tx = async (fn) => {
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      const tget = async (sql, ...params) => { const [r] = await conn.query(sql, params); return r[0]; };
      const tall = async (sql, ...params) => { const [r] = await conn.query(sql, params); return r; };
      const trun = async (sql, ...params) => { const [r] = await conn.query(sql, params); return { insertId: r.insertId, changes: r.affectedRows }; };
      const result = await fn({ get: tget, all: tall, run: trun });
      await conn.commit();
      return result;
    } catch (e) {
      try { await conn.rollback(); } catch (_) {}
      throw e;
    } finally {
      conn.release();
    }
  };
  return { get, all, run, exec, tx, ddl: MYSQL_DDL, alters: [] };
}

// MySQL DUPLICATE-key vs SQLite UNIQUE-constraint text — single predicate the routes use.
function isUniqueViolation(e) {
  if (!e) return false;
  if (e.code === 'ER_DUP_ENTRY' || e.errno === 1062) return true;
  return typeof e.message === 'string' && /UNIQUE constraint/i.test(e.message);
}

// Portable 'YYYY-MM-DD HH:MM:SS' UTC timestamp — matches SQLite datetime('now') output,
// so updated_at stays a dialect-free bound parameter instead of a SQL function literal.
function nowStamp() {
  return new Date().toISOString().slice(0, 19).replace('T', ' ');
}

async function init() {
  backend = useMysql ? buildMysqlBackend() : buildSqliteBackend();
  const { get, all, run, exec } = backend;

  // Safe diagnostics only — never credentials or the connection URL.
  console.log(`DB provider: ${useMysql ? 'mysql' : 'sqlite'}`);
  if (useMysql) {
    const c = mysqlConfig();
    console.log(`MySQL config: host present: ${c.host ? 'yes' : 'no'}, database present: ${c.database ? 'yes' : 'no'}`);
    try {
      await get('SELECT 1 AS ok');
      console.log('MySQL connection established: yes');
    } catch (e) {
      console.error('MySQL connection established: no');
      throw e;
    }
  }

  for (const stmt of backend.ddl) await exec(stmt);
  for (const stmt of backend.alters) { try { await exec(stmt); } catch (_) { /* column already present */ } }

  // Seed demo users only in non-production environments.
  if (process.env.NODE_ENV !== 'production') {
    const u = await get('SELECT COUNT(*) c FROM users');
    if ((u ? u.c : 0) === 0) {
      await run('INSERT INTO users (username, password_hash) VALUES (?, ?)', 'admin', bcrypt.hashSync('admin123', 10));
      await run('INSERT INTO users (username, password_hash) VALUES (?, ?)', 'vasu', bcrypt.hashSync('vasu123', 10));
    }
  }

  // Bootstrap a first admin from env on initial production boot. No-op if admin exists.
  // Fails closed if exactly one bootstrap var is set (partial config unsafe in production).
  if (process.env.NODE_ENV === 'production') {
    const _bUser = process.env.BOOTSTRAP_ADMIN_USERNAME;
    const _bPass = process.env.BOOTSTRAP_ADMIN_PASSWORD;
    const _hasUser = Boolean(_bUser && _bUser.trim());
    const _hasPass = Boolean(_bPass && _bPass.trim());
    if (_hasUser !== _hasPass) {
      console.error('FATAL: BOOTSTRAP_ADMIN_USERNAME and BOOTSTRAP_ADMIN_PASSWORD must both be set or both be unset.');
      process.exit(1);
    }
    if (_hasUser && _hasPass) {
      // No password length restriction (operator requirement 2026-06-18). A non-empty
      // BOOTSTRAP_ADMIN_PASSWORD of any length is accepted; presence + partial-config
      // fail-closed above still apply, and the password is bcrypt-hashed below.
      const a = await get("SELECT COUNT(*) c FROM users WHERE role = 'admin'");
      if ((a ? a.c : 0) === 0) {
        await run("INSERT INTO users (username, password_hash, role, track_scope) VALUES (?, ?, 'admin', '[]')",
          _bUser.trim(), bcrypt.hashSync(_bPass.trim(), 10));
        console.log(`Bootstrap: admin user '${_bUser.trim()}' created.`);
      } else {
        console.log('Bootstrap: admin already exists, skipping.');
      }
    }
  }
  if (process.env.NODE_ENV === 'production') {
    const u = await get('SELECT COUNT(*) c FROM users');
    if ((u ? u.c : 0) === 0) {
      console.warn('WARNING: No users exist in the database. See README for production setup instructions.');
    }
  }

  // Backfill demo user roles after seed so the UPDATE finds existing rows on fresh boot.
  if (process.env.NODE_ENV !== 'production') {
    await exec("UPDATE users SET role = 'admin' WHERE username = 'admin' AND (role IS NULL OR role = 'viewer')");
    await run("UPDATE users SET role = 'track_owner', track_scope = ? WHERE username = 'vasu' AND (role IS NULL OR role = 'viewer')",
      '["T3 AstraX Ops Cloud"]');
  }

  // Seed generic illustrative rows to show row shape (not production data).
  if (process.env.NODE_ENV !== 'production') {
    const e = await get('SELECT COUNT(*) c FROM entries');
    if ((e ? e.c : 0) === 0) {
      await run(
        `INSERT INTO entries (type,title,owner,track,function_area,hypothesis,success_criteria,status)
         VALUES (?,?,?,?,?,?,?,?)`,
        'experiment', 'Sample experiment', 'demo', 'T1 AstraX Device', 'Engineering',
        'If we do X then Y because Z.', 'Baseline metric improves', 'Not Started');
      await run(
        `INSERT INTO entries (type,title,owner,track,function_area,hypothesis,success_criteria,status)
         VALUES (?,?,?,?,?,?,?,?)`,
        'work_item', 'Sample work item', 'demo', 'T2 AstraX Customer Cloud', 'Software',
        null, null, 'In Progress');
    }
  }

  // Backfill audit columns for any rows without stamps (including seed rows on fresh installs).
  await exec("UPDATE entries SET created_by = 'system' WHERE created_by IS NULL");
  await exec("UPDATE entries SET updated_by = 'system' WHERE updated_by IS NULL");
}

// Async DB adapter. Methods throw until init() has run (backend is assigned there).
const dba = {
  get: (sql, ...params) => backend.get(sql, ...params),
  all: (sql, ...params) => backend.all(sql, ...params),
  run: (sql, ...params) => backend.run(sql, ...params),
  exec: (sql) => backend.exec(sql),
  tx: (fn) => backend.tx(fn),
  init,
  isUniqueViolation,
  nowStamp,
  get usingMysql() { return useMysql; },
};

module.exports = { dba, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS };
