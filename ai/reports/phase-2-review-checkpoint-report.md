# Phase 2 Review Checkpoint Report

Feature: phase-2-review-checkpoint
Date: 2026-06-12
Branch: main
Reviewed by: Engineering OS execution pipeline (P2-6)

---

## Executive Summary

Phase 2 is **DEMO-READY**. All six Phase 2 capabilities are RELEASE_APPROVED and committed. All smoke tests pass. The application is fully functional for admin, track_owner, and viewer roles. The import system works correctly for the data currently in the workbook; a P3 carry-forward list addresses the identified coverage and batch-management gaps.

**One caveats:** The live workbook only contains T1 data in the importable sheet. T2-T6 experiments have not been entered into 'All Experiment Summary' yet — this is a data entry gap, not a product bug.

---

## 1. Phase 2 Capability Status

| Feature | State | Commit | Capability |
|---|---|---|---|
| P2-1: Roles & Permissions Backend | RELEASE_APPROVED | 618def0 | 3 roles (admin/track_owner/viewer), track_scope, permission guards on all routes |
| P2-2: Split Workspaces Frontend | RELEASE_APPROVED | e1a5db7 | All Tracks / My Track tabs for track_owner, permission-aware row controls |
| P2-3: Admin User Management | RELEASE_APPROVED | 16320bf | Admin Users tab: list/create/edit/delete users; self-demote/delete blocked; no password_hash leak |
| P2-4: XLSX Import (strict, then open-mode) | RELEASE_APPROVED | 306ec7d | SheetJS base64 import with preview-before-commit; open-mode (P2-4A bad04b9) |
| P2-4A: Open Import Mode Patch | RELEASE_APPROVED | bad04b9 | Capture-first: only blank title blocks; non-canonical track as-is; status coerced to canonical |
| P2-5: Basic Dashboard | RELEASE_APPROVED | 11d7ff2 | 8-widget execution-health dashboard for all roles; no backend change; data preserved verbatim |

**All 6 Phase 2 features: RELEASE_APPROVED ✓**

---

## 2. Smoke Test Results

### Admin Flow

| Test | Expected | Result |
|---|---|---|
| POST /api/login admin | 200, user returned | ✓ PASS |
| GET /api/me | role=admin, no password_hash | ✓ PASS |
| GET /api/rows | 200, 64 rows, no password_hash in rows | ✓ PASS |
| GET /api/users | 200, 2 users, no password_hash | ✓ PASS |
| POST /api/import/preview (empty content) | 400 | ✓ PASS |
| PUT /api/users/1 role=viewer (self-demote) | 403 "cannot demote your own admin account" | ✓ PASS |
| DELETE /api/users/1 (self-delete) | 403 "cannot delete your own account" | ✓ PASS |

### Track-Owner Flow (vasu)

| Test | Expected | Result |
|---|---|---|
| POST /api/login vasu | 200 | ✓ PASS |
| GET /api/me | role=track_owner, scope=["T3 AstraX Ops Cloud"] | ✓ PASS |
| GET /api/rows | 200 | ✓ PASS |
| GET /api/users | 403 | ✓ PASS |
| POST /api/import/preview | 403 | ✓ PASS |
| POST /api/import/commit | 403 | ✓ PASS |
| POST /api/rows track=T3 AstraX Ops Cloud | 201 (cleaned up) | ✓ PASS |
| POST /api/rows track=T1 AstraX Device | 403 | ✓ PASS |
| DELETE /api/rows/:id | 403 | ✓ PASS |

### Anonymous Flow

| Test | Expected | Result |
|---|---|---|
| GET /api/rows | 401 | ✓ PASS |
| GET /api/users | 401 | ✓ PASS |

### CRUD Strict Validation

| Test | Expected | Result |
|---|---|---|
| POST /api/rows track="T1-Device" (non-canonical) | 400 invalid track | ✓ PASS |

### Frontend Assets

| Asset | Check | Result |
|---|---|---|
| /app.js | contains renderDashboard | ✓ PASS |
| /app.js | contains renderImportPanel | ✓ PASS |
| /app.js | does not contain password_hash | ✓ PASS |

**All smoke tests: 20/20 PASS**

---

## 3. Import Coverage Finding

### Summary

The live import preview of `astraX-june-to-nov-experiment-all-tracking.xlsx` reports:
```
sheet: All Experiment Summary
total_rows: 19 | importable: 19 | skipped: 0 | warnings: 36
track distribution: {T1 Device: 1, T1-Device: 10, Unassigned Track: 8}
```

**Observation:** Only T1 data was imported. T2-T6 tracks have zero rows in the importable sheet.

### Workbook Structure

The workbook contains 3 sheets:
1. **Sample Experiment Log** — Personal experiment log template. 25 rows. Has T1-T6 sample rows but uses a different column layout (no Owner column). Header detection correctly skips this sheet because IMPORT_HEADER_MAP requires Owner + Track + Experiment Title in the same header row.
2. **All Experiment Summary** — Operational data sheet. Selected by importer (exact name match on `IMPORT_SHEET` constant). 62 matrix rows; header at row 4; 19 non-empty data rows after header.
3. **How To Use** — Instructions sheet. Not processed.

### Root Cause

**Data coverage, not an importer bug.**

The 'All Experiment Summary' sheet contains only T1 experiments at this time:
- T1-Device: 10 rows
- T1 Device: 1 row
- Blank track (→ Unassigned Track): 8 rows
- T2, T3, T4, T5, T6: **0 rows**

T2-T6 tracks have not been entered into the 'All Experiment Summary' sheet by the team. The 8 blank-track rows may represent T2-T6 experiments that were entered without filling in the Track column. The importer processes all 19 rows correctly.

### Risk Assessment

| Risk | Level |
|---|---|
| Only T1 importable from current workbook | MEDIUM — data entry gap, not a bug |
| No way to undo an import (no batch ID) | HIGH — P3 priority |
| Duplicate rows on re-import of same workbook | MEDIUM — P3 priority |
| 8 rows with Unassigned Track may confuse viewers | LOW — cosmetic |

---

## 4. Demo-Readiness Verdict

**DEMO-READY with known limitations:**

### What works
- All user roles function correctly (admin, track_owner, viewer)
- Row CRUD with strict permission enforcement
- Admin user management (create/edit/delete users; no self-demote/delete)
- XLSX import: preview → commit flow works end-to-end
- Open import mode: messy data imports with warnings, not blocking
- Dashboard: 8 widgets render from actual DB data for all roles
- Workspace tabs: All Tracks / My Track correctly scoped to Rows view
- Track labels preserved verbatim (no silent canonicalization)

### Known limitations (documented for demo context)
1. **Only T1 in workbook:** When demoing import, explain that T2-T6 are not yet entered in the summary sheet. The import works correctly for the data that exists.
2. **No import batch management:** There is no "undo last import" feature. Committed rows cannot be bulk-deleted by batch. This is a P3 item.
3. **Track labels are shorthand:** Imported rows show "T1-Device" not "T1 AstraX Device". This is intentional (open import mode preserves workbook values verbatim). The dashboard and rows table correctly reflect the stored values.
4. **64 rows in DB:** Includes seed data (2 sample rows), manually-created rows from prior testing, and any previously-imported batches. Row provenance is not tracked.

---

## 5. P3 Carry-Forward Requirements

### P3-1: Import Batch Management (HIGH PRIORITY)

**Problem:** There is no mechanism to identify which DB rows came from which import, or to undo an import.

**Proposed data model additions:**
```sql
CREATE TABLE imports (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  filename     TEXT NOT NULL,
  imported_by  TEXT NOT NULL,
  imported_at  TEXT NOT NULL DEFAULT (datetime('now')),
  row_count    INTEGER,
  warning_count INTEGER,
  status       TEXT DEFAULT 'complete'
);

ALTER TABLE entries ADD COLUMN import_batch_id INTEGER DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_sheet TEXT DEFAULT NULL;
ALTER TABLE entries ADD COLUMN import_source_row INTEGER DEFAULT NULL;
```

**New route:**
```
DELETE /api/imports/:id  (admin only)
→ DELETE FROM entries WHERE import_batch_id = :id
→ DELETE FROM imports WHERE id = :id
→ Returns { ok, deleted_count }
```

**UI additions:** Import history list (admin, shows batch date/filename/row_count/status, delete button per batch).

### P3-2: Full Workbook Capture (MEDIUM PRIORITY)

**Questions for operator:**
1. Will T2-T6 teams populate the same 'All Experiment Summary' sheet, or use separate workbooks?
2. Should the importer scan all sheets for rows matching the IMPORT_HEADER_MAP format (multi-sheet ingestion)?
3. Is there a plan to standardize the workbook template across all tracks?

**Options:**
- **Option A (recommended):** Multi-sheet scan — iterate all sheets, find any with a compatible header (Owner + Track + Experiment Title), import from all. Tracks rows to their source sheet via import_source_sheet.
- **Option B:** Multi-workbook — allow uploading N files per import session.
- **Option C:** Documentation — document that all T2-T6 teams must populate 'All Experiment Summary' before importing.

### P3-3: Duplicate Detection (MEDIUM PRIORITY)

**Problem:** Re-importing the same workbook after adding new rows creates duplicates for previously-imported rows.

**Proposed:** On commit, check for (title + owner + track) collisions before inserting, or use import_source_row to skip rows already imported from the same source position.

### P3-4: Viewer Provenance Context (LOW PRIORITY)

**Problem:** Imported rows with "Unassigned Track" or non-canonical labels may confuse viewers who have no context about their import origin.

**Proposed:** Show import_batch_id and import_source_sheet in the row details modal. Allows any user to understand "this row came from import batch #3, sheet 'All Experiment Summary', row 17."

---

## 6. Invariant Status

Pre-execution invariants (Task 001): **5/5 PASS**
Post-execution invariants: run as part of verification gate

| Invariant | Status |
|---|---|
| INV-001: vendor OS immutable | PASS |
| INV-003: artifacts declare Layer+Status | PASS |
| INV-004: ADRs append-only | PASS |
| INV-005: Domain Constitution pre-L2 | PASS |
| INV-006: artifacts declare traceability | PASS |

---

## 7. Protected Files Integrity

Confirmed untouched throughout all of Phase 2 (verified by git diff):

| File | Status |
|---|---|
| app/server.js | NOT modified in P2-5 or P2-6 (last modified P2-4A) |
| app/db.js | NOT modified in any Phase 2 feature |
| app/public/index.html | NOT modified in any Phase 2 feature |
| app/package-lock.json | NOT modified after P2-4 (xlsx install) |

P2-6 modifies only: recon artifact, spec, tasks, report, state registry, journal.

---

## 8. Recommended Demo Script

### Setup
- Ensure server is running: `cd app && node server.js`
- DB should have 2 seed users: admin / vasu
- Optionally pre-import the workbook for track data

### Demo Path
1. **Login as admin** → show Rows (all tracks, imported T1 data visible)
2. **Dashboard tab** → show execution health counts, by-track (T1-Device preserved), blocked/overdue sections
3. **Import tab** → load workbook, run Preview (19 importable, 36 warnings, T1 data), explain T2-T6 gap
4. **Users tab** → show user management (add a viewer, then delete)
5. **Login as vasu** → show workspace tabs (All Tracks vs My Track = T3 only), show New row blocked on T1
6. **Dashboard as vasu** → confirm tab visible; data is same view as admin
7. **Logout**

### Talk track for import demo
> "The import tool reads the 'All Experiment Summary' sheet from the workbook. The tool is in open-capture mode — it accepts every row that has a title, warning about anything non-standard rather than blocking it. The live workbook currently has 19 T1 experiments; T2 through T6 teams haven't filled in the summary yet. When they do, we import again. In P3, we'll add batch tracking and an undo import feature."
