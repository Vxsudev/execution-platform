#!/usr/bin/env bash
# os-intent-entry.sh — Intent-to-Pipeline Entry Point
#
# Accepts a one-line natural-language intent and bootstraps the full
# Engineering OS pipeline: intent → spec → compile → tasks → exec.
#
# Spec layer is ALWAYS materialized — no direct intent → execution path.
# Spec status is set to "approved" at creation so compile gate passes.
#
# Slug generation:
#   - Lowercase, strip non-alpha
#   - Remove common English stopwords
#   - Join remaining words with hyphens
#
# Usage: os-intent-entry.sh <intent words...>
#
# Exit codes: propagated from execution-supervisor.sh

INTENT="$*"

if [ -z "$INTENT" ]; then
  echo "Usage: raystrat-os intent \"<one-line intent>\"" >&2
  echo "Example: raystrat-os intent \"light mode for dashboard\"" >&2
  exit 1
fi

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Slug generation ───────────────────────────────────────────────────────

STOPWORDS="a an the for in of on to at by with and or is are was were be been being that this into from its"

make_slug() {
  local input="$1"
  local slug=""
  local word

  # Lowercase, replace non-alpha chars with spaces, iterate words
  for word in $(printf '%s' "$input" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alpha:]' ' '); do
    local is_stop=false
    local sw
    for sw in $STOPWORDS; do
      if [ "$word" = "$sw" ]; then
        is_stop=true
        break
      fi
    done
    if [ "$is_stop" = false ] && [ -n "$word" ]; then
      slug="${slug:+${slug}-}${word}"
    fi
  done

  printf '%s' "$slug"
}

SLUG=$(make_slug "$INTENT")

if [ -z "$SLUG" ]; then
  echo "ERROR: intent produced empty slug — add content words to your intent" >&2
  exit 1
fi

# ── Title (slug → Title Case) ─────────────────────────────────────────────

TITLE=$(printf '%s' "$SLUG" \
  | tr '-' ' ' \
  | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')

# ── Spec file ─────────────────────────────────────────────────────────────

mkdir -p specs
SPEC_PATH="specs/${SLUG}.md"

if [ -f "$SPEC_PATH" ]; then
  echo "Spec exists: $SPEC_PATH"
  echo "Skipping creation — proceeding to compile."
else
  cat > "$SPEC_PATH" <<SPECEOF
# Spec: ${TITLE}

## Status
approved

## Phase
phase-ui

## Capability

${INTENT}

## Data Model Changes

none

## API Surface

none

## Frontend Surface

- ${INTENT}

## Dependencies

none
SPECEOF

  echo "Created: $SPEC_PATH"
fi

echo ""

# ── Chain: compile → exec ─────────────────────────────────────────────────

bash "$SELF_DIR/compile-spec.sh" "$SPEC_PATH"
exec bash "$SELF_DIR/execution-supervisor.sh" "$SLUG"
