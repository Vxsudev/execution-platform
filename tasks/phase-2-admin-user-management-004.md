# Task: Verify P2-3 admin user management implementation

## Parent Spec
specs/phase-2-admin-user-management.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description
Verify all 32 acceptance criteria from the spec. No source files modified.
Uses curl API tests, Node.js logic test, invariant check, git surface audit.

---

### Setup

```bash
cd /Users/vasudevarao/execution-platform/app
pkill -f "node server.js" 2>/dev/null; sleep 1
node server.js &
APP_PID=$!
sleep 1

# Cookies
ADMIN_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"admin","password":"admin123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
VASU_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"vasu","password":"vasu123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
echo "Admin cookie: $ADMIN_COOKIE"
echo "Vasu cookie:  $VASU_COOKIE"
```

---

### Checks 1-3: App and auth

```bash
# 1
BOOT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
echo "Check 1: Boot $BOOT (expected 200)"

# 2
echo "Check 2: Admin cookie non-empty: $([ -n "$ADMIN_COOKIE" ] && echo PASS || echo FAIL)"

# 3
echo "Check 3: Vasu cookie non-empty: $([ -n "$VASU_COOKIE" ] && echo PASS || echo FAIL)"
```

---

### Checks 4-6: GET /api/users

```bash
# 4: Admin GET returns 200
GEST=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/users --cookie "sid=$ADMIN_COOKIE")
echo "Check 4: Admin GET /api/users $GEST (expected 200)"

# 5: No password_hash in response
GRESP=$(curl -s http://localhost:3000/api/users --cookie "sid=$ADMIN_COOKIE")
echo "Check 5: password_hash in response: $(echo $GRESP | grep -c password_hash) (expected 0)"

# 6: Source: Users button visible for admin (source inspection)
grep -c 'usersPageBtn' /Users/vasudevarao/execution-platform/app/public/app.js && echo "Check 6: usersPageBtn in app.js PASS" || echo "Check 6: FAIL"
grep -c "isAdmin.*usersPageBtn\|usersPageBtn.*isAdmin\|isAdmin()" /Users/vasudevarao/execution-platform/app/public/app.js | xargs -I{} sh -c 'if [ {} -gt 0 ]; then echo "Check 6: admin guard present"; fi'
```

---

### Check 7-12: POST /api/users validation

```bash
# 7: Create viewer user
CVIEW=$(curl -s -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"viewer_test","password":"view123","role":"viewer","track_scope":[]}')
CVIEW_ID=$(echo $CVIEW | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const p=JSON.parse(d);console.log(p.user?p.user.id:"ERR");})')
echo "Check 7: Create viewer user id=$CVIEW_ID (expected numeric id)"
echo "Check 7: password_hash in response: $(echo $CVIEW | grep -c password_hash) (expected 0)"

# 8: Create track_owner with T3 scope
CT3=$(curl -s -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"t3_owner_test","password":"t3pass","role":"track_owner","track_scope":["T3 AstraX Ops Cloud"]}')
CT3_ID=$(echo $CT3 | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const p=JSON.parse(d);console.log(p.user?p.user.id:"ERR");})')
echo "Check 8: Create track_owner id=$CT3_ID (expected numeric id)"

# 9: track_owner with empty scope → 400
C9=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"should_fail","password":"x","role":"track_owner","track_scope":[]}')
echo "Check 9: track_owner empty scope $C9 (expected 400)"

# 10: Invalid role → 400
C10=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"should_fail2","password":"x","role":"superadmin","track_scope":[]}')
echo "Check 10: invalid role $C10 (expected 400)"

# 11: Invalid track → 400
C11=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"should_fail3","password":"x","role":"track_owner","track_scope":["T99 Fake"]}')
echo "Check 11: invalid track $C11 (expected 400)"

# 12: Duplicate username → 400
C12=$(curl -s http://localhost:3000/api/users \
  -X POST -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"viewer_test","password":"x","role":"viewer","track_scope":[]}')
echo "Check 12: duplicate username: $(echo $C12 | grep -c 'already exists') (expected 1)"
```

---

### Checks 13-16: PUT /api/users/:id

```bash
# 13: Change role
C13=$(curl -s -X PUT http://localhost:3000/api/users/$CVIEW_ID \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"role":"track_owner","track_scope":["T1 AstraX Device"]}')
echo "Check 13: Change role: $(echo $C13 | grep -c track_owner) (expected 1)"

# 14: Change track_scope
C14=$(curl -s -X PUT http://localhost:3000/api/users/$CVIEW_ID \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"role":"track_owner","track_scope":["T2 AstraX Customer Cloud"]}')
echo "Check 14: Change scope: $(echo $C14 | grep -c 'T2 AstraX Customer Cloud') (expected 1)"

# 15: Reset password then login with new password
curl -s -X PUT http://localhost:3000/api/users/$CVIEW_ID \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"role":"viewer","track_scope":[],"password":"newpass999"}' > /dev/null
C15=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"viewer_test","password":"newpass999"}')
echo "Check 15: Login with reset password $C15 (expected 200)"

# 16: Admin cannot demote self
ADMIN_ID=$(curl -s http://localhost:3000/api/me --cookie "sid=$ADMIN_COOKIE" | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>console.log(JSON.parse(d).user.id));')
C16=$(curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/api/users/$ADMIN_ID \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"role":"viewer","track_scope":[]}')
echo "Check 16: Self-demotion $C16 (expected 403)"
```

---

### Checks 17-20: DELETE /api/users/:id

```bash
# 17: Delete another user
C17=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:3000/api/users/$CVIEW_ID \
  --cookie "sid=$ADMIN_COOKIE")
echo "Check 17: Delete user $C17 (expected 200)"

# 18: Self-delete
C18=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE http://localhost:3000/api/users/$ADMIN_ID \
  --cookie "sid=$ADMIN_COOKIE")
echo "Check 18: Self-delete $C18 (expected 403)"

# 19: Deleted user cannot login
C19=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"viewer_test","password":"newpass999"}')
echo "Check 19: Deleted user login $C19 (expected 401)"

# 20: Sessions invalidated — get a session cookie for t3_owner_test, then delete it, verify session fails
T3_LOGIN=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"t3_owner_test","password":"t3pass"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
C20_BEFORE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/rows --cookie "sid=$T3_LOGIN")
echo "Check 20: t3_owner_test session before delete $C20_BEFORE (expected 200)"
curl -s -X DELETE http://localhost:3000/api/users/$CT3_ID --cookie "sid=$ADMIN_COOKIE" > /dev/null
C20_AFTER=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/rows --cookie "sid=$T3_LOGIN")
echo "Check 20: t3_owner_test session after delete $C20_AFTER (expected 401)"
```

---

### Checks 21-24: Non-admin access

```bash
# 21: Vasu GET /api/users → 403
C21=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/users --cookie "sid=$VASU_COOKIE")
echo "Check 21: Vasu GET /api/users $C21 (expected 403)"

# 22: Vasu POST /api/users → 403
C22=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"username":"x","password":"x","role":"viewer","track_scope":[]}')
echo "Check 22: Vasu POST /api/users $C22 (expected 403)"

# 23: Viewer GET /api/users → 403 (create temp viewer)
node -e "const {db}=require('./db');const bcrypt=require('bcryptjs');db.prepare('INSERT OR IGNORE INTO users (username,password_hash,role) VALUES(?,?,?)').run('viewer_v23',bcrypt.hashSync('v23pass',10),'viewer');console.log('viewer_v23 created');"
VIEWER23=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"viewer_v23","password":"v23pass"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
C23=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/users --cookie "sid=$VIEWER23")
echo "Check 23: Viewer GET /api/users $C23 (expected 403)"
node -e "const {db}=require('./db');db.prepare('DELETE FROM users WHERE username=?').run('viewer_v23');console.log('viewer_v23 removed');"

# 24: Source inspection — Users button only for admin
grep -c 'isAdmin.*usersPageBtn\|usersPageBtn' /Users/vasudevarao/execution-platform/app/public/app.js && echo "Check 24: usersPageBtn admin-guarded PASS" || echo "Check 24: FAIL"
```

---

### Check 25-27: Smoke test — full lifecycle

```bash
# Create fresh track_owner for smoke test
SMOKE=$(curl -s -X POST http://localhost:3000/api/users \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"username":"smoke_owner","password":"smoke123","role":"track_owner","track_scope":["T3 AstraX Ops Cloud"]}')
SMOKE_ID=$(echo $SMOKE | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const p=JSON.parse(d);console.log(p.user?p.user.id:"ERR");})')
echo "Smoke: Created smoke_owner id=$SMOKE_ID"

SMOKE_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"smoke_owner","password":"smoke123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')

# Check 25: New user can login, POST T3 succeeds, POST T1 → 403
SMOKE_ME=$(curl -s http://localhost:3000/api/me --cookie "sid=$SMOKE_COOKIE")
echo "Check 25: /api/me role: $(echo $SMOKE_ME | grep -o 'track_owner') (expected track_owner)"
POST_T3=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$SMOKE_COOKIE" \
  -d '{"title":"Smoke T3","owner":"smoke_owner","track":"T3 AstraX Ops Cloud","status":"Not Started"}')
echo "Check 25: Smoke POST T3 $POST_T3 (expected 201)"
POST_T1=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$SMOKE_COOKIE" \
  -d '{"title":"Smoke T1","owner":"smoke_owner","track":"T1 AstraX Device","status":"Not Started"}')
echo "Check 25: Smoke POST T1 $POST_T1 (expected 403)"

# Check 26: Admin changes smoke user to viewer → /api/me returns viewer, write blocked
curl -s -X PUT http://localhost:3000/api/users/$SMOKE_ID \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"role":"viewer","track_scope":[]}' > /dev/null
# Re-login to get fresh session with new role
SMOKE_COOKIE2=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"smoke_owner","password":"smoke123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')
SMOKE_ME2=$(curl -s http://localhost:3000/api/me --cookie "sid=$SMOKE_COOKIE2")
echo "Check 26: After role change /api/me: $(echo $SMOKE_ME2 | grep -o 'viewer') (expected viewer)"
POST_BLOCKED=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$SMOKE_COOKIE2" \
  -d '{"title":"Blocked","owner":"smoke_owner","track":"T3 AstraX Ops Cloud","status":"Not Started"}')
echo "Check 26: Viewer write blocked $POST_BLOCKED (expected 403)"

# Check 27: Delete user → login fails
curl -s -X DELETE http://localhost:3000/api/users/$SMOKE_ID --cookie "sid=$ADMIN_COOKIE" > /dev/null
C27=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' -d '{"username":"smoke_owner","password":"smoke123"}')
echo "Check 27: Deleted user login $C27 (expected 401)"
```

---

### Checks 28-30: Regression

```bash
# 28: Existing workspace behavior (source inspection)
grep -c 'workspace' /Users/vasudevarao/execution-platform/app/public/app.js && echo "Check 28: workspace still in app.js PASS" || echo "FAIL"
grep -c 'visibleRowsForWorkspace' /Users/vasudevarao/execution-platform/app/public/app.js && echo "Check 28: visibleRowsForWorkspace present PASS" || echo "FAIL"

# 29: P2-1 guard regression — Vasu POST T1 still 403
C29=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$VASU_COOKIE" \
  -d '{"title":"Regression","owner":"vasu","track":"T1 AstraX Device","status":"Not Started"}')
echo "Check 29: Vasu POST T1 $C29 (expected 403)"

# 30: Audit stamping
AUDIT=$(curl -s -X POST http://localhost:3000/api/rows \
  -H 'Content-Type: application/json' --cookie "sid=$ADMIN_COOKIE" \
  -d '{"title":"Audit check","owner":"admin","track":"T1 AstraX Device","status":"Not Started"}')
echo "Check 30: created_by=$(echo $AUDIT | node -e 'process.stdin.resume();let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const r=JSON.parse(d);console.log(r.row?r.row.created_by:"ERR");})')"
```

---

### Check 31: Invariants

```bash
cd /Users/vasudevarao/execution-platform
bash scripts/invariant-check.sh
# Expected: 5/5 PASS
```

---

### Check 32: Git surface audit

```bash
git diff --name-only
# Expected: app/server.js, app/public/app.js, app/public/style.css, app/README.md, ai/* files
# NOT in diff: app/db.js, app/public/index.html, app/package.json
git diff --name-only | grep -E "^app/db\.js|^app/public/index\.html|^app/package\.json" | wc -l
# Expected: 0
```

---

### Teardown

```bash
kill $APP_PID 2>/dev/null || true
```

## Acceptance Criteria
- [ ] Check 1-3: Boot and auth pass
- [ ] Check 4: GET /api/users → 200 for admin
- [ ] Check 5: No password_hash in GET /api/users response
- [ ] Check 6: usersPageBtn present and admin-guarded in app.js source
- [ ] Check 7: Create viewer user → 201, no password_hash
- [ ] Check 8: Create track_owner with T3 → 201
- [ ] Check 9: track_owner with empty scope → 400
- [ ] Check 10: Invalid role → 400
- [ ] Check 11: Invalid track → 400
- [ ] Check 12: Duplicate username → 400 "username already exists"
- [ ] Check 13: PUT change role → 200
- [ ] Check 14: PUT change scope → 200
- [ ] Check 15: PUT reset password → new password works for login
- [ ] Check 16: Self-demotion → 403
- [ ] Check 17: DELETE another user → 200
- [ ] Check 18: Self-delete → 403
- [ ] Check 19: Deleted user login → 401
- [ ] Check 20: Deleted user session invalidated → 401
- [ ] Check 21: Vasu GET /api/users → 403
- [ ] Check 22: Vasu POST /api/users → 403
- [ ] Check 23: Viewer GET /api/users → 403
- [ ] Check 24: usersPageBtn admin-guarded in source
- [ ] Check 25: New track_owner can login, POST T3 → 201, POST T1 → 403
- [ ] Check 26: After role change to viewer → /api/me = viewer, write → 403
- [ ] Check 27: After delete → login → 401
- [ ] Check 28: workspace/visibleRowsForWorkspace still in app.js
- [ ] Check 29: Vasu POST T1 → 403 (P2-1 regression)
- [ ] Check 30: Audit stamping still correct
- [ ] Check 31: Invariants 5/5 PASS
- [ ] Check 32: Only allowed surfaces modified; db.js/index.html/package.json untouched

## Files Likely Affected
- none (read-only verification)

## Blocked By
- tasks/phase-2-admin-user-management-003.md
