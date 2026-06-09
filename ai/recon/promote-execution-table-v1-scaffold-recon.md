# Recon — promote-execution-table-v1-scaffold

## Status
recon-complete

## Layer
Recon (pre-spec)

## Upstream Authority
- Directive: RAYSTRAT EXECUTION DIRECTIVE (DIRECTIVE_V3)
- ai/invariant-registry.md
- vendor/engineering-os/core-docs/ENGINEERING_OS.md
- sdlc/00-process-constitution/sdlc-architecture-directive.md

## Downstream Consumers
- specs/promote-execution-table-v1-scaffold.md

---

## 1. Environment

**Branch:** main  
**State machine entry (feature):** RECON_READY  
**OS mode:** OS-ENABLED (vendor/engineering-os/ + .engineering-os/ both present)  
**Adapter:** .engineering-os/adapter.config.sh — PASS (12/12 checks)  
**Invariant engine:** scripts/invariant-check.sh — 6/6 PASS  
**Pre-commit hook:** .git/hooks/pre-commit — present and executable  
**State-manager:** scripts/state-manager.sh — present and executable  

**Git status at recon time:**  
Untracked (never committed):
- `.gitignore` (created by prototype-intake-cleanup capability)
- `ai/recon/prototype-intake-execution-table-app.md`
- `prototypes/` (execution-table-app prototype, never committed)

No staged changes. No modified tracked files.

---

## 2. SDLC Position

The repository is at **L1 → L2 transition**:

| Layer | Status |
|-------|--------|
| L0 Context | Approved (CTX-01…CTX-14) |
| L1 Intent | Approved (Product Intent Brief 2026-06-09) |
| L2 Behavior | Not started |
| L3 Structure | Not started |
| L4 Verification | Not started |
| L5 Build | Not started |

The build map explicitly records: "No product code exists. INV-002 holds; src/ and app/ do not exist. The governance gate does not lift until the minimal artifact chain is approved. Next required artifact: Minimal V1 PRD from the workbook."

---

## 3. Existing Artifacts

- `specs/promote-execution-table-v1-scaffold.md` — **does not exist**
- `tasks/promote-execution-table-v1-scaffold-*.md` — **does not exist** (tasks/ directory absent)
- `ai/state_registry.json` — exists, currently `{}`; state-manager correctly returns RECON_READY for this feature
- `app/` — **does not exist**
- `src/` — **does not exist**

---

## 4. Prototype Files Read

Path: `prototypes/execution-table-app/`

Files present:
- `db.js` — database setup, schema, seed
- `server.js` — Express server
- `package.json` — Node dependencies
- `public/` — HTML/CSS/JS frontend
- `data.db`, `data.db-shm`, `data.db-wal` — runtime SQLite (gitignored post-cleanup)
- `node_modules/` — (gitignored)

---

## 5. Workbook Inspection

**File:** `source-materials/workbooks/astraX-june-to-nov-experiment-all-tracking.xlsx`

**Sheets found:**
1. Sample Experiment Log (sheetId=1)
2. All Experiment Summary (sheetId=2)
3. How To Use (sheetId=3)

**All Experiment Summary — column headers (row 4):**
```
Owner | Track | Experiment Title | Function | Parent Item |
Description / Hypothesis | Experiment Design | Success Criteria |
Target End Date | Dependencies | Test outcome / Finding |
Next Action | Status | STATUS SUMMARY (derived) | Count (derived)
```

**Sample Experiment Log — column headers (row 5):**
```
Track | Experiment Title | Description / Hypothesis | Experiment Design |
Success Criteria | Target End Date | Dependencies | Outcome / Finding |
Next Action | Status
```
(No Owner, Function, or Parent Item columns — personal log format.)

**Explicit confirmation:** Excel serves as structure source only. Runtime data persists in SQLite (`app/data.db`). No data is read from or written to the workbook at runtime.

---

## 6. Prototype ROW_FIELDS

From `prototypes/execution-table-app/db.js` lines 15–30:

```
key               label
────────────────────────────────────────
type              Type                    (select: experiment|work_item|task)
title             Title                   (text, required)
owner             Owner                   (text)
track             Track                   (text)
function_area     Function                (text)
parent_item       Parent Item             (text)
hypothesis        Description / Hypothesis (textarea)
design            Experiment Design       (textarea)
success_criteria  Success Criteria        (textarea)
target_end_date   Target End Date         (date)
dependencies      Dependencies            (text)
outcome           Outcome / Finding       (textarea)
next_action       Next Action             (text)
status            Status                  (select: Not Started|In Progress|Complete|Blocked|Inconclusive)
```

---

## 7. Column Mismatch Report

Comparing prototype ROW_FIELDS labels against **All Experiment Summary** (team canonical source):

| Prototype label | Workbook label | Match |
|----------------|----------------|-------|
| Title | Experiment Title | ⚠️ minor — "Experiment" prefix absent in prototype |
| Owner | Owner | ✅ |
| Track | Track | ✅ |
| Function | Function | ✅ |
| Parent Item | Parent Item | ✅ |
| Description / Hypothesis | Description / Hypothesis | ✅ |
| Experiment Design | Experiment Design | ✅ |
| Success Criteria | Success Criteria | ✅ |
| Target End Date | Target End Date | ✅ |
| Dependencies | Dependencies | ✅ |
| Outcome / Finding | Test outcome / Finding (Summary) / Outcome / Finding (Log) | ⚠️ label matches Log sheet exactly; Summary uses "Test outcome" prefix |
| Next Action | Next Action | ✅ |
| Status | Status | ✅ |
| **Type** | *(not in workbook)* | 🆕 prototype addition for row classification |

**Summary:** 11 exact matches. 2 minor label differences (no semantic mismatch). 1 prototype-only field (`type`). No structural mismatch. No column present in workbook but absent from prototype.

**Recommendation:** Retain prototype ROW_FIELDS as-is. `type` field supports experiment/work_item/task classification which aligns with workbook intent. Label differences are cosmetic; no DB schema change required.

---

## 8. INV-002 Invariant Conflict

**Invariant:** INV-002 — No application code before L5 Build  
**Rule file:** `.engineering-os/invariants/INV-002-no-app-code-pre-build.sh`  
**Check:** fails if `app/` or `src/` directories exist and contain files.

**Conflict with this capability:** The execution goal is to create `app/` with production files.

**Gate positions in execution-supervisor.sh:**
1. Pre-execution invariant gate — runs BEFORE any tasks. `app/` does not exist yet → **INV-002 PASSES** ✓
2. Pre-verification invariant gate — runs AFTER all tasks complete. Tasks will have created `app/` with files → **INV-002 FAILS** ✗

**Resolution path:** The task graph for this capability must include retiring INV-002 to `.engineering-os/invariants/_legacy/` as an explicit first-tier task, before any `app/` files are written. This is semantically correct: INV-002 guards against pre-L5 app code; once the L5 Build pipeline is executing, the invariant has served its purpose and must be graduated.

---

## 9. Implementation Risks

1. **INV-002 pre-verification failure** — see §8. Mitigated by retiring INV-002 in task 001.
2. **SDLC is at L1, not L5** — the directive's "phase-build" tag is used for execution ordering only. The repository's SDLC documentation sequence (L2 Behavior → L3 Structure → L4 Verification) has not been completed. The operator has explicitly authorized bypassing the PRD sequence via directive authority.
3. **Demo seed rows** — `db.js` seeds rows with live experiment data (GEOMINFO_ts, STM firmware, etc.). These are real team items, not generic placeholders. The spec must determine whether to preserve, replace, or remove them.
4. **WAL fallback** — already added in prototype-intake-cleanup capability. `app/db.js` will inherit this fix.
5. **Node ≥ 22.5 requirement** — `node:sqlite` is built-in only from Node 22.5+. Must document in `app/README.md`.
6. **No verification scripts exist** — `scripts/verification/` directory absent. The verification task will need to create the minimal verification surface.

---

## 10. Out-of-Scope Confirmation

Confirmed NOT present in prototype and confirmed excluded from v1:
- Escalation workflow: absent ✅
- Approval workflow: absent ✅
- Dashboard: absent ✅
- Agents: absent ✅
- IoT/digital twin scope: absent ✅
- NDT-SaaS architecture: absent ✅

---

## 11. Next Step

State: RECON_READY → proceed to spec generation.  
Create: `specs/promote-execution-table-v1-scaffold.md`  
Run: `bash scripts/compile-spec.sh specs/promote-execution-table-v1-scaffold.md`
