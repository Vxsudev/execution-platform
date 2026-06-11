# Spec: Phase 2 — Review Checkpoint (P2-6)

## Status
approved

## Phase
phase-build

## Layer
L5-Build

## Feature Slug
phase-2-review-checkpoint

## Upstream
P2-1 (phase-2-roles-permissions), P2-2 (phase-2-split-workspaces), P2-3 (phase-2-admin-user-management), P2-4 (phase-2-xlsx-import), P2-4A (phase-2-xlsx-import-open-mode), P2-5 (phase-2-basic-dashboard). All RELEASE_APPROVED and committed.

## Downstream
P3 (import batch management, full workbook capture, duplicate detection)

---

## Goal

Validate Phase 2 end-to-end after P2-1 through P2-5. Produce a demo-readiness report, verify no regressions, audit import coverage behavior, and create a P3 carry-forward list. No new product features are introduced.

## Recon
ai/recon/phase-2-review-checkpoint-recon.md

---

## Architecture Contract

- P2-6 introduces NO product behavior.
- P2-6 does NOT alter app runtime behavior.
- P2-6 validates P2-1 through P2-5 as-built.
- P2-6 documents import coverage issues without patching them.
- P2-6 produces a Phase 2 demo-readiness report and P3 carry-forward list.
- Manual row CRUD validation remains strict.
- Import open mode remains capture-first.
- Dashboard preserves actual DB values (no track label normalization).
- Admin-only user management and import remain admin-only.
- Backend remains authority; frontend controls are UX only.

---

## Data Model Changes
None.

## API Surface Changes
None.

## Frontend Surface Changes
None.

---

## Task Graph

### Task 001 — Phase 2 State and Artifact Audit
Verify state registry (all Phase 2 features RELEASE_APPROVED), spec/task file coverage, git log confirms all commits, invariants 5/5, pre-commit hook present. Read-only.

### Task 002 — Full Runtime Regression Smoke
Boot server (already running or start fresh), run all smoke checks: admin flow (login, rows, users, import, dashboard tab), vasu flow (rows 200, users 403, import 403, T3 create 201, T1 create 403, delete 403), anon flow (401), self-demote/delete 403, strict CRUD validation (non-canonical track 400), frontend assets (app.js has renderDashboard+renderImportPanel). Read-only — no permanent data left behind.

### Task 003 — Import Coverage and Data Quality Audit
Confirm workbook sheets (3: Sample Experiment Log, All Experiment Summary, How To Use). Confirm All Experiment Summary is the import target. Confirm 19 total rows, 19 importable, 0 skipped. Confirm track distribution (T1-Device: 10, T1 Device: 1, Unassigned Track: 8). Confirm T2-T6 are absent from All Experiment Summary. Confirm Sample Experiment Log has a different column format (no Owner column — header detection skips it correctly). Document root cause: data coverage (T2-T6 not entered in the summary sheet), not an importer bug.

### Task 004 — Demo-Readiness and P3 Carry-Forward Report
Compile ai/reports/phase-2-review-checkpoint-report.md. Include: Phase 2 capability status summary, smoke test pass/fail matrix, import coverage finding (root cause, risk level), demo-readiness verdict, P3 carry-forward requirements (import batch management, full workbook capture, duplicate detection, viewer provenance context).

---

## Allowed Mutation Surfaces
- ai/recon/phase-2-review-checkpoint-recon.md
- specs/phase-2-review-checkpoint.md
- tasks/phase-2-review-checkpoint-001.md
- tasks/phase-2-review-checkpoint-002.md
- tasks/phase-2-review-checkpoint-003.md
- tasks/phase-2-review-checkpoint-004.md
- ai/reports/phase-2-review-checkpoint-report.md
- ai/state_registry.json
- ai/engineering-journal.md

Do NOT modify: app/server.js, app/db.js, app/public/app.js, app/public/style.css, app/public/index.html, app/package.json, app/package-lock.json, source-materials/, prototypes/, sdlc/, vendor/, deployment files.

---

## Verification Plan
1. Invariants 5/5 (pre and post execution).
2. State registry: phase-2-review-checkpoint = RELEASE_APPROVED at completion.
3. All Phase 2 feature slugs = RELEASE_APPROVED (no regression).
4. Smoke tests pass for admin / vasu / anon flows.
5. Import coverage audit documented (report section exists).
6. P3 carry-forward list documented (report section exists).
7. No app code modified (server.js, db.js, app.js, style.css, index.html, package*.json untouched).

## Non-Scope
New features · schema changes · API changes · frontend changes · import behavior patches · track normalization · deployment · P3 implementation.
