# Spec: Import Preview UX Friction Fix

## Status
approved

## Phase
phase-build

## Feature Slug
import-preview-ux-friction-fix

## Depends On
Recon: ai/recon/import-preview-ux-friction-fix-recon.md. Frontend-only; preserves import parser, commit, Sheet 2 inclusive capture, batch delete integrity, access control, row-click edit, auth/session.

---

## Summary

Streamline the Import tab (frontend only): replace the long explanatory paragraph with minimal
warning-meaning bullets; auto-run preview when an `.xlsx` is selected and remove the Preview
button; and paginate the importable-rows preview (page size 20) so every importable row can be
reviewed. Parser, commit, and all backend behavior are unchanged; commit still imports all
importable rows regardless of the displayed page.

---

## Background

Recon: the Import tab is JS-rendered in `app/public/app.js`. Friction points — (1) a long
`<p class="import-note">` paragraph, (2) a separate Preview button required before preview, and
(3) a hard `p.rows.slice(0, 10)` cap ("first 10 of N") that hides the remaining importable rows.
Commit already sends all `p.rows`, so these are pure display/UX issues.

---

## Data Model Changes

none

---

## API Surface

none — `app/server.js` is unchanged. The preview response already carries
`summary.importable_rows`, the full `rows` array, and `skipped_rows`; the frontend paginates the
in-memory `rows` locally.

---

## Frontend Surface

`app/public/app.js`:
- `renderImportPanel`: replace the explanatory paragraph with a short `<ul class="import-legend">`
  describing warning meanings (informational, non-blocking). Remove the `#importPreviewBtn`. Add a
  `#importStatus` element for a transient "Previewing…" indicator. Paginate the importable table
  (page size 20) with a heading "Importable rows preview — showing X–Y of N" and
  Previous/Next controls (`#importPrev`/`#importNext`); clamp page to `[0, ceil(N/20)-1]`.
- `bindImportActions`: bind the file input `onchange` to run preview automatically (guard
  `.xlsx`; clear prior preview + reset page on a new file; show/clear the status indicator;
  disable the input during the call). Bind Previous/Next to adjust `state.importPage` and
  re-render. Commit remains disabled until `state.importPreview` has rows and still sends all
  `p.rows`. Reset `state.importPage` after commit and when entering the Import tab.
- `state`: add `importPage: 0`.

`app/public/style.css`: minimal rules for `.import-legend`, `.import-pager`, `.import-status`.

---

## Non-Scope

- No import parser / commit / Sheet 2 inclusive-import change
- No batch delete / duplicate detection / observation change
- No access-control, row-click edit, auth/session change
- No `app/server.js`, `app/db.js`, schema, `index.html`, package, config, or Railway change
- No broad UI redesign; no Docker/Postgres/deploy; no live `app/data.db` mutation

---

## Implementation Plan

### Task 1 — Frontend: warning bullets + auto-preview + pagination (frontend)

`app/public/app.js`: add `state.importPage`; replace paragraph with warning bullets; remove
Preview button; auto-preview on file `onchange` with a status indicator; paginate importable
rows (size 20) with Previous/Next + "showing X–Y of N"; keep Commit gated on preview and sending
all rows; reset page on new preview / commit / tab entry. `app/public/style.css`: minimal
pager/legend/status styling.

### Task 2 — Frontend: confirm preserved behaviors (frontend)

Confirm summary counts, skipped table, Import History, Commit Import, and batch delete still
render/function; commit payload still includes all importable rows.

### Task 3 — Verification

Disposable DB only (recon §7): auto-preview on file select; no Preview button; Commit
disabled→enabled around preview; bullets render; pagination pages through all rows ("X–Y of N"
accurate, N=64 for the operator workbook); commit inserts all 64; history + batch delete intact;
`node --check`; dev boot smoke; invariants 5/5; git status only allowed surfaces.

---

## Mutation Surfaces

| File | Change |
|------|--------|
| `app/public/app.js` | bullets, auto-preview, remove Preview button, pagination, `importPage` state |
| `app/public/style.css` | `.import-legend` / `.import-pager` / `.import-status` minimal rules |
| `ai/recon/...`, `specs/...`, `tasks/...`, `ai/state_registry.json`, `ai/engineering-journal.md` | OS artifacts |

---

## Verification Plan

See recon §7. Key assertions: file selection auto-previews; Preview button gone; pagination
reviews all importable rows; commit imports all rows (preview==commit); summary/skipped/history/
delete preserved; backend untouched; invariants 5/5.

---

## Relationship to Next Node

Next recommended node: Railway redeploy smoke — confirm the streamlined Import tab on the live deploy.
