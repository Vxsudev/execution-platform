// Database setup, schema, and seed.
// The Excel sheet is used ONLY as the source of column/row structure here.
// Runtime data lives in this SQLite database, never in the spreadsheet.
const fs = require('fs');
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const bcrypt = require('bcryptjs');

const defaultDbPath = path.join(__dirname, 'data.db');
const configuredDbPath = process.env.DB_PATH && process.env.DB_PATH.trim()
  ? process.env.DB_PATH.trim()
  : defaultDbPath;

// --- Startup diagnostics (volume/path verification) ---
console.log('[db] DB_PATH env var present:', Boolean(process.env.DB_PATH && process.env.DB_PATH.trim()));
console.log('[db] Resolved database path:', configuredDbPath);
console.log('[db] Using default (ephemeral) path:', configuredDbPath === defaultDbPath);
const _dbDir = path.dirname(configuredDbPath);
console.log('[db] Database directory:', _dbDir);
console.log('[db] Database directory exists:', fs.existsSync(_dbDir));
// --- End startup diagnostics ---

fs.mkdirSync(_dbDir, { recursive: true });
const db = new DatabaseSync(configuredDbPath);
try {
  db.exec("PRAGMA journal_mode = WAL;");
} catch (err) {
  console.warn("SQLite WAL mode unavailable; continuing with default journal mode:", err.message);
}

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

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS sessions (
  token      TEXT PRIMARY KEY,
  user_id    INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS entries (
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
);
CREATE TABLE IF NOT EXISTS imports (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  filename        TEXT NOT NULL,
  imported_by     TEXT NOT NULL,
  imported_at     TEXT NOT NULL DEFAULT (datetime('now')),
  total_rows      INTEGER,
  importable_rows INTEGER,
  skipped_rows    INTEGER,
  warning_count   INTEGER,
  status          TEXT NOT NULL DEFAULT 'complete'
);
CREATE TABLE IF NOT EXISTS import_observations (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  import_batch_id   INTEGER NOT NULL,
  source_sheet      TEXT,
  source_row        INTEGER,
  observation_type  TEXT NOT NULL,
  status            TEXT NOT NULL,
  reason            TEXT,
  raw_data          TEXT,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
`);

try { db.exec("ALTER TABLE entries ADD COLUMN created_by TEXT;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN updated_by TEXT;"); } catch (_) {}

try { db.exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer';"); } catch (_) {}
try { db.exec("ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL;"); } catch (_) {}

try { db.exec("ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;"); } catch (_) {}
try { db.exec("ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;"); } catch (_) {}


// Seed demo users only in non-production environments.
if (process.env.NODE_ENV !== 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
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
    const _adminCount = db.prepare("SELECT COUNT(*) c FROM users WHERE role = 'admin'").get().c;
    // --- Startup diagnostics (bootstrap decision) ---
    console.log('[db] Admin user count (pre-bootstrap):', _adminCount);
    console.log('[db] Bootstrap will run:', _adminCount === 0);
    // --- End startup diagnostics ---
    if (_adminCount === 0) {
      db.prepare("INSERT INTO users (username, password_hash, role, track_scope) VALUES (?, ?, 'admin', '[]')")
        .run(_bUser.trim(), bcrypt.hashSync(_bPass.trim(), 10));
      console.log(`Bootstrap: admin user '${_bUser.trim()}' created.`);
    } else {
      console.log('Bootstrap: admin already exists, skipping.');
    }
  }
}
if (process.env.NODE_ENV === 'production' && db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  console.warn('WARNING: No users exist in the database. See README for production setup instructions.');
}

// Backfill demo user roles after seed so the UPDATE finds existing rows on fresh boot.
if (process.env.NODE_ENV !== 'production') {
  db.exec("UPDATE users SET role = 'admin' WHERE username = 'admin' AND (role IS NULL OR role = 'viewer');");
  db.exec("UPDATE users SET role = 'track_owner', track_scope = '[\"T3 AstraX Ops Cloud\"]' WHERE username = 'vasu' AND (role IS NULL OR role = 'viewer');");
}

// Seed generic illustrative rows to show row shape (not production data).
if (db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
  const ins = db.prepare(`INSERT INTO entries
    (type,title,owner,track,function_area,hypothesis,success_criteria,status)
    VALUES (@type,@title,@owner,@track,@function_area,@hypothesis,@success_criteria,@status)`);
  ins.run({ type: 'experiment', title: 'Sample experiment', owner: 'demo', track: 'T1 AstraX Device',
    function_area: 'Engineering', hypothesis: 'If we do X then Y because Z.',
    success_criteria: 'Baseline metric improves', status: 'Not Started' });
  ins.run({ type: 'work_item', title: 'Sample work item', owner: 'demo', track: 'T2 AstraX Customer Cloud',
    function_area: 'Software', hypothesis: null, success_criteria: null, status: 'In Progress' });
}

// Backfill audit columns for any rows without stamps (including seed rows on fresh installs).
db.exec("UPDATE entries SET created_by = 'system' WHERE created_by IS NULL;");
db.exec("UPDATE entries SET updated_by = 'system' WHERE updated_by IS NULL;");

module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS };
