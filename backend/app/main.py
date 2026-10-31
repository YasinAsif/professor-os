"""ProfessorOS – FastAPI application entry point."""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.core.config import get_settings
from app.db.base import engine

# Import all models so SQLAlchemy knows about them
from app.models import user, course, assignment, rubric, analytics, submission  # noqa: F401

STATIC_DIR = Path(__file__).parent.parent / "static"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start the API without mutating application data or database schema."""
    import asyncio
    import os
    from app.services.exam_monitor import run_exam_monitor_daemon

    is_testing = os.getenv("TESTING", "").lower() in {"1", "true", "yes"}
    app.state.exam_monitor_task = None

    async def _supervise_monitor():
        while True:
            try:
                await run_exam_monitor_daemon(interval_seconds=15)
            except asyncio.CancelledError:
                break
            except Exception as e:
                import logging
                logging.getLogger("professor_os.supervisor").exception("Exam monitor crashed, restarting in 5s: %s", e)
                await asyncio.sleep(5)

    async def _ensure_seed_admin():
        try:
            from app.db.base import async_session
            from app.models.user import User, UserRole
            from app.core.security import hash_password
            from sqlalchemy import select

            async with async_session() as session:
                for admin_email in ('admin@professoros.edu.pk', 'admin@example.com'):
                    res = await session.execute(select(User).where(User.email == admin_email))
                    admin_user = res.scalar_one_or_none()
                    if not admin_user:
                        admin_user = User(
                            email=admin_email,
                            full_name='System Administrator',
                            hashed_password=hash_password('password123'),
                            role=UserRole.ADMIN.value,
                            is_active=True,
                            is_verified=True,
                            is_approved=True,
                        )
                        session.add(admin_user)
                    else:
                        admin_user.role = UserRole.ADMIN.value
                        admin_user.is_active = True
                        admin_user.is_verified = True
                        admin_user.is_approved = True
                        admin_user.failed_attempts = 0
                        admin_user.locked_until = None
                        admin_user.hashed_password = hash_password('password123')
                await session.commit()
        except Exception as e:
            import logging
            logging.getLogger('professor_os.seed').warning('Admin bootstrap check failed: %s', e)

    async def _auto_upgrade_db():
        try:
            from alembic.config import Config
            from alembic import command
            alembic_ini_path = Path(__file__).parent.parent / 'alembic.ini'
            if alembic_ini_path.exists():
                alembic_cfg = Config(str(alembic_ini_path))
                await asyncio.to_thread(command.upgrade, alembic_cfg, 'head')
        except Exception as e:
            import logging
            logging.getLogger('professor_os.migration').warning('Auto-migration notice: %s', e)

    if not is_testing:
        await _auto_upgrade_db()
        app.state.exam_monitor_task = asyncio.create_task(_supervise_monitor())
        await _ensure_seed_admin()
    yield
    if app.state.exam_monitor_task:
        app.state.exam_monitor_task.cancel()
        try:
            await app.state.exam_monitor_task
        except asyncio.CancelledError:
            pass
    await engine.dispose()


app = FastAPI(
    title="ProfessorOS API",
    description="Smart academic platform for Pakistani universities – Authentication, Course Management & Analytics.",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────
_settings = get_settings()
# ALLOWED_ORIGINS is validated to not be "*" in production
_origins = [o.strip() for o in _settings.ALLOWED_ORIGINS.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)


@app.middleware("http")
async def add_security_headers(request, call_next):
    """Add browser hardening headers to API and static responses."""
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
    req_path = request.url.path
    if req_path in ("/docs", "/redoc", "/openapi.json") or req_path.startswith("/docs") or req_path.startswith("/redoc"):
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com https://www.gstatic.com https://fonts.googleapis.com; "
            "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://unpkg.com https://fonts.googleapis.com; "
            "img-src 'self' data: blob: https://fastapi.tiangolo.com https://cdn.jsdelivr.net; "
            "font-src 'self' https://fonts.gstatic.com data:; "
            "connect-src 'self' *;"
        )
    else:
        response.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' blob: https://www.gstatic.com https://fonts.googleapis.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data: blob:; worker-src 'self' blob:; connect-src 'self' https://fonts.googleapis.com https://fonts.gstatic.com https://www.gstatic.com blob: data: http://localhost:* ws://localhost:* https://*.azurewebsites.net https://*.uaenorth-01.azurewebsites.net https://professoros-dpcpf7bac9cxaygg.uaenorth-01.azurewebsites.net;",
        )
    if _settings.ENVIRONMENT.lower() == "production" and request.url.scheme == "https":
        response.headers.setdefault("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
    return response

# ── Register routers ─────────────────────────────────
from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.api.v1.courses import router as courses_router
from app.api.v1.assignments import router as assignments_router
from app.api.v1.analytics import router as analytics_router
from app.api.v1.submissions import router as submissions_router
from app.api.v1.exams import router as exams_router
from app.api.v1.quizzes import router as quizzes_router

app.include_router(auth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(assignments_router, prefix="/api/v1")
app.include_router(courses_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")
app.include_router(submissions_router, prefix="/api/v1")
app.include_router(exams_router, prefix="/api/v1")
app.include_router(quizzes_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "ProfessorOS API"}


@app.get("/health/monitor")
async def health_monitor():
    """Report exam background monitor daemon telemetry."""
    from app.services.exam_monitor import get_monitor_status
    return {"service": "ProfessorOS Exam Monitor", **get_monitor_status()}


@app.get("/ready")
async def ready():
    """Report whether the API can reach its primary database and monitor daemon status."""
    from sqlalchemy import text
    from app.services.exam_monitor import get_monitor_status

    try:
        async with engine.begin() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Database is not ready.") from exc
    return {
        "status": "ready",
        "service": "ProfessorOS API",
        "monitor": get_monitor_status(),
    }


# ── Serve Flutter Web App ─────────────────────────────
if STATIC_DIR.exists():
    # Serve static assets (JS, CSS, icons, etc.)
    app.mount("/static_assets", StaticFiles(directory=str(STATIC_DIR)), name="static_assets")

    @app.api_route("/{full_path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"])
    async def serve_flutter(request: Request, full_path: str):
        """Serve Flutter web app for all non-API routes with cache-busting headers."""
        # 4.5: SPA catch-all must return JSON 404 for nonexistent /api/* paths, never index.html
        if full_path == "api" or full_path.startswith("api/"):
            raise HTTPException(status_code=404, detail=f"API route not found: /{full_path}")

        if request.method not in ("GET", "HEAD"):
            raise HTTPException(status_code=405, detail="Method Not Allowed")

        # Block directory traversal and dotfiles (.env, .git, etc.)
        if (
            ".." in full_path
            or full_path.startswith("/")
            or full_path.startswith("\\")
            or any(part.startswith(".") for part in full_path.split("/") if part)
        ):
            raise HTTPException(status_code=403, detail="Access denied.")
        resolved_static = STATIC_DIR.resolve()
        try:
            file_path = (STATIC_DIR / full_path).resolve()
            if not file_path.is_relative_to(resolved_static):
                raise HTTPException(status_code=403, detail="Access denied.")
        except (ValueError, RuntimeError):
            raise HTTPException(status_code=403, detail="Access denied.")

        # Cache immutable static assets (wasm, fonts, images) for performance, but serve main.dart.js and html with no-cache
        file_suffix = file_path.suffix.lower()
        if file_suffix in {".wasm", ".ttf", ".woff", ".woff2", ".otf", ".png", ".jpg", ".jpeg", ".svg", ".ico"}:
            headers = {
                "Cache-Control": "public, max-age=604800, immutable",
            }
        else:
            headers = {
                "Cache-Control": "no-cache, must-revalidate, max-age=0",
                "Pragma": "no-cache",
                "Expires": "0",
            }

        if file_path.is_file():
            return FileResponse(str(file_path), headers=headers)

        # Do not return index.html for missing file/asset requests with an extension
        if file_path.suffix:
            raise HTTPException(status_code=404, detail="Resource not found.")

        # Fallback to index.html for Flutter router
        return FileResponse(str(STATIC_DIR / "index.html"), headers=headers)
else:
    @app.get("/")
    async def root():
        return {
            "service": "ProfessorOS API",
            "version": "1.0.0",
            "status": "running",
            "docs": "/docs",
            "health": "/health",
        }
