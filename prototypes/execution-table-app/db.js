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

// Seed a few demo rows to illustrate row SHAPE only (not the production sheet data).
if (db.prepare('SELECT COUNT(*) c FROM entries').get().c === 0) {
  const ins = db.prepare(`INSERT INTO entries
    (type,title,owner,track,function_area,hypothesis,design,success_criteria,target_end_date,dependencies,status)
    VALUES (@type,@title,@owner,@track,@function_area,@hypothesis,@design,@success_criteria,@target_end_date,@dependencies,@status)`);
  ins.run({ type:'experiment', title:'GEOMINFO_ts sensitivity on Mo', owner:'Aditya', track:'T1 Device', function_area:'Firmware',
    hypothesis:'If we reduce GEOMINFO_ts by 20%, Mo overcall on 316 SS will drop below 5% delta',
    design:'Run 5 spectra on NIST SRM 361 (316 SS). Vary GEOMINFO_ts 0.8x-1.2x. Log Mo% at each setting.',
    success_criteria:'Mo delta vs certified < 5% on >=3 of 5 runs', target_end_date:'2026-06-20',
    dependencies:'HIL jig live', status:'In Progress' });
  ins.run({ type:'work_item', title:'Set up STM base firmware', owner:'Sreekar', track:'T1 Device', function_area:'Firmware',
    hypothesis:null, design:null, success_criteria:null, target_end_date:'2026-06-14', dependencies:null, status:'Complete' });
  ins.run({ type:'task', title:'Calculate device weight from design', owner:'Gopinath', track:'T1 Device', function_area:'Mechanical',
    hypothesis:null, design:'Build EB1 mock-up, measure, optimise EB2 to weight target',
    success_criteria:null, target_end_date:null, dependencies:'EB1 mock-up sample', status:'Blocked' });
}

module.exports = { db, ROW_FIELDS, ROW_TYPES, STATUSES };
