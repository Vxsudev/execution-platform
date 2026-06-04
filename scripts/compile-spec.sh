#!/usr/bin/env bash
# PROXY → vendored Engineering OS compile-spec.sh
#
# Pins CWD to the repo root and sources the adapter config so EOS_* paths
# propagate to the vendored pipeline (whose inner cross-calls — state-manager,
# generate-tasks — resolve CWD-relative and land on these project proxies).
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
[ -f .engineering-os/adapter.config.sh ] && . .engineering-os/adapter.config.sh
exec bash vendor/engineering-os/scripts/compile-spec.sh "$@"
