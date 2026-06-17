# Azure Migration Recon — NDT-SaaS

> Generated: 2026-06-16 | Source: 10-agent codebase recon  
> Status: Decision document — no Azure resources created, no code changed

---

## 1. Executive Summary

NDT-SaaS is a multi-tenant SaaS platform for non-destructive testing (NDT) labs, built as a FastAPI 0.109.2 backend with a React 19 + Vite 7 frontend, backed by PostgreSQL 16 and a custom DB-backed background worker. The migration goal is to move from a local Docker Compose development setup (zero cloud infrastructure) to a production-grade Azure deployment capable of serving real customer tenants without cold-start interruptions or data-loss risk. The primary risk is the local-disk file storage model: 11 write sites across 5 route files and the worker write PDF output to `/data/uploads` on the container filesystem, which is ephemeral on Azure Container Apps — this must be replaced with Azure Blob Storage before any deployment attempt. The recommended path is Option C (Production-Safe, ~$76–91/month): Azure Static Web Apps (Standard), two Azure Container Apps each at min-replicas=1, Neon Pro serverless PostgreSQL, GHCR for container images, and SendGrid for transactional email — with a Phase 0 secrets rotation completed before any provisioning begins.

---

## 2. Current Architecture

### Frontend
- **Framework:** React 19.2.0 with react-dom 19.2.0, React Router DOM v7.13.1
- **Build tool:** Vite 7.3.1 with `@vitejs/plugin-react`; TypeScript 5.9.3 with strict mode
- **Build output:** `npm run build` → `tsc -b && vite build` → `/app/dist` (static files)
- **Serving method in Docker:** `serve` npm package globally installed, `serve -s /app/dist -l ${PORT:-3000}`
- **Port:** 3000 (container), host 6969 in Docker Compose
- **API integration:** Native `fetch()` only — no axios. Single env var `VITE_API_BASE_URL` (default `http://localhost:9696`)
- **Auth tokens:** JWT stored in localStorage under keys `ndt_access_token` and `ndt_platform_token`
- **UI stack:** MUI 7.3.8, Tiptap 3.22.3, dnd-kit, recharts 3.8.0

### Backend API
- **Framework:** FastAPI 0.109.2
- **WSGI/ASGI server:** uvicorn[standard] 0.27.1, single process, no `--workers` flag
- **Port:** 8000 (container), host 9696 in Docker Compose
- **Entry point:** `app.main:app`
- **27 routers** registered flat (no versioning prefix)
- **Python version:** 3.11-slim Docker base image

### Worker
- **Queue system:** Custom DB-backed polling queue — no Celery, RQ, or Dramatiq
- **Broker table:** `worker_jobs` (PostgreSQL JSONB payload); heartbeat via `worker_heartbeats`
- **Concurrency model:** Single polling thread per container, 2-second poll interval, `FOR UPDATE SKIP LOCKED` for safe multi-worker fanout
- **Job types:** `normalize` (instrument parser dispatch) and `generate_report` (PDF rendering via reportlab)
- **Startup:** `python worker_main.py` in separate Docker Compose service `ndt-worker`

### Database
- **Engine:** PostgreSQL 16-alpine (Docker image)
- **Driver:** psycopg2-binary 2.9.9 (synchronous — no asyncpg)
- **ORM:** SQLAlchemy 2.0.25, synchronous API (`create_engine` + `sessionmaker` + `declarative_base`)
- **Connection pool:** pool_size=5, max_overflow=10, pool_pre_ping=True, pool_recycle=300s
- **Migration tool:** Alembic 1.13.1, 100 migration files (0001–0090 plus named stage files)
- **Auto-migrate on start:** `alembic upgrade head` runs synchronously in `entrypoint.sh` before uvicorn, after `pg_isready` polling (30 retries × 2s)
- **Connection string env var:** `DATABASE_URL` (default `postgresql://ndt_user:ndt_dev_password_change_in_prod@postgres:5432/ndt_saas`)

### File Storage
- **Method:** Local disk only — absolute paths under `LOCAL_UPLOAD_DIR` (default `/data/uploads`)
- **No cloud SDK** — no boto3, azure-storage-blob, or S3-compatible client anywhere in `requirements.txt`
- **Shared between backend and worker** via Docker Compose bind mount `./data/uploads:/data/uploads`
- **Write paths:** `/data/uploads/reports/{report_id}/{uuid8}_{filename}`, `/data/uploads/ai_uploads/{tenant_uuid}/{row_id}_{filename}`, `/data/uploads/reports/{gen_id}/generated.pdf`

### Auth
- **Dual-mode:** `AUTH_MODE` env var (`mock` or `required`)
- **Local JWT:** PyJWT HS256, secret from `JWT_SECRET`, 24h expiry, scopes: `tenant`, `identity`, `platform`
- **Auth0 path:** python-jose RS256, JWKS fetch, only active when `AUTH0_DOMAIN/AUDIENCE/ISSUER` all set
- **RBAC:** `guards.py` — `require_test_center()`, `require_role()`, `ensure_same_test_center()` (raises 404 not 403)
- **Device auth:** HMAC-SHA256 via `X-Device-ID`, `X-Timestamp`, `X-Signature` headers, 5-minute drift window

### Email
- **Provider abstraction:** `services/email_provider.py` — selects via `EMAIL_PROVIDER` env var
- **Providers:** `smtp` (stdlib smtplib + STARTTLS, default), `sendgrid` (REST via `requests`), `azure` (azure-communication-email SDK — **scaffolded but non-functional, package absent from requirements.txt**)
- **Dev config:** Gmail SMTP via `smtp.gmail.com:587` with Google App Password
- **Outbox tracking:** `email_outbox` DB table, MAX_RETRIES=5, exponential backoff capped at 3600s

### Container Setup
- **Docker Compose services:** `postgres` (postgres:16-alpine), `backend` (python:3.11-slim), `worker` (same image as backend), `frontend` (node:20-alpine)
- **Upload data volume:** `./data/uploads:/data/uploads` bind mount shared between backend and worker
- **DB volume:** `pgdata` named volume
- **Frontend in compose:** Vite dev server (`npm run dev -- --host`), not production build

### Environment Config
- **Config files:** `infra/env/backend.env`, `infra/env/frontend.env`, `infra/env/postgres.env`
- **Backend config loaded via:** `os.getenv()` for most vars; `pydantic-settings` from `.env` for Auth0 vars
- **Env guard:** `env_guard.py` validates `CLIENT_SLUG`, `ANTHROPIC_API_KEY`, `AUTH_MODE`, `JWT_SECRET` at startup — hard blocks malformed environments

---

## 3. Azure Target Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AZURE SUBSCRIPTION                                  │
│  Resource Group: ndt-saas-prod                                               │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  GitHub Actions (CI/CD)                                               │   │
│  │  Triggers on: push to main                                            │   │
│  │  Builds → GHCR → triggers Container App deployments                  │   │
│  └──────────────────────┬───────────────────────────────────────────────┘   │
│                         │                                                    │
│  ┌──────────────────────▼──────────────────┐                                │
│  │  Azure Static Web Apps (Standard Tier)  │ ◄── browser clients            │
│  │  Serves: /app/dist (Vite build output)  │                                │
│  │  Custom domain: app.ndt-saas.com        │                                │
│  │  Built-in SWA routing (catch-all → /   │                                │
│  │    index.html for SPA)                  │                                │
│  │  VITE_API_BASE_URL set at build time    │                                │
│  └──────────────────────┬──────────────────┘                                │
│                         │  HTTPS API calls                                   │
│  ┌──────────────────────▼──────────────────┐                                │
│  │  Azure Container Apps Environment       │                                │
│  │  (Consumption + Dedicated plan mix)     │                                │
│  │                                         │                                │
│  │  ┌────────────────────────────────┐     │                                │
│  │  │  Container App: ndt-backend    │     │                                │
│  │  │  Image: ghcr.io/org/ndt-saas/  │     │                                │
│  │  │         backend:sha            │     │                                │
│  │  │  Min replicas: 1               │     │                                │
│  │  │  Max replicas: 3               │     │                                │
│  │  │  Port: 8000 (uvicorn)          │     │                                │
│  │  │  Env: Key Vault refs or direct │     │                                │
│  │  └───────────────┬────────────────┘     │                                │
│  │                  │                       │                                │
│  │  ┌───────────────▼────────────────┐     │                                │
│  │  │  Container App: ndt-worker     │     │                                │
│  │  │  Image: same backend image     │     │                                │
│  │  │  Command: python worker_main.py│     │                                │
│  │  │  Min replicas: 1               │     │                                │
│  │  │  No ingress (internal only)    │     │                                │
│  │  └───────────────┬────────────────┘     │                                │
│  │                  │                       │                                │
│  └──────────────────┼───────────────────────┘                                │
│                     │                                                        │
│  ┌──────────────────▼──────────────────────┐                                │
│  │  Neon Pro (serverless PostgreSQL)        │                                │
│  │  OR Azure DB for PostgreSQL Flexible     │                                │
│  │  Version: PostgreSQL 16                  │                                │
│  │  Accessed via DATABASE_URL DSN           │                                │
│  └─────────────────────────────────────────┘                                │
│                                                                              │
│  ┌─────────────────────────────────────────┐                                │
│  │  Azure Blob Storage                      │                                │
│  │  Container: ndt-uploads                  │                                │
│  │  Used by: backend + worker               │                                │
│  │  Replaces: ./data/uploads bind mount     │                                │
│  │  Access: AZURE_STORAGE_CONNECTION_STRING │                                │
│  └─────────────────────────────────────────┘                                │
│                                                                              │
│  ┌─────────────────────────────────────────┐                                │
│  │  Azure Key Vault (optional in Phase 1)   │                                │
│  │  Stores: JWT_SECRET, ANTHROPIC_API_KEY,  │                                │
│  │  DATABASE_URL, SMTP_PASSWORD             │                                │
│  └─────────────────────────────────────────┘                                │
│                                                                              │
│  ┌─────────────────────────────────────────┐                                │
│  │  GHCR (GitHub Container Registry)       │                                │
│  │  ghcr.io/{org}/ndt-saas/backend:{sha}   │                                │
│  │  Free for public, $0 for org pkgs       │                                │
│  └─────────────────────────────────────────┘                                │
│                                                                              │
│  EMAIL: SendGrid (transactional) — switch EMAIL_PROVIDER=sendgrid           │
│  LOGS: Azure Monitor / Log Analytics (Container Apps built-in)              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Component-to-Service Mapping

| Current Component | Current Tech | Azure Service | Notes |
|---|---|---|---|
| Frontend | React 19 + Vite 7, served by `serve` npm package | Azure Static Web Apps (Standard, ~$9/mo) | Static build served from CDN edge. SPA catch-all rewrite needed via `staticwebapp.config.json`. |
| Backend API | FastAPI 0.109.2, uvicorn, Docker | Azure Container Apps (min-replicas=1) | Single container, port 8000. Stateless except for file writes (mitigated by Blob Storage). |
| Worker | Custom DB-poll worker, `python worker_main.py`, Docker | Azure Container Apps (min-replicas=1, no ingress) | Separate container app, same image. `FOR UPDATE SKIP LOCKED` proven safe for multi-replica. |
| PostgreSQL | postgres:16-alpine (Docker), psycopg2 | Neon Pro (recommended) OR Azure DB for PostgreSQL Flexible Server (Burstable B1ms) | Neon Pro ~$19/mo; Azure Flexible Server ~$25–40/mo. Both support DATABASE_URL DSN with no driver changes. |
| File Storage | Local bind mount `./data/uploads` | Azure Blob Storage (LRS, Hot tier) | ~$1–3/mo for small SaaS. Requires `backend/services/storage.py` abstraction. CRITICAL blocker. |
| Container Registry | None (built locally) | GHCR (GitHub Container Registry) | Free for public repos, included in GitHub org plans. No ACR needed unless private org images required. |
| Email | smtplib SMTP (Gmail App Password) | SendGrid (Free tier → Essentials) | `EMAIL_PROVIDER=sendgrid` already supported in code. Azure Communication Services email NOT functional (package absent from requirements.txt). |
| Secrets | Plaintext in `infra/env/backend.env` | GitHub Actions Secrets (CI/CD) + Azure Container Apps env vars OR Azure Key Vault | Key Vault adds ~$5/mo but is optional in Phase 1 if secrets are injected via Container Apps environment config. |
| Logs | Docker compose logs (local) | Azure Monitor / Log Analytics (included in Container Apps) | Structured stdout logs from FastAPI/uvicorn flow automatically. |
| CI/CD | GitHub Actions (soft-fail, no deployment) | GitHub Actions → GHCR → `az containerapp update` | Extend existing `.github/workflows/ci.yml` with deploy job. |

---

## 5. Required Code Changes

### Change 1: Storage Abstraction Layer

**Files affected:**
- `backend/services/storage.py` (new file — StorageBackend interface)
- `backend/app/routes/files.py`
- `backend/app/routes/ai_staged_uploads.py`
- `backend/app/routes/report_templates.py`
- `backend/app/routes/tenant_branding.py`
- `backend/app/routes/datasets.py`
- `backend/app/routes/dfc.py`
- `backend/app/routes/reports.py`
- `backend/services/worker.py`
- `backend/services/dfc_engine.py`
- `backend/services/ai_controller.py`

**What must change:** All 11 write sites and 10 read sites that reference `LOCAL_UPLOAD_DIR` and call `Path(...).write_bytes()`, `open(..., 'wb')`, `os.replace()`, `Path(...).read_bytes()`, and `os.path.exists()` must route through a `StorageBackend` interface. The `LocalBackend` implementation passes through to current behavior (zero regression for local dev). The `AzureBlobBackend` uses `azure-storage-blob` SDK. Selection controlled by `STORAGE_BACKEND=local|azure` env var.

**Complexity:** High

**Why it cannot be avoided:** Azure Container Apps has ephemeral local storage. Files written by the backend container are invisible to the worker container and are lost on any container restart, scale event, or revision deploy. The `./data/uploads` bind mount does not exist in the Azure Container Apps model — there is no shared filesystem between containers.

**Special case:** `GeneratedReport.pdf_path` column stores absolute filesystem paths (e.g., `/data/uploads/reports/123/generated.pdf`). In the Azure storage model, `pdf_path` must store a Blob path key (e.g., `reports/123/generated.pdf`) relative to the storage container. A one-time data migration script is required to convert existing absolute paths if any production data already exists.

---

### Change 2: AUTH_MODE=mock Disabled in Production

**Files affected:**
- `backend/app/routes/auth.py` (lines 181–223)
- `infra/env/backend.env` (env var only)

**What must change:** `AUTH_MODE` must be set to `required` in the production deployment. In `mock` mode, posting any email to `/api/auth/login` auto-creates a user without a password — this is a critical authentication bypass. No code change is required if the env var is correctly set, but `env_guard.py` must be verified to enforce `required` in production contexts. A recommended hardening is to add an `ENVIRONMENT=production` guard that blocks startup if `AUTH_MODE=mock`.

**Complexity:** Low

**Why it cannot be avoided:** `AUTH_MODE=mock` is a passwordless backdoor. Any user who knows any valid email address can authenticate as that user without credentials.

---

### Change 3: staticwebapp.config.json for SPA Routing

**Files affected:**
- `frontend/staticwebapp.config.json` (new file)

**What must change:** Azure Static Web Apps does not natively serve SPA catch-all routes. Without a `staticwebapp.config.json` with a navigation fallback rule, any direct navigation to a route such as `/dashboard` or `/projects/123` will return a 404 from the Azure CDN. The file must contain a route rewrite: all non-asset requests → `index.html`.

**Complexity:** Low

**Why it cannot be avoided:** React Router v7 uses `BrowserRouter` with client-side routing. Deep links and page refreshes will 404 on Azure SWA without the fallback configuration.

---

### Change 4: VITE_API_BASE_URL Injected at Build Time

**Files affected:**
- `frontend/src/auth/api.ts` (reads `import.meta.env.VITE_API_BASE_URL`)
- GitHub Actions workflow for frontend build

**What must change:** `VITE_API_BASE_URL` is baked into the static bundle at `npm run build` time. In the Azure SWA deployment, the build must be triggered with the production Container Apps backend URL passed as the build arg. One component (`ProvisionedDeviceView.tsx`) falls back to `window.location.origin` for WebSocket URLs — this fallback may point to the SWA domain instead of the API domain and must be verified.

**Complexity:** Low

**Why it cannot be avoided:** Vite replaces `import.meta.env.VITE_*` at compile time. There is no runtime env injection for static builds. The correct API URL must be known at GitHub Actions build time.

---

### Change 5: Alembic Migration Concurrency Guard

**Files affected:**
- `backend/entrypoint.sh`

**What must change:** `entrypoint.sh` runs `alembic upgrade head` unconditionally on every container boot. With multiple Container Apps replicas (e.g., rolling deploy of backend, or backend + worker both starting simultaneously), concurrent Alembic runs against the same PostgreSQL database create a race condition. The fix is a PostgreSQL advisory lock: `SELECT pg_try_advisory_lock(12345)` at the start of the migration step, with a retry or skip if already locked by another instance.

**Complexity:** Medium

**Why it cannot be avoided:** Alembic uses a `alembic_version` table with no row-level locking for concurrent migrations. Two containers running `alembic upgrade head` simultaneously can corrupt the migration state or fail with constraint errors.

---

### Change 6: add azure-storage-blob to requirements.txt

**Files affected:**
- `backend/requirements.txt`

**What must change:** Add `azure-storage-blob>=12.19.0` (the Azure Blob Storage SDK). This is a direct dependency of the new `AzureBlobBackend` class in `services/storage.py`. Also consider adding `azure-identity` if managed identity auth is preferred over connection strings.

**Complexity:** Low

**Why it cannot be avoided:** The Azure SDK package is not present in `requirements.txt`. The Docker image build will fail without it.

---

### Change 7: CORS Origins for Production Domain

**Files affected:**
- `infra/env/backend.env` (env var only)
- `backend/app/main.py` (CORS config reads `CORS_ORIGINS` env var)

**What must change:** `CORS_ORIGINS` currently defaults to `http://localhost:6969` and `http://localhost:5173`. In production, the allowed origin must be the Azure Static Web Apps domain (e.g., `https://app.ndt-saas.com` or the auto-assigned `.azurestaticapps.net` URL). No code change required — the `CORS_ORIGINS` env var accepts a comma-separated list.

**Complexity:** Low

**Why it cannot be avoided:** Browser CORS enforcement will block all API calls from the production frontend if the backend does not list the production domain as an allowed origin.

---

### Change 8: Secrets Rotation

**Files affected:**
- `infra/env/backend.env` (contains live keys committed to working tree)

**What must change:** Before any cloud provisioning, rotate: (1) `ANTHROPIC_API_KEY` (`sk-ant-api03-MVIlpyzAF...`) and `PLATFORM_ANTHROPIC_API_KEY` — same key, must be revoked at console.anthropic.com; (2) `SMTP_PASSWORD` (`lcrzfbtcaehygghw`) — revoke in Google account; (3) `JWT_SECRET` — generate a new 256-bit random string. The `infra/env/backend.env` file must be added to `.gitignore` and replaced with `infra/env/backend.env.example`.

**Complexity:** Low (rotation is a credentials operation, not a code change)

**Why it cannot be avoided:** The working-tree `backend.env` contains live Anthropic API keys and an active Gmail App Password. If this file is ever pushed to a remote (accidentally or via force push), both keys are immediately compromised at full API spend capacity.

---

## 6. No-Code-Change Areas

The following components require zero code changes and run identically on Azure:

- **FastAPI application logic** — all 27 routers, RBAC guards, auth validation, rate limiting, dependency injection
- **SQLAlchemy ORM models** — all model definitions, relationships, and query patterns
- **Alembic migrations** — all 100 migration files run unchanged; DATABASE_URL is the only config needed
- **JWT authentication** — PyJWT HS256 and python-jose RS256 paths work identically with new env vars
- **Worker queue logic** — `services/worker.py`, `FOR UPDATE SKIP LOCKED` pattern, lease/heartbeat mechanics, job type dispatch
- **Instrument parsers** — `icp_universal_parser.py`, `icpms_parser.py`, `niton_parser.py`, `oes_parser.py`, `oxford_xmet_parser.py`, `thermo_chemistry_parser.py`, `thermo_spectra_parser.py`, `ut_flaw_parser.py`, `ut_thickness_parser.py`, `xrf_universal_parser.py`
- **Email provider abstraction** — `services/email_provider.py` already supports `smtp`, `sendgrid`, and `azure` (smtp and sendgrid are functional)
- **PDF generation** — `reportlab`-based PDF rendering in `services/worker.py` is CPU-bound, no filesystem assumptions beyond StorageBackend writes
- **AI/LLM controller** — `anthropic>=0.34.0` SDK calls are HTTP-based and platform-agnostic
- **Device HMAC auth** — `app/dependencies/device_hmac_auth.py` is self-contained
- **Frontend React/MUI code** — no frontend component changes required beyond `staticwebapp.config.json` and build-time env var configuration
- **Frontend API client** — `api/client.ts`, `authHeaders()`, `throwOnError()`, force-logout mechanism all work unchanged with a new `VITE_API_BASE_URL`
- **env_guard.py validation** — works unchanged; just needs updated env var values in production

---

## 7. Storage Migration Analysis

### Current Write Sites (from recon)

| File | Path Pattern | Size Limit | Notes |
|---|---|---|---|
| `app/routes/files.py` | `{LOCAL_UPLOAD_DIR}/reports/{report_id}/{uuid8}_{filename}` | 500 MB | Read into memory; any content_type |
| `app/routes/files.py` | Same path (download read) | — | `os.path.exists()` + `open()` |
| `app/routes/ai_staged_uploads.py` | `{LOCAL_UPLOAD_DIR}/ai_uploads/{tenant_uuid}/{row_id}_{filename}` | 10 MB | PDF, PNG, JPEG only |
| `app/routes/ai_staged_uploads.py` | Same path (extract-template read) | — | `Path.read_bytes()` |
| `app/routes/report_templates.py` | Preview uses `tempfile.NamedTemporaryFile`, unlinked after response | — | System temp dir, short-lived |
| `services/worker.py` | `{LOCAL_UPLOAD_DIR}/reports/{gen_id}/generated.pdf` | — | Atomic write via `tempfile.mkstemp` + `os.replace` |
| `services/worker.py` | `{LOCAL_UPLOAD_DIR}/{tb.logo_url}` (read) | — | Branding logo read for PDF |
| `services/worker.py` | `{LOCAL_UPLOAD_DIR}/ai_uploads/...` (read + delete) | — | Staged uploads cleanup |

**Database columns storing paths:**
- `GeneratedReport.pdf_path` — stores **absolute path** (e.g., `/data/uploads/reports/123/generated.pdf`) — HIGH migration impact
- `ReportFile.stored_path` — relative path — migrates cleanly
- `TenantBranding.logo_url` — relative path — migrates cleanly
- `Dataset.source_file_path` — relative path — migrates cleanly
- `AiStagedUpload.stored_path` — relative path — migrates cleanly

### Proposed StorageBackend Interface

**New file:** `backend/services/storage.py`

```python
# Interface (not a code change — documentation only)
class StorageBackend:
    def write(self, key: str, data: bytes, content_type: str = "application/octet-stream") -> str: ...
    def read(self, key: str) -> bytes: ...
    def exists(self, key: str) -> bool: ...
    def delete(self, key: str) -> None: ...
    def generate_presigned_url(self, key: str, expiry_seconds: int = 3600) -> str: ...

class LocalBackend(StorageBackend): ...   # wraps current Path-based logic
class AzureBlobBackend(StorageBackend): ... # wraps azure-storage-blob BlobServiceClient
```

Selection: `STORAGE_BACKEND=local` (default, zero regression) or `STORAGE_BACKEND=azure`.

### Migration Steps

1. Implement `services/storage.py` with `LocalBackend` and `AzureBlobBackend`
2. Add `azure-storage-blob>=12.19.0` to `requirements.txt`
3. Replace all direct `Path.write_bytes()`, `open()`, `os.replace()` calls in the 11 write sites with `storage.write(key, data)`
4. Replace all `Path.read_bytes()`, `open()` read calls in the 10 read sites with `storage.read(key)`
5. Replace `os.path.exists()` checks with `storage.exists(key)`
6. Change `GeneratedReport.pdf_path` DB column to store relative key, not absolute path — write Alembic migration to strip the `/data/uploads/` prefix from existing rows
7. Add `AZURE_STORAGE_CONNECTION_STRING` and `AZURE_STORAGE_CONTAINER_NAME` env vars
8. Integration test with `LocalBackend` (existing tests unchanged), then smoke test with `AzureBlobBackend` against real Azure Blob container

### Blast Radius Assessment

- **High impact:** `services/worker.py` — both PDF writes and logo reads must migrate
- **High impact:** `app/routes/files.py` — primary upload/download endpoint, 500 MB upload path
- **Medium impact:** `app/routes/ai_staged_uploads.py` — 10 MB uploads, cleanup loop in worker
- **Medium impact:** `app/routes/report_templates.py` — preview uses tempfile (already ephemeral, no migration needed for preview); generated PDF path indirectly via `gen.pdf_path`
- **Low impact:** `app/routes/tenant_branding.py`, `services/dfc_engine.py`, `services/ai_controller.py` — use existing stored paths, just need read path updated

---

## 8. Deployment Pipeline Plan

### Overview

```
GitHub push to main
  → GitHub Actions: ci.yml (extend existing)
      ├── backend-checks (pytest + import check)
      ├── frontend-checks (tsc + build)
      └── [new] deploy (depends on both checks)
            ├── Build backend Docker image
            ├── Push to GHCR
            ├── Run Alembic migration (one-time job or entrypoint)
            ├── Deploy backend Container App
            ├── Deploy worker Container App (same image)
            └── Build + deploy frontend to Static Web Apps
```

### Workflow Stages

**Stage 1: Build and Test**
- Trigger: `push` to `main` or PR targeting `main`
- Jobs: existing `backend-checks` and `frontend-checks` — harden `continue-on-error: false` before production
- No deployment in this stage for PRs

**Stage 2: Container Build and Push**
- Trigger: push to `main` (after checks pass)
- Build `./backend/Dockerfile` with tag `ghcr.io/{org}/ndt-saas/backend:{sha}` and `backend:latest`
- Push both tags to GHCR using `GITHUB_TOKEN` (no additional registry credentials needed)

**Stage 3: Database Migration**
- Run as a one-shot Container App Job: `az containerapp job create` with `python -m alembic upgrade head`
- Injects `DATABASE_URL` from GitHub Secrets
- Must complete (exit 0) before API containers are updated
- Advisory lock added to `entrypoint.sh` protects against concurrent runs

**Stage 4: Container App Deployments**
```bash
az containerapp update \
  --name ndt-backend \
  --resource-group ndt-saas-prod \
  --image ghcr.io/{org}/ndt-saas/backend:{sha}

az containerapp update \
  --name ndt-worker \
  --resource-group ndt-saas-prod \
  --image ghcr.io/{org}/ndt-saas/backend:{sha}
```

**Stage 5: Frontend Deploy to Static Web Apps**
```bash
# Build with production API URL
VITE_API_BASE_URL=https://ndt-backend.{region}.azurecontainerapps.io \
  npm run build

# Deploy via Azure/static-web-apps-deploy action
- uses: Azure/static-web-apps-deploy@v1
  with:
    azure_static_web_apps_api_token: ${{ secrets.SWA_DEPLOY_TOKEN }}
    app_location: "frontend"
    output_location: "dist"
    app_build_command: "npm run build"
```

### Secrets Injection

All secrets stored in **GitHub Actions Secrets** (repository or environment level):
- `DATABASE_URL` → injected as Container App env var at deploy time
- `JWT_SECRET` → injected as Container App env var
- `ANTHROPIC_API_KEY` → injected as Container App env var
- `SMTP_PASSWORD` or `SENDGRID_API_KEY` → injected as Container App env var
- `AZURE_STORAGE_CONNECTION_STRING` → injected as Container App env var
- `SWA_DEPLOY_TOKEN` → used only by GitHub Actions SWA deploy action
- `AZURE_CREDENTIALS` → service principal JSON for `az` CLI authentication in workflow

---

## 9. Cost Options

| Dimension | Option A: Lowest Cost | Option B: Azure-Native | Option C: Production-Safe (RECOMMENDED) |
|---|---|---|---|
| **Monthly estimate** | ~$36–52/month | ~$124–164/month | ~$76–91/month |
| **PostgreSQL** | Azure DB Flexible Server Burstable B1ms (~$13/mo) | Azure DB Flexible Server General Purpose D2s_v3 (~$72/mo) | Neon Pro serverless (~$19/mo, scales to zero on inactivity) |
| **Container hosting** | Azure Container Apps Consumption (scale-to-zero, pay-per-use) | Azure Container Apps Dedicated plan (D4 environment, always-on) | Azure Container Apps Consumption with min-replicas=1 (~$30/mo for both API + worker at 0.25 vCPU / 0.5 GB each) |
| **Storage (Blob)** | Azure Blob LRS Hot tier (~$1–2/mo) | Azure Blob LRS Hot tier (~$1–2/mo) | Azure Blob LRS Hot tier (~$1–2/mo) |
| **Registry** | GHCR (free with GitHub org) | Azure Container Registry Basic (~$5/mo) | GHCR (free with GitHub org) |
| **Email** | Gmail SMTP via smtplib (free, rate-limited to 500/day) | Azure Communication Services Email (~$0.00025/email, effectively free at low volume) | SendGrid Free tier (100/day free) or Essentials ($14.95/mo for 50K/mo) |
| **Static Web Apps** | Azure SWA Free tier ($0, limited bandwidth) | Azure SWA Standard (~$9/mo) | Azure SWA Standard (~$9/mo) |
| **Operational complexity** | Low — minimal services | High — ACR, dedicated ACA plan, Azure SMTP, all Azure-native | Medium — mix of Azure and external services (GHCR, Neon, SendGrid) |
| **Lock-in risk** | Low | High — full Azure vendor lock | Medium — DB (Neon) and email (SendGrid) are portable, ACA is replaceable |
| **Reliability risk** | HIGH — scale-to-zero causes 20–60s cold starts on first request; worker may not be ready when API starts job | Low — dedicated resources, always warm | Low — min-replicas=1 eliminates cold starts; worker always running |
| **Migration difficulty** | Low — fewer services to configure | Medium — ACR auth + dedicated plan complexity | Low-Medium — straightforward but requires Neon account setup |

**Option A** is unsuitable for any production workload due to cold-start risk on scale-to-zero Container Apps. The Alembic migration job on every boot and the 2-second worker poll loop also behave unpredictably with cold starts.

**Option B** is overprovisioned for a sub-1000 user SaaS at launch. The dedicated ACA environment alone is ~$75/mo before any compute.

**Option C** provides genuine production safety (no cold starts, no worker downtime between polls) at a price point appropriate for a pre-revenue or early-revenue SaaS product.

---

## 10. Risk Register

| Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|
| Local uploads lost on container restart | CRITICAL | Certain (Container Apps has ephemeral storage) | Implement StorageBackend abstraction before any deployment (Change 1) |
| `AUTH_MODE=mock` in production | CRITICAL | High (current default in backend.env) | Set `AUTH_MODE=required` in production env vars; add ENVIRONMENT guard to env_guard.py |
| Concurrent Alembic migrations on rolling deploy | HIGH | Medium (two replicas starting simultaneously) | Add PostgreSQL advisory lock to `entrypoint.sh` migration step |
| DB connection pool exhaustion on cold start | HIGH | Medium (two containers + connection limit) | Use Neon Pro (serverless, high connection limit) or set `pool_size=3, max_overflow=5`; enable PgBouncer if needed |
| `GeneratedReport.pdf_path` stores absolute paths | HIGH | Certain (current column format) | Data migration Alembic script to strip `/data/uploads/` prefix; update worker write path |
| `VITE_API_BASE_URL` baked at wrong URL | HIGH | Medium (build must know final API URL before frontend deploy) | Configure GitHub Actions to build frontend after Container App URL is confirmed; store URL in GitHub Vars |
| `staticwebapp.config.json` missing | HIGH | Certain (file does not exist yet) | Create file with SPA fallback rule before first SWA deploy |
| Live Anthropic API key in working tree | HIGH | Certain (key is in `infra/env/backend.env`) | Rotate immediately; add `infra/env/backend.env` to `.gitignore` |
| Gmail SMTP blocked by Google in production | MEDIUM | High (Google may block SMTP from Azure IPs) | Switch `EMAIL_PROVIDER=sendgrid`; Gmail SMTP is already a dev-only config |
| Worker misses jobs during replica scale-down | LOW | Low (`FOR UPDATE SKIP LOCKED` + lease expiry handles this) | Worker proven safe for multi-replica; lease expiry + heartbeat staleness check recovers stuck jobs |
| Blob Storage access permissions misconfigured | MEDIUM | Medium (first-time Azure setup) | Use private container with connection string auth (not public access); test read/write in staging before prod cutover |
| CORS not updated for production domain | HIGH | High (currently hardcoded localhost) | Set `CORS_ORIGINS` env var to production SWA URL at Container App deploy time |
| Rollback complexity | MEDIUM | Low (no in-place migrations without rollback scripts) | All Alembic migrations should have `downgrade` steps; Container App supports revision-based rollback via previous image tag |
| `azure-communication-email` package absent | MEDIUM | Certain (scaffolded but non-functional) | Use `EMAIL_PROVIDER=sendgrid` or `smtp`; do not rely on Azure email until package is added and tested |

---

## 11. Migration DAG

**Node 1: Azure Account + Resource Group Setup**
- Goal: Create Azure subscription (or use existing), create resource group `ndt-saas-prod`, assign service principal with Contributor role for GitHub Actions
- Files likely affected: None (infra provisioning only)
- Verification method: `az group show --name ndt-saas-prod` returns successfully; service principal can authenticate with `az login --service-principal`
- Rollback note: Delete resource group to remove all provisioned resources in one operation
- Depends on: Nothing (first node)

---

**Node 2: Secrets Rotation and .gitignore Hardening**
- Goal: Rotate Anthropic API key (console.anthropic.com), Gmail app password (Google account), generate new JWT_SECRET; add `infra/env/backend.env` to `.gitignore`
- Files likely affected: `infra/env/backend.env`, `.gitignore`
- Verification method: Old API key returns 401 from Anthropic API; new key returns 200; `git status` shows `backend.env` as untracked
- Rollback note: New credentials can be revoked independently; `.gitignore` change is safe
- Depends on: Node 1 (risk awareness; logically independent but should complete before any remote exposure)

---

**Node 3: Container Registry (GHCR)**
- Goal: Decide on GHCR vs ACR; configure GitHub Actions to authenticate and push to `ghcr.io/{org}/ndt-saas/backend`
- Files likely affected: `.github/workflows/ci.yml` (add docker build + push job)
- Verification method: `docker pull ghcr.io/{org}/ndt-saas/backend:latest` succeeds from local machine with GITHUB_TOKEN
- Rollback note: GHCR packages can be deleted via GitHub UI; image tags are immutable by SHA
- Depends on: Node 1

---

**Node 4: Storage Layer (Azure Blob + StorageBackend abstraction)**
- Goal: Create Azure Blob Storage account and container `ndt-uploads`; implement `backend/services/storage.py` with `LocalBackend` and `AzureBlobBackend`; refactor all 11 write sites and 10 read sites; add `azure-storage-blob` to `requirements.txt`; write Alembic migration to normalize `GeneratedReport.pdf_path`
- Files likely affected: `backend/services/storage.py` (new), `backend/requirements.txt`, `backend/app/routes/files.py`, `backend/app/routes/ai_staged_uploads.py`, `backend/app/routes/report_templates.py`, `backend/services/worker.py`, `backend/services/dfc_engine.py`, `backend/services/ai_controller.py`, new Alembic migration file
- Verification method: Upload a file via API with `STORAGE_BACKEND=azure`; verify it appears in Azure Blob Storage portal; download it back; verify worker PDF is written to blob; verify `GeneratedReport.pdf_path` column stores relative key not absolute path
- Rollback note: `STORAGE_BACKEND=local` env var reverts to original behavior with zero code change; blob data can be deleted; Alembic downgrade restores absolute path column
- Depends on: Node 1, Node 2

---

**Node 5: Database Provisioning**
- Goal: Provision Neon Pro (or Azure DB for PostgreSQL Flexible Server); run `alembic upgrade head` against the new database; seed initial admin and demo data; add advisory lock to `entrypoint.sh`
- Files likely affected: `backend/entrypoint.sh` (advisory lock addition), no application code changes
- Verification method: `psql $DATABASE_URL -c "SELECT COUNT(*) FROM alembic_version"` returns 1 row; `SELECT * FROM ndt_centers LIMIT 1` returns the seeded tenant
- Rollback note: Delete Neon project or drop Azure Flexible Server; Alembic migration state is in the DB; dropping the DB resets everything
- Depends on: Node 1

---

**Node 6: Backend Container App Deployment**
- Goal: Deploy `ndt-backend` Container App from GHCR image; configure all env vars (`DATABASE_URL`, `JWT_SECRET`, `ANTHROPIC_API_KEY`, `AZURE_STORAGE_CONNECTION_STRING`, `AUTH_MODE=required`, `CORS_ORIGINS`, `STORAGE_BACKEND=azure`, `LOCAL_UPLOAD_DIR=/data/uploads`); set min-replicas=1
- Files likely affected: `.github/workflows/ci.yml` (deploy stage), no application code changes
- Verification method: `curl https://ndt-backend.{region}.azurecontainerapps.io/health` returns 200; `curl .../openapi.json` returns OpenAPI spec
- Rollback note: `az containerapp update --image {previous_sha}` restores prior revision
- Depends on: Node 3, Node 4, Node 5

---

**Node 7: Frontend Deployment to Static Web Apps**
- Goal: Create Azure Static Web Apps resource; create `frontend/staticwebapp.config.json` with SPA catch-all route; configure GitHub Actions SWA deploy action with `VITE_API_BASE_URL` set to backend Container App URL
- Files likely affected: `frontend/staticwebapp.config.json` (new), `.github/workflows/ci.yml`
- Verification method: Navigate to `https://{swa-name}.azurestaticapps.net/dashboard` — page loads without 404; browser network tab shows API calls going to correct backend URL
- Rollback note: SWA has deployment history; revert to previous deployment via Azure Portal
- Depends on: Node 6 (needs backend URL before build)

---

**Node 8: Worker Container App Deployment**
- Goal: Deploy `ndt-worker` Container App from same GHCR image as backend; set command override to `python worker_main.py`; configure no external ingress; set min-replicas=1; configure `ENABLE_EMAIL_RETRY=true` if desired
- Files likely affected: `.github/workflows/ci.yml` (deploy stage)
- Verification method: Check `worker_heartbeats` table has a recent entry within 30 seconds of deploy; enqueue a test `normalize` job and verify it transitions to `completed`
- Rollback note: `az containerapp update --image {previous_sha}` on the worker Container App
- Depends on: Node 5, Node 6

---

**Node 9: GitHub Actions CI/CD Pipeline (end-to-end)**
- Goal: Harden `ci.yml` — set `continue-on-error: false`; add full deploy flow (build → push → migrate → deploy backend → deploy worker → deploy frontend); configure environments with protection rules for production
- Files likely affected: `.github/workflows/ci.yml`; optionally `.github/workflows/smoke.yml` (convert from scaffold to real smoke test)
- Verification method: Push a commit to `main`; verify all pipeline stages complete green; verify new image is running in Container Apps via `az containerapp show`
- Rollback note: Re-run pipeline with previous SHA; or manually `az containerapp update --image {sha}` for each service
- Depends on: Node 6, Node 7, Node 8

---

**Node 10: DNS + CORS + Domain Config**
- Goal: Point custom domain (e.g., `app.ndt-saas.com`) to SWA; update `CORS_ORIGINS` on backend Container App to include custom domain; optionally configure custom domain on Container App backend
- Files likely affected: DNS records (external), Container App env var update
- Verification method: `curl -I https://app.ndt-saas.com` returns 200; browser DevTools shows no CORS errors on API calls
- Rollback note: Revert DNS CNAME; update `CORS_ORIGINS` back to `.azurestaticapps.net` domain
- Depends on: Node 7, Node 9

---

**Node 11: Smoke Test + Cutover**
- Goal: Convert `smoke.yml` scaffold from print-instructions to real automated test; run full smoke test suite (login, upload file, generate report, download PDF); confirm all critical paths work; formally declare production-ready
- Files likely affected: `.github/workflows/smoke.yml`; `scripts/smoke.sh` (extend)
- Verification method: `make smoke` passes all checks against production URL; Worker heartbeat is fresh; generated PDF is retrievable from Azure Blob Storage via presigned URL
- Rollback note: If any blocker found, revert Container App to previous revision; no data is destroyed by the smoke test
- Depends on: Node 10 (all services running with final domain config)

---

## 12. Open Questions

**1. Neon Pro vs Azure DB for PostgreSQL Flexible Server**
Why it matters: Neon Pro (~$19/mo) has serverless scale-to-zero on the database plane (good for non-peak hours) and a simpler connection string, but adds an external vendor. Azure Flexible Server (~$25–40/mo Burstable B1ms) is fully co-located in Azure with no egress to an external service. The synchronous psycopg2 connection pool (pool_size=5, max_overflow=10) will exhaust Neon's free-tier connection limit (20) when both backend and worker are running; Neon Pro raises this limit. Either choice requires zero code change — only `DATABASE_URL` changes.
Who can answer: Team/owner decision on vendor diversity tolerance and cost sensitivity.

**2. Custom domain availability and DNS control**
Why it matters: `VITE_API_BASE_URL` is baked at build time. The SWA deploy action needs the final domain before the first build. If DNS is not yet controlled by the team, the initial deployment uses the auto-assigned `.azurestaticapps.net` URL, and a second deploy will be needed after DNS cutover to rebuild the frontend with the correct URL.
Who can answer: Domain registrar/DNS administrator for the target domain.

**3. Auth0 integration timeline**
Why it matters: The codebase has a complete Auth0 RS256 integration path in `middleware/auth.py` (python-jose JWKS verification) and `config/auth.py` (pydantic-settings). Setting `AUTH0_DOMAIN`, `AUTH0_AUDIENCE`, and `AUTH0_ISSUER` enables it with zero code change. However, the `.env.example` has these as empty placeholders, and the current dev flow uses local HS256. Running Auth0 in production adds SSO capability but requires an Auth0 tenant, application registration, and user migration. This decision affects both security posture and timeline.
Who can answer: Product owner and security stakeholder.

**4. File upload size limits and Blob Storage tier**
Why it matters: `routes/files.py` reads uploads up to 500 MB into memory before writing. Azure Container Apps with 0.5 GB memory allocation will OOM on a 500 MB upload. Either the memory allocation must be increased (0.5 vCPU / 1.0 GB or higher), or the upload must be streamed directly to Blob Storage using chunked upload or SAS pre-signed URL upload (bypassing the backend entirely for large files). This is a scale concern rather than a P1 blocker, but must be acknowledged.
Who can answer: Engineering lead — depends on expected file sizes for NDT lab reports.

**5. Worker replica count and autoscaling policy**
Why it matters: The worker is proven safe for N replicas via `FOR UPDATE SKIP LOCKED`. If PDF generation becomes a bottleneck (CPU-bound reportlab), scaling the worker to 2–3 replicas is safe and immediate. Should autoscaling be configured based on `worker_jobs` queue depth? This requires a custom scaling rule (KEDA-compatible) or a simple min/max replica count. Defines Container App configuration.
Who can answer: Engineering lead, based on expected report generation volume.

**6. Data residency and compliance requirements**
Why it matters: NDT labs may be subject to data residency requirements (e.g., ISO/IEC 17025 accreditation, export control for aerospace clients). Azure region selection must be deliberate. Choosing `eastus` vs `westeurope` vs `australiaeast` affects latency, compliance, and cost. Neon Pro's region must match or be co-located with the Azure region.
Who can answer: Product owner and any compliance stakeholder.

**7. Email provider for production**
Why it matters: Gmail SMTP (`smtp.gmail.com:587`) with Google App Passwords is rate-limited (500 emails/day) and Google may block SMTP connections from Azure datacenter IP ranges. `EMAIL_PROVIDER=sendgrid` is fully implemented in `services/email_provider.py` and is the correct production choice, but requires a SendGrid account and API key. Azure Communication Services email is scaffolded but non-functional (`azure-communication-email` package absent from `requirements.txt`).
Who can answer: Product owner (SendGrid account creation) + Engineering (add package + test).

---

## 13. Recommendation

**Choose Option C (Production-Safe, ~$76–91/month)** with Neon Pro as the database, Azure Container Apps with min-replicas=1 for both backend and worker, Azure Static Web Apps Standard for the frontend, GHCR for container images, and SendGrid for transactional email. The first concrete action is **Phase 0 — secrets and auth hardening**, which must be completed before any Azure provisioning: rotate the Anthropic API key and Gmail app password that are committed in `infra/env/backend.env`, add that file to `.gitignore`, and set `AUTH_MODE=required` in the production environment configuration. The single highest-risk technical task is the storage abstraction (Change 1), which requires creating `backend/services/storage.py` and updating 11 write sites and 10 read sites across the backend codebase — this is 2–3 days of focused engineering work and is the only blocker that prevents a deployment from running correctly end-to-end. All other required changes (staticwebapp.config.json, CORS update, Alembic advisory lock, azure-storage-blob package addition) are individually 1–4 hours each. The migration DAG has 11 ordered nodes; Nodes 1–5 (resource group, secrets rotation, GHCR setup, storage layer, and database provisioning) can be executed in parallel across teams, and the full deployment can be production-ready in a single focused sprint.
