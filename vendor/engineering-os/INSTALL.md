# Engineering OS — Adapter Integration

Steps for an adopting project to wire the OS package into its repository.

## 1. Vendor or submodule

Place the OS package at `vendor/engineering-os/` (vendored copy) or as a
git submodule pointing at the upstream repo. Vendored is simpler; submodule
is preferred when the package is shared across multiple projects.

## 2. Create the adapter overlay

Create `<project>/.engineering-os/`:

```
.engineering-os/
├── adapter.config.sh
└── invariants/
    ├── INV-001-<name>.sh
    ├── INV-002-<name>.sh
    └── ...
```

Copy `vendor/engineering-os/templates/adapter.config.sh` to
`.engineering-os/adapter.config.sh` and fill in placeholder values.

## 3. Author project invariants

Each invariant file declares:

```sh
EOS_INV_ID="INV-001"
EOS_INV_NAME="Short human-readable name"
check() {
  # Return 0 on pass, non-zero on fail.
  # Use grep, find, test, etc. against project paths.
  grep -rl "<project-trigger-name>" backend/migrations/ > /dev/null 2>&1
}
```

The runner sources each file in a subshell and calls `check`. Exit codes
become PASS/FAIL.

## 4. Initialize the state registry

The OS package ships an empty registry template at
`vendor/engineering-os/templates/state_registry.json`. Copy it to the path
declared in `adapter.config.sh` (typically `ai/state_registry.json`).

## 5. Wire the pipeline

Two integration patterns:

**Direct invocation** — call vendored scripts directly:
```sh
bash vendor/engineering-os/scripts/compile-spec.sh specs/<feature>.md
```

**Proxy** — replace project's in-tree pipeline scripts with one-line proxies:
```sh
exec vendor/engineering-os/scripts/compile-spec.sh "$@"
```

Either works. Proxies are more transparent for tooling that hardcodes the
in-tree path; direct invocation is simpler.

## 6. Run the self-test

```sh
bash vendor/engineering-os/tests/run-self-tests.sh
```

All three sub-tests must PASS. Any failure indicates an integration issue
(usually adapter config missing or paths wrong).

## 7. Use the pipeline

```sh
# Author spec at specs/<feature>.md with Status: approved
bash vendor/engineering-os/scripts/compile-spec.sh specs/<feature>.md
# Edit the generated tasks/<feature>-NNN.md files
bash vendor/engineering-os/scripts/execution-supervisor.sh <feature>
```

The supervisor runs the invariant gate, executes tasks, runs verification,
appends a journal entry, and advances state to RELEASE_APPROVED.
