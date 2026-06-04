# INV-001 — Vendored Engineering OS is immutable
#
# The vendored OS snapshot must match the checksum manifest recorded at
# vendoring time. Any drift means the read-only OS core was tampered with.
# Scope excludes vendor/engineering-os/ai/ (the package's writable scratch
# registry used by OS self-tests), which is intentionally volatile.

EOS_INV_ID="INV-001"
EOS_INV_NAME="vendored Engineering OS snapshot is immutable"
EOS_INV_FAIL_MSG="vendored OS drift detected — vendor/engineering-os no longer matches recorded manifest"

check() {
  local manifest="vendor/.os-snapshot/manifest.sha256"
  [ -f "$manifest" ] || return 1
  shasum -c "$manifest" --status 2>/dev/null
}
