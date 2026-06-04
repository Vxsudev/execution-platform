# INV-003 — Every SDLC artifact declares Layer and Status
#
# Constitution §6 (gates) and §3 (layer model): every governed artifact under
# sdlc/ must declare a "## Layer" and a "## Status" so the gate machinery and
# layer model can place and govern it. Also enforced as a lightweight scan by
# the pre-commit hook.

EOS_INV_ID="INV-003"
EOS_INV_NAME="every SDLC artifact declares Layer and Status"
EOS_INV_FAIL_MSG="an artifact under sdlc/ is missing a '## Layer' or '## Status' declaration"

check() {
  [ -d sdlc ] || return 0
  local f
  while IFS= read -r f; do
    grep -q '^## Layer' "$f" || return 1
    grep -q '^## Status' "$f" || return 1
  done < <(find sdlc -type f -name '*.md')
  return 0
}
