# Import Batch Delete Integrity Fix: Recon

**Feature Slug:** import-batch-delete-integrity-fix  
**Date:** 2026-06-18  
**Author:** AI Engineering OS (in-session worker)  
**HEAD at recon:** 9b34d34

> **RECON OUTCOME: STOP-AND-REPORT triggered.** The directive's recon objective states:
> *"If imported rows exist with missing/null import_batch_id: STOP and report whether this is
> legacy data or a current insertion bug before patching cleanup behavior."* Recon proves the
> **current code is correct** and the affected rows are **legacy/orphaned data**. No authorized
> code mutation remains; operator decision required before any orphan cleanup.

---

## 1. Observed Bug (reported)

- Import History shows a batch with 19 rows.
- Clicking Delete reports: "Deleted 0 imported row(s), 20 observation(s) removed."
- Imported rows remain visible in Rows.

---

## 2. Files Read

| File | Purpose |
|------|---------|
| `app/server.js:479-593` | Import commit + delete routes |
| `app/db.js` (in context) | entries schema + `import_batch_id` migration |
| live `app/data.db` (read-only) | Actual batch/entry/observation state |
| `source-materials/.../astraX-...xlsx` (read-only) | Real import workbook for reproduction |

Local governance surfaces: only `ai/invariant-registry.md` present (as before).

---

## 3. Commands Run

```bash
bash vendor/engineering-os/scripts/os-adapter-check.sh   # adapter valid
bash scripts/invariant-check.sh                           # 5/5 PASS
git status --short; git log --oneline -1                  # clean; HEAD=9b34d34
# read-only DB inspection (DatabaseSync readOnly:true, db.js NOT required → no seeds)
# disposable-DB import+delete reproduction (synthetic workbook + real astraX workbook)
```

All DB inspection/reproduction used `readOnly:true` or a disposable `mktemp` DB. Live
`app/data.db` size+mtime confirmed unchanged after every step.

---

## 4. Current Import Commit Flow (`app/server.js:479-563`)

- Insert ledger row → `batch_id = Number(batchInfo.lastInsertRowid)` (501-504).
- For each importable, non-duplicate row: build `row` via `toImportRow`, set
  `row.import_batch_id = batch_id` (521), `import_source_sheet`, `import_source_row`, then
  `INSERT INTO entries (...keys...)` where keys include `import_batch_id` (524-527).
- Observations inserted with `batch_id` (540-561); `imported_entry` observation raw_data
  includes `entry_id` (553).

**Finding:** the current commit path stamps `import_batch_id` on every inserted entry.

## 5. Current Delete Flow (`app/server.js:576-593`)

```js
const id = Number(req.params.id);                                  // 578
DELETE FROM import_observations WHERE import_batch_id = ?  (id)     // 584 → deleted_observation_count
DELETE FROM entries            WHERE import_batch_id = ?  (id)      // 585 → deleted_entry_count
DELETE FROM imports            WHERE id = ?               (id)      // 586
```

Admin-only (`canImport`, 577); 400 on bad id; 404 if batch missing; transactional. **Finding:**
the delete path is correct — it removes observations, entries, and the ledger row by batch id,
returns accurate counts, and never touches manual rows (`import_batch_id IS NULL`).

---

## 6. Live DB Findings (`app/data.db`, read-only)

| Query | Result |
|-------|--------|
| `imports` (ledger) | **0 rows** (no batches) |
| `entries` total | 65 |
| `entries` grouped by `import_batch_id` | **all 65 → NULL** |
| `import_observations` | **0 rows** |
| `entries` schema | `import_batch_id INTEGER DEFAULT NULL` column present |

The committed `app/data.db` contains only legacy/manual/demo entries (all NULL batch) and no
import batches — so the user's buggy batch is from their own live session DB, not this file.

---

## 7. Reproduction on Disposable DBs (current code)

### 7a. Synthetic 3-row workbook
- commit → `inserted_count=3`, entries linked to batch = **3**, observations = 4.
- delete → `deleted_entry_count=3`, `deleted_observation_count=4`; after: 0 entries, 0 ledger,
  0 observations; 2 demo rows preserved. **All correct.**

### 7b. Real astraX workbook (the user's file) — 19 rows
- preview → `importable=19`, `skipped=0`, `dup=0`.
- commit → `inserted_count=19`, `observation_count=20` (1 `workbook_sheet` + 19
  `imported_entry`); entries linked to batch = **19**.
- delete → `deleted_observation_count=20`, **`deleted_entry_count=19`**; after: 0 batch
  entries, 2 demo rows preserved. **All correct.**

The user's exact numbers (19-row batch, 20 observations) reproduce — **except** their delete
removed **0** entries while current code removes **19**. The 20-observation match (1 sheet + 19
imported_entry) pins the batch size precisely.

---

## 8. Root Cause

**The current insertion and delete code is correct (proven, §7).** The reported bug is
**legacy/orphaned data**: the user's 19 imported entries were created by an **older code
version** that recorded batch-linked observations but did **not** stamp `import_batch_id` onto
the `entries` rows. On delete, `DELETE FROM entries WHERE import_batch_id = N` matches **0**
rows (their `import_batch_id IS NULL`), while the 20 batch-linked observations are removed —
producing exactly "Deleted 0 imported row(s), 20 observation(s) removed," with the rows still
visible.

This is **not a current insertion bug.** `import_batch_id` linkage and batch delete both work
on every fresh import.

---

## 9. Legacy vs Current Bug — Determination

| Question | Answer |
|----------|--------|
| Do new imports stamp `import_batch_id`? | **Yes** (verified, §7a/§7b) |
| Does batch delete remove linked entries + observations + ledger? | **Yes** (verified) |
| Are the affected rows from current code? | **No** — legacy, imported under a pre-linkage version |
| Are there orphaned imported-looking rows (`import_batch_id IS NULL`)? | **Yes** in the user's live DB (and 65 NULL-batch rows in the committed DB, mostly demo/manual) |

Per the directive: orphaned rows must be **classified, not silently deleted**, and **no
destructive orphan cleanup may be implemented without explicit authorization.**

---

## 10. Why No Code Change Is Currently Authorized

The architecture contract's behavioral requirements are **already satisfied** by current code:
- "New imports must write `import_batch_id` onto every imported execution row" ✓
- "Deleting an import batch must delete all entries/observations/ledger; manual rows untouched;
  accurate counts" ✓
- "Fix current import path so future imports are batch-linked" → already batch-linked ✓
- "Do not implement a destructive orphan cleanup unless explicitly authorized" → **not authorized**

There is no current-code defect to patch, and the only way to remove the user's legacy orphaned
rows is an orphan cleanup, which requires explicit operator authorization.

---

## 11. Options for the Operator (require authorization)

| Option | What it does | Risk |
|--------|--------------|------|
| **A — Observation-driven batch delete (recommended)** | Extend `DELETE /api/imports/:id` to also delete entries whose ids are recorded in that batch's `imported_entry` observation `raw_data.entry_id`, in addition to `import_batch_id = N`. Batch-scoped + evidence-based — only removes entries the batch's own observations name. Resolves the user's exact case **if** their legacy observations carry `entry_id`. | Low–med; deletes rows lacking the batch_id but provably from that batch per its observations. Needs sign-off. |
| **B — One-time backfill** | Stamp `import_batch_id` onto orphaned entries by matching observation `raw_data` (title/owner/track/source_row) to entries. | Med; heuristic matching could mislink. Touches existing data. |
| **C — Admin "remove legacy imported rows" tool** | Explicit admin action to delete entries identified as orphaned imported rows. | High; destructive global orphan sweep. Explicit authorization required. |
| **D — Leave as-is** | Document that pre-linkage imports cannot be batch-deleted; new imports are fine. | None; legacy rows must be removed manually. |

Recommendation: **Option A** — it is the narrowest fix that repairs delete integrity for legacy
batches using only each batch's own recorded evidence, with no global orphan sweep. It does
require operator authorization since it deletes entries not carrying the batch_id.

---

## 12. Non-Scope (unchanged regardless of decision)

Import preview, import commit shape, duplicate detection, access-control removal, row-click
edit, DB_PATH, first-admin bootstrap, Railway config, auth/session, schema. No Docker/Postgres/
deploy. No live `app/data.db` mutation (all tests used disposable DBs).

---

## 13. Decision Required

Per the directive's recon STOP clause, execution halts here pending the operator's choice among
§11. No spec/task-graph/implementation has been produced, because no authorized code mutation
exists yet and any cleanup of legacy orphaned rows requires explicit authorization.
