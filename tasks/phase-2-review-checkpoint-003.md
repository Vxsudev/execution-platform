# Task: Audit import coverage and document data quality findings

## Parent Spec
specs/phase-2-review-checkpoint.md

## Phase
phase-build

## Layer
frontend

## Status
done

## Description
This task uses the "frontend" slot as an import coverage audit (no UI mutation — P2-6 produces no app code change). Investigate and document why only T1 data imported from the full workbook.

1. Confirm workbook sheets: ['Sample Experiment Log', 'All Experiment Summary', 'How To Use'].
2. Confirm importer targets 'All Experiment Summary' (IMPORT_SHEET constant + resolveImportSheet logic).
3. Analyze 'All Experiment Summary': total matrix rows=62, header at row 4, 19 non-empty data rows after header.
4. Confirm track distribution: T1-Device: 10, T1 Device: 1, blank (→ Unassigned Track): 8. T2-T6: 0 rows.
5. Analyze 'Sample Experiment Log': 25 rows, personal template format, no "Owner" column — header detection skips it correctly (IMPORT_HEADER_MAP requires Owner+Track+Experiment Title).
6. Run live preview against running server to confirm: 19 importable, 0 skipped, 36 warnings.
7. Document root cause: data coverage (T2-T6 not entered in All Experiment Summary), not an importer bug.
8. Document the 8 blank-track rows: these are Unassigned Track rows, may be T2-T6 entries without a Track value.
9. Confirm Sample Experiment Log contains T1-T6 template rows but uses incompatible format — intentionally not imported.

## Acceptance Criteria
- [ ] Workbook sheet list confirmed (3 sheets)
- [ ] Importer sheet selection logic verified (IMPORT_SHEET constant + fallback regex)
- [ ] All Experiment Summary: 62 matrix rows, header at row 4, 19 data rows
- [ ] Track distribution: T1-Device=10, T1 Device=1, blank=8, T2-T6=0
- [ ] Sample Experiment Log has no compatible header (no Owner column) — correctly skipped
- [ ] Live preview confirms 19 importable / 0 skipped / 36 warnings
- [ ] Root cause documented: data coverage, not importer bug
- [ ] Finding written to ai/reports/phase-2-review-checkpoint-report.md (Import Coverage Finding section)

## Files Likely Affected
- source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx (read-only analysis)
- ai/reports/phase-2-review-checkpoint-report.md (new file — write)

## Blocked By
- tasks/phase-2-review-checkpoint-002.md
