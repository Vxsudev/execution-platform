# Task: Add admin-only XLSX import preview + commit routes to server.js

## Parent Spec
specs/phase-2-xlsx-import.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Add the two-step XLSX import backend to `app/server.js` ONLY. Do NOT modify any
other file (no db.js, no public/, no README). Apply exactly the three edits
below — they are verbatim and were validated end-to-end against the live
workbook and a canonical fixture (preview 0-write, commit insert + stamping,
403 for non-admin, server-side revalidation on commit).

### Edit 1 — add the xlsx require
Use the Edit tool. Find:
```javascript
const bcrypt = require('bcryptjs');
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');
```
Replace with:
```javascript
const bcrypt = require('bcryptjs');
const XLSX = require('xlsx');
const { db, ROW_FIELDS, ROW_TYPES, STATUSES, TRACKS } = require('./db');
```

### Edit 2 — scope a large-limit JSON parser to the import routes
Find:
```javascript
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
```
Replace with:
```javascript
const app = express();
const defaultJsonParser = express.json();
const importJsonParser = express.json({ limit: '25mb' });
app.use((req, res, next) => {
  // Import routes carry base64 workbook payloads exceeding the default 100kb
  // limit; defer them to a route-level large-limit parser. All other routes
  // keep the default parser unchanged.
  if (req.path === '/api/import/preview' || req.path === '/api/import/commit') return next();
  return defaultJsonParser(req, res, next);
});
app.use(express.static(path.join(__dirname, 'public')));
```

### Edit 3 — insert the import helpers + routes before the PORT line
Find:
```javascript
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`));
```
Replace with (the entire block below, ending with the original PORT/listen lines):
```javascript
// ---- xlsx import (admin only) ----
const IMPORT_SHEET = 'All Experiment Summary';
// Workbook header label (summary sheet, row 4) → entries DB column. Only these
// labels are read, so the side STATUS SUMMARY / Count stats panel is ignored.
const IMPORT_HEADER_MAP = {
  'Owner': 'owner',
  'Track': 'track',
  'Experiment Title': 'title',
  'Function': 'function_area',
  'Parent Item': 'parent_item',
  'Description / Hypothesis': 'hypothesis',
  'Experiment Design': 'design',
  'Success Criteria': 'success_criteria',
  'Target End Date': 'target_end_date',
  'Dependencies': 'dependencies',
  'Test outcome / Finding': 'outcome',
  'Next Action': 'next_action',
  'Status': 'status',
};
const IMPORT_REQUIRED = ['owner', 'track', 'title', 'status'];

function resolveImportSheet(wb) {
  if (wb.SheetNames.includes(IMPORT_SHEET)) return IMPORT_SHEET;
  return wb.SheetNames.find((n) => /summary/i.test(n)) || null;
}

function pad2(n) { return String(n).padStart(2, '0'); }
function normalizeImportValue(field, value) {
  if (value === null || value === undefined) return '';
  if (field === 'target_end_date') {
    // Excel date cells arrive as serial numbers; SSF.parse_date_code is pure and
    // timezone-safe (a JS Date would drift a calendar day under TZ behind UTC).
    if (typeof value === 'number' && isFinite(value)) {
      const d = XLSX.SSF.parse_date_code(value);
      if (d && d.y) return `${d.y}-${pad2(d.m)}-${pad2(d.d)}`;
    }
    if (value instanceof Date && !isNaN(value.getTime())) {
      return `${value.getUTCFullYear()}-${pad2(value.getUTCMonth() + 1)}-${pad2(value.getUTCDate())}`;
    }
  }
  return String(value).trim();
}

// Parse a decoded XLSX buffer → { sheet, rows: [{ row_number, data }] } or { error }.
// row_number is the 1-indexed spreadsheet row; fully-empty mapped rows are skipped.
// Read WITHOUT cellDates so date cells stay as Excel serials and are converted
// via XLSX.SSF (pure, timezone-immune) — JS Date drifts a day under non-UTC TZ.
function parseImportWorkbook(buffer) {
  const wb = XLSX.read(buffer, { type: 'buffer' });
  const sheet = resolveImportSheet(wb);
  if (!sheet) return { error: 'summary sheet not found' };
  const matrix = XLSX.utils.sheet_to_json(wb.Sheets[sheet], { header: 1, defval: null, blankrows: true });
  let headerIdx = -1;
  for (let i = 0; i < matrix.length; i++) {
    const cells = (matrix[i] || []).map((c) => (c == null ? '' : String(c).trim()));
    if (cells.includes('Owner') && cells.includes('Track') && cells.includes('Experiment Title')) { headerIdx = i; break; }
  }
  if (headerIdx < 0) return { error: `header row not found in sheet "${sheet}"` };
  const header = (matrix[headerIdx] || []).map((c) => (c == null ? '' : String(c).trim()));
  const colToField = {};
  header.forEach((label, idx) => { if (IMPORT_HEADER_MAP[label]) colToField[idx] = IMPORT_HEADER_MAP[label]; });
  const rows = [];
  for (let i = headerIdx + 1; i < matrix.length; i++) {
    const raw = matrix[i] || [];
    const data = {};
    for (const idx of Object.keys(colToField)) data[colToField[idx]] = normalizeImportValue(colToField[idx], raw[idx]);
    if (Object.values(data).every((v) => v === '')) continue;
    rows.push({ row_number: i + 1, data });
  }
  return { sheet, rows };
}

function validateImportRow(data) {
  const errors = [];
  for (const f of IMPORT_REQUIRED) {
    if (!data[f] || !String(data[f]).trim()) errors.push(`${f} is required`);
  }
  if (data.track && !TRACKS.includes(data.track)) errors.push('invalid track');
  if (data.status && !STATUSES.includes(data.status)) errors.push('invalid status');
  if (data.type !== undefined && data.type !== '' && !ROW_TYPES.includes(data.type)) errors.push('invalid type');
  return errors;
}

function toImportRow(data) {
  const out = {};
  for (const k of FIELD_KEYS) {
    if (data[k] !== undefined && data[k] !== null && String(data[k]) !== '') out[k] = String(data[k]);
  }
  out.type = (data.type && ROW_TYPES.includes(data.type)) ? data.type : 'experiment';
  return out;
}

app.post('/api/import/preview', importJsonParser, requireAuth, (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const { filename, content_base64 } = req.body || {};
  if (!filename || !/\.xlsx$/i.test(String(filename))) return res.status(400).json({ error: 'filename must end in .xlsx' });
  if (!content_base64 || typeof content_base64 !== 'string') return res.status(400).json({ error: 'content_base64 is required' });
  let parsed;
  try {
    const buffer = Buffer.from(content_base64, 'base64');
    parsed = parseImportWorkbook(buffer);
  } catch (_) { return res.status(400).json({ error: 'failed to parse workbook' }); }
  if (parsed.error) return res.status(400).json({ error: parsed.error });
  const valid_rows = [];
  const invalid_rows = [];
  for (const { row_number, data } of parsed.rows) {
    const errors = validateImportRow(data);
    if (errors.length) invalid_rows.push({ row_number, errors, raw: data });
    else valid_rows.push({ ...data, type: 'experiment' });
  }
  res.json({
    summary: { sheet: parsed.sheet, total_rows: parsed.rows.length, valid_rows: valid_rows.length, invalid_rows: invalid_rows.length },
    valid_rows,
    invalid_rows,
  });
});

app.post('/api/import/commit', importJsonParser, requireAuth, (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const { rows } = req.body || {};
  if (!Array.isArray(rows)) return res.status(400).json({ error: 'rows array is required' });
  const accepted = [];
  const rejected = [];
  rows.forEach((data, i) => {
    const errors = validateImportRow(data || {});
    if (errors.length) rejected.push({ index: i, errors });
    else accepted.push(toImportRow(data));
  });
  const ids = [];
  for (const row of accepted) {
    row.created_by = req.user.username;
    row.updated_by = req.user.username;
    const keys = Object.keys(row);
    const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
      .run(...keys.map((k) => row[k]));
    ids.push(Number(info.lastInsertRowid));
  }
  res.json({ ok: true, inserted_count: ids.length, ids, rejected_count: rejected.length, rejected });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`execution-table-app running on http://localhost:${PORT}`));
```

### Step 4 — syntax + boot sanity
```bash
cd /Users/vasudevarao/execution-platform/app
node --check server.js && echo "syntax OK"
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js & SP=$!; sleep 1.2
ADMIN=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
curl -s -o /dev/null -w "admin preview empty-body status: %{http_code}\n" -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{}'
kill $SP 2>/dev/null || true
```

## Acceptance Criteria
- [ ] `server.js` requires `xlsx`; import routes use a 25mb-limit JSON parser, default parser preserved for all other routes.
- [ ] `POST /api/import/preview` and `POST /api/import/commit` exist, both gated by `requireAuth` + `canImport` (403 for non-admin).
- [ ] Preview parses + validates and performs NO database write.
- [ ] Commit revalidates every row server-side and inserts only valid rows, stamping `created_by`/`updated_by` = importing admin and defaulting `type` to `experiment`.
- [ ] `node --check server.js` passes and the server boots.
- [ ] Only `app/server.js` modified by this task.

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-2-xlsx-import-001.md
