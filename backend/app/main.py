"""ProfessorOS – FastAPI application entry point."""

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.db.base import engine, Base

# Import all models so SQLAlchemy knows about them
from app.models import user, course, assignment, rubric, analytics  # noqa: F401


@asynccontextmanager
async def lifespan(app: FastAPI):
    """On startup: ensure all tables exist (alembic handles schema in prod)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
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
    allow_origins=["*"],  # Restrict in production
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


@app.get("/")
async def root():
    return {
        "service": "ProfessorOS API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "health": "/health",
    }

