"""ProfessorOS – FastAPI application entry point."""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.db.base import engine, Base

# Import all models so SQLAlchemy knows about them
from app.models import user, course, assignment, rubric, analytics  # noqa: F401

STATIC_DIR = Path(__file__).parent.parent / "static"


@asynccontextmanager
async def lifespan(app: FastAPI):
    """On startup: ensure all tables exist and safely run minor migrations."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        
        # Auto-migration for join_code column
        try:
            from sqlalchemy import text
            res = await conn.execute(
                text("SELECT column_name FROM information_schema.columns WHERE table_name='courses' AND column_name='join_code'")
            )
            if not res.fetchone():
                await conn.execute(text("ALTER TABLE courses ADD COLUMN join_code VARCHAR(10)"))
                
                # Generate unique codes for any existing courses
                res_courses = await conn.execute(text("SELECT id FROM courses WHERE join_code IS NULL"))
                import secrets
                for row in res_courses.fetchall():
                    code = secrets.token_hex(3).upper()
                    await conn.execute(
                        text("UPDATE courses SET join_code = :code WHERE id = :id"),
                        {"code": code, "id": row[0]}
                    )
                
                # Add unique constraint after populating
                await conn.execute(text("ALTER TABLE courses ADD CONSTRAINT uq_course_join_code UNIQUE (join_code)"))
        except Exception as e:
            print(f"[STARTUP WARN] Auto-migration for join_code failed: {e}")
            
        # Auto-seed admin account for demo
        try:
            from sqlalchemy import text
            from app.core.security import hash_password
            res_admin = await conn.execute(
                text("SELECT id FROM users WHERE email='admin@professoros.edu.pk'")
            )
            if not res_admin.fetchone():
                hashed = hash_password("admin123")
                await conn.execute(
                    text("INSERT INTO users (email, full_name, hashed_password, role, is_active, is_verified, failed_attempts) VALUES (:email, :name, :hashed, :role, :is_active, :is_verified, 0)"),
                    {
                        "email": "admin@professoros.edu.pk",
                        "name": "System Administrator",
                        "hashed": hashed,
                        "role": "admin",
                        "is_active": True,
                        "is_verified": True,
                    }
                )
        except Exception as e:
            print(f"[STARTUP WARN] Auto-seed admin failed: {e}")
            
    yield
    await engine.dispose()


app = FastAPI(
    title="ProfessorOS API",
    description="Smart academic platform for Pakistani universities – Authentication, Course Management & Analytics.",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Register routers ─────────────────────────────────
from app.api.v1.auth import router as auth_router
from app.api.v1.users import router as users_router
from app.api.v1.courses import router as courses_router
from app.api.v1.assignments import router as assignments_router
from app.api.v1.analytics import router as analytics_router

app.include_router(auth_router, prefix="/api/v1")
app.include_router(users_router, prefix="/api/v1")
app.include_router(courses_router, prefix="/api/v1")
app.include_router(assignments_router, prefix="/api/v1")
app.include_router(analytics_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "service": "ProfessorOS API"}


# ── Serve Flutter Web App ─────────────────────────────
if STATIC_DIR.exists():
    # Serve static assets (JS, CSS, icons, etc.)
    app.mount("/static_assets", StaticFiles(directory=str(STATIC_DIR)), name="static_assets")

    @app.get("/{full_path:path}")
    async def serve_flutter(full_path: str):
        """Serve Flutter web app for all non-API routes."""
        file_path = STATIC_DIR / full_path
        if file_path.is_file():
            return FileResponse(str(file_path))
        # Fallback to index.html for Flutter router
        return FileResponse(str(STATIC_DIR / "index.html"))
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
