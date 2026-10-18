# CONTEXT PART 13: INFRASTRUCTURE, DEPLOYMENT & OPERATIONS

> **Forensic Audit Standard:** Strictly read-only analysis of `backend/` and `frontend/`. Every claim is verified with exact file paths and line ranges (`file:line`). All statements are tagged `[CODE]`, `[RAN]`, `[ASSUMED]`, or `[NOT DONE]`.

---

## 1. Container & Deployment Topology

### 1.1 Multi-Service Docker Compose Fleet
`[CODE]` Configured in [docker-compose.yml](file:///e:/FYP_YASIN/docker-compose.yml):
The stack defines 5 containerized services with dependency-aware health checks:

```yaml
# docker-compose.yml:3-89
services:
  db:
    image: postgres:16-alpine
    ports: ["5432:5432"]
    volumes: [postgres_data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 5s, timeout: 5s, retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes: [redis_data:/data]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s, timeout: 5s, retries: 5

  backend:
    build: {context: ./backend, dockerfile: Dockerfile}
    ports: ["8000:8000"]
    depends_on: {db: {condition: service_healthy}, redis: {condition: service_healthy}}
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  celery_worker_grading:
    build: {context: ./backend, dockerfile: Dockerfile}
    depends_on: {db: {condition: service_healthy}, redis: {condition: service_healthy}}
    command: celery -A app.celery_app worker -Q grading_high,grading_normal,xai_queue,celery --concurrency=2 --loglevel=info -n worker_grading@%h

  celery_worker_ai:
    build: {context: ./backend, dockerfile: Dockerfile}
    depends_on: {db: {condition: service_healthy}, redis: {condition: service_healthy}}
    command: celery -A app.celery_app worker -Q rag_queue,question_gen_queue,reporting_queue --concurrency=2 --loglevel=info -n worker_ai@%h
```

### 1.2 Dockerfile Construction (Root & Backend)
`[CODE]` Defined in [Dockerfile:1-29](file:///e:/FYP_YASIN/Dockerfile) and [backend/Dockerfile:1-27](file:///e:/FYP_YASIN/backend/Dockerfile):
- Base: `python:3.12-slim`.
- Native system packages installed:
  - `build-essential`, `libpq-dev`, `libffi-dev` (C-extensions for psycopg and cryptography).
  - `libpango-1.0-0`, `libpangocairo-1.0-0`, `libgdk-pixbuf-2.0-0`, `shared-mime-info` (Required by WeasyPrint for PDF generation).
- Dynamic Port Binding: `CMD sh -c "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"`.

### 1.3 Railway Cloud Production Deployment
`[CODE]` Configured in [railway.json:1-14](file:///e:/FYP_YASIN/railway.json):
- Builder: `DOCKERFILE` with path `Dockerfile`.
- Health Check Probe: `/ready` with a 120-second timeout window.
- Restart Policy: `ON_FAILURE` with 3 max retries.
- Production Host: `https://professor-os-production-65b2.up.railway.app` (listed in `ALLOWED_ORIGINS` in [settings.py:23](file:///e:/FYP_YASIN/backend/app/config/settings.py#L23)).

---

## 2. Celery Background Worker Fleet & Queue Topology

### 2.1 6 Dedicated Celery Queues
`[CODE]` Defined in [backend/app/config/settings.py:95-101](file:///e:/FYP_YASIN/backend/app/config/settings.py#L95-L101) and [backend/app/tasks/__init__.py:25-31](file:///e:/FYP_YASIN/backend/app/tasks/__init__.py#L25-L31):

| Queue Name | Constant in Settings | Associated Tasks | Worker Assigned |
| :--- | :--- | :--- | :--- |
| `grading_normal` | `QUEUE_GRADING_NORMAL` | `grade_submission_task` | `celery_worker_grading` |
| `grading_high` | `QUEUE_GRADING_HIGH` | Expedited / Sync retry grading | `celery_worker_grading` |
| `xai_queue` | `QUEUE_XAI` | Chain-of-thought diagnostics | `celery_worker_grading` |
| `rag_queue` | `QUEUE_RAG` | `ingest_course_document` | `celery_worker_ai` |
| `question_gen_queue` | `QUEUE_QUESTION_GEN` | `generate_questions_task` | `celery_worker_ai` |
| `reporting_queue` | `QUEUE_REPORTING` | `calculate_clo_attainment_task`, `refresh_analytics`, `monitor_exams_task`, `generate_hec_dossier_task` | `celery_worker_ai` |

### 2.2 Threading & Connection Leak Protection in Celery
`[CODE]` Celery workers run in standard synchronous multiprocessing mode. Because `asyncpg` engines cannot run across threads or loops without deadlocking, Celery tasks interact with PostgreSQL via a dedicated synchronous Psycopg3 pooled singleton `_get_sync_engine()` ([grading_pipeline.py:267-280](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L267-L280)):

```python
# backend/app/services/grading_pipeline.py:267-280
def _get_sync_engine():
    global _sync_engine
    if _sync_engine is None:
        from sqlalchemy import create_engine
        sync_db_url = settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql+psycopg://")
        _sync_engine = create_engine(
            sync_db_url,
            pool_size=5,
            max_overflow=10,
            pool_timeout=30,
            pool_pre_ping=True,
        )
    return _sync_engine
```

---

## 3. Database Migrations & Versioning

### 3.1 Alembic Migration Sequence
`[CODE]` Revisions located in [backend/alembic/versions/](file:///e:/FYP_YASIN/backend/alembic/versions/):
1. `20260921_001_foundation_schema.py`: Initial users, courses, enrollments, assignments, submissions, rubrics.
2. `20261014_002_add_quiz_questions.py`: MCQ questions, quiz attempt states.
3. `20261014_003_integrity_constraints.py`: Unique constraints on join codes and cascade rules.
4. `20261014_004_reconcile_legacy_schema.py`: Legacy table alignment.
5. `20261017_005_exam_proctoring_schema.py`: `exam_attempts` table, heartbeat tracking, strikes, violations.
6. `20261017_006_exam_professor_audit_and_settings.py`: Proctoring thresholds on assignments (`strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, `unsupported_browser_policy`).
7. `add_quiz_and_obe_tables.py`: `clo_definitions`, `attainment_records`, `quiz_questions`, `quiz_sessions`.

---

## 4. Static Asset Delivery & Client-Side SPA Routing

### 4.1 Flutter Web SPA Reverse Serving
`[CODE]` In [backend/app/main.py:110-158](file:///e:/FYP_YASIN/backend/app/main.py#L110-L158), FastAPI natively serves the Flutter Web build when `STATIC_DIR` (`backend/static` or `backend/app/static`) exists on disk:
- Mounts `/static_assets` for raw static files ([main.py:112](file:///e:/FYP_YASIN/backend/app/main.py#L112)).
- Fallback route `/{full_path:path}` serves `index.html` for Flutter's client-side browser history routing ([main.py:158](file:///e:/FYP_YASIN/backend/app/main.py#L158)).
- **Security Guardrails**:
  - Rejects path traversal attempts containing `..`, leading slashes, or dotfiles (`.env`, `.git`) with `HTTP 403 Access denied` ([main.py:118-125](file:///e:/FYP_YASIN/backend/app/main.py#L118-L125)).
  - Verifies that `file_path.is_relative_to(resolved_static)` ([main.py:129](file:///e:/FYP_YASIN/backend/app/main.py#L129)).
- **Cache-Busting Strategy**:
  - Immutable assets (`.wasm`, `.ttf`, `.woff`, `.png`, `.svg`): `Cache-Control: public, max-age=604800, immutable` ([main.py:138-141](file:///e:/FYP_YASIN/backend/app/main.py#L138-L141)).
  - Entry points (`main.dart.js`, `index.html`, JSON): `Cache-Control: no-cache, must-revalidate, max-age=0` ([main.py:143-147](file:///e:/FYP_YASIN/backend/app/main.py#L143-L147)).

---

## 5. Observability, Hardening & Health Probes

### 5.1 Health & Readiness Probes
`[CODE]` Defined in [backend/app/main.py:91-106](file:///e:/FYP_YASIN/backend/app/main.py#L91-L106):
- **Liveness (`GET /health`)**:
  ```python
  @app.get("/health")
  async def health():
      return {"status": "ok", "service": "ProfessorOS API"}
  ```
- **Readiness (`GET /ready`)**:
  ```python
  @app.get("/ready")
  async def ready():
      try:
          async with engine.begin() as conn:
              await conn.execute(text("SELECT 1"))
      except Exception as exc:
          raise HTTPException(status_code=503, detail="Database is not ready.") from exc
      return {"status": "ready", "service": "ProfessorOS API"}
  ```

### 5.2 Browser Hardening Middleware
`[CODE]` In [backend/app/main.py:59-69](file:///e:/FYP_YASIN/backend/app/main.py#L59-L69):
Every HTTP response automatically receives security headers:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: no-referrer`
- `Permissions-Policy: camera=(), microphone=(), geolocation=()`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains` (enforced when `ENVIRONMENT == "production"` and HTTPS).

---

PART 13 DONE
