# Spec: Phase 2 — Roles & Permissions Backend

## Status
approved

## Phase
phase-build

## Feature Slug
phase-2-roles-permissions

## Goal
Add backend-enforced role-based and track-scoped row permissions to the execution table
without changing the frontend workspaces, user management UI, XLSX import, dashboard, or
deployment model. After this feature, POST/PUT/DELETE routes enforce role authority
server-side. The frontend remains unmodified — backend is the permission authority.

## Recon
ai/recon/phase-2-team-operating-model-full-spec-recon.md

## Operator Decisions Applied
- Track reassignment rule: STRICT. PUT /api/rows/:id — if payload changes track, the new
  track must also be in the user's track_scope. Otherwise 403 Forbidden.

## Allowed Mutation Surfaces
- app/db.js
- app/server.js
- app/README.md
- ai/state_registry.json
- ai/engineering-journal.md
- specs/phase-2-roles-permissions.md
- tasks/phase-2-roles-permissions-001.md
- tasks/phase-2-roles-permissions-002.md
- tasks/phase-2-roles-permissions-003.md

Do NOT modify: app/public/app.js, app/public/style.css, app/public/index.html,
prototypes/, sdlc/, package.json.

---

## Data Model Changes

Additive, idempotent migrations to the users table in app/db.js.

### New Columns on users table

| Column | Type | Default | Meaning |
|--------|------|---------|---------|
| role | TEXT | 'viewer' | One of: admin, track_owner, viewer |
| track_scope | TEXT | NULL | JSON array of canonical track strings, e.g. '["T3 AstraX Ops Cloud"]'. NULL treated as empty array. |

### Migration Pattern

Follow the established try/catch ALTER TABLE pattern used for audit trail columns.
Add immediately after the existing `try { db.exec("ALTER TABLE entries ADD COLUMN updated_by...") }` block:

```javascript
try { db.exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer';"); } catch (_) {}
try { db.exec("ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL;"); } catch (_) {}
```

### Backfill

After the migration lines, backfill existing demo users. Gate on `NODE_ENV !== 'production'`
(same guard as demo seed) to avoid touching production user data:

```javascript
if (process.env.NODE_ENV !== 'production') {
  db.exec("UPDATE users SET role = 'admin' WHERE username = 'admin' AND (role IS NULL OR role = 'viewer');");
  db.exec("UPDATE users SET role = 'track_owner', track_scope = '[\"T3 AstraX Ops Cloud\"]' WHERE username = 'vasu' AND (role IS NULL OR role = 'viewer');");
}
```

Conditions `(role IS NULL OR role = 'viewer')` make the backfill idempotent — re-running
does not overwrite an admin-assigned role.

### No new tables. No destructive migrations.

---

## API Surface

All changes are in app/server.js only.

### 1. parseScope helper

Add immediately after `const REQUIRED_FIELDS` declarations:

```javascript
function parseScope(user) {
  try { return JSON.parse(user.track_scope || '[]'); } catch (_) { return []; }
}
```

### 2. Permission helpers

Add immediately after parseScope:

```javascript
function canViewRows(user)                      { return !!user; }
function canCreateRow(user, track)              {
  if (user.role === 'admin') return true;
  if (user.role === 'track_owner') return parseScope(user).includes(track);
  return false;
}
function canEditRow(user, existingRow, nextTrack) {
  if (user.role === 'admin') return true;
  if (user.role !== 'track_owner') return false;
  const scope = parseScope(user);
  if (!scope.includes(existingRow.track)) return false;
  if (nextTrack !== undefined && nextTrack !== existingRow.track && !scope.includes(nextTrack)) return false;
  return true;
}
function canDeleteRow(user)                     { return user.role === 'admin'; }
function canImport(user)                        { return user.role === 'admin'; }
function canManageUsers(user)                   { return user.role === 'admin'; }
```

### 3. currentUser() SELECT extension

Update the SELECT in currentUser() from:
```javascript
'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
```
To:
```javascript
'SELECT u.id, u.username, u.role, u.track_scope FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
```

After this change, `req.user` will contain: `{ id, username, role, track_scope }` where
`track_scope` is the raw JSON string from DB (permission helpers call parseScope on it).

### 4. /api/me — return role and track_scope as array

Update GET /api/me response from:
```javascript
res.json({ user: u });
```
To:
```javascript
res.json({ user: { ...u, track_scope: parseScope(u) } });
```

This exposes `track_scope` as a parsed array to the frontend, not the raw JSON string.
The `role` field comes through naturally via `...u`.

### 5. Route guards

#### POST /api/rows — add canCreateRow check

After `const err = validate(data, false, null); if (err) return res.status(400).json(...)`,
add:
```javascript
if (!canCreateRow(req.user, data.track)) return res.status(403).json({ error: 'Forbidden' });
```

#### PUT /api/rows/:id — add canEditRow check with strict track reassignment

After fetching `existing` and after `const data = sanitize(req.body || {})`,
before the validate() call, add:
```javascript
const nextTrack = (data.track !== undefined && data.track !== existing.track) ? data.track : undefined;
if (!canEditRow(req.user, existing, nextTrack)) return res.status(403).json({ error: 'Forbidden' });
```

Note: `nextTrack` is only set when the payload includes a different track from the existing
row's track — this implements the strict track reassignment rule (operator-locked decision).

#### DELETE /api/rows/:id — add canDeleteRow check

Before the DELETE query, add:
```javascript
if (!canDeleteRow(req.user)) return res.status(403).json({ error: 'Forbidden' });
```

### 6. Preserve all existing behavior

- requireAuth middleware: unchanged
- validate(): unchanged
- sanitize(): unchanged
- GET /api/rows: unchanged (requireAuth only — all authenticated users can view)
- GET /api/rows/:id: unchanged
- GET /api/schema: unchanged
- Audit stamping (req.user.username): unchanged
- Error format { "error": "..." }: unchanged
- signToken/verifyToken/parseCookies: unchanged
- Login/logout: unchanged

---

## Frontend Surface
none

---

## Operational Workflow

1. App boots. db.js runs ALTER TABLE users ADD COLUMN role and track_scope (idempotent).
2. Backfill runs: admin gets role='admin'; vasu gets role='track_owner' with T3 scope (non-prod).
3. User logs in → session cookie issued (unchanged).
4. GET /api/me → returns { user: { id, username, role, track_scope: [...] } }.
5. Admin creates row in any track → POST /api/rows → canCreateRow passes → 201.
6. track_owner (vasu) creates row in T3 → canCreateRow checks scope → 201.
7. track_owner (vasu) creates row in T1 → canCreateRow fails → 403 Forbidden.
8. track_owner edits existing T3 row → canEditRow checks existing.track ∈ scope → 200.
9. track_owner edits existing T1 row → canEditRow fails → 403 Forbidden.
10. track_owner tries to reassign T3 row to T1 → canEditRow(nextTrack=T1) fails → 403 Forbidden.
11. track_owner deletes row → canDeleteRow returns false → 403 Forbidden.
12. Admin deletes any row → canDeleteRow returns true → 200.
13. viewer GETs all rows → requireAuth passes → 200 (view is unrestricted).
14. viewer POSTs → canCreateRow → viewer role → false → 403 Forbidden.

---

## Dependencies
- Phase 1 auth hardening (auth-hardening-v1) — RELEASE_APPROVED — provides HMAC session, req.user base
- Phase 1 audit trail (data-model-audit-trail) — RELEASE_APPROVED — req.user.username stamping preserved
- Phase 1 track enum validation (track-enum-server-validation) — RELEASE_APPROVED — TRACKS enum used in canCreateRow

---

## Verification Gate

### Boot and auth
1. App boots locally after `node server.js` (or npm start from app/).
2. Login admin/admin123 → 200, sid cookie set.
3. GET /api/me for admin → { user: { id, username, role: 'admin', track_scope: [] } }.
4. Login vasu/vasu123 → 200.
5. GET /api/me for vasu → { user: { id, username, role: 'track_owner', track_scope: ['T3 AstraX Ops Cloud'] } }.

### Admin row operations
6. Admin POST row in T1 AstraX Device → 201.
7. Admin POST row in T5 Business → 201.
8. Admin PUT any row → 200.
9. Admin DELETE any row → 200.

### track_owner row operations
10. Vasu GET /api/rows → 200 (all rows visible).
11. Vasu POST row in T3 AstraX Ops Cloud → 201.
12. Vasu POST row in T1 AstraX Device → 403 { error: 'Forbidden' }.
13. Vasu PUT existing T3 row (no track change) → 200.
14. Vasu PUT existing T1 row → 403 Forbidden.
15. Vasu PUT T3 row changing track to T1 → 403 Forbidden (strict reassignment).
16. Vasu PUT T3 row changing track to T3 (no-op) → 200.
17. Vasu DELETE any row → 403 Forbidden.

### viewer role
18. viewer user (created temporarily for verification) can GET /api/rows → 200.
19. viewer POST → 403 Forbidden.
20. viewer PUT → 403 Forbidden.
21. viewer DELETE → 403 Forbidden.

### Phase 1 regression
22. Required-field validation still works: POST without owner → 400 'owner is required'.
23. Track enum validation still works: POST with invalid track → 400 'invalid track'.
24. Audit stamping still works: POST → created_by = authenticated username.
25. Frontend still loads for admin at http://localhost:3000.
26. Frontend still loads for vasu (existing CRUD visible even though buttons not yet permission-aware).
27. Invariants: 5/5 PASS.
28. Git status shows only allowed surfaces modified.

---

## Out of Scope

This spec does not cover:

- Frontend workspace changes (My Track Workspace tab, conditional button rendering) — P2-2
- Admin user management UI or routes — P2-3
- XLSX import — P2-4
- Dashboard — P2-5
- Deployment — excluded from Phase 2
- Public signup — excluded from Phase 2
- Email invite flow — excluded from Phase 2
- Password reset — excluded from Phase 2
- SSO / external auth providers — excluded from Phase 2
- Approval workflow — excluded from Phase 2
- Escalation workflow — excluded from Phase 2
- Agents — excluded from Phase 2
- IoT / digital twin — excluded from Phase 2
- Advanced analytics — excluded from Phase 2
- Continuous Excel sync — excluded from Phase 2
- Multi-tenant SaaS architecture — excluded from Phase 2
