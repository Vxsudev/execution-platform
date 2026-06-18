# Task: Confirm frontend has no password length restriction

## Parent Spec
specs/remove-password-length-restrictions.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Frontend check only (recon found nothing to change). The login password field
(`app/public/app.js`, `#p`) and the user-form password field (`#uf-password`) are plain
`type="password"` inputs with **no** `minlength` attribute and **no** length validation in the
save handler (`openUserForm` only does `if (password) payload.password = password;`). There is no
password length rule in the frontend to remove.

Outcome: **no change to `app/public/*`.** This task documents the deliberate decision so the
responsibility group is covered. Do not modify `app/public/app.js`, `app/public/index.html`, or
`app/public/style.css`.

## Acceptance Criteria
- [ ] Confirmed no `minlength` / password length validation in `app/public/app.js` or `index.html`
- [ ] `app/public/app.js`, `app/public/index.html`, `app/public/style.css` unchanged

## Files Likely Affected
- (none — confirmation only)

## Blocked By
- tasks/remove-password-length-restrictions-001.md
