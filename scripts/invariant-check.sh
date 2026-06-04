#!/usr/bin/env bash
# PROXY / BRIDGE → vendored invariant-engine.sh  (recon A7.1)
#
# The vendored execution-supervisor and PROJECT_BOOTSTRAP reference
# `scripts/invariant-check.sh`, but the shipped engine is `invariant-engine.sh`.
# This bridge supplies that exact filename so the supervisor's invariant gate
# is live, routing to the engine with the project adapter config.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec bash vendor/engineering-os/scripts/invariant-engine.sh --config .engineering-os/adapter.config.sh "$@"
