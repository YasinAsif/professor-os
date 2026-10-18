import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.main import app
from app.core.security import hash_password
from app.models.user import User
from app.db.base import get_db

PROFESSOR_EMAIL = "dr.tariq@professoros.edu.pk"
PROFESSOR_PASSWORD = "professor123"


@pytest.mark.asyncio
async def test_logout_revokes_token_and_rejects_subsequent_calls(monkeypatch):
    """Item 6: Verify that logging out invalidates the token and prevents further access in default suite."""
    from app.models.course import Course, Enrollment

    sqlite_engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with sqlite_engine.begin() as conn:
        await conn.run_sync(User.__table__.create, checkfirst=True)
        await conn.run_sync(Course.__table__.create, checkfirst=True)
        await conn.run_sync(Enrollment.__table__.create, checkfirst=True)
    session_factory = async_sessionmaker(sqlite_engine, expire_on_commit=False, class_=AsyncSession)

    prof = User(
        id=1,
        email=PROFESSOR_EMAIL,
        full_name="Dr Tariq",
        hashed_password=hash_password(PROFESSOR_PASSWORD),
        role="professor",
        is_verified=True,
        is_active=True,
        is_approved=True,
    )
    async with session_factory() as session:
        session.add(prof)
        await session.commit()

    async def override_get_db():
        async with session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db

    # In-memory blacklist store for Redis-free test execution
    revoked_tokens = set()

    async def mock_blacklist(jti, ttl_seconds=3600, **kwargs):
        revoked_tokens.add(jti)
        return True

    async def mock_is_blacklisted(jti, **kwargs):
        return jti in revoked_tokens

    import app.services.cache_service as cs
    monkeypatch.setattr(cs, "blacklist_token", mock_blacklist)
    monkeypatch.setattr(cs, "is_token_blacklisted", mock_is_blacklisted)

    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            # 1. Login to obtain access token
            res_login = await client.post(
                "/api/v1/auth/login",
                json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD},
            )
            assert res_login.status_code == 200, res_login.text
            token = res_login.json()["access_token"]
            headers = {"Authorization": f"Bearer {token}"}

            # 2. Token should be valid for authenticated requests
            res_me = await client.get("/api/v1/users/me", headers=headers)
            assert res_me.status_code == 200

            # 3. Call logout
            res_logout = await client.post("/api/v1/auth/logout", headers=headers)
            assert res_logout.status_code == 200
            assert res_logout.json()["message"] == "Logged out successfully."

            # 4. Same token should now be rejected as revoked (401)
            res_me_after = await client.get("/api/v1/users/me", headers=headers)
            assert res_me_after.status_code == 401
            assert "revoked" in res_me_after.json()["detail"].lower()
    finally:
        app.dependency_overrides.pop(get_db, None)
        await sqlite_engine.dispose()


@pytest.mark.asyncio
async def test_serve_flutter_path_traversal_blocked():
    """Verify that path traversal attempts to sensitive files are blocked with 403."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/../../backend/.env")
        assert res.status_code in (403, 404)
        if res.status_code == 403:
            assert res.json()["detail"] == "Access denied."
