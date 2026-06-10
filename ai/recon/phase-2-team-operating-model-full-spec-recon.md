# Recon: Phase 2 — Team Operating Model
## Full Spec Recon

**Date:** 2026-06-10  
**Mode:** RECON ONLY — no app code mutated  
**OS Status:** ADAPTER VALID (12/12) · INVARIANTS 5/5 PASS  
**Git Status:** branch main, up to date with origin/main, working tree CLEAN

---

## 1. Executive Finding

Phase 1 is fully complete and verified. The codebase is a clean, hardened execution table: Express + node:sqlite, HMAC-signed sessions, server-stamped audit trail, canonical track taxonomy, required-field validation, row details modal. All 9 Phase 1 capabilities are RELEASE_APPROVED in the state registry.

Phase 2 is feasible on this foundation with **zero breaking changes** to the Phase 1 schema. The users table needs two additive columns (`role`, `track_scope`). All other Phase 2 features (workspaces, user management, XLSX import, dashboard) build on top without modifying existing data structures.

**P2-3 (Admin User Management) must remain after P2-1** — it depends on the role/track_scope schema. It cannot be merged into P2-1 without producing an oversized, hard-to-verify build slice.

**First build slice is P2-1: Roles & Permissions backend.** No frontend changes. No package additions. Pure backend schema + permission helpers + route enforcement.

---

## 2. Files Inspected

| File | Status |
|------|--------|
| app/db.js | READ |
| app/server.js | READ |
| app/package.json | READ |
| app/README.md | READ |
| app/public/app.js | READ |
| app/public/index.html | READ |
| app/public/style.css | READ |
| roadmap/v1-build-roadmap-dag.md | READ |
| specs/data-model-audit-trail.md | READ |
| specs/auth-hardening-v1.md | READ |
| specs/ux-table-hardening-v1.md | READ |
| ai/state_registry.json | READ |
| ai/engineering-journal.md | READ |
| source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx | BINARY — confirmed present, column contract sourced from engineering journal |
| ai/recon/ directory | SCANNED (11 prior recon files) |

---

## 3. Phase 1 Baseline Verification

| Capability | State Registry | Evidence |
|------------|---------------|----------|
| Login | RELEASE_APPROVED | POST /api/login, bcrypt.compareSync, session cookie |
| Session-backed auth | RELEASE_APPROVED | HMAC-signed sid cookie, sessions table, currentUser() with verifyToken() |
| Excel-like execution table | RELEASE_APPROVED | 14-column dense grid, Sheet-2 column order, sticky header |
| Create / edit / delete records | RELEASE_APPROVED | POST/PUT/DELETE /api/rows, all requireAuth |
| Database persistence | RELEASE_APPROVED | SQLite data.db, WAL mode, survives restart |
| Required-field validation | RELEASE_APPROVED | validate() enforces owner/track/title/status on POST and partial on PUT |
| Canonical astraX track taxonomy | RELEASE_APPROVED | TRACKS array in db.js, enforced by validate(), exposed via /api/schema |
| Backend track enum validation | RELEASE_APPROVED | `if (!TRACKS.includes(data.track)) return 'invalid track'` |
| Audit trail metadata | RELEASE_APPROVED | created_by/updated_by stamped server-side, not passable from client |
| Row details view | RELEASE_APPROVED | openDetails() modal, Details button per row |
| Auth/session hardening | RELEASE_APPROVED | SESSION_SECRET, HMAC signToken/verifyToken, secure cookie in prod, demo seed gated on non-prod |

**All 11 Phase 1 baseline items CONFIRMED.**

---

## 4. Current User/Auth Model

### A1. Users table schema (db.js:46–51)
```sql
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### A2. Fields on a user today
`id`, `username`, `password_hash`, `created_at`. No `role`. No `track_scope`.

### A3. How users are seeded
`db.js:83–87`: if `NODE_ENV !== 'production'` and users table is empty → insert admin/admin123 and vasu/vasu123 via bcrypt.hashSync(). On production with empty users table → warning emitted, no users inserted.

### A4. Demo users gated in production
`if (process.env.NODE_ENV !== 'production' && ...)` — demo seed block is completely skipped in production. Production starts with empty users table (warning logged).

### A5. How currentUser() works (server.js:54–61)
```javascript
function currentUser(req) {
  const signed = parseCookies(req)[SID];   // read sid cookie
  const token = verifyToken(signed);        // HMAC verify, returns raw token or null
  if (!token) return null;
  return db.prepare(
    'SELECT u.id, u.username FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token = ?'
  ).get(token) || null;
}
```

### A6. What req.user contains
`{ id: INTEGER, username: TEXT }` only. Set by `requireAuth` middleware after `currentUser()` succeeds.

### A7. Does req.user include role or track_scope?
**NO.** Neither field exists on the users table or is returned by the SELECT query.

### A8. Where password hashing is done
- Seeding: `bcrypt.hashSync('admin123', 10)` in `db.js:85–86`
- Login verification: `bcrypt.compareSync(String(password), user.password_hash)` in `server.js:74`
- No password creation/reset API exists (no user management routes)

### A9. Where sessions are stored
SQLite `sessions` table: `token TEXT PRIMARY KEY, user_id INTEGER NOT NULL, created_at TEXT`. Token is `crypto.randomBytes(32).toString('hex')`, HMAC-signed before placing in cookie. No session expiry logic (sessions persist until explicit logout or DB wipe).

### A10. What /api/me returns (server.js:95–99)
```json
{ "user": { "id": 1, "username": "admin" } }
```
Returns only id and username. No role, no track_scope.

---

## 5. Roles & Permissions Feasibility

### B1. Can role be added to users table safely?
**YES.** `ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer'` is additive. SQLite allows this with no data loss. Default `'viewer'` is safe — existing users get least-privilege until backfilled. Migration pattern (try/catch ALTER TABLE) is proven from audit trail capability.

### B2. Can track_scope be added to users table safely?
**YES.** `ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL` is additive. NULL = no assigned tracks (correct default for admin role which has implicit all-access).

### B3. Recommended track_scope storage format for SQLite
| Format | Pros | Cons |
|--------|------|------|
| JSON string (`'["T3 AstraX Ops Cloud"]'`) | Flexible, parseable with JSON.parse(), queryable with json_each() in SQLite 3.38+ | Defensive parsing needed, slightly harder to query ad-hoc |
| Delimiter string (`'T3,T5'`) | Simple to split | Fragile with track names containing commas, harder to evolve |
| Join table (`user_track_scopes`) | Relational integrity, proper foreign keys | Schema complexity, additional table, JOIN on every auth check |

### B4. Recommended format: JSON string
**JSON string is best for Phase 2.** Reasons: Node 22.5+ ships SQLite 3.38+ (json_each available), `JSON.parse()`/`JSON.stringify()` trivial in JS, no extra tables, backfill and inspection are easy, team scale is 3–10 users (never a performance issue). Wrap all reads in a safe parser: `function parseScope(s) { try { return JSON.parse(s || '[]'); } catch(_) { return []; } }`.

### B5. Can admin user be backfilled as admin?
**YES.** After ALTER TABLE: `UPDATE users SET role = 'admin' WHERE username = 'admin'`.

### B6. Should vasu be backfilled as track_owner for T3 AstraX Ops Cloud?
**YES per spec intent.** `UPDATE users SET role = 'track_owner', track_scope = '["T3 AstraX Ops Cloud"]' WHERE username = 'vasu'`. This backfill should only run in non-production (same guard as demo seed).

### B7. Required backend helper functions

```javascript
function parseScope(user) { try { return JSON.parse(user.track_scope || '[]'); } catch(_) { return []; } }

function canViewRows(user)          { return !!user; } // all authenticated users
function canCreateRow(user, track)  { return user.role === 'admin' || (user.role === 'track_owner' && parseScope(user).includes(track)); }
function canEditRow(user, row)      { return user.role === 'admin' || (user.role === 'track_owner' && parseScope(user).includes(row.track)); }
function canDeleteRow(user)         { return user.role === 'admin'; }
function canImport(user)            { return user.role === 'admin'; }
function canManageUsers(user)       { return user.role === 'admin'; }
```

Note: `currentUser()` must be updated to `SELECT u.id, u.username, u.role, u.track_scope FROM ...` for helpers to work.

---

## 6. Current Backend Authorization Points

### C1. GET /api/rows — server.js:137
`app.get('/api/rows', requireAuth, ...)` — auth only. **Phase 2: keep requireAuth only.** All roles can view all rows per spec.

### C2. POST /api/rows — server.js:145
`app.post('/api/rows', requireAuth, ...)` — auth only.  
**Phase 2: add `if (!canCreateRow(req.user, data.track)) return res.status(403).json({ error: 'Forbidden' })`** after validate() passes.

### C3. PUT /api/rows/:id — server.js:157
`app.put('/api/rows/:id', requireAuth, ...)` — auth only.  
**Phase 2: add `if (!canEditRow(req.user, existing)) return res.status(403).json({ error: 'Forbidden' })`** after fetching existing row, before sanitize/validate.

### C4. DELETE /api/rows/:id — server.js:170
`app.delete('/api/rows/:id', requireAuth, ...)` — auth only.  
**Phase 2: add `if (!canDeleteRow(req.user)) return res.status(403).json({ error: 'Forbidden' })`** before DELETE query.

### C5. Routes requiring auth but no role/track permission today
All of them: GET /api/rows, GET /api/rows/:id, POST /api/rows, PUT /api/rows/:id, DELETE /api/rows/:id, GET /api/schema.

### C6. Exact permission checks per route

| Route | Current | Phase 2 Addition |
|-------|---------|-----------------|
| GET /api/rows | requireAuth | no change |
| GET /api/rows/:id | requireAuth | no change |
| POST /api/rows | requireAuth | `canCreateRow(user, data.track)` → 403 |
| PUT /api/rows/:id | requireAuth | `canEditRow(user, existing)` → 403 |
| DELETE /api/rows/:id | requireAuth | `canDeleteRow(user)` → 403 |
| GET /api/schema | requireAuth | no change |

### C7. How POST should validate track authority
After `validate(data, false, null)` passes, before INSERT: `if (!canCreateRow(req.user, data.track)) return res.status(403).json({ error: 'Forbidden' })`. The track is already validated as a canonical TRACKS member by `validate()` at this point.

### C8. How PUT should validate row.track authority
Fetch `existing` row first (already done at server.js:158). Check `canEditRow(req.user, existing)` using the CURRENT (pre-edit) track value. Authorization is based on the row's current track assignment, not the incoming payload.

### C9. If PUT changes track from assigned to unassigned — UNRESOLVED
**OPERATOR DECISION REQUIRED.** Two options:
- **Permissive**: Check only the original row's track. Track_owner can reassign a row to any track if they own the current one.
- **Strict**: Check both old track AND new track are in user's scope. Prevents "orphaning" a row to an unassigned track.
Recommendation: Permissive for Phase 2. The edge case is unlikely given team-internal use, and the strict model requires extra logic. Flag this in the P2-1 spec for operator decision before coding.

### C10. Should track_owner delete rows?
**CONFIRMED NO.** Spec states: `track_owner: cannot delete rows by default`. Delete is admin-only. `canDeleteRow` returns false for any role != admin.

---

## 7. Current Frontend Authorization Points

### D1. Where row action buttons are rendered
`app.js:168–171` — `renderTable()` function, inside the row map template literal. Current output per row:
```html
<button data-info="${r.id}">Details</button>
<button data-edit="${r.id}">Edit</button>
<button class="icon-btn danger" data-del="${r.id}">Delete</button>
```

### D2. Where Create/New row button is rendered
`app.js:109` — inside `renderApp()` topbar template: `<button class="btn primary" id="newBtn">+ New row</button>`

### D3. Where edit modal opens
- Create: `app.js:120` — `document.getElementById('newBtn').onclick = () => openForm(null)`
- Edit: `app.js:181` — `bindRowActions()` data-edit handler calls `openForm(row)`

### D4. Where filters are rendered
`app.js:111–115` — inside `renderApp()`: three `<select>` elements (fStatus, fTrack, fType)

### D5. Where unauthorized controls should be hidden or disabled
- New row button: `renderApp()` at app.js:109 — render conditionally based on `state.user.role`
- Edit button: `renderTable()` at app.js:168 — render conditionally per row based on `canEditRow(state.user, row)` equivalent in frontend
- Delete button: `renderTable()` at app.js:170 — render conditionally based on `state.user.role === 'admin'`

Frontend checks are UX only — backend enforces the real permission. The frontend check prevents UI noise.

### D6. Where My Track Workspace should be introduced
Currently no workspace concept. Best insertion point: `renderApp()` topbar at app.js:101–118. Add a tab/toggle between "All Tracks" and "My Tracks". State: add `state.workspace = 'all' | 'mytrack'`.

### D7. Is current single-page state enough for split workspaces?
**YES.** The `state` object (`user`, `fields`, `rows`, `filters`, `search`) can absorb `state.workspace`. `filteredRows()` at app.js:132–145 would add workspace filtering: if workspace = 'mytrack', only show rows where `state.user.track_scope.includes(row.track)`. No new HTML pages, no server routing changes needed.

### D8. Recommended view model
**Tab buttons in the topbar** (not hash routes, not separate pages). Reasons: single HTML file, zero URL complexity, consistent with current SPA pattern, simple `state.workspace` toggle, re-renders via `renderApp()`. Add "All Tracks" and "My Tracks" buttons to topbar; My Tracks tab is hidden for admin and viewer (for viewer it would show nothing useful; for admin all tracks are accessible regardless). Dashboard becomes a third tab in P2-5.

### D9. User permission payload for frontend
Extend `/api/me` response from:
```json
{ "user": { "id": 1, "username": "admin" } }
```
To:
```json
{ "user": { "id": 1, "username": "admin", "role": "admin", "track_scope": [] } }
```
`track_scope` is `[]` for admin (all-access implied) and `["T3 AstraX Ops Cloud"]` for track_owner. Frontend derives permissions from `role` + `track_scope`. No separate `/api/permissions` endpoint needed in Phase 2.

---

## 8. Admin User Management Feasibility

### E1. Any user management routes today?
**NONE.** No GET /api/users, no POST /api/users, no PUT /api/users/:id, no DELETE /api/users/:id.

### E2. Required routes for P2-3
```
GET    /api/users           — list all users (admin only)
POST   /api/users           — create user (admin only) — sets username, password, role, track_scope
PUT    /api/users/:id       — update user (admin only) — can change role, track_scope, optionally password
DELETE /api/users/:id       — delete user (admin only) — prevent self-delete
```

### E3. Fields admin should set
| Field | Required on create | Required on update |
|-------|-------------------|-------------------|
| username | YES | NO (immutable after create recommended) |
| password | YES | NO (optional reset) |
| role | YES | YES |
| track_scope | Conditional (track_owner) | Conditional |

### E4. Should password be set directly by admin in Phase 2?
**YES.** No email invite, no password reset, no external auth in scope. Admin sets initial password directly. bcrypt.hashSync on the server. Password communicated out-of-band. This is explicitly accepted by the Phase 2 scope.

### E5. Is password reset out of scope?
**CONFIRMED OUT OF SCOPE.** Phase 2 spec explicitly lists "Password reset" under "Phase 2 does NOT include."

### E6. Is email invite out of scope?
**CONFIRMED OUT OF SCOPE.** Phase 2 spec explicitly lists "Email invite flow" under "Phase 2 does NOT include."

### E7. Should user management be P2-3 or merged with P2-1?
**P2-3 must remain separate.** P2-1 does backend schema + permission helpers only. P2-3 adds admin UI + user CRUD routes on top. Combining produces an oversized build slice with mixed concerns (schema migration + route guards + admin UI + CRUD routes) that is harder to verify atomically and harder to roll back.

### E8. Risks of combining P2-1 and P2-3
- Merged slice is ~4× the surface area of P2-1 alone
- Verification complexity increases: auth enforcement AND user management AND backfill all in one gate
- Rollback surface is broader
- P2-2 (workspaces) can proceed after P2-1 schema without waiting for user management UI
- **Recommendation: keep separate.** P2-1 delivers working role enforcement without any admin UI. P2-3 adds the admin UI as a distinct capability.

---

## 9. XLSX Import Feasibility

### F1. Any upload handling today?
**NONE.** No multipart handling, no `multer`, no file upload routes in server.js.

### F2. Does package.json include XLSX parsing library?
**NO.** Current dependencies: `express ^4.19.2`, `bcryptjs ^2.4.3` only.

### F3. Is adding a package required?
**YES.** A new npm package is required.

### F4. Recommended package
**`xlsx` (SheetJS community edition).** Reasons:
- Most widely used XLSX parser in Node.js ecosystem
- Handles .xlsx natively
- No native C dependencies (pure JS)
- CommonJS compatible (`require('xlsx')`)
- Supports reading specific sheets, reading header rows, outputting JSON
- Suitable for one-time admin import (not streaming — acceptable for Phase 2 file sizes)
- Alternative: `exceljs` (heavier, better for large files/streaming) — overkill for Phase 2

### F5. Can Sheet 2 mapping be derived from current ROW_FIELDS?
**YES, almost entirely.** Engineering journal confirms Sheet 2 = "All Experiment Summary", header row 4, 13 core columns that map to ROW_FIELDS. A header-label-to-DB-key mapping object must be explicitly authored:

### F6. Workbook column to DB field mapping (from engineering journal + ROW_FIELDS)
| Workbook Header (Sheet 2, row 4) | DB Column | Notes |
|----------------------------------|-----------|-------|
| Owner | owner | required |
| Track | track | must validate vs TRACKS enum |
| Experiment Title | title | required |
| Function | function_area | |
| Parent Item | parent_item | |
| Description / Hypothesis | hypothesis | |
| Experiment Design | design | |
| Success Criteria | success_criteria | |
| Target End Date | target_end_date | store as ISO string |
| Dependencies | dependencies | |
| Outcome / Finding | outcome | |
| Next Action | next_action | |
| Status | status | must validate vs STATUSES enum |
| (not in workbook) | type | default to 'experiment' on import |

**NOTE:** Exact header text in workbook row 4 must be verified from the live .xlsx before P2-4 spec is written. Binary file cannot be read in recon. Engineering journal confirms 11/13 exact matches and 2 minor label differences — these may affect the mapping.

### F7. Validation before preview
1. File is .xlsx (mime type check)
2. Sheet 2 exists in workbook
3. Header row (row 4) contains expected columns
4. `track` values are in TRACKS enum (reject rows with invalid track)
5. `status` values are in STATUSES enum (reject rows with invalid status)
6. `title` non-empty (required)
7. `owner` non-empty (required)
8. `track` non-empty (required)
9. `status` non-empty (required)
10. Report: row count, valid row count, rejected rows with reasons
11. Preview of first N rows before commit

### F8. created_by/updated_by on import
`created_by = req.user.username` (the importing admin), `updated_by = req.user.username`. Same pattern as POST /api/rows batch.

### F9. Does import require admin role?
**YES.** Spec: "admin: import XLSX". `canImport(req.user)` check at route entry → 403 if false.

### F10. Should import be P2-4 after roles/user management?
**CONFIRMED.** Import requires:
- P2-1 role enforcement (canImport check)
- P2-3 (admin user management) is not technically required by import, but logical ordering places import after user infrastructure is complete
Import also requires adding `xlsx` package — this is the only Phase 2 feature that adds an npm dependency.

---

## 10. Dashboard Feasibility

### G1. Any dashboard UI today?
**NONE.** Entire frontend is the execution table + filters. No analytics, no aggregate views.

### G2. Can dashboard metrics be computed from current entries table?
**YES.** All candidate widget data is derivable from the `entries` table as-is.

### G3. Metrics requiring no schema change

| Widget | Query pattern |
|--------|---------------|
| Items by track | `GROUP BY track COUNT(*)` |
| Items by status | `GROUP BY status COUNT(*)` |
| Blocked items | `WHERE status = 'Blocked'` |
| Owner load | `GROUP BY owner COUNT(*)` |
| Recently updated | `ORDER BY updated_at DESC LIMIT N` |
| Open next actions | `WHERE next_action IS NOT NULL AND status NOT IN ('Complete', 'Inconclusive')` |

### G4. Metrics requiring target_end_date parsing
- **Overdue / target-date-risk items**: `WHERE target_end_date < date('now') AND status NOT IN ('Complete', 'Inconclusive')`. SQLite date() function works. ISO date strings compare lexicographically. **No schema change required** — target_end_date already stored as TEXT in ISO format.

### G5–G6. Frontend computed vs backend endpoint — recommendation
**Frontend computed from state.rows.** Reasons:
- state.rows is already loaded on init — no extra API calls needed
- Team scale (small data) — client-side aggregation is trivial
- Avoids new backend routes for Phase 2
- Dashboard refresh = re-render from existing state
- Simple JS `.reduce()` / `.filter()` / `.sort()` suffice
- A future Phase 3+ at scale could move to backend aggregations

### G7. Dashboard ordering confirmation
**CONFIRMED: P2-5, after P2-1 through P2-4.** Dashboard benefits from:
- Role permissions in place (P2-1) — render appropriate content per role
- Import (P2-4) — more data to visualize after bulk import
- Being the last feature before review checkpoint means it can present a holistic view of the full Phase 2 dataset

---

## 11. Recommended Serialized Phase 2 DAG

```
P2-1 Roles & Permissions (backend only)
  │ — ALTER TABLE users ADD COLUMN role, track_scope
  │ — permission helpers: canCreateRow, canEditRow, canDeleteRow, canImport, canManageUsers
  │ — currentUser() extended to SELECT role, track_scope
  │ — /api/me returns role + track_scope
  │ — route guards on POST/PUT/DELETE /api/rows
  │ — backfill: admin → role='admin', vasu → role='track_owner', track_scope='["T3 AstraX Ops Cloud"]'
  │
  ▼
P2-2 Split Workspaces (frontend only)
  │ — state.workspace toggle (all | mytrack)
  │ — My Track Workspace tab in topbar
  │ — filteredRows() workspace filter
  │ — Edit/Delete buttons conditionally shown per permissions
  │ — New row button hidden for viewer role
  │
  ▼
P2-3 Admin User Management
  │ — GET/POST/PUT/DELETE /api/users routes (admin-gated)
  │ — Admin user management UI panel (new tab or admin modal)
  │ — Create user with role + track_scope
  │ — Edit user role + track_scope (optional: reset password)
  │ — Delete user (prevent self-delete)
  │
  ▼
P2-4 XLSX Import
  │ — npm install xlsx (SheetJS)
  │ — POST /api/import (admin-gated, multipart)
  │ — Sheet 2 parsing, header mapping, validation
  │ — Preview UI before commit
  │ — Batch INSERT with created_by/updated_by stamping
  │
  ▼
P2-5 Basic Dashboard
  │ — Dashboard tab in topbar
  │ — Frontend-computed widgets from state.rows
  │ — Items by track, by status, blocked items, overdue items, owner load, recent updates
  │
  ▼
P2-6 Review Checkpoint
      — state registry advancement
      — invariant check
      — smoke test all Phase 2 capabilities
      — engineering journal append
```

### DAG Dependency Reasons

| Edge | Reason |
|------|--------|
| P2-1 → P2-2 | Workspaces depend on user.role + track_scope from P2-1 schema. Frontend cannot conditionally render without permission data. |
| P2-1 → P2-3 | User management routes must set the role/track_scope columns added in P2-1. Cannot create users with role before role column exists. |
| P2-2 → P2-3 | Logical ordering. No hard dependency — P2-3 could theoretically precede P2-2 in theory but workspace UX should be validated before adding user management UI. |
| P2-3 → P2-4 | Logical ordering. Import technically only needs P2-1 (canImport check), but user infrastructure (P2-3) should be in place before bulk importing data authored by named users. |
| P2-4 → P2-5 | Dashboard is more useful after import has populated data. Logical ordering, not a hard dependency. |
| P2-5 → P2-6 | Review checkpoint validates all Phase 2 features are complete. |

### P2-3 Position Determination
**P2-3 stays AFTER P2-1 and P2-2.** It cannot be merged into P2-1 (oversized slice, mixed concerns). It cannot precede P2-1 (depends on role schema). The approved proposal ordering (P2-1 → P2-2 → P2-3) is correct.

---

## 12. First Build Slice Recommendation

**P2-1: Roles & Permissions (backend only)**

### Scope
1. DB migration: `ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer'` (try/catch idempotent)
2. DB migration: `ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL` (try/catch idempotent)
3. Backfill: `UPDATE users SET role = 'admin' WHERE username = 'admin'` (non-prod guard)
4. Backfill: `UPDATE users SET role = 'track_owner', track_scope = '["T3 AstraX Ops Cloud"]' WHERE username = 'vasu'` (non-prod guard)
5. `currentUser()` query: extend SELECT to include `u.role, u.track_scope`
6. Permission helpers: `parseScope()`, `canCreateRow()`, `canEditRow()`, `canDeleteRow()`, `canImport()`, `canManageUsers()`
7. Route guards: POST /api/rows (canCreateRow), PUT /api/rows/:id (canEditRow), DELETE /api/rows/:id (canDeleteRow)
8. `/api/me` response extended: include role + track_scope
9. Verify 403 returned for unauthorized operations, not 401

### Allowed Mutation Surfaces for P2-1
- `app/db.js`
- `app/server.js`
- `app/README.md` (minimal update — document role model)
- `ai/state_registry.json`
- `ai/engineering-journal.md`
- `specs/phase-2-roles-permissions.md` (create)
- `tasks/phase-2-roles-permissions-001.md` through `tasks/phase-2-roles-permissions-004.md` (create)

### NOT in P2-1 scope
- No frontend changes
- No user management routes
- No new npm packages
- No admin UI

---

## 13. Required Data Model Changes

### Phase 2 Schema Additions (all additive, no breaking changes)

#### users table (db.js)
```sql
ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer';
ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL;
```
Backfill (non-prod guard):
```sql
UPDATE users SET role = 'admin' WHERE username = 'admin';
UPDATE users SET role = 'track_owner', track_scope = '["T3 AstraX Ops Cloud"]' WHERE username = 'vasu';
```

#### entries table
**No changes required for Phase 2.** All entries table columns needed for dashboard metrics and import already exist.

#### No new tables needed for P2-1 through P2-5
A user_track_scopes join table is NOT needed — JSON column in users is sufficient for Phase 2's scale.

---

## 14. Required API Changes

| Phase | Route | Change |
|-------|-------|--------|
| P2-1 | `GET /api/me` | Return role + track_scope in user object |
| P2-1 | `POST /api/rows` | Add canCreateRow(user, track) → 403 guard |
| P2-1 | `PUT /api/rows/:id` | Add canEditRow(user, existing) → 403 guard |
| P2-1 | `DELETE /api/rows/:id` | Add canDeleteRow(user) → 403 guard |
| P2-3 | `GET /api/users` | New route — admin only, list all users (omit password_hash) |
| P2-3 | `POST /api/users` | New route — admin only, create user with role + track_scope |
| P2-3 | `PUT /api/users/:id` | New route — admin only, update role/track_scope/(optional) password |
| P2-3 | `DELETE /api/users/:id` | New route — admin only, prevent self-delete |
| P2-4 | `POST /api/import` | New route — admin only, multipart upload, xlsx parse, preview, batch insert |
| P2-5 | None | Dashboard is frontend-computed; no new backend routes |

---

## 15. Required Frontend Changes

| Phase | Location | Change |
|-------|----------|--------|
| P2-1 | `app.js:state` | none (data arrives via /api/me) |
| P2-2 | `app.js:state` | Add `state.workspace = 'all'` |
| P2-2 | `app.js:renderApp()` | Add workspace tab buttons to topbar |
| P2-2 | `app.js:filteredRows()` | Add workspace filter logic |
| P2-2 | `app.js:renderTable()` | Conditionally render Edit/Delete/New buttons based on role |
| P2-3 | `app.js` | Admin user management panel/tab — user list table, create/edit/delete forms |
| P2-4 | `app.js` | Import button (admin only), file picker, preview modal, submit to /api/import |
| P2-5 | `app.js` | Dashboard tab, widget rendering from state.rows |
| P2-5 | `style.css` | Dashboard widget styles |

---

## 16. Risks / Conflicts

| Risk | Severity | Notes |
|------|----------|-------|
| Session invalidation on role schema addition | LOW | currentUser() query SELECT change requires app restart. Existing sessions remain valid — only the SELECT widens. No token invalidation needed. |
| JSON.parse failure on malformed track_scope | LOW | Mitigated by defensive parseScope() wrapper returning []. |
| track_owner PUT track reassignment edge case | MEDIUM | Spec does not specify behavior. Operator decision required before P2-1 spec is written. See Unresolved Questions below. |
| No session expiry logic | LOW | Sessions never expire (no cleanup). Acceptable for Phase 2 team-internal use. Not a Phase 2 requirement. |
| XLSX package dependency | LOW-MEDIUM | Adds first new npm dependency since scaffold. SheetJS is well-maintained, pure JS, no native code. Risk is manageable. |
| Phase 2 has no deployment step | NOTE | Phase 2 explicitly excludes deployment. Sessions, secrets, and multi-user setup will need operator configuration before any production use of Phase 2 capabilities. |
| No password reset in Phase 2 | NOTE | Accepted per spec. Admin communicates initial passwords out-of-band. If a user forgets their password, admin must update it via P2-3 user management. |
| viewer role sees Edit/Delete buttons today | N/A | P2-2 (workspaces) handles hiding controls. P2-1 (backend) blocks the actual API. Belt and suspenders. |

---

## 17. Explicit Non-Scope Confirmation

The following items are explicitly confirmed as NOT in Phase 2:

| Item | Spec Statement |
|------|---------------|
| Deployment | "Phase 2 does NOT include: Deployment" |
| Public signup | "Phase 2 does NOT include: Public signup" |
| Email invite flow | "Phase 2 does NOT include: Email invite flow" |
| Password reset | "Phase 2 does NOT include: Password reset" |
| SSO | "Phase 2 does NOT include: SSO" |
| External auth provider | "Phase 2 does NOT include: External auth provider" |
| Approval workflow | "Phase 2 does NOT include: Approval workflow" |
| Escalation workflow | "Phase 2 does NOT include: Escalation workflow" |
| Agents | "Phase 2 does NOT include: Agents" |
| IoT / digital twin | "Phase 2 does NOT include: IoT / digital twin" |
| Advanced analytics | "Phase 2 does NOT include: Advanced analytics" |
| Continuous Excel sync | "Phase 2 does NOT include: Continuous Excel sync" |
| Multi-tenant SaaS architecture | "Phase 2 does NOT include: Multi-tenant SaaS architecture" |

---

## 18. Recommended Next Execution Directive

**ACTION: Issue P2-1 Spec + Task Graph generation directive.**

Before issuing, operator must resolve one decision:

**REQUIRED OPERATOR DECISION (D1):**
> When a `track_owner` performs PUT /api/rows/:id and the payload changes `track` to a value outside their assigned tracks — what is the expected behavior?
> - **Option A (Permissive):** Allow if user can edit the original row's track. Track reassignment to any canonical track is permitted if the user owns the current track.
> - **Option B (Strict):** Reject if the new track is outside the user's track_scope. Requires user to own both the source and destination track.

Operator decision on D1 should be embedded in the P2-1 spec before task graph generation.

**Post-decision:**
1. Compile spec: `vendor/engineering-os/scripts/compile-spec.sh specs/phase-2-roles-permissions.md`
2. Generate tasks: `vendor/engineering-os/scripts/generate-tasks.sh`
3. Execute: `vendor/engineering-os/scripts/execution-supervisor.sh`

**P2-1 is pure backend. Estimated task graph: 4 tasks (database migration + backfill, permission helpers, route guards, verification).**

---

## Appendix: Current State vs Phase 2 Requirements Matrix

| Phase 2 Requirement | Current State | Gap |
|--------------------|---------------|-----|
| role field on users | MISSING | ADD role TEXT DEFAULT 'viewer' |
| track_scope field on users | MISSING | ADD track_scope TEXT DEFAULT NULL |
| Admin backfilled | MISSING | UPDATE users SET role='admin' WHERE username='admin' |
| Permission helpers in server.js | MISSING | canCreateRow, canEditRow, canDeleteRow, canImport, canManageUsers |
| POST /api/rows permission check | MISSING | add canCreateRow guard |
| PUT /api/rows/:id permission check | MISSING | add canEditRow guard |
| DELETE /api/rows/:id permission check | MISSING | add canDeleteRow guard |
| /api/me returns role + track_scope | MISSING | extend SELECT and response |
| My Track Workspace tab | MISSING | P2-2 |
| All Tracks View (existing table) | EXISTS | no change needed |
| Edit/Delete conditional on permissions | MISSING | P2-2 frontend |
| User management routes | MISSING | P2-3 |
| User management UI | MISSING | P2-3 |
| XLSX import route | MISSING | P2-4 |
| xlsx npm package | MISSING | P2-4 |
| Dashboard tab | MISSING | P2-5 |
| Dashboard widgets | MISSING | P2-5 |
| Entries schema for dashboard | EXISTS | all needed columns present |
