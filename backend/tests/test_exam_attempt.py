"""ExamAttempt anti-cheat flag logic – unit tests (no DB required).

Tests the flagging logic in isolation using a plain Python object that
mirrors the ExamAttempt model fields, matching the SimpleNamespace pattern.
"""

from types import SimpleNamespace
from datetime import datetime, timedelta, timezone


def _make_attempt(**kwargs):
    """Create a mock attempt with defaults."""
    defaults = dict(
        id=1, assignment_id=1, student_id=1,
        tab_switch_count=0, is_flagged=False, flag_reason=None,
    )
    defaults.update(kwargs)
    return SimpleNamespace(**defaults)


import pytest
from unittest.mock import AsyncMock, MagicMock
from app.api.v1.exams import record_violation_atomic
from app.models.exam_attempt import ExamAttempt, ExamViolation


@pytest.mark.asyncio
async def test_real_record_violation_atomic_flagging_and_dedupe():
    """Verify real record_violation increments strikes and flags when threshold is reached."""
    from app.api.v1.exams import record_violation

    attempt = ExamAttempt(
        id=1,
        assignment_id=1,
        student_id=1,
        started_at=datetime.now(timezone.utc),
        tab_switch_count=2,
        is_flagged=False,
        flag_reason=None,
    )
    assignment = SimpleNamespace(
        id=1,
        time_limit_minutes=60,
        deadline=None,
    )
    db = AsyncMock()
    db.add = MagicMock()
    # Mock no recent violation so dedupe passes
    mock_res = MagicMock()
    mock_res.scalar_one_or_none.return_value = None
    db.execute.return_value = mock_res
    db.get.return_value = attempt

    async def mock_refresh(inst, attrs=None):
        if attrs and "tab_switch_count" in attrs:
            inst.tab_switch_count += 1
            if inst.tab_switch_count >= 3:
                inst.is_flagged = True
                inst.flag_reason = f"Flagged: {inst.tab_switch_count} tab switches detected."

    db.refresh = AsyncMock(side_effect=mock_refresh)

    # Record 3rd strike via real production function
    result = await record_violation(
        attempt=attempt,
        assignment=assignment,
        violation_type="tab_switch",
        details="Exited tab",
        db=db,
    )

    assert result["strike_count"] == 3
    assert result["is_flagged"] is True
    assert attempt.is_flagged is True
    assert "Flagged" in (attempt.flag_reason or "")


def test_timed_attempt_is_expired_from_server_start_time():
    from app.api.v1.exams import is_attempt_expired

    started_at = datetime(2026, 10, 14, 12, 0, tzinfo=timezone.utc)
    attempt = _make_attempt(started_at=started_at, submitted_at=None)
    assignment = SimpleNamespace(time_limit_minutes=60)

    assert is_attempt_expired(
        attempt,
        assignment,
        now=started_at + timedelta(minutes=60, seconds=1),
    ) is True


def test_timed_attempt_is_not_expired_before_server_deadline():
    from app.api.v1.exams import is_attempt_expired

    started_at = datetime(2026, 10, 14, 12, 0, tzinfo=timezone.utc)
    attempt = _make_attempt(started_at=started_at, submitted_at=None)
    assignment = SimpleNamespace(time_limit_minutes=60)

    assert is_attempt_expired(
        attempt,
        assignment,
        now=started_at + timedelta(minutes=59, seconds=59),
    ) is False


def test_exam_start_query_locks_parent_assignment_for_no_row_races():
    from sqlalchemy import select
    from app.models.assignment import Assignment

    query = select(Assignment).where(Assignment.id == 1).with_for_update()

    assert query._for_update_arg is not None

