# INV-005 — Domain Constitution is derived, not invented
#
# Constitution §8: product invariants / runtime contracts / service boundaries
# (the Domain Constitution) may not exist until L2 Behavior artifacts are
# complete and approved. Until then, no domain-constitution artifact may be
# present. This guards against inventing invariants ahead of evidence.

EOS_INV_ID="INV-005"
EOS_INV_NAME="Domain Constitution forbidden before L2 Behavior is approved"
EOS_INV_FAIL_MSG="a Domain Constitution artifact exists before L2 Behavior preconditions are met — see Constitution §8"

# Candidate domain-constitution paths that must NOT exist pre-L2.
check() {
  local p
  for p in \
    ai/product-invariants.md \
    ai/runtime-contracts.md \
    ai/service-boundaries.md \
    sdlc/*/domain-constitution.md \
    sdlc/*/product-invariants.md
  do
    # Glob may not expand; test only real files.
    [ -e "$p" ] && return 1
  done
  return 0
}
