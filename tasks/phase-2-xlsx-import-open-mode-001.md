# Task: Switch XLSX import to open (capture-first) mode in server.js

## Parent Spec
specs/phase-2-xlsx-import-open-mode.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
Replace strict import validation with open-mode classification in `app/server.js` ONLY.
Do NOT modify db.js, public/, README, or package.json. Do NOT change the strict
`validate()` used by `POST`/`PUT /api/rows` — only the import routes change.

This block was validated end-to-end: the live workbook yields 19 importable / 0 skipped,
non-canonical track imported as-is, blank owner/track/status defaulted, non-canonical
status coerced to "Not Started" (the `entries.status` CHECK forbids arbitrary text and
db.js must stay untouched), title-blank rows skipped, commit never crashes.

### Edit — replace the entire XLSX import section
In `app/server.js`, replace EVERYTHING from the line:
```
// ---- xlsx import (admin only) ----
```
up to (but NOT including) the line:
```
const PORT = process.env.PORT || 3000;
```
with exactly this block (it KEEPS `parseImportWorkbook`, `normalizeImportValue`,
`resolveImportSheet`, `IMPORT_HEADER_MAP`, `toImportRow` from P2-4; REMOVES
`IMPORT_REQUIRED` + `validateImportRow`; ADDS `classifyImportRow` + open-mode constants;
and REWRITES both routes):

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

// Open-mode (capture-first) defaults. title is the only hard requirement.
const IMPORT_UNASSIGNED_OWNER = 'Unassigned';
const IMPORT_UNASSIGNED_TRACK = 'Unassigned Track';
const IMPORT_DEFAULT_STATUS = 'Not Started';

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

// Open-mode classification (capture-first). A row is unimportable ONLY if title is blank.
// owner/track/status are defaulted and/or warned, never blocking:
//   - blank owner  → "Unassigned"          (warn)
//   - blank track  → "Unassigned Track"     (warn);  non-canonical track imports AS-IS (warn) — track is free TEXT
//   - blank status → "Not Started"          (warn);  non-canonical status COERCED to "Not Started" (warn)
// status is coerced because entries.status has a CHECK constraint (db.js is not modified);
// type is coerced to a canonical value for the same reason. Returns normalized data + warnings.
function classifyImportRow(data) {
  const d = data && typeof data === 'object' ? (data.data && typeof data.data === 'object' ? data.data : data) : {};
  const title = d.title == null ? '' : String(d.title).trim();
  if (!title) return { importable: false, reason: 'title is required' };
  const out = {};
  for (const k of FIELD_KEYS) {
    if (d[k] !== undefined && d[k] !== null) out[k] = String(d[k]).trim();
  }
  out.title = title;
  const warnings = [];
  if (!out.owner) { out.owner = IMPORT_UNASSIGNED_OWNER; warnings.push('owner blank; set to Unassigned'); }
  if (!out.track) { out.track = IMPORT_UNASSIGNED_TRACK; warnings.push('track blank; set to Unassigned Track'); }
  else if (!TRACKS.includes(out.track)) { warnings.push(`non-canonical track "${out.track}" imported as-is`); }
  if (!out.status) { out.status = IMPORT_DEFAULT_STATUS; warnings.push('status blank; set to Not Started'); }
  else if (!STATUSES.includes(out.status)) { warnings.push(`status "${out.status}" not a canonical status; stored as Not Started`); out.status = IMPORT_DEFAULT_STATUS; }
  out.type = (out.type && ROW_TYPES.includes(out.type)) ? out.type : 'experiment';
  return { importable: true, warnings, data: out };
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
  const rows = [];
  const skipped_rows = [];
  let warning_count = 0;
  for (const { row_number, data } of parsed.rows) {
    const c = classifyImportRow(data);
    if (!c.importable) { skipped_rows.push({ row_number, reason: c.reason }); continue; }
    warning_count += c.warnings.length;
    rows.push({ row_number, warnings: c.warnings, data: c.data });
  }
  res.json({
    summary: { sheet: parsed.sheet, total_rows: parsed.rows.length, importable_rows: rows.length, skipped_rows: skipped_rows.length, warning_count },
    rows,
    skipped_rows,
  });
});

app.post('/api/import/commit', importJsonParser, requireAuth, (req, res) => {
  if (!canImport(req.user)) return res.status(403).json({ error: 'Forbidden' });
  const { rows } = req.body || {};
  if (!Array.isArray(rows)) return res.status(400).json({ error: 'rows array is required' });
  const ids = [];
  const skipped = [];
  rows.forEach((raw, i) => {
    const c = classifyImportRow(raw);
    if (!c.importable) { skipped.push({ index: i, reason: c.reason }); return; }
    const row = toImportRow(c.data);
    row.created_by = req.user.username;
    row.updated_by = req.user.username;
    try {
      const keys = Object.keys(row);
      const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
        .run(...keys.map((k) => row[k]));
      ids.push(Number(info.lastInsertRowid));
    } catch (e) {
      skipped.push({ index: i, reason: 'insert failed: ' + (e && e.message ? e.message : 'unknown error') });
    }
  });
  res.json({ ok: true, inserted_count: ids.length, ids, skipped_count: skipped.length, skipped });
});
```

Leave the `const PORT = ...` / `app.listen(...)` lines that follow exactly as they are.

### Syntax + boot sanity
```bash
cd /Users/vasudevarao/execution-platform/app
node --check server.js && echo "syntax OK"
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js & SP=$!; sleep 1.2
ADMIN=$(curl -si -X POST http://localhost:3000/api/login -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' | grep -i set-cookie | sed 's/.*sid=\([^;]*\).*/\1/')
curl -s -o /dev/null -w "preview empty-body: %{http_code}\n" -X POST http://localhost:3000/api/import/preview -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{}'
# strict manual CRUD must STILL reject invalid track
echo "manual POST invalid track (expect 403/400): $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3000/api/rows -H 'Content-Type: application/json' --cookie "sid=$ADMIN" -d '{"owner":"a","title":"t","track":"T9 Bogus","type":"experiment","status":"Not Started"}')"
kill $SP 2>/dev/null || true
```

## Acceptance Criteria
- [ ] Import section replaced; `classifyImportRow` present; `validateImportRow`/`IMPORT_REQUIRED` removed.
- [ ] `parseImportWorkbook`, `normalizeImportValue`, `toImportRow`, `IMPORT_HEADER_MAP` unchanged.
- [ ] Preview returns `summary.{importable_rows,skipped_rows,warning_count}`, `rows[].{row_number,warnings,data}`, `skipped_rows[]`; no DB write.
- [ ] Commit re-classifies, inserts importable rows (per-row try/catch — never crashes), stamps created_by/updated_by.
- [ ] Strict `validate()` for `POST`/`PUT /api/rows` is unchanged (invalid track still rejected).
- [ ] `node --check server.js` passes; server boots. Only `app/server.js` modified.

## Files Likely Affected
- app/server.js

## Blocked By
- none
