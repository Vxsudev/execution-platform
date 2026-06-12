---
Slug: phase-3-dashboard-relevance
Layer: frontend
Upstream: specs/phase-3-row-click-interaction.md
Downstream: specs/phase-3-review-checkpoint.md
Status: approved
Phase: phase-build
---

## Status
approved

## Phase
phase-build

# Spec: P3-8 Dashboard Relevance

## Purpose

Make the dashboard more relevant for track owners by prioritizing their
assigned-track data while preserving all-track context. Admin and viewer
dashboard behavior remains all-data. Frontend-only change — no backend
mutation.

## Problem

All dashboard helpers (`dashStats`, `blockedRows`, `overdueRows`,
`recentRows`, `openNextActions`, `byCount`) use `state.rows` directly,
ignoring the existing `state.workspace` context. A track owner in My Track
workspace sees all-organisation data on the dashboard despite being scoped
to their assigned tracks in the Rows table. Additionally, the All Tracks /
My Track toggle is only rendered on the Rows page — track owners have no
way to switch dashboard scope without leaving the dashboard.

## Dependencies

- P3-5 (import provenance) — Details modal; no dashboard interaction.
- P3-6 (dense cell reveal) — table cells; no dashboard interaction.
- P3-7 (row/cell click) — row click handlers; no dashboard interaction.
- `visibleRowsForWorkspace(rows)` (line 32) — existing helper, reused.
- `state.workspace` (default `'all'`) — existing state field, reused.
- `userScope()` — existing helper, reused.

## Track Owner Dashboard Relevance Model

### `dashboardRows()` helper

```javascript
function dashboardRows() {
  if (isTrackOwner()) return visibleRowsForWorkspace(state.rows);
  return state.rows;
}
```

- track_owner + workspace==='my': returns `state.rows.filter(r => userScope().includes(r.track))`
- track_owner + workspace==='all': returns `state.rows`
- admin: returns `state.rows`
- viewer: returns `state.rows`

### Updated dashboard helpers

Replace `state.rows` with `dashboardRows()` in every dashboard helper:

| Function | Change |
|----------|--------|
| `dashStats()` | `const rows = dashboardRows();` |
| `blockedRows()` | `return dashboardRows().filter(...)` |
| `overdueRows()` | `return dashboardRows().filter(...)` |
| `recentRows()` | `return [...dashboardRows()].sort(...)` |
| `openNextActions()` | `return dashboardRows().filter(...)` |
| `renderDashboard()` byCount calls (×3) | `byCount(dashboardRows(), ...)` |

### Workspace toggle on dashboard

Show All Tracks / My Track toggle for track_owner when on dashboard page:

```javascript
// Render condition (line 143):
${isTrackOwner() && (isRowsPage || isDashPage) ? `...` : ''}

// Bind condition (line 187):
if (isTrackOwner() && (isRowsPage || isDashPage)) { ... }
```

Binding is identical to Rows: wsAll sets workspace='all', wsMy sets
workspace='my', then renderApp().

### Context label

`renderDashboard()` shows a `.dash-scope-label` subtitle:

```javascript
const scopeLabel = isTrackOwner()
  ? (state.workspace === 'my'
      ? `My Track (${userScope().join(', ') || 'unscoped'})`
      : 'All Tracks')
  : 'All Tracks';
```

Rendered as `<div class="dash-scope-label">${scopeLabel}</div>` inside
the `<div class="dash">` before the first card.

## Admin/Viewer Behavior

- Admin: `dashboardRows()` returns `state.rows` unchanged. No scope toggle.
- Viewer: `dashboardRows()` returns `state.rows` unchanged. No scope toggle.

## Empty Scoped Dashboard Safety

`dashMiniTable([], ...)` → `<div class="empty-mini">None.</div>`
`dashCountList([], ...)` → `<div class="empty-mini">No data.</div>`
`dashStats()` with empty rows → all zeros. No crash.

## Frontend Mutation Plan

### app/public/app.js

1. Add `dashboardRows()` helper after `visibleRowsForWorkspace` (~line 35).
2. Update `dashStats()`, `blockedRows()`, `overdueRows()`, `recentRows()`,
   `openNextActions()` to use `dashboardRows()`.
3. Update `renderDashboard()` — replace 3× `byCount(state.rows, ...)` with
   `byCount(dashboardRows(), ...)`; add `scopeLabel` and `.dash-scope-label`.
4. Update workspace toggle render condition and bind condition to include
   `isDashPage`.

### app/public/style.css

```css
.dash-scope-label{font-size:12px;color:var(--muted);margin-top:4px;font-weight:400;}
```

## Non-Scope

- No backend changes (app/server.js, app/db.js)
- No import management changes
- No Rows table changes
- No Details modal changes (P3-5)
- No dense cell reveal changes (P3-6)
- No row/cell click changes (P3-7)
- No schema changes
- No permission model changes
- P3-9 review checkpoint NOT implemented

## Verification Plan

1. `node --check public/app.js` → 0
2. `bash scripts/invariant-check.sh` → 5/5 PASS
3. Admin dashboard: all rows, no workspace toggle
4. Track owner (all): all-rows counts, toggle visible
5. Track owner (my): scoped counts match assigned tracks only
6. Toggle on dashboard switches scope and re-renders
7. Viewer: all-rows dashboard, no toggle
8. Empty My Track scope → zeros/empty, no crash
9. Rows workspace toggle still works
10. P3-7 row click, P3-6 cell reveal, P3-5 provenance modal all unchanged
11. Import stack regression clean
