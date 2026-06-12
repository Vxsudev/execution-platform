---
name: phase-3-dashboard-relevance-recon
description: Recon for P3-8 dashboard relevance — workspace-aware dashboard for track_owner
metadata:
  type: recon
  slug: phase-3-dashboard-relevance
  upstream: phase-3-row-click-interaction
  downstream: phase-3-review-checkpoint
---

# Recon: P3-8 Dashboard Relevance

## Date
2026-06-12

## Branch
main (P3-7 committed at 30f4f58)

## Recon Method
Direct code reads. No assumptions. No inferred architecture.

---

## Commands Run

```
grep -n "renderDashboard|dashStats|blockedRows|overdueRows|recentRows|openNextActions|state.workspace|visibleRowsForWorkspace|My Track|All Track|workspace|canEditRow|isAdmin|isViewer|userRole|userScope|track_owner" app/public/app.js
grep -n "byCount|isClosed|isOpen|state.page|page =|'dashboard'|'rows'" app/public/app.js
wc -l app/public/app.js
cat ai/state_registry.json
```

---

## Files Read

- `app/public/app.js` (860 lines, full)
- `ai/state_registry.json`
- `ai/invariant-registry.md`

---

## Current Dashboard Data Source Findings

### Problem Statement

ALL dashboard helpers use `state.rows` directly, ignoring workspace context:

| Helper | Row source (current) |
|--------|----------------------|
| `dashStats()` line 380 | `state.rows` (hardcoded) |
| `blockedRows()` line 356 | `state.rows` (hardcoded) |
| `overdueRows()` line 358 | `state.rows` (hardcoded) |
| `recentRows()` line 368 | `state.rows` (hardcoded) |
| `openNextActions()` line 374 | `state.rows` (hardcoded) |
| `renderDashboard()` line 426-428 | `state.rows` for 3x byCount calls |

`visibleRowsForWorkspace(rows)` (line 32-35) exists and correctly filters by
`userScope()` when `state.workspace === 'my'`. It is used only by the Rows
table path (line 228). Dashboard never calls it.

### Workspace Toggle Visibility (current)

```javascript
// Line 143-147 — only shown for isRowsPage
${isTrackOwner() && isRowsPage ? `
  <div class="ws-tabs">
    <button ... id="wsAll">All Tracks</button>
    <button ... id="wsMy">My Track</button>
  </div>` : ''}
```

Track owners on the Dashboard page see NO workspace toggle. They get all-data
dashboard regardless of their intended scope.

### Workspace Toggle Binding (current)

```javascript
// Line 187-190 — only bound when isRowsPage
if (isTrackOwner() && isRowsPage) {
  document.getElementById('wsAll').onclick = ...
  document.getElementById('wsMy').onclick  = ...
}
```

Since the toggle is not rendered on dashboard, no binding needed currently —
but must be added alongside toggle rendering.

### Dashboard Page Navigation (current)

```javascript
// Line 186
document.getElementById('dashPageBtn').onclick = async () => {
  state.page = 'dashboard'; await loadRows(); renderApp();
};
```

`state.workspace` is NOT reset on dashboard page entry — persists from Rows.
This is correct behavior and means: if track owner was in 'my' workspace in
Rows and navigates to Dashboard, `state.workspace === 'my'` already.

### state.workspace Initial Value

```javascript
// Line 5
search: '', filters: { status: '', track: '', type: '' }, workspace: 'all',
```

Default is `'all'`. Track owners who never touched the Rows toggle will land
on Dashboard with `workspace === 'all'`. The toggle on Dashboard will let them
switch.

---

## Current Role/Workspace Behavior

| Function | Location | Behavior |
|----------|----------|----------|
| `userScope()` | line 15 | Returns `user.track_scope` array (assigned tracks) |
| `isAdmin()` | line 18 | `user.role === 'admin'` |
| `isTrackOwner()` | line 19 | `user.role === 'track_owner'` |
| `isViewer()` | line 20 | Not admin and not track_owner |
| `canCreateInCurrentWorkspace()` | line 21 | Admin: always. track_owner: workspace==='my' AND scope non-empty |
| `canEditRow(row)` | line 26 | Admin: always. track_owner: scope includes row.track |
| `visibleRowsForWorkspace(rows)` | line 32 | workspace==='my': filter by scope. else: return rows |

Rows page already correctly uses `visibleRowsForWorkspace` for the visible
row set (line 228). P3-8 extends the same logic to dashboard helpers.

---

## Recommended Dashboard Filtering Model

### `dashboardRows()` helper

```javascript
function dashboardRows() {
  if (isTrackOwner()) return visibleRowsForWorkspace(state.rows);
  return state.rows;
}
```

For track_owner: workspace-aware (my=scoped, all=all rows).
For admin/viewer: always all rows (no behavioral change).

### Update all dashboard helpers to use `dashboardRows()`

| Helper | Change |
|--------|--------|
| `dashStats()` | `const rows = dashboardRows();` |
| `blockedRows()` | `return dashboardRows().filter(...)` |
| `overdueRows()` | `return dashboardRows().filter(...)` |
| `recentRows()` | `return [...dashboardRows()].sort(...)` |
| `openNextActions()` | `return dashboardRows().filter(...)` |
| `renderDashboard()` `byCount` calls | `byCount(dashboardRows(), ...)` |

### Workspace toggle on Dashboard

Show the All Tracks / My Track toggle for track_owner when on dashboard page too:

```javascript
// Change condition from (isRowsPage) to (isRowsPage || isDashPage)
${isTrackOwner() && (isRowsPage || isDashPage) ? `
  <div class="ws-tabs">
    <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
    <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
  </div>` : ''}
```

And bind handlers when on either page:

```javascript
if (isTrackOwner() && (isRowsPage || isDashPage)) {
  document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
  document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
}
```

### Context label in dashboard

`renderDashboard()` should show the active scope as a subtitle:

```javascript
const scopeLabel = isTrackOwner()
  ? (state.workspace === 'my' ? `My Track (${userScope().join(', ') || 'unscoped'})` : 'All Tracks')
  : 'All Tracks';
```

Render as `.dash-scope-label` span near the dashboard heading or inside
Execution health card.

### Empty scoped dashboard safety

`dashMiniTable([], ...)` already returns `<div class="empty-mini">None.</div>`.
`dashCountList([], ...)` already returns `<div class="empty-mini">No data.</div>`.
`dashStats()` with empty rows → all zeros, no crash. Safe.

---

## Alternative Models Considered

**Alt A — Backend scoping**: Add `?track=...` query param to `GET /api/rows`.
Rejected: adds backend coupling, requires server.js mutation (forbidden surface),
no behavioral need since `state.rows` is already fully loaded.

**Alt B — Separate dashboard state**: Maintain `state.dashboardWorkspace` independent
of `state.workspace`.
Rejected: two sources of truth, confusing UX. Persisting `state.workspace` across
pages is the already-established pattern. Reusing it is correct.

**Alt C — Auto-switch workspace to 'my' on dashboard entry for track_owner**.
Risky: would change workspace state globally, affecting Rows table behavior
when user navigates back. Directive says "if default choice is ambiguous, preserve
current state.workspace and expose toggle clearly." Alt C rejected.

Chosen: **Option A (client-side dashboardRows() helper + workspace toggle on dashboard)**.

---

## Mutation Plan

### app/public/app.js — 4 changes

**Change 1 — Add `dashboardRows()` helper** (after `visibleRowsForWorkspace`, ~line 35)

```javascript
function dashboardRows() {
  if (isTrackOwner()) return visibleRowsForWorkspace(state.rows);
  return state.rows;
}
```

**Change 2 — Update dashboard stat helpers** (~lines 356-388)

- `blockedRows()`: `dashboardRows().filter(...)`
- `overdueRows()`: `dashboardRows().filter(...)`
- `recentRows()`: `[...dashboardRows()].sort(...)`
- `openNextActions()`: `dashboardRows().filter(...)`
- `dashStats()`: `const rows = dashboardRows();`

**Change 3 — Update renderDashboard()** (~lines 411-438)

- 3x `byCount(state.rows, ...)` → `byCount(dashboardRows(), ...)`
- Add `scopeLabel` and `.dash-scope-label` subtitle in dashboard header

**Change 4 — Show/bind workspace toggle on dashboard** (~lines 143-190)

- Render condition: `isTrackOwner() && (isRowsPage || isDashPage)`
- Bind condition: `isTrackOwner() && (isRowsPage || isDashPage)`

### app/public/style.css — 1 addition

```css
.dash-scope-label{font-size:12px;color:var(--muted);margin-top:4px;font-weight:400;}
```

---

## Verification Plan

1. `node --check public/app.js` → 0
2. `bash scripts/invariant-check.sh` → 5/5 PASS
3. Admin: dashboard shows all rows, no workspace toggle
4. Track owner (workspace=all): all-rows counts, workspace toggle visible
5. Track owner (workspace=my): scoped counts match assigned track only
6. Toggle on dashboard page switches scope and re-renders dashboard
7. Viewer: all-rows dashboard, no toggle
8. Empty scoped dashboard (scope=[]) → zeros/empty, no crash
9. Rows workspace toggle still works (Rows page unchanged)
10. P3-7 row click still works
11. P3-6 cell reveal still works
12. P3-5 provenance modal still works
13. Import stack still works

---

## P3-9 Dependency

P3-9 is the review checkpoint for Phase 3. It depends on P3-8 being
RELEASE_APPROVED. P3-8 does not depend on P3-9 for any implementation.
P3-9 is NOT implemented in this slice.

---

## Conflicts

None found.
