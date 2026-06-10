# Task: Verify P2-2 split workspaces frontend implementation

## Parent Spec
specs/phase-2-split-workspaces.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify all 30 acceptance criteria from the spec. No source files modified — verification only.
Uses source code inspection, a Node.js headless logic test, curl API tests, invariant check,
and git surface audit.

---

### Setup: Start the app

```bash
cd /Users/vasudevarao/execution-platform/app
# Kill any existing server
pkill -f "node server.js" 2>/dev/null || true
sleep 1
node server.js &
APP_PID=$!
sleep 1
echo "Server started PID=$APP_PID"
```

---

### Checks 1-3: App and auth

**Check 1 — App boots on :3000:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
# Expected: 200
```

**Check 2 — Login admin/admin123:**
```bash
ADMIN_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
echo "Admin cookie: $ADMIN_COOKIE"
# Expected: non-empty cookie
```

**Check 3 — Login vasu/vasu123:**
```bash
VASU_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"vasu","password":"vasu123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
echo "Vasu cookie: $VASU_COOKIE"
# Expected: non-empty cookie
```

---

### Checks 4-9: Source inspection for admin workspace behavior

These checks verify the frontend logic by inspecting the source and running Node.js headless tests.

**Source structure checks:**
```bash
# Checks 4-9: Verify key patterns in app.js
echo "--- Source inspection ---"
grep -c "workspace: 'all'" app/public/app.js && echo "CHECK: state.workspace present" || echo "FAIL: state.workspace missing"
grep -c "function isAdmin"     app/public/app.js && echo "CHECK: isAdmin present" || echo "FAIL: isAdmin missing"
grep -c "function canDeleteRow" app/public/app.js && echo "CHECK: canDeleteRow present" || echo "FAIL: canDeleteRow missing"
grep -c "isTrackOwner.*ws-tab\|ws-tab.*isTrackOwner\|isTrackOwner()" app/public/app.js && echo "CHECK: workspace tabs conditional on isTrackOwner" || echo "FAIL: tabs condition missing"
grep -c "canCreateInCurrentWorkspace()" app/public/app.js && echo "CHECK: newBtn conditional present" || echo "FAIL: newBtn condition missing"
grep -c "canEditRow(r)" app/public/app.js && echo "CHECK: canEditRow in renderTable" || echo "FAIL: canEditRow missing from table"
grep -c "canDeleteRow()" app/public/app.js && echo "CHECK: canDeleteRow in renderTable" || echo "FAIL: canDeleteRow missing from table"
grep -c "visibleRowsForWorkspace(state.rows)" app/public/app.js && echo "CHECK: filteredRows uses workspace filter" || echo "FAIL: workspace filter missing"
grep -c "isTrackOwner.*f\.key.*track\|f\.key.*track.*isTrackOwner" app/public/app.js || grep -c "f.key === 'track' && isTrackOwner" app/public/app.js && echo "CHECK: track form constraint present" || echo "FAIL: track form constraint missing"
```

**CSS checks:**
```bash
grep -c "ws-tabs" app/public/style.css && echo "CHECK: .ws-tabs CSS present" || echo "FAIL: .ws-tabs missing"
grep -c "ws-tab.active\|ws-tab\.active" app/public/style.css && echo "CHECK: .ws-tab.active CSS present" || echo "FAIL: .ws-tab.active missing"
```

---

### Checks 4-23: Node.js headless logic test

Run the full permission logic test in Node.js without a browser:

```bash
node -e "
// Headless test harness for P2-2 permission helpers
// Minimal DOM mock to allow app.js to load without errors
const document = {
  getElementById: () => ({ onclick: null, oninput: null, onchange: null, textContent: '', value: '' }),
  querySelectorAll: () => [],
  body: { appendChild: () => {} },
  createElement: () => ({
    className: '', innerHTML: '',
    appendChild: () => {}, addEventListener: () => {},
    querySelector: () => ({ onclick: null, textContent: '' }),
    querySelectorAll: () => []
  }),
};
const fetch = async () => ({ ok: true, json: async () => ({}) });
const confirm = () => true;

// Load app.js with init() call disabled
const fs = require('fs');
let src = fs.readFileSync('public/app.js', 'utf8');
src = src.replace(/^init\(\);$/m, '// init() disabled for test');

// Evaluate in function scope so locals don't conflict
const runner = new Function(
  'document', 'fetch', 'confirm',
  src + \`
// === TEST HARNESS ===
let pass = 0, fail = 0;
function assert(label, cond) {
  if (cond) { console.log('  PASS:', label); pass++; }
  else { console.error('  FAIL:', label); fail++; }
}

// --- Admin checks (4-9) ---
state.user = { role: 'admin', track_scope: [] };
state.workspace = 'all';
assert('Check 4/5/6/9: isAdmin() true', isAdmin());
assert('Check 4/5/6/9: isTrackOwner() false for admin', !isTrackOwner());
assert('Check 5: canCreateInCurrentWorkspace() true for admin', canCreateInCurrentWorkspace());
assert('Check 6: canEditRow() true for admin on T1 row', canEditRow({ track: 'T1 AstraX Device' }));
assert('Check 6: canDeleteRow() true for admin', canDeleteRow());
assert('Check 9: workspace tabs NOT shown for admin (isTrackOwner false)', !isTrackOwner());

// --- track_owner All Tracks checks (10-13) ---
state.user = { role: 'track_owner', track_scope: ['T3 AstraX Ops Cloud'] };
state.workspace = 'all';
assert('Check 10: isTrackOwner() true', isTrackOwner());
assert('Check 12: canEditRow() true for T3 (in scope)', canEditRow({ track: 'T3 AstraX Ops Cloud' }));
assert('Check 12: canEditRow() false for T1 (not in scope)', !canEditRow({ track: 'T1 AstraX Device' }));
assert('Check 12: canDeleteRow() false for track_owner', !canDeleteRow());
assert('Check 13: canCreateInCurrentWorkspace() false in all-workspace', !canCreateInCurrentWorkspace());

// --- track_owner My Track checks (14-19) ---
state.workspace = 'my';
assert('Check 15: canCreateInCurrentWorkspace() true in my-workspace', canCreateInCurrentWorkspace());
assert('Check 17: canDeleteRow() still false in my-workspace', !canDeleteRow());
assert('Check 16: canEditRow() true for T3 in my-workspace', canEditRow({ track: 'T3 AstraX Ops Cloud' }));

// --- visibleRowsForWorkspace checks (11, 14) ---
const allRows = [
  { id:1, track: 'T1 AstraX Device', title: 'T1 row' },
  { id:2, track: 'T3 AstraX Ops Cloud', title: 'T3 row' },
  { id:3, track: 'T2 AstraX Customer Cloud', title: 'T2 row' },
];
state.workspace = 'all';
state.rows = allRows;
assert('Check 11: visibleRowsForWorkspace: all 3 rows in all-workspace', visibleRowsForWorkspace(allRows).length === 3);
state.workspace = 'my';
const myRows = visibleRowsForWorkspace(allRows);
assert('Check 14: visibleRowsForWorkspace: only T3 in my-workspace', myRows.length === 1 && myRows[0].track === 'T3 AstraX Ops Cloud');

// --- userScope check (18, 19) ---
assert('Check 18/19: userScope() returns T3 track', JSON.stringify(userScope()) === JSON.stringify(['T3 AstraX Ops Cloud']));

// --- Viewer checks (20-23) ---
state.user = { role: 'viewer', track_scope: [] };
state.workspace = 'all';
assert('Check 20/23: isViewer() true', isViewer());
assert('Check 21: canCreateInCurrentWorkspace() false for viewer', !canCreateInCurrentWorkspace());
assert('Check 22: canEditRow() false for viewer', !canEditRow({ track: 'T1 AstraX Device' }));
assert('Check 22: canDeleteRow() false for viewer', !canDeleteRow());
assert('Check 23: workspace tabs NOT shown for viewer (isTrackOwner false)', !isTrackOwner());

console.log('');
console.log('Logic test: ' + pass + ' pass, ' + fail + ' fail');
if (fail > 0) process.exit(1);
\`
);
runner(document, fetch, confirm);
" 2>&1
```

Expected: All PASS, 0 fail.

---

### Check 27: Backend P2-1 regression — Vasu raw POST to T1 returns 403

```bash
VPOST_T1=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"title":"Vasu T1 Row","owner":"vasu","track":"T1 AstraX Device","status":"Not Started"}')
echo "Check 27: Vasu POST T1 (backend guard): $VPOST_T1 (expected 403)"
```

### Check 28: Audit stamping still works

```bash
NEWROW=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"P2-2 audit test","owner":"admin","track":"T1 AstraX Device","status":"Not Started"}')
echo "Check 28: created_by=$(echo $NEWROW | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).row.created_by));')"
# Expected: admin
```

---

### Checks 25-26: API-level regression (search + filter still work via /api/rows)

```bash
ROWS=$(curl -s http://localhost:3000/api/rows --cookie "sid=$ADMIN_COOKIE")
ROW_COUNT=$(echo $ROWS | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).rows.length));')
echo "Check 25/26: /api/rows returns rows: $ROW_COUNT (expected > 0)"
```

---

### Check 24: Details modal — source inspection

```bash
grep -c "data-info" app/public/app.js && echo "Check 24: Details button present in renderTable" || echo "FAIL: data-info missing"
grep -c "openDetails" app/public/app.js && echo "Check 24: openDetails function present" || echo "FAIL: openDetails missing"
```

---

### Check 29: Invariants: 5/5 PASS

```bash
cd /Users/vasudevarao/execution-platform
bash scripts/invariant-check.sh
# Expected: 5/5 PASS
```

---

### Check 30: Git surface audit

```bash
git status
# Expected: only app/public/app.js and app/public/style.css shown as modified
# app/server.js and app/db.js must NOT be modified
# app/public/index.html must NOT be modified
```

Verify explicitly:
```bash
git diff --name-only | grep -E "^app/server\.js|^app/db\.js|^app/public/index\.html" | wc -l
# Expected: 0 (none of these files modified)
git diff --name-only | grep "^app/public/app\.js" | wc -l
# Expected: 1
git diff --name-only | grep "^app/public/style\.css" | wc -l
# Expected: 1
```

---

### Teardown

```bash
kill $APP_PID 2>/dev/null || true
```

---

### Report format

Report all 30 checks with PASS/FAIL. Include:
- Full Node.js logic test output
- HTTP status codes for backend tests
- Invariant gate result
- Git surface audit

## Acceptance Criteria
- [ ] Check 1: App boots on :3000 → HTTP 200
- [ ] Check 2: Login admin/admin123 → cookie returned
- [ ] Check 3: Login vasu/vasu123 → cookie returned
- [ ] Check 4-9: Admin logic: isAdmin true, canCreate/Edit/Delete all true, no workspace tabs
- [ ] Check 10-13: Vasu All Tracks: isTrackOwner, tabs shown, Edit on T3 only, no New, no Delete
- [ ] Check 14-19: Vasu My Track: T3-only rows, New button, Edit all visible rows, no Delete
- [ ] Check 18-19: Vasu form: track select constrained to T3 only (userScope)
- [ ] Check 20-23: Viewer: isViewer, no New/Edit/Delete, no tabs
- [ ] Check 24: Details button present for all rows
- [ ] Check 25-26: /api/rows returns rows (search/filter API unchanged)
- [ ] Check 27: Vasu raw POST to T1 → 403 (P2-1 backend guard regression)
- [ ] Check 28: created_by audit stamp set correctly
- [ ] Check 29: Invariants 5/5 PASS
- [ ] Check 30: Git modified: app/public/app.js, app/public/style.css only; server.js, db.js, index.html untouched

## Files Likely Affected
- No source files modified — verification only

## Blocked By
- tasks/phase-2-split-workspaces-002.md
