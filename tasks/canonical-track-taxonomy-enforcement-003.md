# Task: Update app.js to load tracks from schema and use for filter dropdown

## Parent Spec
specs/canonical-track-taxonomy-enforcement.md

## Phase
phase-build

## Status
done

## Layer
frontend

## Description

Edit `app/public/app.js` ONLY. Do NOT modify db.js, server.js, style.css, or index.html.

### Step 1 — Add tracks to state

Find the state object:
```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' },
};
```

Change it to:
```javascript
const state = {
  user: null, fields: [], types: [], statuses: [], tracks: [], rows: [], editing: null,
  search: '', filters: { status: '', track: '', type: '' },
};
```

### Step 2 — Load schema.tracks in init()

Find the init function where schema is loaded:
```javascript
    const schema = await api('/schema');
    state.fields = schema.fields; state.types = schema.types; state.statuses = schema.statuses;
```

Change it to:
```javascript
    const schema = await api('/schema');
    state.fields = schema.fields; state.types = schema.types; state.statuses = schema.statuses;
    state.tracks = schema.tracks || [];
```

### Step 3 — Replace distinctTracks() with state.tracks in the filter select

Find in renderApp():
```javascript
      <select id="fTrack" title="Filter by track">${optionTags(distinctTracks(), state.filters.track)}</select>
```

Change it to:
```javascript
      <select id="fTrack" title="Filter by track">${optionTags(state.tracks, state.filters.track)}</select>
```

### Step 4 — Remove distinctTracks() function (optional but clean)

The `distinctTracks()` function at lines 92–93 is no longer needed for the canonical filter.
Remove it entirely:
```javascript
function distinctTracks() {
  return [...new Set(state.rows.map((r) => r.track).filter(Boolean))].sort();
}
```

If removing it, verify no other call site uses it. (It was only used in renderApp() for the filter select, which is now replaced.)

### Important: keep all other behavior

- `filteredRows()` with `if (track && r.track !== track)` — do NOT modify
- Status/Type filters — do NOT modify
- Search — do NOT modify
- CRUD (create, edit, delete, refresh) — do NOT modify
- Modal form — do NOT modify (track field will auto-render as select since ROW_FIELDS.input is now 'select')

Note: The modal form already handles `input: 'select'` fields generically:
```javascript
if (f.input === 'select') {
  const opts = f.options.map(...)
  control = `<select data-k="${f.key}">${opts}</select>`;
}
```
This will automatically render the track dropdown correctly using the canonical TRACKS options from schema.fields. No additional modal change needed.

Also update app/README.md:
- Add a "Track Taxonomy" section listing the 6 canonical tracks
- Note that track is dropdown-only (not free-text)

## Acceptance Criteria
- [ ] state object has `tracks: []`.
- [ ] init() sets `state.tracks = schema.tracks || []`.
- [ ] renderApp() uses `state.tracks` for the track filter `<select>`, not `distinctTracks()`.
- [ ] `distinctTracks()` function removed (or left but no longer used).
- [ ] filteredRows(), status/type filters, search, and CRUD are unchanged.
- [ ] Modal track field auto-renders as select (no modal code change needed).
- [ ] README updated with canonical track taxonomy.
- [ ] No modification to db.js, server.js, style.css, or index.html.

## Files Likely Affected
- `app/public/app.js`
- `app/README.md`

## Blocked By
- tasks/canonical-track-taxonomy-enforcement-002.md
