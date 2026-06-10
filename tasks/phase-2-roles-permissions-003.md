# Task: Verify roles, permissions, and Phase 1 regression

## Parent Spec
specs/phase-2-roles-permissions.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify all acceptance criteria from the spec using curl commands and direct SQLite queries
against the running app. Start the app fresh (remove data.db first for a clean boot), run
all verification checks, then report results. Do not modify any app source files.

### Setup

```bash
cd /Users/vasudevarao/execution-platform/app
rm -f data.db data.db-shm data.db-wal
node server.js &
APP_PID=$!
sleep 1
```

### Check 1 — Admin /api/me

```bash
# Login as admin
ADMIN_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')

# Check /api/me
curl -s http://localhost:3000/api/me --cookie "sid=$ADMIN_COOKIE"
# Expected: {"user":{"id":1,"username":"admin","role":"admin","track_scope":[]}}
```

### Check 2 — Vasu /api/me

```bash
VASU_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"vasu","password":"vasu123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')

curl -s http://localhost:3000/api/me --cookie "sid=$VASU_COOKIE"
# Expected: {"user":{"id":2,"username":"vasu","role":"track_owner","track_scope":["T3 AstraX Ops Cloud"]}}
```

### Check 3 — Admin row operations (all must succeed)

```bash
# Admin POST in T1
R1=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"Admin T1 Row","owner":"admin","track":"T1 AstraX Device","status":"Not Started"}')
echo "Admin POST T1: $(echo $R1 | grep -o '"id":[0-9]*' | head -1)"

# Admin POST in T5
R2=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"Admin T5 Row","owner":"admin","track":"T5 Business","status":"Not Started"}')
echo "Admin POST T5: $(echo $R2 | grep -o '"id":[0-9]*' | head -1)"

# Admin PUT
T1_ID=$(echo $R1 | python3 -c "import sys,json; print(json.load(sys.stdin)['row']['id'])")
PUTR=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/api/rows/$T1_ID \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"status":"In Progress"}')
echo "Admin PUT: $PUTR (expected 200)"

# Admin DELETE
DELR=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:3000/api/rows/$T1_ID \
  --cookie "sid=$ADMIN_COOKIE")
echo "Admin DELETE: $DELR (expected 200)"
```

### Check 4 — Vasu track_owner operations

```bash
# Vasu GET all rows (must succeed)
GETR=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/rows --cookie "sid=$VASU_COOKIE")
echo "Vasu GET rows: $GETR (expected 200)"

# Vasu POST in T3 (assigned track — must succeed)
R3=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"title":"Vasu T3 Row","owner":"vasu","track":"T3 AstraX Ops Cloud","status":"Not Started"}')
T3_ID=$(echo $R3 | python3 -c "import sys,json; print(json.load(sys.stdin)['row']['id'])")
echo "Vasu POST T3: row id $T3_ID (expected a valid id)"

# Vasu POST in T1 (NOT assigned — must be 403)
VPOST_T1=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"title":"Vasu T1 Row","owner":"vasu","track":"T1 AstraX Device","status":"Not Started"}')
echo "Vasu POST T1: $VPOST_T1 (expected 403)"

# Vasu PUT T3 row (assigned — must succeed)
VPUT_T3=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/api/rows/$T3_ID \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"status":"In Progress"}')
echo "Vasu PUT T3 (no track change): $VPUT_T3 (expected 200)"

# Vasu PUT T5 row (not assigned — must be 403)
T5_ID=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"Admin T5 for Vasu test","owner":"admin","track":"T5 Business","status":"Not Started"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['row']['id'])")
VPUT_T5=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/api/rows/$T5_ID \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"status":"In Progress"}')
echo "Vasu PUT T5 row: $VPUT_T5 (expected 403)"

# Vasu strict track reassignment: PUT T3 row changing track to T1 — must be 403
VPUT_REASSIGN=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/api/rows/$T3_ID \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"track":"T1 AstraX Device"}')
echo "Vasu reassign T3→T1: $VPUT_REASSIGN (expected 403)"

# Vasu DELETE — must be 403
VDEL=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:3000/api/rows/$T3_ID \
  --cookie "sid=$VASU_COOKIE")
echo "Vasu DELETE: $VDEL (expected 403)"
```

### Check 5 — Viewer role

Create a temporary viewer user directly in SQLite, verify blocks, then clean up:

```bash
node -e "
const {db} = require('./db');
const bcrypt = require('bcryptjs');
const hash = bcrypt.hashSync('viewer123', 10);
db.prepare('INSERT OR IGNORE INTO users (username, password_hash, role) VALUES (?,?,?)').run('viewer_test', hash, 'viewer');
console.log('viewer_test created');
"

VIEWER_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"viewer_test","password":"viewer123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')

VGET=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/rows --cookie "sid=$VIEWER_COOKIE")
echo "Viewer GET: $VGET (expected 200)"

VPOST=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$VIEWER_COOKIE" \
  -d '{"title":"Viewer row","owner":"v","track":"T1 AstraX Device","status":"Not Started"}')
echo "Viewer POST: $VPOST (expected 403)"

VPUT2=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/api/rows/1 \
  -H 'Content-Type: application/json' --cookie "sid=$VIEWER_COOKIE" \
  -d '{"status":"Complete"}')
echo "Viewer PUT: $VPUT2 (expected 403)"

VDEL2=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:3000/api/rows/1 \
  --cookie "sid=$VIEWER_COOKIE")
echo "Viewer DELETE: $VDEL2 (expected 403)"

# Clean up viewer_test (do not leave in DB)
node -e "const {db} = require('./db'); db.prepare('DELETE FROM users WHERE username=?').run('viewer_test'); console.log('viewer_test removed');"
```

### Check 6 — Phase 1 regression

```bash
# Required-field validation
RF=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"No owner","track":"T1 AstraX Device","status":"Not Started"}')
echo "Missing owner: $(echo $RF | python3 -c 'import sys,json; print(json.load(sys.stdin))')"
# Expected: {"error":"owner is required"}

# Track enum validation
TE=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"Bad track","owner":"admin","track":"T99 Fake","status":"Not Started"}')
echo "Bad track: $(echo $TE | python3 -c 'import sys,json; print(json.load(sys.stdin))')"
# Expected: {"error":"invalid track"}

# Audit stamping
NEWROW=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"Audit test","owner":"admin","track":"T1 AstraX Device","status":"Not Started"}')
echo "created_by: $(echo $NEWROW | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"row\"][\"created_by\"])')"
# Expected: admin
```

### Check 7 — Invariants

```bash
cd /Users/vasudevarao/execution-platform
bash scripts/invariant-check.sh
# Expected: 5/5 PASS
```

### Check 8 — Git surface audit

```bash
git status
# Expected: only app/db.js, app/server.js modified (plus task/spec/registry files)
# app/public/ must NOT be modified
```

### Teardown

```bash
kill $APP_PID 2>/dev/null || true
```

Report all check results with PASS/FAIL. Any unexpected HTTP status codes or error messages
constitute FAIL. Do not modify any source files during verification.

## Acceptance Criteria
- [ ] GET /api/me for admin returns role:'admin' and track_scope:[] (empty array)
- [ ] GET /api/me for vasu returns role:'track_owner' and track_scope:['T3 AstraX Ops Cloud']
- [ ] Admin POST in T1 AstraX Device → 201
- [ ] Admin POST in T5 Business → 201
- [ ] Admin PUT any row → 200
- [ ] Admin DELETE any row → 200
- [ ] Vasu GET /api/rows → 200
- [ ] Vasu POST in T3 AstraX Ops Cloud → 201
- [ ] Vasu POST in T1 AstraX Device → 403 { error: 'Forbidden' }
- [ ] Vasu PUT T3 row (no track change) → 200
- [ ] Vasu PUT T5 row → 403 Forbidden
- [ ] Vasu PUT T3 row reassigning track to T1 → 403 Forbidden (strict rule)
- [ ] Vasu DELETE any row → 403 Forbidden
- [ ] Viewer GET /api/rows → 200
- [ ] Viewer POST → 403 Forbidden
- [ ] Viewer PUT → 403 Forbidden
- [ ] Viewer DELETE → 403 Forbidden
- [ ] POST missing owner → 400 'owner is required' (Phase 1 regression)
- [ ] POST invalid track → 400 'invalid track' (Phase 1 regression)
- [ ] Audit stamping: created_by = authenticated username (Phase 1 regression)
- [ ] Invariants: 5/5 PASS
- [ ] Git status: only allowed surfaces modified (app/db.js, app/server.js, task/spec/registry files); app/public/ untouched

## Files Likely Affected
- No source files modified — verification only

## Blocked By
- tasks/phase-2-roles-permissions-002.md
