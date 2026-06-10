# Task: Verify P2-1 database columns exist before backend execution

## Parent Spec
specs/phase-2-admin-user-management.md

## Phase
phase-build

## Status
done

## Layer
database

## Description
No schema changes needed — role and track_scope columns were added in P2-1.
This task verifies the database preconditions before the backend worker runs.

### Step 1 — Verify columns exist

```bash
cd /Users/vasudevarao/execution-platform/app
node -e "
const {db} = require('./db');
const cols = db.prepare('PRAGMA table_info(users)').all().map(c => c.name);
console.log('users columns:', cols.join(', '));
const ok = cols.includes('role') && cols.includes('track_scope');
if (!ok) { console.error('FAIL: role or track_scope column missing'); process.exit(1); }
console.log('PASS: role and track_scope columns present');
"
```

### Step 2 — Verify admin/vasu roles

```bash
node -e "
const {db} = require('./db');
const admin = db.prepare(\"SELECT username,role FROM users WHERE username='admin'\").get();
const vasu  = db.prepare(\"SELECT username,role FROM users WHERE username='vasu'\").get();
if (!admin || admin.role !== 'admin')       { console.error('FAIL: admin.role wrong'); process.exit(1); }
if (!vasu  || vasu.role  !== 'track_owner') { console.error('FAIL: vasu.role wrong');  process.exit(1); }
console.log('PASS: admin.role=admin, vasu.role=track_owner');
"
```

## Acceptance Criteria
- [ ] users table has role and track_scope columns
- [ ] admin user has role='admin'
- [ ] vasu user has role='track_owner'
- [ ] No source files modified by this task

## Files Likely Affected
- none (read-only verification)

## Blocked By
- none
