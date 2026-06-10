# Spec: Phase 2 — XLSX Import Open Mode (P2-4A)

## Status
approved

## Phase
phase-build

## Feature Slug
phase-2-xlsx-import-open-mode

## Goal
Patch P2-4 XLSX import from strict canonical validation to **capture-first ("open
mode")**. Whatever the workbook contains imports into the database; the importer
**warns** about imperfect data instead of **blocking** it. A row is unimportable
only when its title is blank. Manual row CRUD (`POST`/`PUT /api/rows`) keeps strict
canonical validation — this change is import-specific.

## Recon
- ai/recon/phase-2-team-operating-model-full-spec-recon.md (§9)
- P2-4 finding: the live astraX workbook yields 0 strictly-valid rows (track labels `T1-Device`/`T1 Device`/blank; many blank owner/status).

## Dependency
- P2-4 XLSX Import (RELEASE_APPROVED) — reuses `parseImportWorkbook`, `normalizeImportValue` (SSF date fix), `resolveImportSheet`, `IMPORT_HEADER_MAP`, `toImportRow`, the scoped 25mb JSON parser, and `canImport` gating. Only the validation classification and the two route bodies change; helpers above are unchanged.

## Operator Decision (authoritative)
"Blow the import open." Strict canonical validation is replaced for import only:
invalid track / blank owner / blank status no longer block import.

**Schema-aware exception (operator-confirmed):** `app/db.js` must NOT be modified.
The `entries` table has DB `CHECK` constraints on `status` (5 canonical values) and
`type` (3 values) — verified to reject arbitrary text. `track` is free `TEXT` (no
CHECK). Therefore:
- **track** — non-canonical/blank imports as workbook value / "Unassigned Track" **as-is**.
- **status** — blank OR non-canonical is **coerced to "Not Started"** with a warning (cannot store arbitrary status given the CHECK). Preview discloses the coercion.
- **type** — always `experiment` unless a valid ROW_TYPES value is supplied.
- Commit must never crash (per-row insert is guarded).

---

## Data Model Changes
none

---

## API Surface

Two routes in `app/server.js` change behavior (still `requireAuth` + `canImport`,
non-admin → 403, anon → 401). The base64 parsing, sheet/header resolution, and SSF
date handling are unchanged. Strict `validate()` for `POST`/`PUT /api/rows` is untouched.

### Replace strict validation with open-mode classification
- Remove `IMPORT_REQUIRED` + `validateImportRow`.
- Add `classifyImportRow(data)` → `{ importable, reason }` when title blank, else
  `{ importable: true, warnings: [...], data: <normalized> }`:
  - title blank → not importable (`reason: 'title is required'`)
  - owner blank → `'Unassigned'` (warn)
  - track blank → `'Unassigned Track'` (warn); non-canonical track kept as-is (warn `non-canonical track "X" imported as-is`)
  - status blank → `'Not Started'` (warn); non-canonical status coerced to `'Not Started'` (warn `status "X" not a canonical status; stored as Not Started`)
  - type defaulted to `experiment` unless a valid ROW_TYPES value supplied
- `toImportRow` unchanged (projects onto entries columns, defaults type).

### POST /api/import/preview — open-mode classification, no DB write
Response shape:
```json
{
  "summary": { "sheet": "All Experiment Summary", "total_rows": 19, "importable_rows": 19, "skipped_rows": 0, "warning_count": 36 },
  "rows": [ { "row_number": 5, "warnings": ["non-canonical track \"T1-Device\" imported as-is"], "data": { "owner": "Vijay", "track": "T1-Device", "title": "...", "status": "Not Started", "type": "experiment" } } ],
  "skipped_rows": [ { "row_number": 23, "reason": "title is required" } ]
}
```

### POST /api/import/commit — re-classify server-side, insert importable rows
Request `{ "rows": [ ...row data objects from preview... ] }`. Re-runs
`classifyImportRow` on each row (does not trust preview), inserts importable rows
(per-row try/catch — a failed insert is reported, never crashes the batch), stamps
`created_by`/`updated_by` = importing admin. Response:
```json
{ "ok": true, "inserted_count": 19, "ids": [..], "skipped_count": 0, "skipped": [] }
```

---

## Frontend Surface

Update the admin Import panel in `app/public/app.js` to the open-mode language + shape:
- Read the new preview shape (`summary.{importable_rows,skipped_rows,warning_count}`, `rows[].{row_number,warnings,data}`, `skipped_rows[].{row_number,reason}`).
- Summary line: importable / warnings / skipped counts.
- Importable-rows preview (first 10): owner, track, title, status, type, **warnings** column.
- Skipped-rows list: row number + reason.
- Copy says **importable / warnings / skipped** — not valid/invalid.
- Commit enabled when `importable_rows > 0`; commit posts `rows.map(r => r.data)`.
- `style.css`: add a `.import-summary .warn` (amber) token.

---

## Allowed Mutation Surfaces
- app/server.js
- app/public/app.js
- app/public/style.css
- app/README.md
- specs/phase-2-xlsx-import-open-mode.md
- tasks/phase-2-xlsx-import-open-mode-001.md … 003.md
- ai/state_registry.json
- ai/engineering-journal.md

Do NOT modify: app/db.js, app/public/index.html, app/package.json, app/package-lock.json (no package change), prototypes/, sdlc/, vendor/, deployment files.

---

## Verification Plan
1. Live workbook preview now reports importable_rows > 0 (expected 19) and skipped 0.
2. Commit imports the workbook rows; they appear in All Tracks with `created_by`/`updated_by` = admin, `type=experiment`.
3. Blank owner → `Unassigned`; blank track → `Unassigned Track`; non-canonical track stored as-is; blank/non-canonical status → `Not Started` (with warnings); title-blank rows skipped.
4. Commit never crashes (per-row guard); commit re-validates (title-blank rejected).
5. Non-admin preview/commit → 403; anon → 401.
6. Manual `POST /api/rows` with invalid track still → 403/400 (strict CRUD unchanged).
7. P2-1/P2-2/P2-3 regressions pass; invariants 5/5; only allowed surfaces changed; `db.js` untouched.

## Verification Scripts
(none — no scripts/verification/ directory; verification via supervisor gates + the verification task + post-pipeline live checks.)

---

## Non-Scope
Schema relaxation (no db.js change) · track normalization/aliasing · dedupe ·
continuous sync · multipart upload · dashboard · changes to manual row CRUD validation.
