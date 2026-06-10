# Task: Verify audit trail end-to-end: migration, stamping, forge-prevention, UI display

## Parent Spec
specs/data-model-audit-trail.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Read-only verification. No app mutations. Reset DB and boot server, then verify all audit
trail behavior via curl + browser smoke test.

### Pre-flight
```bash
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
rm -f app/data.db app/data.db-shm app/data.db-wal app/data.db-journal
```

### Step 1 — Boot
```bash
cd /Users/vasudevarao/execution-platform/app && node server.js &
```
Wait for "running on http://localhost:3000".

### Step 2 — Login
```bash
curl -s -c /tmp/tdat-cookies.txt -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```
Expected: 200, session cookie set.

### Step 3 — Seed rows have backfill values
```bash
curl -s -b /tmp/tdat-cookies.txt http://localhost:3000/api/rows | \
  python3 -c "import sys,json; rows=json.load(sys.stdin)['rows']; [print(r['id'],r.get('created_by'),r.get('updated_by')) for r in rows]"
```
Expected: Each seed row shows `created_by = system` and `updated_by = system`.

### Step 4 — POST valid row → audit stamped from session
```bash
curl -s -o /tmp/tdat-r.json -w "%{http_code}" -b /tmp/tdat-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"Audit test row","owner":"verifier","track":"T1 AstraX Device","status":"Not Started"}'
cat /tmp/tdat-r.json
```
Expected: 201. Body includes `"created_by":"admin"` and `"updated_by":"admin"` and non-null `created_at`.
Capture row id from response.

### Step 5 — POST with forged audit fields → forge ignored
```bash
curl -s -o /tmp/tdat-r.json -w "%{http_code}" -b /tmp/tdat-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"Forge test","owner":"v","track":"T2 AstraX Customer Cloud","status":"Not Started","created_by":"hacker","updated_by":"hacker","created_at":"1970-01-01","updated_at":"1970-01-01"}'
cat /tmp/tdat-r.json
```
Expected: 201. Response `created_by = "admin"` (not "hacker"). `updated_by = "admin"`. Timestamps are current.

### Step 6 — PUT valid row → updated_by stamped, created_by unchanged
```bash
ROW_ID=$(cat /tmp/tdat-r.json | python3 -c "import sys,json; print(json.load(sys.stdin)['row']['id'])" 2>/dev/null || echo "2")
curl -s -o /tmp/tdat-put.json -w "%{http_code}" -b /tmp/tdat-cookies.txt \
  -X PUT http://localhost:3000/api/rows/$ROW_ID \
  -H 'Content-Type: application/json' \
  -d '{"status":"In Progress"}'
cat /tmp/tdat-put.json
```
Expected: 200. `updated_by = "admin"`. `updated_at` changed. `created_by` and `created_at` unchanged.

### Step 7 — PUT with forged audit fields → forge ignored
```bash
curl -s -o /tmp/tdat-forge-put.json -w "%{http_code}" -b /tmp/tdat-cookies.txt \
  -X PUT http://localhost:3000/api/rows/$ROW_ID \
  -H 'Content-Type: application/json' \
  -d '{"status":"Blocked","updated_by":"hacker","created_by":"hacker"}'
cat /tmp/tdat-forge-put.json
```
Expected: 200. `updated_by = "admin"` (not "hacker"). `created_by` unchanged.

### Step 8 — Required-field regression
```bash
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tdat-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","track":"T1 AstraX Device","status":"Not Started"}'
cat /tmp/r.json
```
Expected: 400. Body `{"error":"owner is required"}`.

### Step 9 — Track enum regression
```bash
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tdat-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"v","track":"Fake Track","status":"Not Started"}'
cat /tmp/r.json
```
Expected: 400. Body `{"error":"invalid track"}`.

### Step 10 — Invariant gate
```bash
bash /Users/vasudevarao/execution-platform/scripts/invariant-check.sh
```
Expected: 5/5 PASS.

### Step 11 — Surface audit
```bash
git -C /Users/vasudevarao/execution-platform status
```
Confirm: only `app/db.js`, `app/server.js`, `app/public/app.js`, `app/README.md` modified.
No changes to `app/public/index.html`, `app/public/style.css`, `prototypes/`, `sdlc/`.

### Step 12 — Report
PASS/FAIL per step. VERIFICATION_COMPLETE if all pass.

## Acceptance Criteria
- [ ] Server boots; login 200.
- [ ] Seed rows have created_by = 'system' and updated_by = 'system'.
- [ ] POST valid row → 201; created_by/updated_by = 'admin'.
- [ ] POST with forged created_by → 201; created_by = 'admin' (forge rejected).
- [ ] PUT valid row → 200; updated_by = 'admin'; created_by unchanged.
- [ ] PUT with forged updated_by → 200; updated_by = 'admin' (forge rejected).
- [ ] Required-field check still works (owner missing → 400 "owner is required").
- [ ] Track enum check still works (bad track → 400 "invalid track").
- [ ] 5/5 invariants PASS.
- [ ] Only allowed surfaces modified.

## Files Likely Affected
- None (read-only verification; DB reset at start)

## Blocked By
- tasks/data-model-audit-trail-003.md
