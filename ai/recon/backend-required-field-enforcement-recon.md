# RECON: backend-required-field-enforcement

## Capability
Backend Required Field Enforcement

## Date
2026-06-10

## State at Recon
RECON_READY

---

## 1. Current Frontend Required-Field Validation

`app/public/app.js` lines 232–238 (modal save handler):

```javascript
const missing = state.fields
  .filter((f) => f.required && !String(payload[f.key] || '').trim())
  .map((f) => f.label);
if (missing.length) {
  back.querySelector('#formErr').textContent = 'Required: ' + missing.join(', ');
  return;
}
```

Required fields from schema: owner, track, title, status (derived from `ROW_FIELDS` `required: true` flags).

This validation is **client-side only**. Any HTTP client that calls the API directly (curl, Postman, scripts) can bypass it by submitting POST /api/rows or PUT /api/rows/:id with blank required fields.

---

## 2. Current Backend validate() Behavior

`app/server.js`, `validate()` function:

```javascript
function validate(data, partial) {
  if (!partial && (!data.title || !data.title.trim())) return 'title is required';
  if (partial && data.title !== undefined && (!data.title || !data.title.trim())) return 'title cannot be empty';
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && data.status !== '' && !STATUSES.includes(data.status)) return 'invalid status';
  return null;
}
```

Gaps:
- Only `title` is enforced. `owner`, `track`, `status` are not validated.
- POST route assigns default `status = 'Not Started'` before validation — a POST with no status succeeds.
- `status !== ''` guard in enum check allows blank status through without error.
- No merge-check: a PUT that leaves a row with blank required fields passes.

---

## 3. Required Fields from ROW_FIELDS

From `app/db.js`:

| Field | `required` flag | DB constraint |
|-------|-----------------|---------------|
| title | true            | NOT NULL (server INSERT always includes it) |
| owner | true            | nullable column |
| track | true            | nullable column |
| status | true           | NOT NULL DEFAULT 'Not Started' CHECK(IN ...) |

Note: `owner` and `track` are nullable at the DB level. The required-field policy is application-layer policy, not DB-layer.

---

## 4. API Error Shape — Frontend Compatibility

`app/public/app.js` line 34:
```javascript
if (!res.ok) throw new Error((data && data.error) || ('Request failed: ' + res.status));
```

The frontend already extracts `data.error` from JSON responses and displays it in `#formErr`. All existing error responses use `{ error: "..." }` — confirmed consistent throughout `app/server.js`.

**No frontend change needed.** Backend validation errors will surface automatically in the modal error area.

---

## 5. Scope Confirmation

No approval, escalation, dashboard, agent, or NDT-SaaS code present in `app/`. Scope is clean.

---

## 6. Existing Tests / Smoke Scripts

No `scripts/verification/` corpus. Manual smoke tests have been run inline during previous verification tasks. The pattern is:
- Boot server
- POST /api/login → get cookie
- API calls with curl using the session cookie
- Check response status codes

---

## 7. Implementation Plan

**`validate()` replacement:**

```javascript
const REQUIRED_FIELDS = ROW_FIELDS.filter(f => f.required).map(f => f.key);
// → ['owner', 'track', 'title', 'status']

function validate(data, partial, existingRow) {
  if (!partial) {
    // POST: all required fields must be present and non-blank
    for (const field of REQUIRED_FIELDS) {
      if (!data[field] || !String(data[field]).trim()) return `${field} is required`;
    }
  } else {
    // PUT: supplied required fields must not be blank
    for (const field of REQUIRED_FIELDS) {
      if (data[field] !== undefined && !String(data[field] || '').trim())
        return `${field} cannot be empty`;
    }
    // Merge check: after applying update, all required fields must be non-blank
    if (existingRow) {
      const merged = { ...existingRow, ...data };
      for (const field of REQUIRED_FIELDS) {
        if (!merged[field] || !String(merged[field]).trim())
          return `${field} is required`;
      }
    }
  }
  if (data.type !== undefined && !ROW_TYPES.includes(data.type)) return 'invalid type';
  if (data.status !== undefined && !STATUSES.includes(data.status)) return 'invalid status';
  return null;
}
```

**POST route change:** Remove `if (!data.status) data.status = 'Not Started';` default — status must now be explicitly provided. (Frontend already sends `status: 'Not Started'` for new rows.)

**PUT route change:** Pass `existing` row to validate() as third arg for merge check.

**`status` enum check change:** Remove `data.status !== ''` guard — blank status should be caught by the required-field check, not silently allowed.

---

## 8. Risks

- Existing rows seeded with owner='demo'/track='T1 Device'/status='Not Started' — all non-blank; PUT on these will pass merge check.
- No schema migration needed.
- No frontend change needed.
- `type` remains optional (defaults to 'experiment' on POST); not a required field.
