# Task: Verify left-nav-rail layout — syntax, invariants, smoke tests

## Parent Spec
specs/left-nav-rail-layout.md

## Phase
phase-build

## Status
done

## Layer
verification

## Description

Verify that the implementation in task-001 is correct and complete before release.
All steps must pass before marking this task done.

### Step 1 — Syntax check

```
node --check app/public/app.js
```
Must exit 0. If it fails, fix the syntax error in app.js and recheck.

### Step 2 — Invariant check

```
bash scripts/invariant-check.sh
```
Must report 5/5 passing. If any fail, investigate and fix.

### Step 3 — Structural grep checks (no server required)

All of these must pass:

```bash
# Old nav IDs must be gone
grep -c "rowsPageBtn\|dashPageBtn\|usersPageBtn\|importPageBtn" app/public/app.js
# → must print 0

# New nav IDs must be present
grep -c "navRows\|navDash\|navUsers\|navImport" app/public/app.js
# → must print a number > 0

# App-shell structure present
grep -c "app-shell\|nav-rail\|nav-item\|main-pane\|page-header" app/public/app.js
# → must print a number > 0

# CSS rules present
grep -c "\.app-shell\|\.nav-rail\|\.nav-item\|\.main-pane\|\.page-header" app/public/style.css
# → must print a number > 0

# Existing topbar CSS NOT removed
grep -c "\.topbar" app/public/style.css
# → must print a number > 0

# rowCount still present (required by refreshTable, isUsersPage, isDashPage blocks)
grep -c "rowCount" app/public/app.js
# → must print a number > 0

# workspace toggle uses wsAll/wsMy (unchanged)
grep -c "wsAll\|wsMy" app/public/app.js
# → must print a number > 0

# state.workspace semantics unchanged
grep -c "state\.workspace" app/public/app.js
# → must print a number > 0
```

### Step 4 — Browser smoke (start the server, then manually test)

Start the app:
```
cd app && node server.js
```
(or `npm start` if that is defined)

**Admin smoke** (log in as admin with admin credentials):

1. Left rail appears with 4 items: Rows (active), Dashboard, Users, Import
2. Click Dashboard → left rail shows Dashboard as active, page header shows "Dashboard"
3. Click Users → left rail shows Users as active, user list renders, "+ New user" in header
4. Click Import → left rail shows Import as active, import panel renders
5. Click Rows → back to rows table, row count in header, "+ New row" button in header
6. Filters (Status/Track/Type) and search box work
7. Click a table row → edit form opens; clicking a specific cell highlights that field (clicked-cell field highlight preserved)
8. Details button → Details modal opens
9. Delete button on a row → confirm dialog → row deleted
10. Log out → redirects to login page

**Track owner smoke** (log in as vasu/vasu123 or equivalent track_owner):

1. Left rail shows 2 items only: Rows, Dashboard (no Users, no Import)
2. On Rows page: "All Tracks" / "My Track" workspace toggle appears in page
3. Click My Track → table filters to track owner's scope
4. Click All Tracks → table shows all rows
5. Click Dashboard → workspace toggle appears on Dashboard page too
6. My Track on Dashboard → dashboardRows() filters correctly

**Viewer smoke** (if a viewer user exists):

1. Left rail shows only Rows, Dashboard (no Users, no Import)
2. No workspace toggle visible on either page
3. No delete button on rows

### Step 5 — git status check

```
git diff --stat
```
Must show ONLY `app/public/app.js` and `app/public/style.css` (plus OS artifacts:
`tasks/`, `specs/`, `ai/`). No server files, no db files, no package.json, no Railway config.

---

## Acceptance Criteria
- [ ] `node --check app/public/app.js` exits 0
- [ ] `bash scripts/invariant-check.sh` reports 5/5
- [ ] All grep checks in Step 3 pass (old IDs gone, new IDs present, CSS rules appended, topbar CSS preserved)
- [ ] Admin browser smoke: all 4 nav items work, active states correct, all page features intact (row edit, cell-highlight, Details, Delete, Import, Users, logout)
- [ ] Track owner browser smoke: only Rows+Dashboard visible in rail, workspace toggle appears on BOTH pages
- [ ] git diff only touches allowed surfaces

## Files Likely Affected
- (read-only verification — no source files modified by this task)

## Blocked By
- tasks/left-nav-rail-layout-001.md
