# Task: Add CSS classes for wide Details modal

## Parent Spec
specs/phase-3-import-provenance.md

## Phase
phase-build

## Status
done

## Layer
styling

## Description
Add all CSS classes required by the P3-5 Details modal redesign to
`app/public/style.css`. No changes to HTML or JS in this task.

### Classes to add

```css
/* Details modal — wide variant */
.modal-wide { width: 760px; }

/* Detail sections */
.detail-section { margin-bottom: 18px; }
.detail-section h3 { font-size: 12px; text-transform: uppercase; letter-spacing: .06em;
  color: var(--muted); font-weight: 600; margin: 0 0 10px; padding-bottom: 6px;
  border-bottom: 1px solid var(--line); }

/* 2-col label/value grid for compact fields */
.detail-grid { display: grid; grid-template-columns: 140px 1fr; gap: 6px 14px; font-size: 13px; }
.detail-label { color: var(--muted); }
.detail-value { color: var(--text); word-break: break-word; }

/* Full-width long text block */
.detail-long { grid-column: 1 / -1; font-size: 13px; color: var(--text);
  white-space: pre-wrap; word-break: break-word; background: var(--panel2);
  border: 1px solid var(--line); border-radius: 6px; padding: 8px 10px;
  max-height: 160px; overflow-y: auto; }
.detail-long-label { grid-column: 1 / -1; color: var(--muted); font-size: 12px;
  margin-top: 8px; }

/* Origin provenance badge */
.origin-badge { display: inline-block; font-size: 11px; font-weight: 600;
  padding: 2px 8px; border-radius: 4px; }
.origin-badge.imported { background: rgba(59,130,246,.18); color: var(--accent);
  border: 1px solid rgba(59,130,246,.35); }
.origin-badge.manual { background: var(--panel2); color: var(--muted);
  border: 1px solid var(--line); }
```

Add these at the end of `app/public/style.css` after the existing dashboard styles.

### Reuse existing classes
- `.modal-back` — unchanged
- `.modal` — unchanged; `.modal-wide` overrides width only
- `.modal-actions` — unchanged
- `.btn.ghost` — Close button unchanged

## Acceptance Criteria
- [ ] .modal-wide exists in style.css with width 760px
- [ ] .detail-section and h3 sub-rule exist
- [ ] .detail-grid with 140px first column exists
- [ ] .detail-label and .detail-value exist
- [ ] .detail-long and .detail-long-label exist
- [ ] .origin-badge, .origin-badge.imported, .origin-badge.manual exist
- [ ] No existing rules modified or removed
- [ ] No layout regressions in table or import panel

## Files Likely Affected
- app/public/style.css

## Blocked By
- tasks/phase-3-import-provenance-001.md
