# Task: Compile demo-readiness report and P3 carry-forward list

## Parent Spec
specs/phase-2-review-checkpoint.md

## Phase
phase-build

## Layer
verification

## Status
done

## Description
Compile the final Phase 2 review report at ai/reports/phase-2-review-checkpoint-report.md. The report must be complete enough to serve as a hand-off document for P3 planning and as a demo-readiness sign-off.

Report must include:
1. Phase 2 Capability Status — table of all 6 features with RELEASE_APPROVED confirmation and commit hashes.
2. Smoke Test Results — pass/fail matrix from task 002.
3. Import Coverage Finding — root cause analysis from task 003.
4. Demo-Readiness Verdict — overall yes/no with caveats.
5. P3 Carry-Forward — explicit requirements for: import batch management (imports table + entries.import_batch_id + DELETE /api/imports/:id), full workbook capture (T2-T6 question), duplicate detection, viewer provenance context.

Additionally:
- Run invariant engine again (post-execution gate): bash vendor/engineering-os/scripts/invariant-engine.sh — must exit 0
- Verify state registry phase-2-review-checkpoint = RELEASE_APPROVED after supervisor run
- Verify no app code modified (server.js / db.js / app.js / style.css / index.html / package*.json unchanged via git diff)
- Append entry to ai/engineering-journal.md

## Acceptance Criteria
- [ ] ai/reports/phase-2-review-checkpoint-report.md exists and has all required sections
- [ ] Demo-readiness verdict stated
- [ ] P3 carry-forward list contains at minimum: import batch management, full workbook capture, duplicate detection
- [ ] Post-execution invariants 5/5
- [ ] state_registry phase-2-review-checkpoint = RELEASE_APPROVED
- [ ] git diff confirms app/server.js, app/db.js, app/public/app.js, app/public/style.css, app/public/index.html, app/package.json, app/package-lock.json all unchanged
- [ ] Engineering journal entry appended

## Files Likely Affected
- ai/reports/phase-2-review-checkpoint-report.md (write)
- ai/engineering-journal.md (append)
- ai/state_registry.json (state update to RELEASE_APPROVED)

## Blocked By
- tasks/phase-2-review-checkpoint-003.md
