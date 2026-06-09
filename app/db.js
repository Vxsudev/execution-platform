// Database setup, schema, and seed.
// The Excel sheet is used ONLY as the source of column/row structure here.
// Runtime data lives in this SQLite database, never in the spreadsheet.
const path = require('path');
const { DatabaseSync } = require('node:sqlite');
const bcrypt = require('bcryptjs');

const db = new DatabaseSync(path.join(__dirname, 'data.db'));
try {
  db.exec("PRAGMA journal_mode = WAL;");
} catch (err) {
  console.warn("SQLite WAL mode unavailable; continuing with default journal mode:", err.message);
}

const ROW_TYPES = ['experiment', 'work_item', 'task'];
const STATUSES = ['Not Started', 'In Progress', 'Complete', 'Blocked', 'Inconclusive'];

// field.key === DB column name. Order === display/form order.
const ROW_FIELDS = [
  { key: 'type',            label: 'Type',                    input: 'select',   options: ROW_TYPES },
  { key: 'title',           label: 'Title',                   input: 'text',     required: true },
  { key: 'owner',           label: 'Owner',                   input: 'text' },
  { key: 'track',           label: 'Track',                   input: 'text' },
  { key: 'function_area',   label: 'Function',                input: 'text' },
  { key: 'parent_item',     label: 'Parent Item',             input: 'text' },
  { key: 'hypothesis',      label: 'Description / Hypothesis', input: 'textarea' },
  { key: 'design',          label: 'Experiment Design',       input: 'textarea' },
  { key: 'success_criteria',label: 'Success Criteria',        input: 'textarea' },
  { key: 'target_end_date', label: 'Target End Date',         input: 'date' },
  { key: 'dependencies',    label: 'Dependencies',            input: 'text' },
  { key: 'outcome',         label: 'Outcome / Finding',       input: 'textarea' },
  { key: 'next_action',     label: 'Next Action',             input: 'text' },
  { key: 'status',          label: 'Status',                  input: 'select',   options: STATUSES },
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
`);

// Seed users (change these in production).
if (db.prepare('SELECT COUNT(*) c FROM users').get().c === 0) {
  const ins = db.prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
  ins.run('admin', bcrypt.hashSync('admin123', 10));
  ins.run('vasu',  bcrypt.hashSync('vasu123', 10));
}

// Seed a generic illustrative row to show row shape (not production data).
if (db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
  const ins = db.prepare(`INSERT INTO entries
    (type,title,owner,track,function_area,success_criteria,status)
    VALUES (@type,@title,@owner,@track,@function_area,@success_criteria,@status)`);
  ins.run({ type: 'experiment', title: 'Sample experiment', owner: 'demo', track: 'T1',
    function_area: 'Engineering', success_criteria: 'Baseline metric improves', status: 'Not Started' });
}

module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES };
