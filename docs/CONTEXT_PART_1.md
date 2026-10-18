# PART 1: REPO MAP + STACK

---

## 1. Directory Tree

[CODE] Root tree generated from codebase structure (excluding hidden `.git`, caches, and build directories):

```
e:\FYP_YASIN/
├── backend/
│   ├── alembic/
│   │   ├── versions/
│   │   │   ├── 20260921_001_foundation_schema.py
│   │   │   ├── 20261014_002_add_quiz_questions.py
│   │   │   ├── 20261014_003_integrity_constraints.py
│   │   │   ├── 20261014_004_reconcile_legacy_schema.py
│   │   │   ├── 20261017_005_exam_proctoring_schema.py
│   │   │   ├── 20261017_006_exam_professor_audit_and_settings.py
│   │   │   └── add_quiz_and_obe_tables.py
│   │   ├── env.py
│   │   └── script.py.mako
│   ├── app/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── analytics.py
│   │   │       ├── assignments.py
│   │   │       ├── auth.py
│   │   │       ├── courses.py
│   │   │       ├── exams.py
│   │   │       ├── quizzes.py
│   │   │       ├── submissions.py
│   │   │       └── users.py
│   │   ├── config/
│   │   │   ├── llm_config.py
│   │   │   └── settings.py
│   │   ├── core/
│   │   │   ├── config.py
│   │   │   ├── dependencies.py
│   │   │   ├── proctor_config.py
│   │   │   └── security.py
│   │   ├── db/
│   │   │   └── base.py
│   │   ├── models/
│   │   │   ├── analytics.py
│   │   │   ├── assignment.py
│   │   │   ├── course.py
│   │   │   ├── exam_attempt.py
│   │   │   ├── quiz_obe.py
│   │   │   ├── rubric.py
│   │   │   ├── submission.py
│   │   │   └── user.py
│   │   ├── schemas/
│   │   │   ├── analytics.py
│   │   │   ├── assignment.py
│   │   │   ├── auth.py
│   │   │   ├── course.py
│   │   │   ├── rubric.py
│   │   │   ├── submission.py
│   │   │   └── user.py
│   │   ├── services/
│   │   │   ├── analytics_service.py
│   │   │   ├── approval_state.py
│   │   │   ├── assignment_access.py
│   │   │   ├── assignment_service.py
│   │   │   ├── auth_service.py
│   │   │   ├── blooms_gate.py
│   │   │   ├── cache_service.py
│   │   │   ├── clo_attainment.py
│   │   │   ├── course_service.py
│   │   │   ├── document_ingestion.py
│   │   │   ├── email_service.py
│   │   │   ├── exam_monitor.py
│   │   │   ├── grading_pipeline.py
│   │   │   ├── hec_dossier.py
│   │   │   ├── intent_router.py
│   │   │   ├── question_generation.py
│   │   │   ├── registration_policy.py
│   │   │   ├── student_access.py
│   │   │   ├── student_dashboard_service.py
│   │   │   ├── submission_service.py
│   │   │   └── user_service.py
│   │   ├── static/ (compiled Flutter web assets duplicate copy)
│   │   ├── tasks/
│   │   │   └── __init__.py
│   │   ├── celery_app.py
│   │   └── main.py
│   ├── backups/ (gitignored dev database dumps)
│   ├── data/
│   │   └── dossiers/
│   ├── scripts/
│   │   ├── db_check_backup.py
│   │   └── test_postgres_scratch_migrations.py
│   ├── static/ (compiled Flutter web assets production target)
│   ├── tests/ (93 test files covering auth, exams, analytics, OBE)
│   ├── alembic.ini
│   ├── Dockerfile
│   ├── pytest.ini
│   ├── railway.json
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── app.dart
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── network/ (api_constants.dart, dio_client.dart)
│   │   │   ├── router/ (app_router.dart, responsive_navigation.dart)
│   │   │   ├── theme/ (app_theme.dart, theme_provider.dart)
│   │   │   └── utils/ (error_parser.dart, validators.dart)
│   │   ├── features/
│   │   │   ├── admin/
│   │   │   │   ├── data/ (admin_repository.dart)
│   │   │   │   ├── presentation/ (admin_dashboard_screen.dart, user_management_screen.dart)
│   │   │   │   └── providers/ (admin_providers.dart)
│   │   │   ├── analytics/
│   │   │   │   ├── data/ (analytics_repository.dart)
│   │   │   │   ├── presentation/ (analytics_dashboard_screen.dart)
│   │   │   │   └── providers/ (analytics_provider.dart)
│   │   │   ├── auth/
│   │   │   │   ├── data/ (auth_repository.dart)
│   │   │   │   ├── presentation/ (login_screen.dart, register_screen.dart, etc.)
│   │   │   │   └── providers/ (auth_provider.dart)
│   │   │   ├── courses/
│   │   │   │   ├── data/ (course_repository.dart)
│   │   │   │   ├── presentation/ (course_detail_screen.dart, exam_screen.dart, assignment_detail_screen.dart)
│   │   │   │   ├── providers/ (course_providers.dart)
│   │   │   │   └── utils/ (proctor_detector.dart, offline_violation_queue.dart, exam_route.dart)
│   │   │   └── profile/
│   │   │       └── presentation/ (profile_screen.dart)
│   │   └── shared/
│   │       ├── journal_ui/
│   │       └── widgets/ (prof_card.dart, prof_badge.dart, submission_triage.dart)
│   ├── test/ (53 widget and unit tests)
│   ├── web/ (index.html, manifest.json, favicon.png)
│   ├── analysis_options.yaml
│   └── pubspec.yaml
├── docker-compose.yml
├── Dockerfile
├── railway.json
└── docs/
    └── PROCTORING_MANUAL_TEST.md
```

---

## 2. Languages, Framework Versions & Key Packages

### Local Runtime Versions
- **Python:** `3.14.3` [RAN: `python --version` -> `Python 3.14.3`]
- **Flutter:** `3.24.3` • channel stable [RAN: `flutter --version` -> `Flutter 3.24.3`]
- **Dart SDK:** `3.5.3` [RAN: `flutter --version` -> `Tools • Dart 3.5.3`]

### Backend Dependencies
[CODE: `backend/requirements.txt:1-53`]
- `fastapi==0.115.0`: Core Web Framework
- `uvicorn[standard]==0.30.0`: ASGI Server
- `sqlalchemy[asyncio]==2.0.35`: Async ORM
- `asyncpg==0.30.0`: Async PostgreSQL driver
- `psycopg2-binary==2.9.9` & `psycopg[binary]>=3.1.0`: Sync/fallback PostgreSQL driver
- `alembic==1.13.0`: Database migrations
- `greenlet==3.0.3`: Asyncio greenlet bridge for SQLAlchemy
- `pydantic==2.9.0` & `pydantic-settings==2.5.0`: Schema validation & settings
- `argon2-cffi==23.1.0`: Password hashing
- `python-jose[cryptography]==3.3.0`: JWT tokens
- `redis==5.1.0`: Redis client
- `celery[redis]==5.4.0`: Background distributed worker
- `resend==2.4.0`: Transactional email API
- `weasyprint==62.3`: PDF Dossier generator
- `pytest==8.3.0` & `pytest-asyncio==0.24.0`: Testing framework
- `httpx==0.27.0`: Async HTTP client
- `sentence-transformers>=3.0.0`: Local embeddings (`all-MiniLM-L6-v2`)
- `faiss-cpu>=1.8.0`: Vector similarity search
- `docling>=2.0.0`: Document parsing & chunking
- `langchain>=0.2.0` & `langchain-community>=0.2.0`: RAG pipeline helpers
- `pymupdf>=1.24.0`, `pypdf>=4.0.0`, `python-docx>=1.1.0`: File parsing

### Frontend Dependencies
[CODE: `frontend/pubspec.yaml:6-51`]
- Environment SDK: `^3.5.3`
- `flutter_riverpod: ^2.5.1` & `riverpod_annotation: ^2.3.5`: Global state management
- `go_router: ^14.2.0`: Declarative routing
- `dio: ^5.5.0+1`: HTTP networking client
- `flutter_secure_storage: ^9.2.2`: Encrypted token storage
- `fl_chart: ^0.68.0`: Analytics and grade distribution charts
- `google_fonts: ^6.2.1`: Fonts (`Outfit`, `Inter`, `DM Sans`, `JetBrains Mono`)
- `file_picker: ^8.0.6`: Native file uploads
- `flutter_quill: ^9.3.7`: Rich-text editor
- `local_auth: ^2.3.0`: Biometric authentication gate
- `flutter_markdown: ^0.7.7+1`: Markdown rendering
- `flutter_test`: Unit & widget test runner
- `flutter_lints: ^4.0.0`: Linter rules

---

## 3. How to Run

### Run Backend Locally
[CODE: `backend/Dockerfile:26`, `backend/app/main.py:1-43`]
```bash
cd backend
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

### Run Frontend Locally (Flutter Web)
[CODE: `frontend/pubspec.yaml`]
```bash
cd frontend
flutter run -d chrome --web-port 8080
```

### Run Full Docker Compose Stack (Postgres + Redis + API + 2 Celery Workers)
[CODE: `docker-compose.yml:1-89`]
```bash
docker-compose up --build
```
Services spun up:
- `db`: `postgres:16-alpine` on port `5432`
- `redis`: `redis:7-alpine` on port `6379`
- `backend`: FastAPI API on port `8000`
- `celery_worker_grading`: Celery worker on queues `grading_high,grading_normal,xai_queue,celery`
- `celery_worker_ai`: Celery worker on queues `rag_queue,question_gen_queue,reporting_queue`

### Run Database Migrations
[CODE: `backend/alembic.ini`, `backend/alembic/env.py:47-60`]
```bash
cd backend
alembic upgrade head
```

### Run Backend Tests
[CODE: `backend/pytest.ini`]
```bash
cd backend
pytest -v
```

### Run Frontend Tests & Linter
[CODE: `frontend/pubspec.yaml`]
```bash
cd frontend
flutter test
flutter analyze
```

### Build Production Flutter Web Bundle
[CODE: `frontend/pubspec.yaml`, `backend/app/main.py:18-20`]
```bash
cd frontend
flutter build web --release
# To deploy into FastAPI static server:
cp -r build/web/* ../backend/app/static/
cp -r build/web/* ../backend/static/
```

---

## 4. Environment Variables & Configuration

[CODE: `backend/app/config/settings.py:14-106`]
All variables are read via Pydantic v2 `BaseSettings` reading from `.env` or system environment:

| Variable Name | Default / Dev Fallback | Where Read | Purpose |
|---|---|---|---|
| `ENVIRONMENT` | `"development"` | `settings.py:19` | Controls security validations and strict CORS |
| `DEBUG` | `False` | `settings.py:20` | Database query logging (`echo=settings.DEBUG`) |
| `BACKEND_URL` | `"http://localhost:8000"` | `settings.py:21` | Base URL for outbound email links |
| `FRONTEND_URL` | `"http://localhost:8080"` | `settings.py:22` | Frontend client origin |
| `ALLOWED_ORIGINS` | `"http://localhost:3000,http://localhost:8080,..."` | `settings.py:23` | CORS allowed origins list |
| `STORAGE_ROOT` | `"./data"` | `settings.py:27` | Base directory for uploaded files, dossiers, and cache |
| `DATABASE_URL` | `"postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os"` | `settings.py:30` | Main application database connection string |
| `DB_POOL_SIZE` | `20` | `settings.py:31` | Async engine connection pool size |
| `DB_MAX_OVERFLOW` | `10` | `settings.py:32` | Max connection pool overflow |
| `DB_POOL_TIMEOUT` | `30` | `settings.py:33` | Seconds to wait before timing out pool checkout |
| `REDIS_URL` | `"redis://localhost:6379/0"` | `settings.py:36` | Message broker and caching backend |
| `JWT_SECRET_KEY` | Development test key (32+ chars) | `settings.py:39` | Signs HS256 JWT access and refresh tokens |
| `JWT_ALGORITHM` | `"HS256"` | `settings.py:40` | Token signing algorithm |
| `ACCESS_TOKEN_EXPIRE_MINUTES`| `1440` (24h) | `settings.py:41` | Access token lifespan |
| `REFRESH_TOKEN_EXPIRE_DAYS` | `7` | `settings.py:42` | Refresh token lifespan |
| `MAX_LOGIN_ATTEMPTS` | `5` | `settings.py:43` | Failed attempts before account lock |
| `LOCKOUT_DURATION_MINUTES` | `15` | `settings.py:44` | Temporary lockout duration |
| `INITIAL_ADMIN_PASSWORD` | `""` | `settings.py:47` | One-time bootstrap password for system administrator |
| `EMAIL_BACKEND` | `"smtp"` | `settings.py:50` | Selects `"smtp"`, `"resend"`, or `"console"` |
| `EMAIL_FROM` | `"noreply@professor-os.edu.pk"` | `settings.py:51` | Sender address |
| `RESEND_API_KEY` | `""` | `settings.py:52` | API key if Resend email provider is used |
| `SMTP_HOST` | `"smtp.gmail.com"` | `settings.py:53` | SMTP server host |
| `SMTP_PORT` | `587` | `settings.py:54` | SMTP port |
| `SMTP_USER` | `""` | `settings.py:55` | SMTP username |
| `SMTP_PASSWORD` | `""` | `settings.py:56` | SMTP password |
| `GROQ_API_KEY` | `""` | `settings.py:59` | Primary LPU LLM inference API key |
| `GROQ_BASE_URL` | `"https://api.groq.com/openai/v1"` | `settings.py:60` | Groq OpenAI-compatible endpoint |
| `OPENROUTER_API_KEY` | `""` | `settings.py:63` | Fallback LLM inference API key |
| `OPENROUTER_BASE_URL` | `"https://openrouter.ai/api/v1"`| `settings.py:64` | OpenRouter API endpoint |
| `LLM_BASE_URL` | `None` | `settings.py:69` | Local GPU box override (e.g. Ollama `http://localhost:11434/v1`) |
| `LLM_API_KEY` | `"ollama"` | `settings.py:70` | Local GPU API key |
| `MODEL_GRADING_PRIMARY` | `"deepseek-r1-distill-llama-70b"` | `settings.py:73` | Main AI grading model |
| `MODEL_GRADING_FALLBACK` | `"anthropic/claude-haiku-4.5"` | `settings.py:74` | Failover AI grading model |
| `GRADING_MODEL_DEV` | `None` | `settings.py:75` | Cost-saving dev model override (e.g. `llama-3.1-8b-instant`) |
| `MODEL_RAG_PRIMARY` | `"llama-3.1-8b-instant"` | `settings.py:78` | Course Chat TA model |
| `MODEL_QUESTION_GEN_PRIMARY` | `"llama-3.3-70b-versatile"` | `settings.py:82` | AI Question Bank generation model |
| `EMBEDDING_MODEL_NAME` | `"all-MiniLM-L6-v2"` | `settings.py:86` | HuggingFace embedding model |
| `FAISS_STORAGE_PATH` | `"./data/faiss_indexes"` | `settings.py:87` | Vector store disk path |
| `DOCLING_CACHE_PATH` | `"./data/docling_cache"` | `settings.py:90` | Document parser cache path |
| `JUDGE0_URL` | `"http://localhost:2358"` | `settings.py:103` | Code execution sandbox endpoint |
| `API_BASE_URL` (Frontend) | `""` | `api_constants.dart:11` | Build-time `--dart-define` override for Flutter web API origin |

---

## 5. Which Database Does Each Environment Use?

[CODE: `backend/app/config/settings.py:30-117`, `backend/tests/test_exam_concurrency.py:38`, `backend/tests/test_exam_threads_concurrency.py:27`]

1. **Development (`ENVIRONMENT="development"`):**
   - Defaults to **PostgreSQL with asyncpg**: `postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os`.
   - The validator `fix_database_url` (`settings.py:110-117`) automatically rewrites standard `postgres://` or `postgresql://` strings to async driver format `postgresql+asyncpg://`.
2. **Production (`ENVIRONMENT="production"`):**
   - Uses PostgreSQL supplied via `DATABASE_URL` environment variable (e.g. Railway managed PostgreSQL).
   - Validation enforces that `ENVIRONMENT="production"` will reject startup if `JWT_SECRET_KEY` is the default string or if `ALLOWED_ORIGINS` contains `*` (`settings.py:127-134`).
3. **Automated Tests:**
   - **Unit / Mock Tests:** Run entirely in-memory with `SimpleNamespace` without connecting to any database (`test_exam_attempt.py`).
   - **Async Concurrency & Flow Tests:** Run against an in-memory SQLite database via `sqlite+aiosqlite:///:memory:` (`test_exam_concurrency.py:38`).
   - **Threaded Concurrency Tests:** Run against a file-based SQLite database with WAL enabled: `sqlite:///./scratch_concurrency_test.db` (`test_exam_threads_concurrency.py:27`).
   - **Integration / Scratch Migration Tests:** Run against a dedicated temporary PostgreSQL database: `postgresql://postgres:postgres@localhost:5432/professor_os_scratch_migration_test` (`scripts/test_postgres_scratch_migrations.py:15`).
   - **Real Dev DB Exposure:** Note that tests importing `app.main` or executing without monkeypatching `async_session` will connect to the local dev PostgreSQL instance (`localhost:5432/professor_os`).

---

## 6. How the Flutter Web Build Gets Served

[CODE: `backend/app/main.py:18-20`, `backend/app/main.py:109-158`]

1. **Static Directory Resolution:**
   ```python
   # backend/app/main.py:18-20
   STATIC_DIR = Path(__file__).parent / "static"
   if not STATIC_DIR.exists():
       STATIC_DIR = Path(__file__).parent.parent / "static"
   ```
   The server checks `backend/app/static/` first, and if not present, falls back to `backend/static/`.
2. **Mounting Assets:**
   ```python
   # backend/app/main.py:112
   app.mount("/static_assets", StaticFiles(directory=str(STATIC_DIR)), name="static_assets")
   ```
3. **SPA Catch-All Route with Hardened Security & Cache Headers:**
   ```python
   # backend/app/main.py:114-158
   @app.get("/{full_path:path}")
   async def serve_flutter(full_path: str):
       # 1. Blocks path traversal ("..", leading slashes, dotfiles)
       # 2. Enforces file_path.is_relative_to(resolved_static)
       # 3. Sets Cache-Control headers based on asset type:
   ```
   - **Immutable Static Assets** (`.wasm`, `.ttf`, `.woff`, `.woff2`, `.otf`, `.png`, `.jpg`, `.svg`, `.ico`):
     `Cache-Control: public, max-age=604800, immutable`
   - **Application Code & Entrypoint** (`index.html`, `main.dart.js`, `flutter_service_worker.js`, etc.):
     `Cache-Control: no-cache, must-revalidate, max-age=0`, `Pragma: no-cache`, `Expires: 0`
   - **Missing files with an extension:** Returns `404 Resource not found` (does not return `index.html` for broken image/asset URLs).
   - **SPA Routing Fallback:** Non-asset paths fall back to serving `STATIC_DIR / "index.html"`.

---

## 7. Background Work & Daemons

[CODE: `backend/app/main.py:22-35`, `backend/app/services/exam_monitor.py:73-98`, `backend/app/tasks/__init__.py:1-68`]

### 1. Application Startup / Lifespan
```python
# backend/app/main.py:22-35
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start the API without mutating application data or database schema."""
    import asyncio
    from app.services.exam_monitor import run_exam_monitor_daemon
    monitor_task = asyncio.create_task(run_exam_monitor_daemon(interval_seconds=15))
    yield
    monitor_task.cancel()
    try:
        await monitor_task
    except asyncio.CancelledError:
        pass
    await engine.dispose()
```

### 2. Exam Monitor Background Daemon
```python
# backend/app/services/exam_monitor.py:73-98
async def run_exam_monitor_daemon(interval_seconds: int = 15) -> None:
    """Continuous background loop monitoring active exam attempts."""
    logger.info("Exam monitor daemon started (polling every %ds)...", interval_seconds)
    while True:
        try:
            async with async_session_factory() as session:
                stats = await monitor_active_exam_attempts(session)
                if stats["closed"] > 0 or stats["heartbeats_missed"] > 0:
                    logger.info("Exam monitor cycle completed: %s", stats)
        except asyncio.CancelledError:
            logger.info("Exam monitor daemon received cancellation.")
            raise
        except Exception as exc:
            logger.error("Exam monitor daemon encountered error: %s", exc, exc_info=True)
        await asyncio.sleep(interval_seconds)
```
- **Interval:** Runs every 15 seconds.
- **Resilience:** Errors in a cycle are caught, logged, and the loop continues without crashing the server process.

### 3. Celery Distributed Task Fleet
```python
# backend/app/tasks/__init__.py:25-32
task_routes = {
    "grade_submission_task": {"queue": settings.QUEUE_GRADING_NORMAL},
    "ingest_course_document": {"queue": settings.QUEUE_RAG},
    "generate_questions_task": {"queue": settings.QUEUE_QUESTION_GEN},
    "calculate_clo_attainment_task": {"queue": settings.QUEUE_REPORTING},
    "refresh_analytics": {"queue": settings.QUEUE_REPORTING},
}
```
Exposed via `backend/app/celery_app.py:7` for CLI workers.

---

## 8. Git State & Committed Artifacts

### Active Branch
[RAN: `git branch`]
- **Current Branch:** `codex/audit-remediation`

### Tracked Large / Generated Files in Git
[RAN: `git ls-tree -r -l HEAD`]
The repository contains large compiled binary build artifacts and Word documents directly committed to git:
- `26.44 MB`: `backend/static/professor-os.apk` (Compiled Android APK)
- `6.44 MB`: `backend/static/canvaskit/canvaskit.wasm`
- `6.44 MB`: `backend/app/static/canvaskit/canvaskit.wasm` (Duplicate)
- `5.12 MB`: `backend/static/canvaskit/chromium/canvaskit.wasm`
- `5.12 MB`: `backend/app/static/canvaskit/chromium/canvaskit.wasm` (Duplicate)
- `4.24 MB`: `ProfessorOS_FYP_Report_30pct.docx`
- `4.24 MB`: `ProfessorOS_FYP_Report_Formatted.docx`
- `3.49 MB`: `backend/app/static/main.dart.js` (Compiled JavaScript bundle)
- `3.45 MB`: `backend/static/main.dart.js` (Duplicate JavaScript bundle)
- `3.07 MB`: `backend/static/canvaskit/skwasm.wasm`
- `3.07 MB`: `backend/app/static/canvaskit/skwasm.wasm` (Duplicate)
- `1.73 MB`: `Professor OS_SDS (1).pdf`
- `1.72 MB`: `ProfessorOS_SRS.pdf`

### Uncommitted / Modified Working Directory State
[RAN: `git status -s`]
- **Modified files:**
  - Backend models & APIs: `exams.py`, `submissions.py`, `auth.py`, `analytics.py`, `exam_attempt.py`, `assignment.py`, `submission.py`, `main.py`.
  - Frontend screens & utilities: `exam_screen.dart`, `assignment_detail_screen.dart`, `course_detail_screen.dart`, `web_window_listener_web.dart`, `dio_client.dart`, `api_constants.dart`.
  - Compiled static bundles: `backend/app/static/main.dart.js`, `backend/static/main.dart.js`.
- **Untracked files:**
  - Migrations 001–006 (`backend/alembic/versions/2026*`).
  - Unit and concurrency test suites (`backend/tests/test_exam_concurrency.py`, `test_migration_006.py`, `frontend/test/exam_screen_widget_test.dart`, etc.).
  - Proctoring utility files (`frontend/lib/features/courses/utils/exam_route.dart`, `proctor_detector.dart`, `offline_violation_queue.dart`).
- **Ignored Safety:**
  - `backend/backups/` is confirmed untracked and ignored via `.gitignore`.

---
PART 1 DONE
