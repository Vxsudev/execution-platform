#!/usr/bin/env bash
# PROXY → vendored Engineering OS state-manager.sh
#
# Sources the adapter config so EOS_STATE_REGISTRY redirects the vendored
# state-manager to the PROJECT registry (ai/state_registry.json) rather than
# the read-only vendored package default.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
[ -f .engineering-os/adapter.config.sh ] && . .engineering-os/adapter.config.sh
exec bash vendor/engineering-os/scripts/state-manager.sh "$@"
