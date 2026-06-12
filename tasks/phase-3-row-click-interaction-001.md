# Task: Add CSS for clickable row affordance

## Parent Spec
specs/phase-3-row-click-interaction.md

## Phase
phase-build

## Status
done

## Layer
styling

## Description
Add 2 CSS rules for `.clickable-row` to `app/public/style.css`. No JS or HTML changes.

### Rules to add (append after existing styles)

```css
.clickable-row{cursor:pointer}
.clickable-row:focus-visible{outline:2px solid var(--accent);outline-offset:-2px}
```

**Note on hover**: `tr:hover td{background:var(--panel2)}` already exists at line 54 and
applies to all rows including `.clickable-row`. No additional hover rule needed.

**Note on focus outline**: Using `:focus-visible` (not `:focus`) so the outline only
appears for keyboard focus — not on mouse click — matching modern browser behavior.

### What must NOT change
- `tr:hover td` rule at line 54 — unchanged
- All existing `.trunc`, `.cell-toggle`, `.modal-wide` rules — unchanged
- No layout changes

## Acceptance Criteria
- [ ] `.clickable-row{cursor:pointer}` exists in style.css
- [ ] `.clickable-row:focus-visible` with `outline:2px solid var(--accent)` exists
- [ ] No existing rules modified
- [ ] `tr:hover td` still at line 54 (unchanged)

## Files Likely Affected
- app/public/style.css

## Blocked By
- none
