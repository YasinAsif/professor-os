"""ProfessorOS – Application configuration via environment variables."""

from pydantic_settings import BaseSettings
from pydantic import field_validator
from functools import lru_cache


class Settings(BaseSettings):
    """Reads from .env or OS environment variables."""

    # ── Database ──────────────────────────────────────
    DATABASE_URL: str = "postgresql+asyncpg://professor_os:changeme@db:5432/professor_os_db"

    # ── Redis ─────────────────────────────────────────
    REDIS_URL: str = "redis://redis:6379/0"

    # ── JWT ───────────────────────────────────────────
    JWT_SECRET_KEY: str = "super-secret-jwt-key-change-this"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ── Security ──────────────────────────────────────
    MAX_LOGIN_ATTEMPTS: int = 5
    LOCKOUT_DURATION_MINUTES: int = 15

    # ── Email ─────────────────────────────────────────
    EMAIL_BACKEND: str = "smtp"
    EMAIL_FROM: str = "muhammadyasinasifofficial@gmail.com"
    RESEND_API_KEY: str = ""
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""

    # ── App ───────────────────────────────────────────
    BACKEND_URL: str = "http://localhost:8000"
    FRONTEND_URL: str = "http://localhost:8080"
    DEBUG: bool = False

    # Auto-fix Railway's postgres:// or postgresql:// → postgresql+asyncpg://
    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def fix_database_url(cls, v: str) -> str:
        if v.startswith("postgres://"):
            return v.replace("postgres://", "postgresql+asyncpg://", 1)
        if v.startswith("postgresql://") and "+asyncpg" not in v:
            return v.replace("postgresql://", "postgresql+asyncpg://", 1)
        return v

    model_config = {"env_file": ".env", "extra": "ignore"}


@lru_cache()
def get_settings() -> Settings:
    """Singleton settings instance, cached for performance."""
    return Settings()
