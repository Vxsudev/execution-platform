# Task: Tag cells with column key and highlight the matching form field on click

## Parent Spec
specs/clicked-cell-field-highlight.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Implement clicked-cell → form-field highlight in `app/public/app.js` (+ minimal `style.css`).

`app/public/app.js`:
1. `renderTable` (cells): add `data-col="${k}"` to every data `<td>` across all branches — the
   `type` cell, the `status` cell, the trunc cells (expanded, >80 with toggle, ≤80), and the
   default text cell. The Actions `<td>` gets no `data-col`.
2. `bindRowActions` row `onclick`: keep the existing guard
   `if (e.target.closest('button, a, input, select, textarea')) return;`, then read
   `const cell = e.target.closest('td[data-col]');` and call `openForm(row, cell ? cell.dataset.col : null)`.
   Leave the Enter `onkeydown` as `openForm(row)` (no specific cell → no highlight).
3. `openForm(row, focusKey)`: add the second parameter. After `document.body.appendChild(back)`
   and binding cancel/save, if `focusKey`:
   - `const control = back.querySelector('[data-k="' + focusKey + '"]');`
   - if `control`: `(control.closest('.field') || control).classList.add('field-highlight');`
     then `control.scrollIntoView({ block: 'center', behavior: 'smooth' })` and
     `control.focus({ preventScroll: true })` (wrap focus/scroll in try/catch). If no control,
     open unchanged.

`app/public/style.css`: add a subtle highlight:
```
@keyframes fieldFlash{from{background:rgba(110,168,254,.18)}to{background:transparent}}
.field-highlight{animation:fieldFlash 2.4s ease-out;border-radius:8px}
.field-highlight>label{color:var(--accent)}
.field-highlight input,.field-highlight select,.field-highlight textarea{border-color:var(--accent)}
```

Do NOT change Details/Delete/More-Less handlers, the row-click-to-edit contract, the
`.modal-back` z-index, `app/server.js`, `app/db.js`, or `index.html`. Highlight must not change
values, submit, or block typing.

## Acceptance Criteria
- [ ] Every data `<td>` carries `data-col="${k}"`; Actions cell does not
- [ ] Row `onclick` derives `td[data-col]` and calls `openForm(row, col)` (guard preserved)
- [ ] `openForm(row, focusKey)` adds `.field-highlight` to the matching `.field`, scrolls it into view, and focuses the control
- [ ] No focusKey / no matching field → form opens unchanged (no error)
- [ ] `.field-highlight` + `@keyframes fieldFlash` added to style.css (subtle, dark-mode, uses --accent)
- [ ] Details/Delete/More-Less/Enter-open/Save/modal-layering unchanged
- [ ] `node --check app/public/app.js` passes; `app/server.js`/`app/db.js`/`index.html` unchanged

## Files Likely Affected
- app/public/app.js (renderTable cells, bindRowActions onclick, openForm signature+highlight)
- app/public/style.css (.field-highlight + keyframes)

## Blocked By
- tasks/clicked-cell-field-highlight-001.md
