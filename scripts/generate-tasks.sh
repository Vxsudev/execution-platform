#!/usr/bin/env bash
# PROXY → vendored Engineering OS generate-tasks.sh  (path bridge, recon A7.2)
#
# The vendored compile-spec.sh calls `bash scripts/generate-tasks.sh`
# CWD-relative; this proxy makes that resolve into the vendored generator.
# Conform-via-phases: the OS build-tier generator is retained as-is (build
# deferral to L5); no logic override.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck disable=SC1091
[ -f .engineering-os/adapter.config.sh ] && . .engineering-os/adapter.config.sh
exec bash vendor/engineering-os/scripts/generate-tasks.sh "$@"
