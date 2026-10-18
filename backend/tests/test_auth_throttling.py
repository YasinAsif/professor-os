import pytest

from app.services import cache_service


@pytest.mark.asyncio
async def test_login_rate_limit_allows_limit_then_rejects(monkeypatch):
    cache_service._login_rate_memory.clear()
    monkeypatch.setattr(cache_service, "get_redis", lambda: _none_redis())

    for _ in range(3):
        assert await cache_service.allow_login_attempt("10.0.0.1", limit=3) is True
    assert await cache_service.allow_login_attempt("10.0.0.1", limit=3) is False


@pytest.mark.asyncio
async def test_login_rate_limit_expires(monkeypatch):
    now = 1000.0
    cache_service._login_rate_memory.clear()
    monkeypatch.setattr(cache_service.time, "time", lambda: now)
    monkeypatch.setattr(cache_service, "get_redis", lambda: _none_redis())

    assert await cache_service.allow_login_attempt("10.0.0.2", limit=1, window_seconds=10) is True
    assert await cache_service.allow_login_attempt("10.0.0.2", limit=1, window_seconds=10) is False
    monkeypatch.setattr(cache_service.time, "time", lambda: now + 11)
    assert await cache_service.allow_login_attempt("10.0.0.2", limit=1, window_seconds=10) is True


async def _none_redis():
    return None
