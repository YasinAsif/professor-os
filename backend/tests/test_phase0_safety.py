"""Test Phase 0 Safety: Production settings validation & token expiration."""

import pytest
from app.config.settings import Settings


def test_production_rejects_default_postgres_password():
    """Production must refuse startup if DATABASE_URL uses postgres:postgres default credentials."""
    with pytest.raises(ValueError, match="DATABASE_URL"):
        Settings(
            ENVIRONMENT="production",
            JWT_SECRET_KEY="x" * 64,
            DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os",
        )


def test_production_rejects_debug_true():
    """Production must refuse startup if DEBUG=True."""
    with pytest.raises(ValueError, match="DEBUG"):
        Settings(
            ENVIRONMENT="production",
            JWT_SECRET_KEY="x" * 64,
            DATABASE_URL="postgresql+asyncpg://app_user:strong_pass_12345@db.railway.internal:5432/railway",
            DEBUG=True,
        )


def test_production_rejects_weak_initial_admin_password():
    """Production must refuse startup if INITIAL_ADMIN_PASSWORD is set but weak (< 12 chars)."""
    with pytest.raises(ValueError, match="INITIAL_ADMIN_PASSWORD"):
        Settings(
            ENVIRONMENT="production",
            DEBUG=False,
            JWT_SECRET_KEY="x" * 64,
            DATABASE_URL="postgresql+asyncpg://app_user:strong_pass_12345@db.railway.internal:5432/railway",
            INITIAL_ADMIN_PASSWORD="weak",
        )


def test_default_access_token_expire_is_60_minutes():
    """Access token default expiration must be 60 minutes."""
    settings = Settings(
        JWT_SECRET_KEY="x" * 64,
        DATABASE_URL="postgresql+asyncpg://app_user:strong_pass_12345@db.railway.internal:5432/railway",
    )
    assert settings.ACCESS_TOKEN_EXPIRE_MINUTES == 60
