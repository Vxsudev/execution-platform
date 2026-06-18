# Task: Verify collapsible nav rail — syntax, structure, smoke tests

## Parent Spec
specs/collapsible-nav-rail.md

## Phase
phase-build

## Status
in-progress

## Layer
verification

## Description

Verify the implementation from task-001 is correct and complete. All steps must pass.

### Step 1 — Syntax check

```
node --check app/public/app.js
```
Must exit 0.

### Step 2 — Invariant check

```
bash scripts/invariant-check.sh
```
Must report 5/5.

### Step 3 — Structural grep checks (no server required)

```bash
# navCollapsed in state initializer
grep -c "navCollapsed" app/public/app.js
# → > 0

# Toggle button ID
grep -c "navToggle" app/public/app.js
# → > 0

# localStorage key
grep -c "astraX.navCollapsed" app/public/app.js
# → > 0

# nav-item-abbr spans present
grep -c "nav-item-abbr" app/public/app.js
# → > 0

# abbreviated labels
grep -c '"Ro"\|"Da"\|"Us"\|"Im"' app/public/app.js
# → > 0

# CSS collapsed class
grep -c "nav-rail.collapsed\|\.nav-toggle\|\.nav-brand\|nav-item-abbr" app/public/style.css
# → > 0

# Existing nav-rail CSS not removed
grep -c "\.nav-rail{" app/public/style.css
# → > 0

# Old nav IDs still present (nav items unchanged)
grep -c "navRows\|navDash" app/public/app.js
# → > 0
```

### Step 4 — Browser smoke (server running at http://localhost:3000)

**Collapse/expand cycle:**
1. Log in as admin
2. Left rail shows: astraX brand, Rows, Dashboard, Users, Import, "Signed in as ...", Log out
3. `«` toggle button is visible at right of logo bar
4. Click `«` → rail narrows to ~52px, items show Ro/Da/Us/Im abbreviations, toggle now shows `»`
5. Click `»` → rail expands back to 210px, full labels restored, toggle shows `«` again

**localStorage persistence:**
6. While collapsed, refresh the page (F5 / Cmd+R)
7. Rail loads in collapsed state (localStorage preserved)
8. While expanded, refresh the page
9. Rail loads in expanded state

**Navigation from collapsed rail:**
10. Click "Da" → Dashboard page loads, rail remains collapsed
11. Click "Us" → Users page loads
12. Click "Im" → Import page loads
13. Click "Ro" → Rows page loads

**All Tracks / My Track (track owner role):**
14. Log out, log in as track owner (vasu/vasu123 or equivalent)
15. Collapsed rail shows only Ro/Da (no Us/Im)
16. Workspace toggle appears on Rows and Dashboard pages in both rail states

**Functional behaviors preserved:**
17. + New row opens the form
18. Click a table row → edit form opens; click a specific cell → that field highlights (cell-highlight)
19. Logout button in collapsed state (→ symbol) → logs out, redirects to login

### Step 5 — git diff check

```
git diff --stat
```
Must show only `app/public/app.js`, `app/public/style.css`, and OS artifacts. No backend files.

---

## Acceptance Criteria
- [ ] `node --check app/public/app.js` exits 0
- [ ] `bash scripts/invariant-check.sh` reports 5/5
- [ ] All grep checks in Step 3 pass
- [ ] Browser: collapse/expand toggle works visually (52px collapsed, 210px expanded)
- [ ] Browser: localStorage persists state across page refresh
- [ ] Browser: all nav items work from collapsed state
- [ ] Browser: workspace toggle, + New row, row edit, cell highlight, logout all work
- [ ] git diff only touches allowed surfaces (no backend files)

## Files Likely Affected
- (read-only verification — no source files modified by this task)

## Blocked By
- tasks/collapsible-nav-rail-001.md
