# Task: Update renderDashboard() to use dashboardRows() and add scope label

## Parent Spec
specs/phase-3-dashboard-relevance.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `renderDashboard()` to use `dashboardRows()` for the three `byCount`
calls and add a `.dash-scope-label` context subtitle.

### Update byCount calls in renderDashboard() (~line 426-428)

Current:
```javascript
<div class="card"><h3>Items by status</h3>${dashCountList(byCount(state.rows, 'status'))}</div>
<div class="card"><h3>Items by track</h3>${dashCountList(byCount(state.rows, 'track'))}</div>
<div class="card"><h3>Owner load (top 10)</h3>${dashCountList(byCount(state.rows, 'owner'), 10)}</div>
```

Change to:
```javascript
<div class="card"><h3>Items by status</h3>${dashCountList(byCount(dashboardRows(), 'status'))}</div>
<div class="card"><h3>Items by track</h3>${dashCountList(byCount(dashboardRows(), 'track'))}</div>
<div class="card"><h3>Owner load (top 10)</h3>${dashCountList(byCount(dashboardRows(), 'owner'), 10)}</div>
```

### Add scope label in renderDashboard() (~line 411)

After `const s = dashStats();` at the top of `renderDashboard()`, add:

```javascript
const scopeLabel = isTrackOwner()
  ? (state.workspace === 'my'
      ? `My Track (${userScope().join(', ') || 'unscoped'})`
      : 'All Tracks')
  : 'All Tracks';
```

Then inside the `<div class="dash">` opening, add the scope label before
the first card:

Current:
```javascript
  return `
    <div class="dash">
      <div class="card">
```

Change to:
```javascript
  return `
    <div class="dash">
      <div class="dash-scope-label">${esc(scopeLabel)}</div>
      <div class="card">
```

## Acceptance Criteria
- [ ] All 3 `byCount(state.rows, ...)` calls in renderDashboard() changed to `byCount(dashboardRows(), ...)`
- [ ] `scopeLabel` computed from `isTrackOwner()` and `state.workspace`
- [ ] `.dash-scope-label` div renders the scope label in dashboard
- [ ] Admin sees "All Tracks" scope label
- [ ] Viewer sees "All Tracks" scope label
- [ ] Track owner (workspace=all) sees "All Tracks" scope label
- [ ] Track owner (workspace=my) sees "My Track (track1, track2)" scope label
- [ ] `node --check public/app.js` exits 0

## Files Likely Affected
- app/public/app.js

## Blocked By
- tasks/phase-3-dashboard-relevance-001.md
