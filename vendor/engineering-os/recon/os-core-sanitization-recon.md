# OS Core Sanitization Recon
# OS_CORE_SANITIZATION_V1

Date: 2026-05-01
Scope: RaystratSystems-AI-Engineering-OS full repo

---

## Summary

NEEDS CLEANUP — 5 files contain NDT-specific or stack-specific contamination.
Scripts, tests, templates, and ai/state_registry.json are clean.

---

## Contaminated Files

### 1. core-docs/spec-compiler.md — HARD + STACK CONTAMINATION

| Line | Hit | Classification |
|------|-----|----------------|
| 126 | `VITE_API_BASE_URL` hardcoded as OS-level API comm rule | HARD CONTAMINATION |
| 128 | `infra/env/` hardcoded as environment authority path | HARD CONTAMINATION |
| 149 | `Alembic migrations, ORM model additions` as pattern example | STACK CONTAMINATION |
| 157 | `ndt_center_id_uuid` as mandatory tenant filter field | HARD CONTAMINATION |
| 317 | `Alembic migration + ORM model update` in layer table | STACK CONTAMINATION |
| 319 | `RoleGuard wiring` in layer table | STACK CONTAMINATION |
| 330 | `Alembic migration and ORM model change` in mapping rule | STACK CONTAMINATION |
| 339 | `RoleGuard wiring` in mapping rule | STACK CONTAMINATION |

Required replacements:
- `VITE_API_BASE_URL` → `adapter-configured API base URL`
- `infra/env/` → `adapter-configured environment path`
- `Alembic migrations` / `Alembic migration file` → `migration artifact`
- `ORM model additions` → `data model additions`
- `ndt_center_id_uuid` → `<project_scope_field>`
- `RoleGuard wiring` → `access guard wiring`

---

### 2. core-docs/task-generator.md — STACK CONTAMINATION

| Line | Hit | Classification |
|------|-----|----------------|
| 263 | `Alembic migration file, ORM model changes` in layer table | STACK CONTAMINATION |
| 265 | `React page components`, `RoleGuard wiring` in layer table | STACK CONTAMINATION |

Required replacements:
- `Alembic migration file` → `migration artifact`
- `ORM model changes` → `data model changes`
- `React page components` → `frontend surface components`
- `RoleGuard wiring` → `access guard wiring`

---

### 3. core-docs/spec-to-task-playbook.md — STACK CONTAMINATION

| Line | Hit | Classification |
|------|-----|----------------|
| 174 | `Alembic migration file, ORM model additions/changes` | STACK CONTAMINATION |
| 176 | `React pages`, `RoleGuard wrappers` | STACK CONTAMINATION |

Required replacements:
- `Alembic migration file` → `migration artifact`
- `ORM model additions/changes` → `data model additions/changes`
- `React pages` → `frontend surface components`
- `RoleGuard wrappers` → `access guard wrappers`

---

### 4. core-docs/ENGINEERING_OS.md — STACK CONTAMINATION

| Line | Hit | Classification |
|------|-----|----------------|
| 136 | `` `infra/env/` `` hardcoded in runtime-contracts example | STACK CONTAMINATION |

Required replacement:
- `` `infra/env/` `` → `adapter-configured environment path`

---

### 5. README.md — NEEDS REVIEW (informational, not logic contamination)

| Line | Hit | Classification |
|------|-----|----------------|
| 4 | "Compiled from the NDT SaaS Engineering OS" — origin attribution | NEEDS REVIEW |

Required replacement:
- → "Extracted from a production system and generalized into a portable Engineering OS core."

---

## Acceptable — No Action Required

| File | Hit | Why Acceptable |
|------|-----|----------------|
| `tests/003-os-invariant-engine.sh:85` | `ndt\|audit_logs\|raw_events` in grep | Test logic checking FOR contamination — not contamination itself |
| `templates/adapter.config.sh:30` | `EOS_ALEMBIC_CMD` commented out | Commented-out placeholder example for adapter config |
| `claude/hooks/docker-build-guard.sh` | `docker compose build backend` | Generic docker compose guard; "backend" is example service name |
| `core-docs/directive-template.md:139` | `backend/migrations/` | Template example using `<project-trigger-name>` placeholder |
| `ai/state_registry.json` | OS state only | No NDT feature state present |

---

## Verification Command

```bash
grep -RniE "ndt|ndt_center|ndt_center_id_uuid|raw_events|audit_logs|device_sync|XRF|OES|report_templates|localhost:9696|ndt-backend|/Users/vasudevarao/ndt-saas|VITE_API_BASE_URL|infra/env|RoleGuard|React|Alembic" . --exclude-dir=.git
```

Post-cleanup expected residuals (all acceptable):
- `tests/003-os-invariant-engine.sh` — contamination-detection grep strings
- `templates/adapter.config.sh` — commented-out `EOS_ALEMBIC_CMD` example
- `core-docs/directive-template.md` — template placeholder example

---

## Additional Contamination Found During Verification Pass

The following files were not in the initial scan (used broader "ndt" pattern):

| File | Hit | Classification |
|------|-----|----------------|
| `claude/agents/spec-agent.md:9` | `# Spec Agent — NDT SaaS` | HARD CONTAMINATION — fixed |
| `claude/agents/journal-agent.md:9` | `# Journal Agent — NDT SaaS` | HARD CONTAMINATION — fixed |
| `scripts/compile-spec.sh:4` | `NDT SaaS Engineering OS` in comment | CONTAMINATION — fixed |
| `scripts/generate-tasks.sh:4` | `NDT SaaS Engineering OS` in comment | CONTAMINATION — fixed |
| `scripts/execution-supervisor.sh:4` | `NDT SaaS Engineering OS` in comment | CONTAMINATION — fixed |
| `scripts/execution-supervisor.sh:205` | `NDT Engineering OS` in live agent prompt | HARD CONTAMINATION — fixed |

## False Positives in Final Grep

Pattern `OES` case-insensitively matches "oes" in "does". All "does not" line hits are false positives.

## Status

- [x] core-docs/spec-compiler.md — COMPLETE
- [x] core-docs/task-generator.md — COMPLETE
- [x] core-docs/spec-to-task-playbook.md — COMPLETE
- [x] core-docs/ENGINEERING_OS.md — COMPLETE
- [x] README.md — COMPLETE
- [x] claude/agents/spec-agent.md — COMPLETE
- [x] claude/agents/journal-agent.md — COMPLETE
- [x] scripts/compile-spec.sh — COMPLETE
- [x] scripts/generate-tasks.sh — COMPLETE
- [x] scripts/execution-supervisor.sh — COMPLETE (comment + agent prompt)

## Self-Test Note

tests/run-self-tests.sh is designed for adapter-side execution only.
Run from consumer project root: `bash vendor/engineering-os/tests/run-self-tests.sh`
Tests look for `vendor/engineering-os/scripts/...` — not present in OS core repo.
Cannot pass when run from OS core repo itself. Expected behavior. Not a regression.
