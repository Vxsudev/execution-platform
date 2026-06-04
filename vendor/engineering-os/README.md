# RaystratSystems AI Engineering OS

Private execution-control layer for deterministic AI-assisted software delivery.

This repository contains the portable Engineering OS core extracted from a production system and sanitized for project-agnostic reuse.

## Boundary

The OS core owns:

- execution lifecycle
- spec-to-task pipeline
- state-machine enforcement
- invariant engine runner
- verification harness
- adapter contract templates

A consuming project owns:

- domain invariants
- service boundaries
- runtime contracts
- adapter configuration
- project-specific verification gates

## Structure

- `core-docs/` — portable OS doctrine
- `scripts/` — execution runtime
- `claude/` — agent, skill, and hook scaffolding
- `templates/` — adapter templates
- `tests/` — OS self-tests

## Status

Private core. Not public distribution material.