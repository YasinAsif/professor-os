"""ProfessorOS – Security helpers: Argon2id hashing & JWT tokens."""

from datetime import datetime, timedelta, timezone
from typing import Optional
import uuid

from argon2 import PasswordHasher, Type
from argon2.exceptions import VerifyMismatchError
from jose import JWTError, jwt

from app.core.config import get_settings

# ── Password Hashing (Argon2id) ──────────────────────

_ph = PasswordHasher(
    time_cost=2,
    memory_cost=65536,
    parallelism=1,
    hash_len=32,
    salt_len=16,
    type=Type.ID,  # argon2id
)


def hash_password(plain: str) -> str:
    """Hash a plaintext password with Argon2id."""
    return _ph.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a plaintext password against an Argon2id hash."""
    try:
        return _ph.verify(hashed, plain)
    except VerifyMismatchError:
        return False


# ── JWT Tokens ────────────────────────────────────────

def create_access_token(
    user_id: int,
    role: str,
    extra: Optional[dict] = None,
) -> str:
    """Create a short-lived JWT access token (default 60 min)."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role,
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        "jti": str(uuid.uuid4()),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: int) -> str:
    """Create a long-lived JWT refresh token (default 7 days)."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_email_token(email: str, purpose: str = "verify") -> str:
    """Create a token for email verification or password reset (24h)."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": email,
        "type": purpose,
        "iat": now,
        "exp": now + timedelta(hours=24),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    """Decode and validate a JWT token. Returns payload or None on failure."""
    settings = get_settings()
    try:
        return jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except JWTError:
        return None
