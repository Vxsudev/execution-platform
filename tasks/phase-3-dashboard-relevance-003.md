# Task: Show workspace toggle on dashboard and add CSS scope label style

## Parent Spec
specs/phase-3-dashboard-relevance.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Two changes:
1. Show the All Tracks / My Track workspace toggle for track_owner on the
   dashboard page (not just Rows page).
2. Add `.dash-scope-label` CSS rule to style.css.

### Change 1 — Show toggle on dashboard page (app/public/app.js ~line 143)

Current render condition:
```javascript
${isTrackOwner() && isRowsPage ? `
  <div class="ws-tabs">
    <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
    <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
  </div>` : ''}
```

Change to:
```javascript
${isTrackOwner() && (isRowsPage || isDashPage) ? `
  <div class="ws-tabs">
    <button class="ws-tab${state.workspace === 'all' ? ' active' : ''}" id="wsAll">All Tracks</button>
    <button class="ws-tab${state.workspace === 'my' ? ' active' : ''}" id="wsMy">My Track</button>
  </div>` : ''}
```

### Change 2 — Bind toggle handlers on dashboard page (app/public/app.js ~line 187)

Current bind condition:
```javascript
if (isTrackOwner() && isRowsPage) {
  document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
  document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
}
```

Change to:
```javascript
if (isTrackOwner() && (isRowsPage || isDashPage)) {
  document.getElementById('wsAll').onclick = () => { state.workspace = 'all'; renderApp(); };
  document.getElementById('wsMy').onclick  = () => { state.workspace = 'my';  renderApp(); };
}
```

### Change 3 — Add CSS rule (app/public/style.css)

Append after existing rules:
```css
.dash-scope-label{font-size:12px;color:var(--muted);margin-bottom:10px;font-weight:400;}
```

## Acceptance Criteria
- [ ] Workspace toggle renders for track_owner when isDashPage
- [ ] Workspace toggle does NOT render for admin or viewer on any page
- [ ] Workspace toggle still renders for track_owner on isRowsPage (unchanged)
- [ ] wsAll and wsMy onclick handlers bind when isTrackOwner() && (isRowsPage || isDashPage)
- [ ] Clicking All Tracks on dashboard sets workspace='all' and re-renders
- [ ] Clicking My Track on dashboard sets workspace='my' and re-renders
- [ ] `.dash-scope-label` CSS rule exists in style.css
- [ ] `node --check public/app.js` exits 0

## Files Likely Affected
- app/public/app.js
- app/public/style.css

## Blocked By
- tasks/phase-3-dashboard-relevance-002.md
