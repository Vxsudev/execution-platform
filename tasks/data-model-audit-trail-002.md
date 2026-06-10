# Task: Server-stamp created_by and updated_by from authenticated session in POST and PUT

## Parent Spec
specs/data-model-audit-trail.md

## Phase
phase-build

## Status
done

## Layer
backend

## Description

Edit `app/server.js` ONLY. `app/db.js` was already updated by task 001.

### Change 1 — POST handler: stamp created_by and updated_by

Find the POST route handler (currently around lines 109–118):
```javascript
app.post('/api/rows', requireAuth, (req, res) => {
  const data = sanitize(req.body || {});
  if (!data.type) data.type = 'experiment';
  const err = validate(data, false, null);
  if (err) return res.status(400).json({ error: err });
  const keys = Object.keys(data);
  const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
    .run(...keys.map(k => data[k]));
  ...
```

After the `validate` check (the `if (err)` line) and before `const keys = Object.keys(data)`, add:

```javascript
  data.created_by = req.user.username;
  data.updated_by = req.user.username;
```

The full POST handler must look like:
```javascript
app.post('/api/rows', requireAuth, (req, res) => {
  const data = sanitize(req.body || {});
  if (!data.type) data.type = 'experiment';
  const err = validate(data, false, null);
  if (err) return res.status(400).json({ error: err });
  data.created_by = req.user.username;
  data.updated_by = req.user.username;
  const keys = Object.keys(data);
  const info = db.prepare(`INSERT INTO entries (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
    .run(...keys.map(k => data[k]));
  res.status(201).json({ row: db.prepare('SELECT * FROM entries WHERE id = ?').get(Number(info.lastInsertRowid)) });
});
```

**Why after validate()?** `validate()` only checks ROW_FIELDS-derived keys. Adding audit stamps
after validate() keeps them out of validation scope — they are server-controlled, not user-supplied.

**Why after sanitize()?** `sanitize()` only passes FIELD_KEYS (ROW_FIELDS keys). Any client-submitted
`created_by`/`updated_by` is already stripped. Adding them to `data` after sanitize() is the only
way they get into the INSERT, and only with the session value.

### Change 2 — PUT handler: stamp updated_by alongside updated_at

Find the PUT handler setSql line (currently around lines 125–129):
```javascript
  const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now')";
  db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.params.id);
```

Change to:
```javascript
  const setSql = keys.map(k => `${k} = ?`).join(', ') + ", updated_at = datetime('now'), updated_by = ?";
  db.prepare(`UPDATE entries SET ${setSql} WHERE id = ?`).run(...keys.map(k => data[k]), req.user.username, req.params.id);
```

`updated_by = ?` is added to the SET clause. The corresponding bind value `req.user.username`
is inserted between the data values and the row id in `.run()`.

### Preservation requirements

- `validate()` function is unchanged (signature + body).
- `sanitize()` function is unchanged.
- `REQUIRED_FIELDS` definition is unchanged.
- type / status / track enum checks unchanged.
- DELETE route unchanged.
- GET routes unchanged.
- `created_at` is NOT explicitly stamped — DB DEFAULT handles it.
- PUT does NOT touch `created_by` or `created_at` — originals preserved.
- Error format `{ "error": "..." }` HTTP 400 — unchanged.

## Acceptance Criteria
- [ ] POST route: `data.created_by = req.user.username` added after validate() check.
- [ ] POST route: `data.updated_by = req.user.username` added after validate() check.
- [ ] POST route: both stamps are BEFORE `const keys = Object.keys(data)`.
- [ ] PUT route: setSql includes `updated_by = ?`.
- [ ] PUT route: `.run()` includes `req.user.username` between data values and row id.
- [ ] validate() function is unchanged.
- [ ] sanitize() function is unchanged.
- [ ] GET / DELETE routes unchanged.
- [ ] POST valid row → 201 with created_by/updated_by = authenticated username.
- [ ] POST with `{"created_by":"hacker"}` → created_by = session username (forge ignored).
- [ ] PUT valid row → 200 with updated_by = authenticated username; created_by unchanged.

## Files Likely Affected
- `app/server.js`

## Blocked By
- tasks/data-model-audit-trail-001.md
