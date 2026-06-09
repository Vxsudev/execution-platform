# Task: Copy frontend assets to app/public/

## Parent Spec
specs/promote-execution-table-v1-scaffold.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Copy the entire `prototypes/execution-table-app/public/` directory tree to
`app/public/`. No changes to any file content.

Files to copy:
- `prototypes/execution-table-app/public/index.html` → `app/public/index.html`
- `prototypes/execution-table-app/public/app.js`     → `app/public/app.js`
- `prototypes/execution-table-app/public/style.css`  → `app/public/style.css`

If additional files exist under public/, copy them all without modification.

Do NOT modify any file under `prototypes/execution-table-app/public/`.

## Acceptance Criteria
- [ ] `app/public/index.html` exists.
- [ ] `app/public/app.js` exists.
- [ ] `app/public/style.css` exists.
- [ ] All files under `app/public/` are byte-identical to their prototype counterparts.
- [ ] `prototypes/execution-table-app/public/` is unmodified.

## Files Likely Affected
- `app/public/index.html` (new)
- `app/public/app.js` (new)
- `app/public/style.css` (new)

## Blocked By
- tasks/promote-execution-table-v1-scaffold-002.md
