"""ProfessorOS – Redis cache service (5-minute TTL, fault-tolerant)."""

import json
import logging
import hashlib
from typing import Optional

import redis.asyncio as redis

from app.core.config import get_settings

import time

logger = logging.getLogger(__name__)
_redis_client: Optional[redis.Redis] = None
_redis_offline_until: float = 0.0
CACHE_TTL = 300  # 5 minutes


async def get_redis() -> Optional[redis.Redis]:
    """Get or create the Redis client singleton with circuit breaker."""
    global _redis_client, _redis_offline_until
    if time.time() < _redis_offline_until:
        return None

    if _redis_client is None:
        settings = get_settings()
        try:
            _redis_client = redis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_timeout=0.2,
                socket_connect_timeout=0.2,
            )
        except Exception:
            _redis_offline_until = time.time() + 15
            return None
    return _redis_client


async def cache_get(key: str) -> Optional[dict]:
    """Get a cached value by key (returns None on cache miss or Redis failure)."""
    try:
        r = await get_redis()
        if r is None:
            return None
        data = await r.get(key)
        if data:
            return json.loads(data)
    except Exception as e:
        logger.warning(f"Redis cache_get error: {e}")
    return None


async def cache_set(key: str, value: dict, ttl: int = CACHE_TTL) -> None:
    """Set a cached value with TTL (silently fails if Redis unavailable)."""
    try:
        r = await get_redis()
        if r is not None:
            await r.set(key, json.dumps(value, default=str), ex=ttl)
    except Exception as e:
        logger.warning(f"Redis cache_set error: {e}")


# In-memory blacklist fallback for development or when Redis is temporarily unavailable.
# Values are expiry timestamps so the fallback cannot grow forever.
_token_blacklist_memory: dict[str, float] = {}
_login_rate_memory: dict[str, tuple[int, float]] = {}


async def blacklist_token(jti: str, ttl_seconds: int = 3600) -> None:
    """Add a JWT jti to the blacklist for the duration of its remaining lifetime."""
    if not jti:
        return
    _token_blacklist_memory[jti] = time.time() + max(0, ttl_seconds)
    try:
        r = await get_redis()
        if r is not None:
            await r.set(f"blacklist:{jti}", "1", ex=ttl_seconds)
    except Exception as e:
        logger.warning(f"Redis blacklist_token error: {e}")


async def is_token_blacklisted(jti: str) -> bool:
    """Check if a JWT jti has been invalidated."""
    if not jti:
        return False
    expires_at = _token_blacklist_memory.get(jti)
    if expires_at is not None:
        if expires_at > time.time():
            return True
        _token_blacklist_memory.pop(jti, None)
    try:
        r = await get_redis()
        if r is not None:
            val = await r.get(f"blacklist:{jti}")
            return val is not None
    except Exception as e:
        global _redis_offline_until
        _redis_offline_until = time.time() + 15
        logger.warning(f"Redis is_token_blacklisted error: {e}")
    return False


async def allow_login_attempt(
    identity: str,
    *,
    limit: int = 10,
    window_seconds: int = 60,
) -> bool:
    """Allow a login attempt using a shared Redis counter when available."""
    if not identity:
        return False
    key = f"login-limit:{hashlib.sha256(identity.encode()).hexdigest()}"
    try:
        r = await get_redis()
        if r is not None:
            count = await r.incr(key)
            if count == 1:
                await r.expire(key, window_seconds)
            return count <= limit
    except Exception as e:
        logger.warning(f"Redis login rate-limit error: {e}")

    now = time.time()
    count, expires_at = _login_rate_memory.get(key, (0, 0.0))
    if expires_at <= now:
        count = 0
        expires_at = now + window_seconds
    count += 1
    _login_rate_memory[key] = (count, expires_at)
    if len(_login_rate_memory) > 10000:
        _login_rate_memory.clear()
    return count <= limit


async def clear_login_attempts(identity: str) -> None:
    """Clear a login rate-limit bucket after a successful login."""
    if not identity:
        return
    key = f"login-limit:{hashlib.sha256(identity.encode()).hexdigest()}"
    _login_rate_memory.pop(key, None)
    try:
        r = await get_redis()
        if r is not None:
            await r.delete(key)
    except Exception as e:
        logger.warning(f"Redis login rate-limit clear error: {e}")

