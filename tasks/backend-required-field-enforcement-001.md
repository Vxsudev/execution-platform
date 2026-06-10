# Task: Update validate() in app/server.js to enforce required fields server-side

## Parent Spec
specs/backend-required-field-enforcement.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description

Edit `app/server.js` ONLY. Do NOT modify db.js, app.js, style.css, or index.html.

### Step 1 — Add REQUIRED_FIELDS constant after the FIELD_KEYS line

After the line:
```javascript
const FIELD_KEYS = ROW_FIELDS.map(f => f.key);
```

Add:
```javascript
const REQUIRED_FIELDS = ROW_FIELDS.filter(f => f.required).map(f => f.key);
```

### Step 2 — Replace the validate() function

Replace the existing `validate()` function in its entirety with:

```javascript
function validate(data, partial, existingRow) {
  if (!partial) {
    for (const field of REQUIRED_FIELDS) {
      if (!data[field] || !String(data[field]).trim()) return `${field} is required`;
    }
  } else {
    for (const field of REQUIRED_FIELDS) {
      if (data[field] !== undefined && !String(data[field] || '').trim())
        return `${field} cannot be empty`;
    }
    if (existingRow) {
      const merged = { ...existingRow, ...data };
      for (const field of REQUIRED_FIELDS) {
        if (!merged[field] || !String(merged[field]).trim()) return `${field} is required`;
      }
    }
  }
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
  return null;
}
```

Key changes from previous version:
- Enforces all four required fields (owner, track, title, status) not just title
- Adds merge check for PUT: after merging existing row + incoming data, required fields must remain non-blank
- Removes the `data.status !== ''` guard from the enum check (blank status is now caught as required-field violation first)
- validate() now takes a third arg `existingRow` (null for POST, existing row object for PUT)

### Step 3 — Remove the status default in the POST route

In the POST handler, find and remove this line:
```javascript
  if (!data.status) data.status = 'Not Started';
```

Status must now be explicitly supplied by the caller. The type default (`if (!data.type) data.type = 'experiment';`) stays.

After removal the POST handler should look like:
```javascript
app.post('/api/rows', requireAuth, (req, res) => {
  const data = sanitize(req.body || {});
  if (!data.type) data.type = 'experiment';
  const err = validate(data, false, null);
  if (err) return res.status(400).json({ error: err });
  ...
```

### Step 4 — Pass existingRow to validate() in the PUT route

In the PUT handler, change the validate() call from:
```javascript
  const err = validate(data, true);
```
to:
```javascript
  const err = validate(data, true, existing);
```

### Step 5 — Update app/README.md

Add a brief "API Validation" section to `app/README.md` documenting:
- Required fields on POST: title, owner, track, status (all must be non-blank)
- PUT partial updates are allowed; blank-ing a required field returns 400
- Error responses: `{ "error": "field is required" }` HTTP 400

## Acceptance Criteria
- [ ] REQUIRED_FIELDS constant defined from ROW_FIELDS (not hardcoded).
- [ ] validate() enforces all four required fields on POST (title, owner, track, status).
- [ ] validate() rejects blank required fields on PUT (supplied field check).
- [ ] validate() applies merge check on PUT using existing row.
- [ ] POST route: no status default assignment before validate().
- [ ] PUT route: passes `existing` as third arg to validate().
- [ ] status enum check has no `data.status !== ''` guard.
- [ ] No modification to db.js, app.js, style.css, or index.html.

## Files Likely Affected
- `app/server.js`
- `app/README.md`

## Blocked By
- none
