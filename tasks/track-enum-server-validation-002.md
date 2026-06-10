# Task: Verify track enum enforcement: invalid track rejected, valid track accepted

## Parent Spec
specs/track-enum-server-validation.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Verify track enum validation end-to-end via API. Reset DB, boot server, curl tests.

### Pre-flight
```
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
rm -f app/data.db app/data.db-shm app/data.db-wal app/data.db-journal
```

### Step 1 — Boot
```
cd app && npm install && npm start &
```
Wait for "running on http://localhost:3000".

### Step 2 — Login
```
curl -s -c /tmp/tesv-cookies.txt -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```
Expected: 200, session cookie set.

### Step 3 — POST with invalid track → 400

(a) track="T2 Cloud" (old app-invented, not canonical):
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"v","track":"T2 Cloud","status":"Not Started"}'
```
Expected: 400. Body must be `{"error":"invalid track"}`.

(b) track="Fake Track":
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"v","track":"Fake Track","status":"Not Started"}'
```
Expected: 400. Body: `{"error":"invalid track"}`.

### Step 4 — POST with valid canonical track → 201
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"Enum test row","owner":"verifier","track":"T3 AstraX Ops Cloud","status":"Not Started"}'
```
Expected: 201. Capture row id.

### Step 5 — PUT with invalid track → 400
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X PUT http://localhost:3000/api/rows/<id> \
  -H 'Content-Type: application/json' \
  -d '{"track":"Fake Track"}'
```
Expected: 400. Body: `{"error":"invalid track"}`.

### Step 6 — PUT with valid canonical track → 200
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X PUT http://localhost:3000/api/rows/<id> \
  -H 'Content-Type: application/json' \
  -d '{"track":"T5 Business"}'
```
Expected: 200.

### Step 7 — Required-field regression check
POST without owner (required field unrelated to track) must still return 400 "owner is required":
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","track":"T1 AstraX Device","status":"Not Started"}'
```
Expected: 400. Body: `{"error":"owner is required"}`.

### Step 8 — Status enum regression check
POST with invalid status must still return 400 "invalid status":
```
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tesv-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"v","track":"T1 AstraX Device","status":"BadStatus"}'
```
Expected: 400. Body: `{"error":"invalid status"}`.

### Step 9 — Schema tracks unchanged
GET /api/schema — `tracks` must still contain all 6 canonical values.

### Step 10 — Persistence
Stop and restart server. GET /api/rows confirms the T3/T5 row from steps 4/6 persists.

### Step 11 — Invariant gate
```
bash scripts/invariant-check.sh
```
Expected: 5/5 PASS.

### Step 12 — Surface audit
```
git status
```
Confirm: only app/server.js and app/README.md modified in app/. No changes to app/db.js,
app/public/, prototypes/, sdlc/.

### Step 13 — Report
PASS/FAIL per step. VERIFICATION_COMPLETE if all pass.

## Acceptance Criteria
- [ ] Server boots; login 200.
- [ ] POST with "T2 Cloud" → 400 "invalid track".
- [ ] POST with "Fake Track" → 400 "invalid track".
- [ ] POST with "T3 AstraX Ops Cloud" → 201.
- [ ] PUT with "Fake Track" → 400 "invalid track".
- [ ] PUT with "T5 Business" → 200.
- [ ] Required-field check still works (owner missing → "owner is required").
- [ ] Status enum check still works (invalid status → "invalid status").
- [ ] schema.tracks unchanged (6 canonical values).
- [ ] Persistence after restart confirmed.
- [ ] 5/5 invariants PASS.
- [ ] Only app/server.js and app/README.md modified.

## Files Likely Affected
- None (read-only verification; DB reset at start)

## Blocked By
- tasks/track-enum-server-validation-001.md
