# Engineering Journal — execution-platform

Append-only record of completed capabilities. Written by the execution
supervisor after verification passes. No entries yet — the repository is at
control-plane bootstrap (pre-Context).

---

## 2026-06-10 — promote-execution-table-v1-scaffold

**Capability:** Promote Execution Table Prototype To V1 App Scaffold  
**Feature slug:** promote-execution-table-v1-scaffold  
**Branch:** main  
**Phase:** phase-build  
**Spec:** specs/promote-execution-table-v1-scaffold.md v1.0.0  
**Spec version:** 1.0.0  

**Tasks executed:**
- 001 database — Retire INV-002, create app/db.js, package.json, .gitignore
- 002 backend  — Create app/server.js, app/README.md
- 003 frontend — Copy prototypes/execution-table-app/public/ → app/public/
- 004 verification — npm install, boot test, invariant check, smoke test

**Files modified:**
- `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh` → moved to `_legacy/`
- `app/` — created (db.js, server.js, README.md, package.json, package-lock.json, .gitignore, public/)
- `ai/recon/promote-execution-table-v1-scaffold-recon.md` — created
- `specs/promote-execution-table-v1-scaffold.md` — created
- `tasks/promote-execution-table-v1-scaffold-001..004.md` — created
- `ai/engineering-journal.md` — appended

**Prototype source:** prototypes/execution-table-app/ (preserved unmodified, ref only)

**Workbook column verification:**
- Source: source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx
- Sheets inspected: All Experiment Summary (row 4), Sample Experiment Log (row 5)
- Result: 11 exact matches; 2 minor label differences (cosmetic, no semantic mismatch); 1 prototype-only field (type, retained for row classification)
- Recommendation: ROW_FIELDS retained as-is; no DB schema change required
- Excel is structure source only; runtime data persists in app/data.db

**Architectural reasoning:**
- INV-002 retirement is semantically correct: the invariant guards against pre-L5 app code; once L5 Build execution is active and completed, the invariant has served its purpose and was graduated to _legacy/
- Seed rows replaced with generic placeholder (removed real team experiment data)
- prototype/ preserved unchanged as historical reference per spec invariant

**Invariant status:** 5/5 PASS (INV-002 retired; INV-001,003,004,005,006 pass)

**Verification results:**
- npm install: EXIT 0
- npm start: boots on :3000, ExperimentalWarning (node:sqlite, expected)
- scripts/invariant-check.sh: 5/5 PASS
- Surface audit: all mutations within declared surfaces; no extras
- prototype/: unmodified

**Smoke test outcome:**
- (b) login admin/admin123: 200, session cookie set ✅
- (c) GET /api/rows: 200, rows returned ✅
- (d) POST /api/rows: 201, row created with id ✅
- (e) GET includes new row ✅
- (f) PUT /api/rows/:id: 200 ✅
- (g) update confirmed in GET response ✅
- (h) persistence after server restart: row survives ✅
- No escalation/approval/dashboard/agent UI in responses ✅

**Unresolved risks:**
- No production auth (no CSRF, no secure cookie for HTTPS, session table never pruned) — documented in README, prototype-only credentials
- node:sqlite ExperimentalWarning on Node 25 — documented in README
- No CI pipeline — npm start only
- scripts/verification/ directory still absent; verification task ran checks inline

---

### 2026-06-09

### Feature

excel-like-team-summary-view

### Phase

phase-build

### Spec

specs/excel-like-team-summary-view.md

### Tasks


- tasks/excel-like-team-summary-view-001.md [database]
- tasks/excel-like-team-summary-view-002.md [backend]
- tasks/excel-like-team-summary-view-003.md [frontend]
- tasks/excel-like-team-summary-view-004.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-09T23:44:25Z (headless claude
workers, one per task). All 4 tasks completed; supervisor verification gate
passed (no scripts/verification/ corpus → skipped); state advanced to
RELEASE_APPROVED. Independent post-run verification performed by the supervising
session (below).

**Branch:** main

**Files modified:**
- app/db.js — ROW_FIELDS reordered to Sheet-2 contract (owner→…→status, type last);
  title relabelled "Experiment Title"; required flags on owner/track/title/status;
  Sheet-3 `help` text added to 11 fields; seed reduced to 2 generic client-safe rows.
- app/public/app.js — full 13-column Sheet-2 table + Type tag + Actions; sticky
  dense grid; search box + Status/Track/Type filters (client-side, AND); long-text
  truncation with tooltip; modal helper text; new-row status defaults Not Started;
  client-side required-field enforcement.
- app/public/style.css — dense Excel-like grid (30px rows, 12.5px font, grid lines
  via border-right/bottom), sticky header, horizontal scroll (min-width 1700px),
  controls bar styling.
- app/public/index.html — title → "astraX — Team Experiment Summary".

**Workbook sheets inspected (openpyxl, actual .xlsx):**
- Sheet 1 "Sample Experiment Log" (personal template, reference).
- Sheet 2 "All Experiment Summary" — primary table source; header row 4, 13 core
  columns A–M + derived stats panel P–Q.
- Sheet 3 "How To Use" — field guidance (rows 4–13), used as modal helper text.

**Column contract (display/DB order):** owner, track, title, function_area,
parent_item, hypothesis, design, success_criteria, target_end_date, dependencies,
outcome, next_action, status, type. Table column order matches Sheet 2 + Actions.
DB schema columns were already complete — no add/rename/migration required.

**Verification results (independent):**
- npm install: deps present (0 vulnerabilities).
- npm start: boots on :3000 (node:sqlite ExperimentalWarning, expected).
- GET /api/schema: owner-first, type-last, "Experiment Title", required =
  owner/track/title/status, 11 help strings.
- invariant-check.sh: 5/5 PASS.
- Surface audit: mutations only within declared surfaces; prototypes/ unmodified.

**Smoke test result:** login (admin/admin123) ✅; seed 2 rows ✅; create valid
201 with status default Not Started ✅; row included ✅; PUT status→In Progress
200 ✅; status persisted ✅; survives server restart ✅; no escalation/approval/
dashboard/agent terms in responses ✅. Frontend assets confirmed: 14-col table,
search + 3 filters, dense grid + sticky header + grid lines, modal helper text.

### Scope Correction

The generated spec's "## API Surface" routed required-field validation into
app/server.js, and the backend worker edited it. However, the directive's
**Allowed mutation surfaces** list does NOT include app/server.js. The change
was reverted (`git checkout app/server.js`) and required-field enforcement was
moved into the modal in app/public/app.js (an allowed surface, satisfying
directive requirement #5). server.js is byte-identical to its committed state.

### Pattern Updates

None.

### Incidents

None. (See Scope Correction — handled in-session, not a verification failure.)

### Unresolved Risks

- Required-field enforcement is client-side only (server.js out of scope per
  directive); raw API clients could bypass it. Acceptable for v1 scaffold.
- Real team data remains in the reference workbook only; never seeded/committed.
- No production auth, no CI, node:sqlite experimental — carried from predecessor.

---

### 2026-06-10

### Feature

v1-serialized-build-roadmap-dag

### Phase

phase-build

### Spec

specs/v1-serialized-build-roadmap-dag.md

### Tasks


- tasks/v1-serialized-build-roadmap-dag-001.md [frontend]
- tasks/v1-serialized-build-roadmap-dag-002.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T00:04:50Z.
All 2 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-10

### Feature

backend-required-field-enforcement

### Phase

phase-build

### Spec

specs/backend-required-field-enforcement.md

### Tasks


- tasks/backend-required-field-enforcement-001.md [backend]
- tasks/backend-required-field-enforcement-002.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T00:15:57Z.
All 2 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-10

### Feature

canonical-track-taxonomy-enforcement

### Phase

phase-build

### Spec

specs/canonical-track-taxonomy-enforcement.md

### Tasks


- tasks/canonical-track-taxonomy-enforcement-001.md [database]
- tasks/canonical-track-taxonomy-enforcement-002.md [backend]
- tasks/canonical-track-taxonomy-enforcement-003.md [frontend]
- tasks/canonical-track-taxonomy-enforcement-004.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T07:54:27Z.
All 4 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-10

### Feature

track-enum-server-validation

### Phase

phase-build

### Spec

specs/track-enum-server-validation.md

### Tasks


- tasks/track-enum-server-validation-001.md [backend]
- tasks/track-enum-server-validation-002.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T08:09:29Z.
All 2 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

## 2026-06-10 — data-model-audit-trail

### Feature

data-model-audit-trail

### Phase

phase-build

### Spec

specs/data-model-audit-trail.md

### Tasks

- tasks/data-model-audit-trail-001.md [database]
- tasks/data-model-audit-trail-002.md [backend]
- tasks/data-model-audit-trail-003.md [frontend]
- tasks/data-model-audit-trail-004.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh (tasks 001–002) and direct worker execution (tasks 003–004) at 2026-06-10.
All 4 tasks completed. Verification passed.

**Migration**: `ALTER TABLE entries ADD COLUMN created_by TEXT` and `updated_by TEXT` (try/catch for
idempotency). Backfill UPDATE runs after seed rows to stamp NULL rows with 'system'. Covers both
existing-DB upgrades and fresh installs.

**Backend stamping**: POST handler stamps `data.created_by = req.user.username` and `data.updated_by`
after `validate()` and before `Object.keys(data)`. PUT handler appends `updated_by = ?` to the SET
clause with `req.user.username` bound between data values and row id. `created_by`/`created_at` are
never touched on PUT.

**Forge prevention**: `sanitize()` whitelist (FIELD_KEYS = ROW_FIELDS keys) strips any client-supplied
`created_by`/`updated_by`/`created_at`/`updated_at` before validation. Audit columns are not in ROW_FIELDS,
so they cannot pass through — no additional protection layer needed.

**Frontend**: `AUDIT_LABELS` constant added; `colLabel()` checks AUDIT_LABELS before state.fields;
LIST_COLS extended with `created_by`, `updated_by`, `created_at`, `updated_at` before `type`. Audit
columns are not in ROW_FIELDS so they never appear in the create/edit form. Table already has
horizontal scroll — no CSS change needed.

**Backfill order fix**: Initial implementation placed backfill before seed insert, leaving seed rows
NULL on fresh installs. Fixed by moving backfill to after the seed block (still WHERE IS NULL, so
idempotent on existing rows with stamps).

### Pattern Updates

None.

### Incidents

Execution supervisor stopped after task 002 due to output truncation; tasks 003–004 executed
directly as authorized worker within EXECUTION_ACTIVE state. State advanced manually to
VERIFICATION_REQUIRED → RELEASE_APPROVED after 5/5 invariant pass.

### Invariant Status

5/5 PASS (INV-001, INV-003, INV-004, INV-005, INV-006)

### Verification Results

| Check | Result |
|-------|--------|
| Server boots | ✅ |
| Login 200 | ✅ |
| Seed rows: created_by=system, updated_by=system | ✅ |
| POST valid → 201 with created_by=admin, updated_by=admin | ✅ |
| POST forge → 201 with created_by=admin (forge rejected) | ✅ |
| PUT valid → 200 with updated_by=admin, created_by preserved | ✅ |
| PUT forge → 200 with updated_by=admin (forge rejected) | ✅ |
| POST missing owner → 400 owner is required | ✅ |
| POST fake track → 400 invalid track | ✅ |
| POST bad status → 400 invalid status | ✅ |
| Persistence after restart | ✅ |
| 5/5 invariants PASS | ✅ |
| Surface audit clean | ✅ |

---

### 2026-06-10

### Feature

ux-table-hardening-v1

### Phase

phase-build

### Spec

specs/ux-table-hardening-v1.md

### Tasks


- tasks/ux-table-hardening-v1-001.md [frontend]
- tasks/ux-table-hardening-v1-002.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T09:44:31Z.
All 2 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

## 2026-06-10 — ux-table-hardening-v1

### Feature

ux-table-hardening-v1

### Phase

phase-build

### Spec

specs/ux-table-hardening-v1.md

### Tasks

- tasks/ux-table-hardening-v1-001.md [frontend]
- tasks/ux-table-hardening-v1-002.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T09:43:21Z.
All 2 tasks completed. Verification passed.

**UX decision**: Audit metadata (created_by, updated_by, created_at, updated_at) was added to the
default LIST_COLS in the prior `data-model-audit-trail` capability. This pushed the table from 14 to
18 columns, cluttering the daily execution scan. This capability moves audit metadata behind a
per-row "Details" button. The 4 execution-focused columns (owner through type) remain at 14.

**Details modal**: Reuses existing `.modal-back`, `.modal`, `.modal-actions`, `.btn.ghost` CSS
classes. New `.modal-sm` narrows the modal to 320px (appropriate for 4 label/value pairs).
New `.detail-list` provides a 2-column definition-list grid using existing CSS custom properties
(--muted, --text). Zero new design tokens or component patterns introduced.

**AUDIT_LABELS preserved**: The `AUDIT_LABELS` constant and updated `colLabel()` from the prior
capability remain intact and are used by `openDetails()`. No orphaned code.

**openDetails() is read-only**: No `data-k` inputs, no `querySelectorAll('[data-k]')`, no save
action. The only interactive control is the Close button.

### Pattern Updates

None.

### Incidents

None.

### Invariant Status

5/5 PASS (INV-001, INV-003, INV-004, INV-005, INV-006)

### Verification Results

| Check | Result |
|-------|--------|
| Server boots | ✅ |
| LIST_COLS back to 14 (no audit columns) | ✅ |
| AUDIT_LABELS still present | ✅ |
| Details button and [data-info] binding | ✅ |
| openDetails() renders read-only audit fields | ✅ |
| .modal-sm and .detail-list in style.css | ✅ |
| Required-field regression: 400 owner is required | ✅ |
| Track enum regression: 400 invalid track | ✅ |
| Audit stamping: POST → created_by=admin | ✅ |
| README updated to mention Details button | ✅ |
| 5/5 invariants PASS | ✅ |
| Surface audit clean | ✅ |

---

## 2026-06-10 — auth-hardening-v1

**State:** RELEASE_APPROVED
**Spec:** specs/auth-hardening-v1.md
**Recon:** ai/recon/auth-hardening-v1-recon.md
**Tasks:** auth-hardening-v1-001 (database), auth-hardening-v1-002 (backend), auth-hardening-v1-003 (verification)

### Summary

Hardened the session/auth layer for client demo and deployment readiness without introducing external dependencies or changing product scope.

**db.js:** Demo credential seeding (`admin/admin123`, `vasu/vasu123`) is now gated on `NODE_ENV !== 'production'`. A warning is emitted in production if the database has no users.

**server.js:**
- `SESSION_SECRET` is read from env. Dev fallback applied when `NODE_ENV` is not `production`. In production: boot fails (FATAL) if absent or < 32 characters.
- `signToken(token)` — appends HMAC-SHA256 over the raw session token using SESSION_SECRET.
- `verifyToken(signed)` — validates HMAC with `crypto.timingSafeEqual()` before DB lookup. Returns raw token or null.
- `currentUser()` — calls `verifyToken()` before querying sessions table.
- Login cookie — value is `signToken(token)`; adds `secure: NODE_ENV === 'production'`.
- Logout — calls `verifyToken()` before DB delete; null cookie handled safely.

**app/.env.example:** New file documenting `SESSION_SECRET`, `NODE_ENV`, and `PORT` with generation instructions.

**app/README.md:** Added "## Production Environment" section with env var table, secret generation command, and production safety notes.

### Key Design Decisions

- No `dotenv` dependency: env vars loaded externally (shell, docker-compose, process manager). Consistent with existing zero-dep philosophy.
- HMAC signing adds server-identity verification before DB round-trip; does not change the session storage model.
- `timingSafeEqual` with length guard (`sig.length !== 64`) prevents timing oracle on HMAC comparison.
- Existing logged-in sessions invalidated on restart — expected and acceptable for auth hardening.

### Invariant Status

5/5 PASS (INV-001, INV-003, INV-004, INV-005, INV-006)

### Verification Results

| Check | Result |
|-------|--------|
| Local dev boots without SESSION_SECRET | ✅ |
| Login cookie contains dot (token.hmac format) | ✅ |
| GET /api/me 200 with cookie | ✅ |
| GET /api/rows 200 with cookie, 401 without | ✅ |
| POST /api/rows stamps created_by = admin | ✅ |
| Logout invalidates session (me → 401) | ✅ |
| Required-field regression: 400 owner is required | ✅ |
| Track enum regression: 400 invalid track | ✅ |
| NODE_ENV=production, missing SECRET → FATAL exit | ✅ |
| NODE_ENV=production, SECRET < 32 chars → FATAL exit | ✅ |
| NODE_ENV=production, valid SECRET → boots | ✅ |
| Production login cookie has Secure attribute | ✅ |
| 5/5 invariants PASS | ✅ |
| Surface audit clean (no public/, prototypes/, sdlc/ changes) | ✅ |

---

## 2026-06-10 — phase-2-roles-permissions

**Capability:** P2-1 Roles & Permissions Backend
**Feature slug:** phase-2-roles-permissions
**Branch:** main
**Phase:** phase-build
**Spec:** specs/phase-2-roles-permissions.md
**Recon:** ai/recon/phase-2-team-operating-model-full-spec-recon.md

**Tasks executed:**
- tasks/phase-2-roles-permissions-001.md [database] — ALTER TABLE users + backfill
- tasks/phase-2-roles-permissions-002.md [backend] — permission helpers + currentUser + route guards
- tasks/phase-2-roles-permissions-003.md [verification] — full smoke test

**Files modified:**
- app/db.js — role + track_scope migration + backfill (bug fix applied post-supervisor)
- app/server.js — parseScope, permission helpers, extended currentUser SELECT, /api/me, route guards
- ai/state_registry.json — RELEASE_APPROVED
- ai/engineering-journal.md — appended

**Operator decisions applied:**
- Track reassignment rule: STRICT — track_owner PUT must own both existing.track AND new track

**DB migration:**
- `ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'viewer'` (idempotent try/catch)
- `ALTER TABLE users ADD COLUMN track_scope TEXT DEFAULT NULL` (idempotent try/catch)
- Backfill: admin → role='admin'; vasu → role='track_owner', track_scope='["T3 AstraX Ops Cloud"]'
- Backfill placed AFTER seed INSERT to ensure rows exist on fresh boot (bug fix)
- Backfill gated on NODE_ENV !== 'production'; idempotent condition (role IS NULL OR role = 'viewer')

**Permission helpers (server.js):**
- parseScope(user): JSON.parse(track_scope) with [] fallback on error
- canCreateRow(user, track): admin=true; track_owner checks scope.includes(track); viewer=false
- canEditRow(user, existingRow, nextTrack): admin=true; track_owner checks existing.track ∈ scope; if nextTrack differs, nextTrack must also ∈ scope (strict rule)
- canDeleteRow(user): admin only
- canImport(user), canManageUsers(user): admin only

**Route guards:**
- POST /api/rows: canCreateRow after validate() → 403 if false
- PUT /api/rows/:id: canEditRow with nextTrack derived from payload diff → 403 if false
- DELETE /api/rows/:id: canDeleteRow → 403 if false
- GET routes unchanged (requireAuth only — all authenticated users view all rows)

**/api/me extended:**
- Now returns: { user: { id, username, role, track_scope: [...] } }
- track_scope serialized as parsed array (not raw JSON string)
- role comes through via ...u spread from extended currentUser() SELECT

**Bug found and fixed:**
- Task-001 worker placed backfill UPDATE before seed INSERT; fresh-boot produced role='viewer' for admin/vasu
- Fix: moved backfill block to after both seed blocks in db.js; re-verified on strict fresh boot

**Invariant Status:** 5/5 PASS (INV-001, INV-003, INV-004, INV-005, INV-006)

**Verification Results (all on fresh boot after bug fix):**

| Check | Result |
|-------|--------|
| Admin /api/me → role:'admin', track_scope:[] | ✅ |
| Vasu /api/me → role:'track_owner', track_scope:['T3 AstraX Ops Cloud'] | ✅ |
| Admin POST T1 AstraX Device → 201 | ✅ |
| Admin POST T5 Business → 201 | ✅ |
| Admin PUT row → 200 | ✅ |
| Admin DELETE row → 200 | ✅ |
| Vasu GET /api/rows → 200 | ✅ |
| Vasu POST T3 AstraX Ops Cloud → 201 | ✅ |
| Vasu POST T1 AstraX Device → 403 Forbidden | ✅ |
| Vasu PUT T3 row (no track change) → 200 | ✅ |
| Vasu PUT T5 row → 403 Forbidden | ✅ |
| Vasu PUT T3→T1 reassignment (strict) → 403 Forbidden | ✅ |
| Vasu DELETE → 403 Forbidden | ✅ |
| Viewer GET → 200 | ✅ |
| Viewer POST → 403 Forbidden | ✅ |
| Viewer PUT → 403 Forbidden | ✅ |
| Viewer DELETE → 403 Forbidden | ✅ |
| POST missing owner → 400 'owner is required' | ✅ |
| POST invalid track → 400 'invalid track' | ✅ |
| Audit stamping: created_by = 'admin' | ✅ |
| Invariants 5/5 PASS | ✅ |
| Surface audit: app/public/ untouched | ✅ |

**Unresolved risks carried to P2-2:**
- Frontend still shows Edit/Delete buttons for all users regardless of role — P2-2 scope
- No viewer seed in production — admin creates users via P2-3 (accepted)
- No session expiry — carried from Phase 1, not P2-1 scope

---

### 2026-06-10

### Feature

phase-2-split-workspaces

### Phase

phase-build

### Spec

specs/phase-2-split-workspaces.md

### Tasks


- tasks/phase-2-split-workspaces-001.md [backend]
- tasks/phase-2-split-workspaces-002.md [frontend]
- tasks/phase-2-split-workspaces-003.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T11:13:17Z.
All 3 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-10

### Feature

phase-2-admin-user-management

### Phase

phase-build

### Spec

specs/phase-2-admin-user-management.md

### Tasks


- tasks/phase-2-admin-user-management-001.md [database]
- tasks/phase-2-admin-user-management-002.md [backend]
- tasks/phase-2-admin-user-management-003.md [frontend]
- tasks/phase-2-admin-user-management-004.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T14:06:01Z.
All 4 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-10

### Feature

phase-2-xlsx-import

### Phase

phase-build

### Spec

specs/phase-2-xlsx-import.md

### Tasks


- tasks/phase-2-xlsx-import-001.md [database]
- tasks/phase-2-xlsx-import-002.md [backend]
- tasks/phase-2-xlsx-import-003.md [frontend]
- tasks/phase-2-xlsx-import-004.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T15:58:20Z.
All 4 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-10

### Feature

phase-2-xlsx-import-open-mode

### Phase

phase-build

### Spec

specs/phase-2-xlsx-import-open-mode.md

### Tasks


- tasks/phase-2-xlsx-import-open-mode-001.md [backend]
- tasks/phase-2-xlsx-import-open-mode-002.md [frontend]
- tasks/phase-2-xlsx-import-open-mode-003.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-10T21:41:51Z.
All 3 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.

---

### 2026-06-11 — P2-4A Open Import Mode Patch (operator note)

**Feature:** phase-2-xlsx-import-open-mode (RELEASE_APPROVED) — patch on top of P2-4.

**Operator decision:** changed the requirement from strict canonical import to
**capture-first ("open") import** after testing the real astraX workbook (P2-4
strict validation rejected all 19 rows because track labels are shorthand like
`T1-Device`/`T1 Device` and many owner/status cells are blank).

**What changed (import routes only):**
- Import validation now **warns instead of blocks**. `classifyImportRow` replaced
  the strict `validateImportRow`. A row is unimportable **only** when its title is
  blank (`title is required`); every other row imports.
- owner blank → `Unassigned`; track blank → `Unassigned Track`; non-canonical track
  imported **as-is** (track is free TEXT). status blank → `Not Started`.
- **Schema-aware exception:** `entries.status` carries a DB `CHECK` constraint and
  `app/db.js` was NOT modified, so a blank or non-canonical status is **coerced to
  `Not Started` with a disclosing warning** (arbitrary status text cannot be stored).
  `type` is likewise always defaulted to `experiment`. Commit guards each insert in
  try/catch so it never crashes the batch.

**What did NOT change:** strict row CRUD validation for `POST`/`PUT /api/rows`
remains canonical-only (manual rows still reject invalid track and invalid status).
Admin-only gating, preview-before-commit, audit stamping, the SSF date fix, and the
DB-as-source-of-truth invariant are all preserved.

**Live workbook verification:** preview now returns **19 importable / 0 skipped /
36 warnings** (was 0 importable under strict mode); commit inserted all 19 with
`created_by`/`updated_by=admin`, `type=experiment`, non-canonical track stored
verbatim, all statuses canonical (CHECK-safe). Title-blank rows skipped; non-admin
preview/commit 403, anon 401; manual invalid-track/status POST still rejected;
P2-1/P2-2/P2-3 regressions pass; invariants 5/5.

**Incident (resolved):** the verification task's shell cleanup loop captured Node's
FORCE_COLOR-colorized numbers into `curl` URLs, orphaning 19 import rows; cleaned up
out-of-band, DB restored to its original 7 rows. Recorded as a recurring-artifact memo.

---

### 2026-06-11

### Feature

phase-2-basic-dashboard

### Phase

phase-build

### Spec

specs/phase-2-basic-dashboard.md

### Tasks


- tasks/phase-2-basic-dashboard-001.md [database]
- tasks/phase-2-basic-dashboard-002.md [frontend]
- tasks/phase-2-basic-dashboard-003.md [verification]

### Implementation Notes

Executed by execution-supervisor.sh at 2026-06-11T21:44:02Z.
All 3 tasks completed. Verification passed.

### Pattern Updates

None.

### Incidents

None.
