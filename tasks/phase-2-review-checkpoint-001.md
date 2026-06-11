# Task: Audit Phase 2 state registry, spec/task coverage, git log, and invariants

## Parent Spec
specs/phase-2-review-checkpoint.md

## Phase
phase-build

## Layer
database

## Status
done

## Description
This task uses the "database" slot as a pre-flight gate (no DB mutation — P2-6 produces no schema change). Verify that all Phase 2 state machine artifacts are consistent and clean before runtime smoke tests run.

1. Read ai/state_registry.json and confirm all phase-2-* feature slugs are RELEASE_APPROVED.
2. Confirm specs/ directory contains all 6 Phase 2 specs (phase-2-roles-permissions, phase-2-split-workspaces, phase-2-admin-user-management, phase-2-xlsx-import, phase-2-xlsx-import-open-mode, phase-2-basic-dashboard).
3. Confirm tasks/ directory contains all 19 Phase 2 task files (3 per P2-1, P2-2, P2-3=4, P2-4=4, P2-4A=3, P2-5=3).
4. Confirm git log shows commits for P2-1 through P2-5 (11d7ff2, bad04b9, 306ec7d present).
5. Run invariant engine: bash vendor/engineering-os/scripts/invariant-engine.sh — must exit 0, 5/5 PASS.
6. Confirm .git/hooks/pre-commit exists (enforcement layer 1 active).
7. Confirm no [FILL:] residue in any Phase 2 spec or task file.

## Acceptance Criteria
- [ ] All 6 Phase 2 feature slugs = RELEASE_APPROVED in state_registry.json
- [ ] 6 Phase 2 spec files present
- [ ] 19 Phase 2 task files present
- [ ] git log contains 11d7ff2 (P2-5), bad04b9 (P2-4A), 306ec7d (P2-4)
- [ ] Invariants 5/5 PASS
- [ ] Pre-commit hook file exists
- [ ] No [FILL:] residue in Phase 2 artifacts

## Files Likely Affected
- ai/state_registry.json (read-only verification)
- specs/phase-2-*.md (read-only verification)
- tasks/phase-2-*.md (read-only verification)

## Blocked By
- none
