# Task: Add dashboardRows() helper and update dashboard stat helpers

## Parent Spec
specs/phase-3-dashboard-relevance.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Add a `dashboardRows()` helper function and update all dashboard stat helpers
to use it instead of `state.rows` directly.

### Add dashboardRows() (after visibleRowsForWorkspace, ~line 35)

```javascript
function dashboardRows() {
  if (isTrackOwner()) return visibleRowsForWorkspace(state.rows);
  return state.rows;
}
```

For track_owner: workspace-aware (my=scoped, all=all rows via
visibleRowsForWorkspace). For admin/viewer: always returns state.rows unchanged.

### Update dashStats() (~line 380)

Current:
```javascript
function dashStats() {
  const rows = state.rows;
```

Change to:
```javascript
function dashStats() {
  const rows = dashboardRows();
```

### Update blockedRows() (~line 356)

Current:
```javascript
function blockedRows() { return state.rows.filter((r) => r.status === 'Blocked'); }
```

Change to:
```javascript
function blockedRows() { return dashboardRows().filter((r) => r.status === 'Blocked'); }
```

### Update overdueRows() (~line 358)

Current:
```javascript
function overdueRows() {
  const now = new Date();
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  return state.rows.filter((r) => {
```

Change to:
```javascript
function overdueRows() {
  const now = new Date();
  const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  return dashboardRows().filter((r) => {
```

### Update recentRows() (~line 368)

Current:
```javascript
function recentRows() {
  return [...state.rows]
```

Change to:
```javascript
function recentRows() {
  return [...dashboardRows()]
```

### Update openNextActions() (~line 374)

Current:
```javascript
function openNextActions() {
  return state.rows
```

Change to:
```javascript
function openNextActions() {
  return dashboardRows()
```

## Acceptance Criteria
- [ ] `dashboardRows()` function exists after `visibleRowsForWorkspace`
- [ ] `dashboardRows()` returns `visibleRowsForWorkspace(state.rows)` for track_owner
- [ ] `dashboardRows()` returns `state.rows` for admin and viewer
- [ ] `dashStats()` uses `dashboardRows()`
- [ ] `blockedRows()` uses `dashboardRows()`
- [ ] `overdueRows()` uses `dashboardRows()`
- [ ] `recentRows()` uses `dashboardRows()`
- [ ] `openNextActions()` uses `dashboardRows()`
- [ ] `node --check public/app.js` exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- none
