# Task: Add CSS for inline cell reveal

## Parent Spec
specs/phase-3-dense-cell-reveal.md

## Phase
phase-build

## Status
done

## Layer
styling

## Description
Add all CSS rules required by the P3-6 dense cell reveal to `app/public/style.css`.
No changes to HTML or JS in this task.

### Rules to add (append after existing styles)

```css
td.trunc.has-toggle{overflow:visible;white-space:normal;vertical-align:top;max-width:260px}
td.trunc.has-toggle .cell-text{display:block;max-width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.cell-toggle{display:inline-block;font-size:10px;padding:1px 5px;margin-top:2px;border-radius:3px;border:1px solid var(--line);background:transparent;color:var(--accent);cursor:pointer;line-height:1.4}
.cell-toggle:focus{outline:2px solid var(--accent);outline-offset:1px}
td.trunc.has-toggle.expanded{max-width:420px}
td.trunc.has-toggle.expanded .cell-text{overflow:visible;text-overflow:clip;white-space:pre-wrap;word-break:break-word;max-width:400px}
```

### What these rules do

- `td.trunc.has-toggle`: overrides the base `.trunc` to show the button below the text. Sets `overflow:visible` and `white-space:normal` so td stacks text + button, keeps `max-width:260px`.
- `.cell-text` (inside `has-toggle`): truncation ellipsis moves to this inner span.
- `.cell-toggle`: the More/Less button — small, accented, keyboard-focusable.
- `.cell-toggle:focus`: visible focus ring.
- `td.trunc.has-toggle.expanded`: widens cell to 420px when expanded.
- `.cell-text` (inside `expanded`): switches to `pre-wrap` to show multiline content.

### What must NOT change
- `td.trunc` base rule at line 53: unchanged
- All other existing rules

## Acceptance Criteria
- [ ] `td.trunc.has-toggle` rule exists with overflow:visible
- [ ] `td.trunc.has-toggle .cell-text` rule with overflow:hidden, text-overflow:ellipsis exists
- [ ] `.cell-toggle` rule with color:var(--accent) exists
- [ ] `.cell-toggle:focus` with outline exists
- [ ] `td.trunc.has-toggle.expanded` with max-width:420px exists
- [ ] `td.trunc.has-toggle.expanded .cell-text` with white-space:pre-wrap exists
- [ ] Original `td.trunc` base rule unchanged
- [ ] No existing rules modified

## Files Likely Affected
- app/public/style.css

## Blocked By
- none
