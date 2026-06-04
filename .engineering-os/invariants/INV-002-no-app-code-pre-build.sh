# INV-002 — No application code before L5 Build
#
# Constitution §10 (build deferral): application-layer code may not exist
# until the SDLC reaches implementation-ready state. This guards the
# application surface paths declared in adapter.config.sh.

EOS_INV_ID="INV-002"
EOS_INV_NAME="no application code before L5 Build"
EOS_INV_FAIL_MSG="application-layer files present before build phase — see Constitution §10"

check() {
  local p
  for p in ${EOS_APP_SURFACE_PATHS:-}; do
    if [ -d "$p" ] && [ -n "$(find "$p" -type f 2>/dev/null | head -1)" ]; then
      return 1
    fi
  done
  return 0
}
