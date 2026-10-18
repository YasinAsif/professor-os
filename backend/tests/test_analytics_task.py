from types import SimpleNamespace
from unittest.mock import AsyncMock

import app.tasks as celery_module


def test_refresh_analytics_task_recomputes_and_commits(monkeypatch):
    session = SimpleNamespace(commit=AsyncMock())

    class SessionContext:
        async def __aenter__(self):
            return session

        async def __aexit__(self, *args):
            return False

    class FakeAnalyticsService:
        def __init__(self, db):
            assert db is session

        async def compute_analytics_from_db(self, course_id):
            assert course_id == 4
            return SimpleNamespace(total_students=12)

    monkeypatch.setattr(celery_module, "async_session", lambda: SessionContext())
    monkeypatch.setattr(celery_module, "AnalyticsService", FakeAnalyticsService)

    result = celery_module.refresh_analytics_task.run(4)

    assert result == {"status": "completed", "course_id": 4, "total_students": 12}
    session.commit.assert_awaited_once()
