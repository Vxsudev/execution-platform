# INV-004 — ADRs are append-only and well-formed
#
# Constitution §11: ADRs live at architecture/decisions/ADR-NNN-*.md, are
# never deleted or renumbered, and each carries a Status. This check enforces
# the structural portion (naming + Status presence). True temporal
# append-only (no edits to accepted ADRs) is additionally guarded at the
# commit boundary by the pre-commit hook + git history.

EOS_INV_ID="INV-004"
EOS_INV_NAME="ADRs are append-only and well-formed"
EOS_INV_FAIL_MSG="an ADR violates naming (ADR-NNN-*.md) or is missing a Status field"

check() {
  local dir="architecture/decisions"
  [ -d "$dir" ] || return 0
  local f base
  while IFS= read -r f; do
    base=$(basename "$f")
    case "$base" in
      ADR-[0-9][0-9][0-9]-*.md) ;;
      *) return 1 ;;
    esac
    grep -qi '^## Status\|^Status:' "$f" || return 1
  done < <(find "$dir" -type f -name '*.md')
  return 0
}
