# INV-006 — Every SDLC artifact declares traceability
#
# Constitution §7 (traceability): every governed artifact under sdlc/ must
# declare both "## Upstream Authority" and "## Downstream Consumers" so the
# authority graph stays closed (no orphans). Companion to INV-003.
#
# Note: this is the sixth process invariant. The vendored OS self-test
# (tests/003-os-invariant-engine.sh) requires exactly six invariant rule
# files and asserts "Result: 6/6 PASS"; INV-006 completes that contract while
# enforcing a genuine constitutional rule.

EOS_INV_ID="INV-006"
EOS_INV_NAME="every SDLC artifact declares upstream + downstream traceability"
EOS_INV_FAIL_MSG="an artifact under sdlc/ is missing '## Upstream Authority' or '## Downstream Consumers'"

check() {
  [ -d sdlc ] || return 0
  local f
  while IFS= read -r f; do
    grep -q '^## Upstream Authority' "$f" || return 1
    grep -q '^## Downstream Consumers' "$f" || return 1
  done < <(find sdlc -type f -name '*.md')
  return 0
}
