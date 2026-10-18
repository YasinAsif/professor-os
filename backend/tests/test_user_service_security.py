from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services import user_service
from app.services.user_service import UserService


@pytest.mark.asyncio
async def test_admin_password_reset_invalidates_existing_sessions(monkeypatch):
    user = SimpleNamespace(hashed_password="old", token_valid_after=None)
    db = SimpleNamespace(get=AsyncMock(return_value=user), flush=AsyncMock())
    monkeypatch.setattr(user_service, "hash_password", lambda password: f"hashed:{password}")

    before = datetime.now(timezone.utc)
    result = await UserService(db).admin_reset_password(11, "new-password")

    assert result is user
    assert user.hashed_password == "hashed:new-password"
    assert user.token_valid_after is not None
    assert user.token_valid_after >= before
    db.flush.assert_awaited_once()
