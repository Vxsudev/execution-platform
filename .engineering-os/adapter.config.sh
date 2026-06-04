# Engineering OS Adapter Config — execution-platform
#
# Consumed by the vendored OS via CWD-relative resolution (CWD = repo root).
# Sourced by: invariant-engine.sh, os-adapter-check.sh, os-boot-check.sh,
# and the project proxy shims in scripts/.
#
# All paths are relative to the repository root.

# ── Identity ────────────────────────────────────────────────────────────────
export EOS_PROJECT_NAME="execution-platform"

# ── Application surfaces ──────────────────────────────────────────────────────
# Path prefixes the pre-commit gate / INV-002 use to detect application-layer
# code. No application code exists pre-L5 (build deferral, Constitution §10).
export EOS_APP_SURFACE_PATHS="src/ app/"

# ── State machine + journal ───────────────────────────────────────────────────
export EOS_STATE_REGISTRY="ai/state_registry.json"
export EOS_JOURNAL="ai/engineering-journal.md"

# ── OS artifact directories ───────────────────────────────────────────────────
export EOS_SPEC_DIR="specs/"
export EOS_TASK_DIR="tasks/"
export EOS_PHASE_DIR="specs/phases/"
export EOS_VERIFICATION_DIR="scripts/verification/"

# ── Project invariant rule files (one *.sh per invariant) ─────────────────────
export EOS_INVARIANTS_DIR=".engineering-os/invariants/"
