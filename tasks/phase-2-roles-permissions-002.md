# Task: Add permission helpers, extend currentUser, and enforce route guards

## Parent Spec
specs/phase-2-roles-permissions.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description
All changes are in `app/server.js` only. This task adds permission helpers, extends
currentUser() to return role and track_scope, updates /api/me to expose them as an array,
and adds 403 guards to POST/PUT/DELETE /api/rows. No frontend changes. No db.js changes.

### 1. parseScope helper

Add immediately after the `const REQUIRED_FIELDS = ...` line (before the SESSION_SECRET block):

```javascript
function parseScope(user) {
  try { return JSON.parse(user.track_scope || '[]'); } catch (_) { return []; }
}
```

### 2. Permission helpers

Add immediately after parseScope:

```javascript
function canCreateRow(user, track) {
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
function canDeleteRow(user)   { return user.role === 'admin'; }
function canImport(user)      { return user.role === 'admin'; }
function canManageUsers(user) { return user.role === 'admin'; }
```

canEditRow strict reassignment rule (operator-locked):
- If nextTrack is defined and differs from existingRow.track, nextTrack must also be in scope.
- If nextTrack is undefined (payload has no track change), only existingRow.track is checked.

### 3. Extend currentUser() SELECT

In the currentUser() function, update the SELECT from:
```javascript
'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
```
To:
```javascript
'SELECT u.id, u.username, u.role, u.track_scope FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
```

After this, req.user will contain { id, username, role, track_scope } where track_scope is the
raw JSON string from the DB. parseScope() handles malformed values defensively.

### 4. Update GET /api/me response

In the GET /api/me handler, change:
```javascript
res.json({ user: u });
```
To:
```javascript
res.json({ user: { ...u, track_scope: parseScope(u) } });
```

This exposes track_scope as a parsed JavaScript array to the frontend (not the raw JSON string).
The role field comes through naturally via ...u spread.

### 5. Route guard: POST /api/rows

After the validate() call and its error check, add:
```javascript
if (!canCreateRow(req.user, data.track)) return res.status(403).json({ error: 'Forbidden' });
```

The guard goes AFTER validate() so track is already confirmed valid (canonical TRACKS member).
The guard goes BEFORE the INSERT.

### 6. Route guard: PUT /api/rows/:id — strict track reassignment

After fetching `existing` and after `const data = sanitize(req.body || {})`, BEFORE the
validate() call, add:
```javascript
const nextTrack = (data.track !== undefined && data.track !== existing.track) ? data.track : undefined;
if (!canEditRow(req.user, existing, nextTrack)) return res.status(403).json({ error: 'Forbidden' });
```

nextTrack is defined only when the payload explicitly changes the track to a different value.
This implements the strict reassignment rule without breaking PUT requests that don't change track.

### 7. Route guard: DELETE /api/rows/:id

Before the DELETE query, add:
```javascript
if (!canDeleteRow(req.user)) return res.status(403).json({ error: 'Forbidden' });
```

### Preserve all existing server.js behavior

Do NOT change:
- SESSION_SECRET block, signToken, verifyToken, parseCookies
- requireAuth middleware
- sanitize(), validate()
- GET /api/rows (requireAuth only — all authenticated users view all rows)
- GET /api/rows/:id (requireAuth only)
- GET /api/schema
- Audit stamping: data.created_by = req.user.username, updated_by = req.user.username
- Error format: { "error": "..." } HTTP 400
- Login/logout handlers
- Port listen logic

## Acceptance Criteria
- [ ] parseScope(user) function present in server.js, handles JSON.parse failure by returning []
- [ ] canCreateRow(user, track): admin→true, track_owner with track in scope→true, viewer→false, track_owner with track outside scope→false
- [ ] canEditRow(user, existingRow, nextTrack): admin→true; track_owner checks existingRow.track ∈ scope; if nextTrack defined and differs from existing.track, nextTrack must also be ∈ scope; viewer→false
- [ ] canDeleteRow(user): admin→true, any other role→false
- [ ] canImport(user) and canManageUsers(user): admin→true, others→false
- [ ] currentUser() SELECT includes u.role and u.track_scope
- [ ] GET /api/me returns { user: { id, username, role, track_scope: [...] } } where track_scope is an array
- [ ] POST /api/rows has canCreateRow guard returning 403 { error: 'Forbidden' } for unauthorized role/track
- [ ] PUT /api/rows/:id has canEditRow guard with nextTrack derived from payload; strict track reassignment enforced; returns 403 on failure
- [ ] DELETE /api/rows/:id has canDeleteRow guard returning 403 for non-admin
- [ ] GET /api/rows and GET /api/rows/:id unchanged (requireAuth only, no new guards)
- [ ] Audit stamping still works (req.user.username available after currentUser extension)
- [ ] Login admin/admin123 → 200; GET /api/me → role:'admin', track_scope:[]
- [ ] Login vasu/vasu123 → 200; GET /api/me → role:'track_owner', track_scope:['T3 AstraX Ops Cloud']
- [ ] App boots without error after change

## Files Likely Affected
- app/server.js

## Blocked By
- tasks/phase-2-roles-permissions-001.md
