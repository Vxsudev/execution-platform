#!/usr/bin/env bash
# 001-os-enforcement-layer.sh — Vendored OS Self-Test
#
# Mirrors scripts/verification/279-os-enforcement-layer-v1.sh, asserting
# that the vendored package's enforcement-layer surfaces are intact.
#
# Run from repository root:
#   bash vendor/engineering-os/tests/001-os-enforcement-layer.sh
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks fail

PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "001 — Vendored OS Enforcement Layer Self-Test"
echo "══════════════════════════════════════════════════════════════"

# V1: Pre-commit hook exists and is executable in source repo
echo ""
echo "V1. Pre-commit hook exists and is executable"
if [ -f .git/hooks/pre-commit ] && [ -x .git/hooks/pre-commit ]; then
  pass "V1: .git/hooks/pre-commit exists and is executable"
else
  fail "V1: .git/hooks/pre-commit missing or not executable"
fi

# V2: Vendored generate-tasks.sh exists and is executable
echo ""
echo "V2. Vendored generate-tasks.sh exists and is executable"
if [ -f vendor/engineering-os/scripts/generate-tasks.sh ] && [ -x vendor/engineering-os/scripts/generate-tasks.sh ]; then
  pass "V2: vendor/engineering-os/scripts/generate-tasks.sh exists and is executable"
else
  fail "V2: vendor/engineering-os/scripts/generate-tasks.sh missing or not executable"
fi

# V3: Vendored generate-tasks.sh fails without OS execution token
echo ""
echo "V3. Vendored generate-tasks.sh exits non-zero without OS token"
rm -f /tmp/.os-compile-token-test 2>/dev/null
TOKEN_BACKUP=""
if [ -f /tmp/.os-compile-token ]; then
  TOKEN_BACKUP=$(cat /tmp/.os-compile-token)
  mv /tmp/.os-compile-token /tmp/.os-compile-token.testbak
fi
if bash vendor/engineering-os/scripts/generate-tasks.sh /tmp/dummy-spec.md > /dev/null 2>&1; then
  fail "V3: generate-tasks.sh exited 0 without OS token (should fail)"
else
  pass "V3: generate-tasks.sh exits non-zero without OS token"
fi
if [ -n "$TOKEN_BACKUP" ]; then
  mv /tmp/.os-compile-token.testbak /tmp/.os-compile-token
fi

# V4: Vendored compile-spec.sh exists and is executable
echo ""
echo "V4. Vendored compile-spec.sh exists and is executable"
if [ -f vendor/engineering-os/scripts/compile-spec.sh ] && [ -x vendor/engineering-os/scripts/compile-spec.sh ]; then
  pass "V4: vendor/engineering-os/scripts/compile-spec.sh exists and is executable"
else
  fail "V4: vendor/engineering-os/scripts/compile-spec.sh missing or not executable"
fi

# V5: Vendored execution-supervisor.sh exists and is executable
echo ""
echo "V5. Vendored execution-supervisor.sh exists and is executable"
if [ -f vendor/engineering-os/scripts/execution-supervisor.sh ] && [ -x vendor/engineering-os/scripts/execution-supervisor.sh ]; then
  pass "V5: vendor/engineering-os/scripts/execution-supervisor.sh exists and is executable"
else
  fail "V5: vendor/engineering-os/scripts/execution-supervisor.sh missing or not executable"
fi

# V6: Vendored state-manager.sh exists and is executable
echo ""
echo "V6. Vendored state-manager.sh exists and is executable"
if [ -f vendor/engineering-os/scripts/state-manager.sh ] && [ -x vendor/engineering-os/scripts/state-manager.sh ]; then
  pass "V6: vendor/engineering-os/scripts/state-manager.sh exists and is executable"
else
  fail "V6: vendor/engineering-os/scripts/state-manager.sh missing or not executable"
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "Result: $PASS PASS / $FAIL FAIL"

if [ $FAIL -gt 0 ]; then
  exit 1
fi
exit 0
