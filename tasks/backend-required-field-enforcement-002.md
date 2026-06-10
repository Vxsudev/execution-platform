# Task: Verify backend required-field enforcement: boot, API smoke test, invariants

## Parent Spec
specs/backend-required-field-enforcement.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Verify backend required-field enforcement works end-to-end. All checks are
API-level using node:http or curl. No UI automation.

### Pre-flight
Kill any existing process on port 3000:
```
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
```

### Step 1 — Boot
```
cd app && npm install && npm start &
```
Wait for "running on http://localhost:3000" in output (use a sleep or poll loop),
then run checks. Kill after.

### Step 2 — Login
```
curl -s -c /tmp/brf-cookies.txt -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```
Expected: 200 with `{ user: { ... } }` and cookie set in /tmp/brf-cookies.txt.

### Step 3 — Required field rejection (POST)

Each of the following must return HTTP 400:

(a) POST without title:
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"owner":"test","track":"T1","status":"Not Started"}'
```
Expected: 400. Body must contain "title is required".

(b) POST without owner:
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","track":"T1","status":"Not Started"}'
```
Expected: 400. Body must contain "owner is required".

(c) POST without track:
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"alice","status":"Not Started"}'
```
Expected: 400. Body must contain "track is required".

(d) POST without status:
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"alice","track":"T1"}'
```
Expected: 400. Body must contain "status is required".

### Step 4 — Valid POST returns 201
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"Backend test row","owner":"verifier","track":"T1 Device","status":"Not Started"}'
```
Expected: 201. Capture row id from response for PUT tests.

### Step 5 — PUT with blank required field returns 400
Using the id from Step 4:
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X PUT http://localhost:3000/api/rows/<id> \
  -H 'Content-Type: application/json' \
  -d '{"owner":""}'
```
Expected: 400. Body must contain "owner cannot be empty".

### Step 6 — Valid PUT returns 200
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/brf-cookies.txt \
  -X PUT http://localhost:3000/api/rows/<id> \
  -H 'Content-Type: application/json' \
  -d '{"status":"In Progress"}'
```
Expected: 200.

### Step 7 — Persistence check
Stop and restart server, GET /api/rows, confirm the row from Step 4 still exists with status 'In Progress'.

### Step 8 — Invariant gate
```
bash scripts/invariant-check.sh
```
Expected: 5/5 PASS.

### Step 9 — Surface audit
```
git status
```
Confirm:
- Only app/server.js, app/README.md are modified in app/
- No changes to app/public/, app/db.js, prototypes/, sdlc/
- Spec/task/recon artifacts untracked as expected

### Step 10 — Report
Emit PASS/FAIL per step. State VERIFICATION_COMPLETE if all pass.

## Acceptance Criteria
- [ ] Server boots on :3000.
- [ ] Login returns 200 with session cookie.
- [ ] POST without title → 400 "title is required".
- [ ] POST without owner → 400 "owner is required".
- [ ] POST without track → 400 "track is required".
- [ ] POST without status → 400 "status is required".
- [ ] POST with all required fields → 201.
- [ ] PUT with blank owner → 400 "owner cannot be empty".
- [ ] PUT valid partial update → 200.
- [ ] Data persists after server restart.
- [ ] 5/5 invariants PASS.
- [ ] No mutation outside app/server.js and app/README.md in app/.

## Files Likely Affected
- None (read-only verification; DB rows cleaned up after test)

## Blocked By
- tasks/backend-required-field-enforcement-001.md
