# Task: Verify canonical track taxonomy: schema, filter, form, CRUD, smoke test

## Parent Spec
specs/canonical-track-taxonomy-enforcement.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Verify the canonical track taxonomy works end-to-end. Reset DB, boot server, run API checks.

### Pre-flight
```
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
rm -f app/data.db app/data.db-shm app/data.db-wal app/data.db-journal
```

### Step 1 — Boot
```
cd app && npm install && npm start &
```
Wait for "running on http://localhost:3000", then proceed.

### Step 2 — Login
```
curl -s -c /tmp/ctte-cookies.txt -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```
Expected: 200 with session cookie.

### Step 3 — Schema check: tracks present and complete
```
curl -s -b /tmp/ctte-cookies.txt http://localhost:3000/api/schema
```
Expected: JSON includes `tracks` array with exactly these 6 values in order:
- "T1 AstraX Device"
- "T2 AstraX Customer Cloud"
- "T3 AstraX Ops Cloud"
- "T4 Manufacturing partners"
- "T5 Business"
- "T6 Sales partner"

Also confirm `fields` shows track with `input: "select"` and `options` array.

### Step 4 — Seed rows use canonical track names
```
curl -s -b /tmp/ctte-cookies.txt http://localhost:3000/api/rows
```
Expected: seed rows have `track: "T1 AstraX Device"` and `track: "T2 AstraX Customer Cloud"`.
(Not 'T1 Device' or 'T2 Cloud'.)

### Step 5 — Create row with T3 AstraX Ops Cloud
```
curl -s -b /tmp/ctte-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"Ops cloud test","owner":"verifier","track":"T3 AstraX Ops Cloud","status":"Not Started"}'
```
Expected: 201.

### Step 6 — Verify filter works on canonical track
GET /api/rows — confirm the new row appears with track = "T3 AstraX Ops Cloud".

### Step 7 — Edit row track
```
curl -s -b /tmp/ctte-cookies.txt \
  -X PUT http://localhost:3000/api/rows/<id> \
  -H 'Content-Type: application/json' \
  -d '{"track":"T5 Business"}'
```
Expected: 200, track updated.

### Step 8 — Persistence check
Stop and restart server, GET /api/rows, confirm row has track = "T5 Business".

### Step 9 — Invariant gate
```
bash scripts/invariant-check.sh
```
Expected: 5/5 PASS.

### Step 10 — Frontend asset static check
Grep app/public/app.js:
- Must NOT contain `distinctTracks()` call in the renderApp filter select
- Must contain `state.tracks` in the filter select
- Must contain `state.tracks = schema.tracks`

### Step 11 — Surface audit
```
git status
```
Confirm: modifications only in app/db.js, app/server.js, app/public/app.js, app/README.md.
No changes to app/public/style.css, app/public/index.html, prototypes/, sdlc/.

### Step 12 — Report
Emit PASS/FAIL per step. State VERIFICATION_COMPLETE if all pass.

## Acceptance Criteria
- [ ] Server boots on :3000; login 200.
- [ ] GET /api/schema returns tracks with all 6 canonical values.
- [ ] track field in schema.fields is input:'select' with options array.
- [ ] Seed rows have canonical track names (T1 AstraX Device, T2 AstraX Customer Cloud).
- [ ] POST with T3 AstraX Ops Cloud → 201.
- [ ] PUT track to T5 Business → 200; persists after restart.
- [ ] app.js uses state.tracks (not distinctTracks()) for filter select.
- [ ] 5/5 invariants PASS.
- [ ] Only allowed surfaces modified.

## Files Likely Affected
- None (read-only verification; DB reset at start)

## Blocked By
- tasks/canonical-track-taxonomy-enforcement-003.md
