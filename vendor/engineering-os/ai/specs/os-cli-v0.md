# Spec: OS CLI V0 — Thin Wrapper Interface

## Status
approved

## Phase
phase-1

## Capability

Provide a single entry-point CLI (`raystrat-os`) that wraps the OS runtime scripts
without introducing new logic. Every command is a 1:1 or 1:N proxy to existing
scripts. The CLI does not invent behavior — it routes, validates preconditions, and
propagates exit codes unchanged.

A developer running any OS operation invokes `raystrat-os <cmd>` instead of
memorizing individual script paths and argument conventions.

After this capability exists: a developer can boot, check, verify, query state,
compile specs, execute task graphs, run regression, and run self-tests through a
single named entry point. Nothing they could not already do with direct script
invocation — only discoverable and consistent.

## Data Model Changes

none

## API Surface

none

## Frontend Surface

none

## Operational Workflow

### CLI Runtime Contract

1. CLI is a repo-local bash script at `scripts/raystrat-os` (no global install)
2. Invoked as: `bash scripts/raystrat-os <cmd> [args...]` or `./scripts/raystrat-os <cmd>` (if chmod +x)
3. On invocation, CLI:
   a. Resolves repo root (via script location or explicit detection)
   b. Verifies `.engineering-os/adapter.config.sh` exists for adapter-required commands
   c. Sources adapter config — exports EOS_* vars into environment
   d. Routes command to backing script
   e. Propagates exit code unchanged

### Command: boot

Backing script: `scripts/os-boot-check.sh`

Validates that the current environment is usable by the Engineering OS.
Detects OS core vs adapter context, checks required scripts, verifies adapter
config and EOS_INVARIANTS_DIR if adapter context is detected.

```
raystrat-os boot
```

Exit: 0 = READY, 1 = BLOCKED

---

### Command: check

Backing script: `scripts/os-adapter-check.sh`

Validates the adapter configuration against the Engineering OS contract.
Checks config sources, EOS_INVARIANTS_DIR (hard required), EOS_STATE_REGISTRY
resolvability, optional directory declarations, and EOS_PROJECT_NAME.

```
raystrat-os check [--config <path>]
```

Exit: 0 = adapter valid, 1 = invalid adapter

---

### Command: verify

Backing script: `scripts/invariant-engine.sh`

Runs all project invariants (or a single invariant with --only).
Sources adapter config to supply EOS_INVARIANTS_DIR before invocation.
All flags passed through to invariant-engine.sh unchanged.

```
raystrat-os verify [--only <INV-ID>]
```

Exit: 0 = all pass, 1 = config error, 2 = violation

---

### Command: status

Backing script: `scripts/state-manager.sh get`

Prints current pipeline state for a registered feature.

```
raystrat-os status <feature-slug>
```

Exit: propagated from state-manager.sh (0 = success, 1 = missing arg)

---

### Command: state

Backing script: `scripts/state-manager.sh`

Full state machine access — get, require, advance, reset.
All arguments passed through unchanged.

```
raystrat-os state <get|require|advance|reset> <feature> [state]
```

Exit: propagated from state-manager.sh (0 = success, 1 = error, 2 = state violation)

---

### Command: compile

Backing script: `scripts/compile-spec.sh`

Runs spec compilation gate: validates spec status + phase, advances state
RECON_READY → SPEC_LOCKED, writes OS token, delegates to generate-tasks.sh.

```
raystrat-os compile <spec-file>
```

Exit: propagated from compile-spec.sh (0 = success, 1 = validation error, 2 = state violation)

---

### Command: exec

Backing script: `scripts/execution-supervisor.sh`

Runs full task execution loop for a feature: dependency validation, Claude
invocation per task, per-task verification, state advancement through
EXECUTION_ACTIVE → RELEASE_APPROVED, journal append.

```
raystrat-os exec <feature-slug>
```

Exit: propagated from execution-supervisor.sh (0 = all tasks done and verified,
1 = execution/verification failure, 2 = control-plane mutation)

---

### Command: regress

Backing script: `scripts/run-full-regression.sh`

Runs all active verification scripts in `scripts/verification/` (excludes
`_legacy/`, `_quarantine/`, and the regression script itself).

```
raystrat-os regress
```

Exit: propagated from run-full-regression.sh (0 = all pass, 1 = any fail)

---

### Command: self-test

Backing script: `scripts/os-self-test.sh`

Context-safe self-test runner. Detects whether running in adapter project
(routes to `vendor/engineering-os/tests/run-self-tests.sh`) or OS core repo
(routes to `tests/run-self-tests.sh`). Exit code propagated unchanged.

```
raystrat-os self-test
```

Exit: propagated from run-self-tests.sh (0 = all sub-tests pass, 1 = any fail)

---

## CLI Routing Table (Authoritative)

All mappings derived from recon (ai/recon/OS_CLI_V0_SURFACE.md). No invented behavior.

| CLI command | Backing script | Args passed | Exit code source |
|------------|---------------|-------------|-----------------|
| `boot` | `scripts/os-boot-check.sh` | none | os-boot-check.sh |
| `check [--config P]` | `scripts/os-adapter-check.sh` | `--config` passthrough | os-adapter-check.sh |
| `verify [--only ID]` | `scripts/invariant-engine.sh` | `--config <path>` + passthrough | invariant-engine.sh |
| `status <feature>` | `scripts/state-manager.sh get` | feature slug | state-manager.sh |
| `state <cmd> <feature> [state]` | `scripts/state-manager.sh` | all args passthrough | state-manager.sh |
| `compile <spec-file>` | `scripts/compile-spec.sh` | spec file path | compile-spec.sh |
| `exec <feature>` | `scripts/execution-supervisor.sh` | feature slug | execution-supervisor.sh |
| `regress` | `scripts/run-full-regression.sh` | none | run-full-regression.sh |
| `self-test` | `scripts/os-self-test.sh` | none | os-self-test.sh |

Every command maps to a real script. No command maps to prose-only behavior.

---

## CLI Runtime Constraints

All constraints derived from recon. No new behavior introduced.

1. **Repo root detection**: CLI detects cwd by checking for `scripts/`, `ai/`, `core-docs/` — or resolves via script location
2. **Adapter config**: Required for `check`, `verify`, `compile`, `exec`, `regress`. Optional for `boot`, `status`, `state`, `self-test`
3. **EOS_* export**: CLI sources adapter config before invoking adapter-required commands
4. **Exit code propagation**: `exit $?` after every backing script call — no wrapping, no swallowing
5. **Error transparency**: stderr from all backing scripts passes through unchanged
6. **No script modification**: CLI is a new file only — `scripts/raystrat-os`
7. **No global install**: invoked as `bash scripts/raystrat-os` or via PATH if adapter adds `scripts/` to PATH
8. **bash 3+ only**: no associative arrays (matches existing script constraint)

---

## Dependencies

- `scripts/os-boot-check.sh` — boot command
- `scripts/os-adapter-check.sh` — check command
- `scripts/os-self-test.sh` — self-test command
- `scripts/invariant-engine.sh` — verify command
- `scripts/state-manager.sh` — status, state commands
- `scripts/compile-spec.sh` — compile command
- `scripts/execution-supervisor.sh` — exec command
- `scripts/run-full-regression.sh` — regress command
- `.engineering-os/adapter.config.sh` — adapter-provided; required for adapter-mode commands
- `EOS_INVARIANTS_DIR` — required by verify command (via adapter config)
- bash 3+

## Acceptance Criteria

- [ ] `bash scripts/raystrat-os boot` exits 0 in OS core context with all required scripts present
- [ ] `bash scripts/raystrat-os boot` exits 1 when in adapter context with missing adapter config
- [ ] `bash scripts/raystrat-os check` exits 1 when adapter config absent
- [ ] `bash scripts/raystrat-os verify` propagates exit code from `scripts/invariant-engine.sh` exactly
- [ ] `bash scripts/raystrat-os verify --only INV-001` passes `--only INV-001` through unchanged
- [ ] `bash scripts/raystrat-os status os-cli-v0` prints state from registry; exits 0
- [ ] `bash scripts/raystrat-os state get os-cli-v0` propagates state-manager.sh output exactly
- [ ] `bash scripts/raystrat-os compile specs/os-cli-v0.md` propagates compile-spec.sh exit code exactly
- [ ] `bash scripts/raystrat-os exec os-cli-v0` propagates execution-supervisor.sh exit code exactly
- [ ] `bash scripts/raystrat-os regress` propagates run-full-regression.sh exit code exactly
- [ ] `bash scripts/raystrat-os self-test` routes to correct runner for detected context; propagates exit code
- [ ] No CLI command modifies any existing script
- [ ] All CLI commands propagate stderr from backing scripts unchanged
- [ ] Unknown command prints usage and exits 1

## Out of Scope

- Global install or PATH manipulation
- Shell completion
- Config file creation or scaffolding
- Any command not backed by an existing script in `scripts/` or `tests/`
- Modification of any existing script
- Logging, audit trail, or journal entries from the CLI layer itself
- Interactive prompts or confirmations
