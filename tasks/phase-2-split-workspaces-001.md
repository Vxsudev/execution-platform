# Task: Verify P2-1 dependency is satisfied before frontend execution

## Parent Spec
specs/phase-2-split-workspaces.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
This task has NO app code changes. It is a pre-flight gate that verifies the P2-1 backend
dependency is satisfied before the frontend worker (task-002) executes.

### Step 1 — Read state registry

Read `ai/state_registry.json`. Confirm the entry for `phase-2-roles-permissions` has
`"state": "RELEASE_APPROVED"`. If it does, the P2-1 dependency is satisfied.

### Step 2 — Verify /api/me returns role and track_scope

Start the app and verify:

```bash
cd /Users/vasudevarao/execution-platform/app
node server.js &
APP_PID=$!
sleep 1

ADMIN_COOKIE=$(curl -si -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"admin123"}' \
  | grep -i 'set-cookie' | sed 's/.*sid=\([^;]*\).*/\1/')

ME=$(curl -s http://localhost:3000/api/me --cookie "sid=$ADMIN_COOKIE")
echo "Admin /api/me: $ME"
# Must contain "role":"admin" and "track_scope":[]

kill $APP_PID 2>/dev/null || true
```

Expected: response contains `"role":"admin"` and `"track_scope":[]`.

### Step 3 — Report

If both checks pass, this task is complete. No source files are modified by this task.
Report PASS and the /api/me response.

## Acceptance Criteria
- [ ] ai/state_registry.json shows phase-2-roles-permissions: RELEASE_APPROVED
- [ ] GET /api/me for admin returns { role: 'admin', track_scope: [] }
- [ ] No app source files modified by this task

## Files Likely Affected
- none (read-only verification)

## Blocked By
- none
