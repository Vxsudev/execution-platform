# Task: Verify audit columns removed from default table; Details action shows audit metadata

## Parent Spec
specs/ux-table-hardening-v1.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Read-only verification. No app mutations. Boot server and verify all UX changes.

### Pre-flight
```bash
lsof -ti:3000 | xargs kill -9 2>/dev/null || true
```
Do NOT reset DB (data from previous capability should persist).

### Step 1 — Boot
```bash
cd /Users/vasudevarao/execution-platform/app && node server.js &
```
Wait for "running on http://localhost:3000".

### Step 2 — Login
```bash
curl -s -c /tmp/tuxh-cookies.txt -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}'
```
Expected: 200.

### Step 3 — Code audit: verify LIST_COLS
```bash
grep -A5 "const LIST_COLS" /Users/vasudevarao/execution-platform/app/public/app.js
```
Expected: 14 columns (owner through type). No created_by/updated_by/created_at/updated_at.

### Step 4 — Code audit: verify AUDIT_LABELS still present
```bash
grep "AUDIT_LABELS" /Users/vasudevarao/execution-platform/app/public/app.js
```
Expected: AUDIT_LABELS constant present. colLabel checks it.

### Step 5 — Code audit: verify Details button in renderTable
```bash
grep "data-info" /Users/vasudevarao/execution-platform/app/public/app.js
```
Expected: `data-info="${r.id}"` in renderTable; `[data-info]` binding in bindRowActions.

### Step 6 — Code audit: verify openDetails function
```bash
grep -A5 "function openDetails" /Users/vasudevarao/execution-platform/app/public/app.js
```
Expected: `openDetails` function exists with `modal-sm` class and `detail-list` class.

### Step 7 — Code audit: verify style.css additions
```bash
grep "modal-sm\|detail-list" /Users/vasudevarao/execution-platform/app/public/style.css
```
Expected: .modal-sm and .detail-list rules present.

### Step 8 — API regression: required-field validation
```bash
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tuxh-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","track":"T1 AstraX Device","status":"Not Started"}'
```
Expected: 400. Body `{"error":"owner is required"}`.

### Step 9 — API regression: track enum
```bash
curl -s -o /tmp/r.json -w "%{http_code}" -b /tmp/tuxh-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"test","owner":"v","track":"Fake","status":"Not Started"}'
```
Expected: 400. Body `{"error":"invalid track"}`.

### Step 10 — Audit stamping regression
```bash
curl -s -o /tmp/tuxh-row.json -w "%{http_code}" -b /tmp/tuxh-cookies.txt \
  -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' \
  -d '{"title":"UX hardening test","owner":"v","track":"T3 AstraX Ops Cloud","status":"Not Started"}'
```
Expected: 201. Response includes `created_by = "admin"`.

### Step 11 — README audit
```bash
grep -A6 "## Audit Metadata" /Users/vasudevarao/execution-platform/app/README.md
```
Expected: mentions "Details" button.

### Step 12 — Invariant gate
```bash
bash /Users/vasudevarao/execution-platform/scripts/invariant-check.sh
```
Expected: 5/5 PASS.

### Step 13 — Surface audit
```bash
git -C /Users/vasudevarao/execution-platform status
```
Confirm: only app/public/app.js, app/public/style.css, app/README.md modified in app/.
No changes to app/db.js, app/server.js, app/public/index.html, prototypes/, sdlc/.

### Step 14 — Report
PASS/FAIL per step. VERIFICATION_COMPLETE if all pass.

## Acceptance Criteria
- [ ] Server boots.
- [ ] LIST_COLS has 14 columns (no audit columns).
- [ ] AUDIT_LABELS still present in app.js.
- [ ] data-info attribute in renderTable and binding in bindRowActions.
- [ ] openDetails function present with correct structure.
- [ ] .modal-sm and .detail-list in style.css.
- [ ] Required-field regression: 400 "owner is required".
- [ ] Track enum regression: 400 "invalid track".
- [ ] Audit stamping still works: POST returns created_by = "admin".
- [ ] README mentions Details button in Audit Metadata section.
- [ ] 5/5 invariants PASS.
- [ ] Only allowed surfaces modified.

## Files Likely Affected
- None (read-only verification)

## Blocked By
- tasks/ux-table-hardening-v1-001.md
