import pytest

from app.services import cache_service


@pytest.mark.asyncio
async def test_memory_blacklist_fallback_expires_entries(monkeypatch):
    now = 1000.0
    monkeypatch.setattr(cache_service.time, "time", lambda: now)
    cache_service._token_blacklist_memory.clear()
    monkeypatch.setattr(cache_service, "get_redis", lambda: _none_redis())

    await cache_service.blacklist_token("jti-1", ttl_seconds=10)
    assert await cache_service.is_token_blacklisted("jti-1") is True

    monkeypatch.setattr(cache_service.time, "time", lambda: 1011.0)
    assert await cache_service.is_token_blacklisted("jti-1") is False


async def _none_redis():
    return None
