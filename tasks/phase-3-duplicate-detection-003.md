# Task: Add duplicate UX to import preview and commit panels

## Parent Spec
specs/phase-3-duplicate-detection.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description
Update `app/public/app.js` and `app/public/style.css` to surface duplicate
detection in the Import panel.

### State addition (app/public/app.js, near top state object)

Add `allowDuplicates: false` to the initial state. Reset to false on each new
preview load.

### renderImportPanel() changes

1. Preview summary line: if `p.summary.duplicate_count > 0`, append
   `· <span class="warn-text">N duplicate(s)</span>` to the summary line.

2. Importable row preview table: for rows where `row.duplicate === true`, add a
   `<span class="badge warn">Duplicate</span>` badge after the title or row
   number. Keep existing structure; badge is additive.

3. Allow-duplicates checkbox: render BELOW the commit button area, only when
   `p.summary.duplicate_count > 0`:
   ```html
   <label class="import-dup-label">
     <input type="checkbox" id="importAllowDupsCb" /> Import duplicates anyway
   </label>
   ```
   Default unchecked.

### bindImportActions() changes

1. After preview loads, reset `state.allowDuplicates = false`.

2. For the checkbox (`importAllowDupsCb`): bind `onchange` to update
   `state.allowDuplicates`:
   ```javascript
   const cb = document.getElementById('importAllowDupsCb');
   if (cb) cb.onchange = () => { state.allowDuplicates = cb.checked; };
   ```

3. Commit payload: include `allow_duplicates: state.allowDuplicates || false`:
   ```javascript
   const res = await api('/import/commit', { method: 'POST', body: {
     filename: state.importFilename || '',
     sheet: state.importPreview.summary.sheet || '',
     rows: state.importPreview.rows,
     allow_duplicates: state.allowDuplicates || false,
   }});
   ```

4. Post-commit alert: update to show duplicate_skipped_count if present:
   ```javascript
   let msg = `Imported ${res.inserted_count} row(s)`;
   if (res.skipped_count) msg += `, ${res.skipped_count} skipped`;
   if (res.duplicate_skipped_count) msg += ` (${res.duplicate_skipped_count} duplicate(s))`;
   alert(msg + '.');
   ```

5. Reset `state.allowDuplicates = false` after commit.

### style.css additions

```css
.badge { display:inline-block; font-size:10px; padding:1px 6px; border-radius:3px; font-weight:600; margin-left:4px; }
.badge.warn { background:#fff3cd; color:#856404; border:1px solid #ffc107; }
.warn-text { color:#856404; }
.import-dup-label { display:flex; align-items:center; gap:6px; font-size:13px; margin-top:8px; cursor:pointer; }
```

Do NOT change: renderUsersPanel, dashboard rendering, table row click behavior,
provenance/observations UI. Do NOT add any import_observations display.
Preserve Delete batch button and P3-2 bindings.

## Acceptance Criteria
- [ ] Preview summary shows "N duplicate(s)" when duplicate_count > 0
- [ ] Duplicate rows in preview table show Duplicate badge
- [ ] "Import duplicates anyway" checkbox renders only when duplicates exist
- [ ] Checkbox is unchecked by default
- [ ] Commit payload includes allow_duplicates field
- [ ] Post-commit alert shows duplicate_skipped_count if > 0
- [ ] P3-2 Delete batch button and flow still works
- [ ] No provenance/observations/table/dashboard UI added
- [ ] node --check app/public/app.js exits 0

## Files Likely Affected
- app/public/app.js
- app/public/style.css

## Blocked By
- tasks/phase-3-duplicate-detection-002.md
