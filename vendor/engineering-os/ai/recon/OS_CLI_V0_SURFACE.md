# OS CLI V0 — Executable Surface Recon

Feature slug: os-cli-v0
Date: 2026-05-01
Source: STRICT recon from scripts/, templates/adapter.config.sh, tests/,
        core-docs/execution-orchestrator.md, core-docs/execution-loop-controller.md,
        core-docs/verification-playbook.md

---

## 1. Executable Surfaces

### scripts/compile-spec.sh

**Args:**
```
$1 — spec file path (required, e.g. specs/my-feature.md)
```
Usage line: `compile-spec <spec-file>`

**Exit conditions:**
- `exit 1` — missing arg, spec file not found, status not `approved`, phase missing/invalid
- `exit 2` — state machine violation (state-manager.sh returns 2)
- `exit 0` — (implicit via delegation to generate-tasks.sh) full pipeline success

**Side effects:**
- Reads spec file for `## Status` and `## Phase` fields
- Calls `bash scripts/state-manager.sh require <feature> RECON_READY`
- Calls `bash scripts/state-manager.sh advance <feature> SPEC_LOCKED`
- Writes `/tmp/.os-compile-token` (content: `<spec-path>:<unix-timestamp>`)
- Calls `bash scripts/generate-tasks.sh "$SPEC"` (delegation, not return)

**Dependencies:**
- `scripts/state-manager.sh` (optional — skipped if file absent)
- `scripts/generate-tasks.sh`
- `specs/phases/` directory — scans for `^Phase: <tag>` match
- Python3 (via state-manager.sh)

**CWD assumption:** repo root (all paths relative)

**State transition triggered:** `RECON_READY → SPEC_LOCKED` (then delegates to SPEC_LOCKED → TASK_GRAPH_LOCKED via generate-tasks.sh)

---

### scripts/generate-tasks.sh

**Args:**
```
$1 — spec file path (required, same as compile-spec.sh arg)
```
Usage line: `generate-tasks <spec-file>`

**Exit conditions:**
- `exit 1` — OS token missing, missing arg, spec not found, status not `approved`, phase missing/invalid
- `exit 2` — state machine violation
- `exit 0` — all task files scaffolded, state advanced

**Side effects:**
- Consumes (deletes) `/tmp/.os-compile-token`
- Creates `tasks/` directory if absent
- Writes task scaffold files: `tasks/<feature>-NNN.md` (one per detected layer)
- Calls `bash scripts/state-manager.sh require <feature> SPEC_LOCKED`
- Calls `bash scripts/state-manager.sh advance <feature> TASK_GRAPH_LOCKED`
- Emits task graph summary to stdout

**NOT intended for direct invocation** — must be called via `compile-spec.sh`.
Direct invocation exits 1 immediately ("OS execution token not found").

**Layer detection (from spec sections):**
- `## Data Model Changes` non-empty → `database` task
- `## API Surface` non-empty → `backend` task
- `## Frontend Surface` non-empty → `frontend` task
- `verification` always appended

**Dependencies:**
- `/tmp/.os-compile-token` (written by compile-spec.sh — consumed on read)
- `scripts/state-manager.sh`
- `specs/phases/` directory
- Python3 (via state-manager.sh)

**CWD assumption:** repo root

**State transition triggered:** `SPEC_LOCKED → TASK_GRAPH_LOCKED`

---

### scripts/state-manager.sh

**Commands and args:**

| Command | Args | Description |
|---------|------|-------------|
| `get` | `<feature>` | Print current state to stdout |
| `require` | `<feature> <state>` | Exit 2 if feature is in registry and state ≠ expected |
| `advance` | `<feature> <state>` | Validate transition, write new state |
| `reset` | `<feature>` | Write RECON_READY unconditionally |

**Exit conditions:**
- `exit 0` — operation succeeded
- `exit 1` — missing args, invalid state name, missing command
- `exit 2` — state machine violation (wrong current state for require/advance)

**Side effects:**
- `get`: read-only
- `require`: read-only (exits 2 on mismatch; passes with warning if feature not in registry)
- `advance`: writes `ai/state_registry.json` (or `$EOS_STATE_REGISTRY`); auto-registers feature at RECON_READY if absent
- `reset`: writes RECON_READY to registry

**State chain (ordered):**
```
RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE →
VERIFICATION_REQUIRED → RELEASE_APPROVED
```

**Config resolution:**
- `EOS_STATE_REGISTRY` env var set → uses that path (absolute or relative to cwd)
- Not set → defaults to `<package-root>/ai/state_registry.json`

**Dependencies:**
- Python3 (registry read/write via python3 inline script)
- `ai/state_registry.json` (created as `{}` if absent)

**CWD assumption:** must be invoked from a location where relative paths resolve correctly; package-root detection via `$(dirname "$0")/..`

---

### scripts/invariant-engine.sh

**Invocation patterns:**
```bash
bash scripts/invariant-engine.sh                        # run all invariants
bash scripts/invariant-engine.sh --only INV-003         # run one invariant by ID
bash scripts/invariant-engine.sh --config <path>        # explicit adapter config
bash scripts/invariant-engine.sh --only ID --config P   # combined
```

**Supported flags:**
- `--only <ID>` — run single invariant matching `EOS_INV_ID`
- `--config <path>` — explicit adapter config path (overrides env resolution)

**Config resolution (first match wins):**
1. `$EOS_CONFIG` env var
2. `--config <path>` argument
3. `.engineering-os/adapter.config.sh` (relative to cwd)

**Exit conditions:**
- `exit 0` — all selected invariants PASS
- `exit 1` — config error (no config found, invariants dir missing, no *.sh rule files)
- `exit 2` — one or more invariant violations

**Output structure:**
```
Invariant Check Engine
══════════════════════════════════════
  INV-001: PASS — <name>
  INV-002: FAIL — <reason>
  ...
══════════════════════════════════════
Result: N/M PASS
```

**Required from adapter config:**
- `EOS_INVARIANTS_DIR` — path to directory containing `*.sh` rule files
  - Hard `exit 1` if not exported by adapter config
  - Hard `exit 1` if directory does not exist
  - Hard `exit 1` if no `*.sh` files found in directory

**Per-rule file contract:**
Each `*.sh` in `EOS_INVARIANTS_DIR` must define:
- `EOS_INV_ID` — e.g. `"INV-001"`
- `EOS_INV_NAME` — short human-readable name
- `check()` — function returning 0 (pass) or non-zero (fail)
- Optional: `EOS_INV_FAIL_MSG` — custom failure message

---

### scripts/execution-supervisor.sh

**Args:**
```
$1 — feature slug (required, e.g. pipeline-test-fixture)
```
Usage line: `execution-supervisor.sh <feature>`

**Exit conditions:**
- `exit 0` — all tasks done, verification passed, journal appended
- `exit 1` — no task files found, execution failure, verification failure
- `exit 2` — control-plane mutation detected (worker modified tasks/ or ai/ files)

**Side effects:**
- Reads `tasks/<feature>-*.md` files
- Sets task statuses: `pending → in-progress → done`
- Invokes `claude --dangerously-skip-permissions -p <worker-prompt>` per task
- Runs `scripts/verification/` scripts (delta mode: explicit or full-corpus fallback)
- Advances state: `TASK_GRAPH_LOCKED → EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED`
- Appends entry to `ai/engineering-journal.md` on success

**Dependencies:**
- `tasks/<feature>-*.md` files (required — exits 1 if none found)
- `scripts/state-manager.sh` (optional — skipped if absent)
- `scripts/invariant-check.sh` (optional — gates pre-execution and pre-verification)
- `scripts/verification/` (optional — skipped if dir absent)
- `ai/engineering-journal.md` (appended on success)
- `claude` CLI (required for task execution)

**CWD assumption:** repo root

**State transitions triggered:**
```
TASK_GRAPH_LOCKED → EXECUTION_ACTIVE → VERIFICATION_REQUIRED → RELEASE_APPROVED
```

---

### scripts/run-full-regression.sh

**Args:** none

**Invocation:**
```bash
bash scripts/run-full-regression.sh
```

**Exit conditions:**
- `exit 0` — all active verification scripts pass
- `exit 1` — one or more fail

**Side effects:**
- Runs all `scripts/verification/*.sh` (top level only, sorted)
- Skips itself, `_legacy/`, `_quarantine/`
- Emits per-script PASS/FAIL to stdout
- Emits aggregate totals

**Dependencies:**
- `scripts/verification/*.sh` files
- CWD auto-detection: resolves repo root via `SCRIPT_DIR/../..`

---

## 2. State Interaction Surface

Source: `scripts/state-manager.sh`

**Valid states (ordered):**
```
RECON_READY → SPEC_LOCKED → TASK_GRAPH_LOCKED → EXECUTION_ACTIVE →
VERIFICATION_REQUIRED → RELEASE_APPROVED
```

**Valid operations:**

| Operation | Command | Args | Failure mode |
|-----------|---------|------|-------------|
| Read state | `get <feature>` | feature slug | exit 1 on missing arg |
| Assert state | `require <feature> <state>` | slug, state name | exit 2 if wrong state; passes with warning if not in registry |
| Transition | `advance <feature> <state>` | slug, valid next state | exit 2 if invalid transition; exit 1 if target not a valid state |
| Reset | `reset <feature>` | slug | exit 1 on missing arg |

**Registry location:**
- `$EOS_STATE_REGISTRY` if set
- Otherwise: `<script-dir>/../ai/state_registry.json`

**Auto-registration:** `advance` registers feature at RECON_READY if not in registry, then advances. `reset` does not require prior registration.

**Features not in registry:** `require` passes with a printed warning (graceful degradation for legacy features).

---

## 3. Invariant Execution Surface

Source: `scripts/invariant-engine.sh`

**Invocation pattern:**
```bash
bash scripts/invariant-engine.sh [--only <ID>] [--config <path>]
```

**Flags:**
- `--only <ID>` — single-invariant mode; skips all others
- `--config <path>` — bypass env resolution, use explicit path

**Config resolution precedence:**
1. `$EOS_CONFIG` env var
2. `--config <path>` arg
3. `.engineering-os/adapter.config.sh` (cwd-relative)

**Required adapter export:** `EOS_INVARIANTS_DIR`

**Output format:**
```
Invariant Check Engine
══════════════════════════════════════
  <ID>: PASS — <name>
  <ID>: FAIL — <reason>
══════════════════════════════════════
Result: N/M PASS        ← full run
Result: N/1 PASS (<ID>) ← --only mode
```

**Exit codes:** 0 = all pass, 1 = config error, 2 = violation

---

## 4. Verification Harness

Source: `tests/`

**Entrypoint:**
```bash
bash vendor/engineering-os/tests/run-self-tests.sh
```

**Expected invocation context:**
- Must be run from **adapter project root** (NOT from OS core repo root)
- OS package must be vendored at `vendor/engineering-os/`
- Adapter project must have `.git/hooks/pre-commit` installed

**Sub-tests (run in order):**
1. `001-os-enforcement-layer.sh` — checks pre-commit hook, vendored script presence, token gate
2. `002-os-state-machine.sh` — checks state machine transitions, registry isolation
3. `003-os-invariant-engine.sh` — checks generic invariant runner against adapter overlay

**Pass/fail semantics:**
- Each sub-test: `exit 0` = PASS, `exit 1` = FAIL
- Orchestrator: `exit 0` = all 3 pass, `exit 1` = any fail
- Failed test names printed to stdout

**Cannot pass when run from OS core repo** — `vendor/engineering-os/scripts/` paths do not exist there. Expected behavior; not a defect.

---

## 5. Adapter Contract Requirements

Source: `templates/adapter.config.sh`

**All EOS_* variables:**

| Variable | Required/Optional | Consumer | Failure if missing |
|----------|------------------|----------|--------------------|
| `EOS_PROJECT_NAME` | Required (identity) | Pre-commit gate, journal | Silent degradation |
| `EOS_APP_SURFACE_PATHS` | Required | Pre-commit gate | Gate cannot detect app changes |
| `EOS_STATE_REGISTRY` | Optional | `state-manager.sh` | Graceful: defaults to package root `ai/state_registry.json` |
| `EOS_JOURNAL` | Optional | `execution-supervisor.sh` | Uses `ai/engineering-journal.md` directly |
| `EOS_SPEC_DIR` | Optional | Pre-commit gate | Gate uses `specs/` default |
| `EOS_TASK_DIR` | Optional | Pre-commit gate | Gate uses `tasks/` default |
| `EOS_PHASE_DIR` | Optional | Pre-commit gate | Gate uses `specs/phases/` default |
| `EOS_VERIFICATION_DIR` | Optional | `execution-supervisor.sh` | Uses `scripts/verification/` default |
| `EOS_INVARIANTS_DIR` | **REQUIRED** | `invariant-engine.sh` | Hard `exit 1` — no fallback |
| `EOS_ALEMBIC_CMD` | Optional | Adapter-specific hooks | Skipped if not set |
| `EOS_TSC_PATH` | Optional | Adapter-specific hooks | Skipped if not set |

**Config file location contract:**
- Template source: `templates/adapter.config.sh`
- Deployed to: `<project>/.engineering-os/adapter.config.sh`
- Sourced by: `invariant-engine.sh` (default resolution), pre-commit gate

**Hard-fail variable:** `EOS_INVARIANTS_DIR` is the only variable whose absence causes immediate exit 1 in an OS core script.

---

## Recon Completeness Verification

All 6 scripts in `scripts/` documented:
- [x] compile-spec.sh
- [x] generate-tasks.sh
- [x] state-manager.sh
- [x] invariant-engine.sh
- [x] execution-supervisor.sh
- [x] run-full-regression.sh

State machine: [x] all 4 commands documented
Invariant engine: [x] all flags, config resolution, output structure
Tests: [x] entrypoint, context, pass/fail semantics
Adapter contract: [x] all 11 EOS_* variables, hard-fail identified

---

## Recon Status

COMPLETE — ready for CLI spec derivation (ai/specs/os-cli-v0.md)
