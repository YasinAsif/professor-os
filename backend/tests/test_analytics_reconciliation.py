from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.analytics_service import AnalyticsService


@pytest.mark.asyncio
async def test_at_risk_detection_reconciles_recovered_students():
    db = SimpleNamespace(execute=AsyncMock(), add=lambda record: None, flush=AsyncMock())
    service = AnalyticsService(db)

    records = await service.detect_at_risk_students(
        course_id=4,
        threshold=50,
        student_scores={10: 75, 11: 25},
    )

    assert len(records) == 1
    assert records[0].student_id == 11
    assert db.execute.await_count == 1
    db.flush.assert_awaited_once()
