# Engineering OS Adapter Config — TEMPLATE
#
# Copy this file to <project>/.engineering-os/adapter.config.sh and replace
# placeholder values (__PROJECT_NAME__, __APP_PATHS__, etc.) with project
# specifics.
#
# All paths are relative to the repository root (the CWD at invocation).

# Identity
export EOS_PROJECT_NAME="__PROJECT_NAME__"

# Application surfaces — space-separated path prefixes the pre-commit gate
# will use to detect application-layer changes.
export EOS_APP_SURFACE_PATHS="__APP_PATH_1__/ __APP_PATH_2__/"

# State machine + journal
export EOS_STATE_REGISTRY="ai/state_registry.json"
export EOS_JOURNAL="ai/engineering-journal.md"

# OS artifact directories
export EOS_SPEC_DIR="specs/"
export EOS_TASK_DIR="tasks/"
export EOS_PHASE_DIR="specs/phases/"
export EOS_VERIFICATION_DIR="scripts/verification/"

# Project-specific invariant rule files (one *.sh per invariant)
export EOS_INVARIANTS_DIR=".engineering-os/invariants/"

# Optional: project commands the OS hooks invoke. Comment out if unused.
# export EOS_ALEMBIC_CMD="docker exec __CONTAINER__ alembic current"
# export EOS_TSC_PATH="frontend/node_modules/.bin/tsc"
