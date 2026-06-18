# Task: Warning bullets, auto-preview (remove Preview button), and preview pagination

## Parent Spec
specs/import-preview-ux-friction-fix.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Implement the Import tab UX changes in `app/public/app.js` (+ minimal `app/public/style.css`).

`app/public/app.js`:
1. `state` (line ~3-8): add `importPage: 0`.
2. `renderImportPanel`:
   - Replace the `<p class="import-note">Admin only. Capture-first import …</p>` paragraph with a
     short `<ul class="import-legend">`: a lead "Warnings are informational — they never block a
     row." then bullets: blank owner → `Unassigned`; blank track → `Unassigned Track`; blank
     status → `Not Started`; blank title with other data → `Untitled`; non-canonical track →
     imported as-is.
   - Remove the `#importPreviewBtn`. Add `<span class="import-status" id="importStatus"></span>`
     in the controls row.
   - Paginate the importable table: page size 20; clamp `state.importPage` to
     `[0, ceil(N/20)-1]`; render `p.rows.slice(start, end)`; heading
     "Importable rows preview — showing {start+1}–{end} of {N}"; when N>20 render an
     `.import-pager` with `#importPrev` / `#importNext` (disabled at bounds) and "Page i of k".
3. `bindImportActions`:
   - Bind the file input `onchange`: guard `/\.xlsx$/i`; on a valid file, show "Previewing…" in
     `#importStatus`, disable the input, call `/api/import/preview`, store `state.importPreview` /
     `importFilename`, reset `state.importPage = 0` and `state.allowDuplicates = false`, then
     `renderApp()`; on error clear preview state, re-render, and show the message. A new file
     selection replaces the prior preview. Remove the old `#importPreviewBtn` binding.
   - Bind `#importPrev` / `#importNext` to decrement/increment `state.importPage` then
     `renderApp()` (display only — never mutates `state.importPreview`).
   - Commit: unchanged — gated on `state.importPreview.rows.length`, still sends all `p.rows`;
     after a successful commit also reset `state.importPage = 0`.
4. The Import-tab entry handler (`importPageBtn.onclick`, ~line 195-199): also reset
   `state.importPage = 0` when clearing `state.importPreview`.

`app/public/style.css`: add minimal rules for `.import-legend` (list spacing), `.import-pager`
(flex row, gap, centered), `.import-status` (muted inline text).

Do NOT change `app/server.js`, `app/db.js`, parser/commit logic, `index.html`, or any
non-import behavior. Commit must still import all importable rows, not just the visible page.

## Acceptance Criteria
- [ ] Explanatory paragraph replaced with concise warning-meaning bullets
- [ ] No Preview button; selecting an `.xlsx` auto-runs preview with a visible "Previewing…" state
- [ ] Selecting a different file clears the prior preview and re-previews
- [ ] Commit Import disabled until preview has rows; still commits all importable rows
- [ ] Importable preview paginated (size 20) with Previous/Next and "showing X–Y of N"; page clamped
- [ ] Pagination changes display only — never the commit payload
- [ ] Summary counts, skipped table, Import History, batch delete preserved
- [ ] `state.importPage` reset on new preview, commit, and Import-tab entry
- [ ] `app/server.js`, `app/db.js`, `index.html` unchanged
- [ ] `node --check app/public/app.js` passes

## Files Likely Affected
- app/public/app.js (state, renderImportPanel, bindImportActions, import-tab entry)
- app/public/style.css (.import-legend, .import-pager, .import-status)

## Blocked By
- tasks/import-preview-ux-friction-fix-001.md
