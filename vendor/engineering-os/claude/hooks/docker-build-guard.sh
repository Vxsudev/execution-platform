#!/bin/bash
# docker-build-guard.sh — PreToolUse hook
# Blocks docker build without --no-cache.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if ! docker info >/dev/null 2>&1; then
  exit 0
fi

if echo "$CMD" | grep -qE "(^|\s)docker build" && ! echo "$CMD" | grep -q "\-\-no-cache"; then
  echo "BLOCKED: docker build without --no-cache is forbidden on this project." >&2
  echo "Required form: docker compose build backend --no-cache" >&2
  exit 2
fi

if echo "$CMD" | grep -qE "docker compose build" && ! echo "$CMD" | grep -q "\-\-no-cache"; then
  echo "BLOCKED: docker compose build without --no-cache is forbidden." >&2
  echo "Required form: docker compose build [service] --no-cache" >&2
  exit 2
fi

exit 0
