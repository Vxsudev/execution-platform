#!/usr/bin/env bash
# PROXY → vendored Engineering OS execution-supervisor.sh
#
# Pins CWD to repo root and sources the adapter config so EOS_STATE_REGISTRY
# (and other paths) propagate. The vendored supervisor's inner cross-calls
# (scripts/state-manager.sh, scripts/invariant-check.sh) resolve onto the
# project proxies.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
[ -f .engineering-os/adapter.config.sh ] && . .engineering-os/adapter.config.sh
exec bash vendor/engineering-os/scripts/execution-supervisor.sh "$@"
