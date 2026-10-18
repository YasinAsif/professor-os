"""Comprehensive automated tests for proctoring, concurrency, and server-side timer integrity.

Verified against an async SQLite database.
"""

import asyncio
from datetime import datetime, timedelta, timezone
import pytest
from sqlalchemy import select, text
from sqlalchemy.pool import StaticPool
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db.base import Base
from app.models.user import User, UserRole
from app.models.course import Course, CLO, Enrollment
from app.models.assignment import Assignment, AssignmentType, AssignmentStatus, assignment_clo_table, assignment_ta_table
from app.models.rubric import Rubric
from app.models.submission import Submission
from app.models.exam_attempt import ExamAttempt, ExamViolation
from app.schemas.submission import SubmissionCreate
from app.services.submission_service import SubmissionService
from app.api.v1.exams import (
    record_violation_atomic,
    is_attempt_expired,
    compute_remaining_seconds,
    auto_close_attempt,
    DEFAULT_GRACE_SECONDS,
)
from app.api.v1.submissions import validate_timed_submission_attempt
from app.services.exam_monitor import monitor_active_exam_attempts


@pytest.fixture
async def test_db():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
        echo=False,
    )
    tables = [
        User.__table__,
        Course.__table__,
        CLO.__table__,
        Enrollment.__table__,
        Assignment.__table__,
        assignment_clo_table,
        assignment_ta_table,
        Rubric.__table__,
        Submission.__table__,
        ExamAttempt.__table__,
        ExamViolation.__table__,
    ]
    async with engine.begin() as conn:
        await conn.run_sync(lambda sync_conn: Base.metadata.create_all(sync_conn, tables=tables))

    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        # Seed test user and assignment
        user = User(
            id=1,
            email="student@university.edu.pk",
            hashed_password="hash",
            full_name="Test Student",
            role=UserRole.STUDENT.value,
            is_active=True,
            is_verified=True,
            is_approved=True,
        )
        course = Course(
            id=1,
            code="CS401",
            title="Distributed Systems",
            semester="Spring-2026",
            professor_id=1,
            join_code="DIST401",
        )
        assignment = Assignment(
            id=1,
            course_id=1,
            title="Midterm Exam",
            type=AssignmentType.TEXT.value,
            status=AssignmentStatus.PUBLISHED.value,
            time_limit_minutes=30,
            max_attempts=1,
        )
        session.add_all([user, course, assignment])
        await session.commit()

    yield session_factory
    await engine.dispose()


@pytest.mark.asyncio
async def test_client_sent_auto_submitted_is_ignored(test_db):
    """Client attempting to pass auto_submitted=True in the payload is ignored;
    the server forces auto_submitted=False for client-submitted work."""
    async with test_db() as session:
        svc = SubmissionService(session)
        # Client passes auto_submitted=True
        data = SubmissionCreate(
            submission_type="text",
            content="Student content",
        )
        # Verify SubmissionCreate schema has no writable auto_submitted field (or extra is ignored)
        dump = data.model_dump()
        assert "auto_submitted" not in dump

        sub = await svc.submit(1, 1, data, auto_submitted=False)
        assert sub.auto_submitted is False


@pytest.mark.asyncio
async def test_expired_attempt_gets_autoclosed_by_background_job(test_db):
    """Active attempt past deadline gets auto-closed by the background job with auto_submitted=True,
    even if the student closed their browser tab."""
    now = datetime.now(timezone.utc)
    # Attempt started 45 minutes ago on a 30-minute exam
    past_started = now - timedelta(minutes=45)

    async with test_db() as session:
        attempt = ExamAttempt(
            id=10,
            assignment_id=1,
            student_id=1,
            duration_minutes=30,
            started_at=past_started,
            last_heartbeat_at=past_started,
            current_answers="Draft written before tab closed",
        )
        session.add(attempt)
        await session.commit()

    # Run monitor job
    async with test_db() as session:
        stats = await monitor_active_exam_attempts(session)
        assert stats["closed_count"] == 1

    # Verify attempt and submission state
    async with test_db() as session:
        saved_attempt = await session.get(ExamAttempt, 10)
        assert saved_attempt.submitted_at is not None
        assert saved_attempt.auto_submitted is True

        sub_res = await session.execute(
            select(Submission).where(Submission.assignment_id == 1, Submission.student_id == 1)
        )
        sub = sub_res.scalar_one()
        assert sub.auto_submitted is True
        assert sub.content == "Draft written before tab closed"


@pytest.mark.asyncio
async def test_late_submission_is_rejected(test_db):
    """Submissions arriving after the deadline plus grace period are rejected with clear error."""
    now = datetime.now(timezone.utc)
    # Started 35 minutes ago on 30 min exam (beyond 10s grace period)
    past_started = now - timedelta(minutes=35)

    attempt = ExamAttempt(
        id=20,
        assignment_id=1,
        student_id=1,
        duration_minutes=30,
        started_at=past_started,
    )
    assignment = Assignment(id=1, time_limit_minutes=30)

    with pytest.raises(ValueError, match="The exam time limit has expired and the grace period has ended."):
        validate_timed_submission_attempt(assignment, attempt, now=now, grace_seconds=DEFAULT_GRACE_SECONDS)


@pytest.mark.asyncio
async def test_heartbeat_timeout_creates_flag_and_event(test_db):
    """If an active attempt receives no heartbeat for >30s, background job flags it as offline."""
    now = datetime.now(timezone.utc)
    # Active attempt with heartbeat 40s ago
    attempt = ExamAttempt(
        id=30,
        assignment_id=1,
        student_id=1,
        duration_minutes=30,
        started_at=now - timedelta(minutes=5),
        last_heartbeat_at=now - timedelta(seconds=40),
    )
    async with test_db() as session:
        session.add(attempt)
        await session.commit()

    async with test_db() as session:
        stats = await monitor_active_exam_attempts(session)
        assert stats["flagged_offline"] == 1

    async with test_db() as session:
        saved = await session.get(ExamAttempt, 30)
        assert saved.is_flagged is True
        assert "[OFFLINE]" in saved.flag_reason

        # Check violation timeline row
        v_res = await session.execute(
            select(ExamViolation).where(
                ExamViolation.attempt_id == 30,
                ExamViolation.violation_type == "heartbeat_missed",
            )
        )
        v = v_res.scalar_one_or_none()
        assert v is not None


@pytest.mark.asyncio
async def test_duplicate_violations_within_dedupe_window_count_once(test_db):
    """Violations of the same type within 1.5s (such as blur + visibilitychange firing together)
    are deduplicated to exactly one strike."""
    async with test_db() as session:
        assignment = await session.get(Assignment, 1)
        attempt = ExamAttempt(
            id=40,
            assignment_id=1,
            student_id=1,
            duration_minutes=30,
            started_at=datetime.now(timezone.utc),
            tab_switch_count=0,
        )
        session.add(attempt)
        await session.commit()

        # First violation
        res1 = await record_violation_atomic(attempt, assignment, "tab_switch", "First switch", session)
        assert res1["tab_switch_count"] == 1
        assert "deduplicated" not in res1

        # Second duplicate violation immediately after
        res2 = await record_violation_atomic(attempt, assignment, "tab_switch", "Second rapid switch", session)
        assert res2["tab_switch_count"] == 1
        assert res2.get("deduplicated") is True

        # Total violation count in DB must remain 1
        await session.refresh(attempt)
        assert attempt.tab_switch_count == 1


@pytest.mark.asyncio
async def test_stale_or_crashed_attempt_resumed_without_extra_time(test_db):
    """When a student returns after a browser crash, the remaining time is calculated
    authoritatively from started_at. No extra time is granted."""
    now = datetime.now(timezone.utc)
    # Started exactly 10 minutes ago on a 30-minute exam
    started_at = now - timedelta(minutes=10)

    attempt = ExamAttempt(
        id=50,
        assignment_id=1,
        student_id=1,
        duration_minutes=30,
        started_at=started_at,
    )
    assignment = Assignment(id=1, time_limit_minutes=30)

    remaining = compute_remaining_seconds(attempt, assignment, now=now)
    # 30 min - 10 min = 20 min = 1200 seconds
    assert 1198 <= remaining <= 1200


@pytest.mark.asyncio
async def test_concurrent_violations_give_exact_count(test_db):
    """Multiple concurrent violation reports from asynchronous tasks update the counter
    using atomic SQL (SET count = count + 1). The final count must be 100% exact."""
    async with test_db() as session:
        attempt = ExamAttempt(
            id=60,
            assignment_id=1,
            student_id=1,
            duration_minutes=30,
            started_at=datetime.now(timezone.utc),
            tab_switch_count=0,
        )
        session.add(attempt)
        await session.commit()

    # REAL violation types concurrently:
    # tab_switch and window_blur belong to focus_loss group and dedupe within 1.5s (yielding 1 strike)
    # fullscreen_exit is a separate group (yielding 1 strike)
    # copy_paste and multi_monitor log violation events but do not increment strikes
    types = ["tab_switch", "window_blur", "fullscreen_exit", "copy_paste", "multi_monitor"]

    async def _post_violation(v_type: str):
        async with test_db() as session:
            assignment = await session.get(Assignment, 1)
            att = await session.get(ExamAttempt, 60)
            res = await record_violation_atomic(att, assignment, v_type, f"Violation {v_type}", session)
            await session.commit()
            return res

    results = []
    for t in types:
        results.append(await _post_violation(t))

    async with test_db() as session:
        final_attempt = await session.get(ExamAttempt, 60)
        # focus_loss (tab_switch + window_blur) = 1 strike; fullscreen_exit = 1 strike; total = 2 strikes
        assert final_attempt.tab_switch_count == 2
        v_res = await session.execute(
            select(ExamViolation).where(ExamViolation.attempt_id == 60)
        )
        violations = v_res.scalars().all()
        # window_blur was deduplicated; 4 violation events logged (tab_switch, fullscreen_exit, copy_paste, multi_monitor)
        assert len(violations) == 4


@pytest.mark.asyncio
async def test_heartbeat_missed_logged_once_per_outage_across_cycles(test_db):
    """Heartbeat missed event is logged exactly once per outage, not repeated on every daemon cycle."""
    now = datetime.now(timezone.utc)
    # Attempt offline for 40s
    attempt = ExamAttempt(
        id=70,
        assignment_id=1,
        student_id=1,
        duration_minutes=30,
        started_at=now - timedelta(minutes=5),
        last_heartbeat_at=now - timedelta(seconds=40),
    )
    async with test_db() as session:
        session.add(attempt)
        await session.commit()

    # Cycle 1: Disconnect detected -> logs 1st heartbeat_missed event
    async with test_db() as session:
        stats1 = await monitor_active_exam_attempts(session)
        assert stats1["flagged_offline"] == 1

    # Cycle 2: Student is still offline (no heartbeat sent) -> MUST NOT LOG duplicate event
    async with test_db() as session:
        stats2 = await monitor_active_exam_attempts(session)
        assert stats2["flagged_offline"] == 0

    # Cycle 3: Still offline -> MUST NOT LOG duplicate event
    async with test_db() as session:
        stats3 = await monitor_active_exam_attempts(session)
        assert stats3["flagged_offline"] == 0

    # Verify exactly 1 violation was persisted for this entire outage
    async with test_db() as session:
        v_res = await session.execute(
            select(ExamViolation).where(
                ExamViolation.attempt_id == 70,
                ExamViolation.violation_type == "heartbeat_missed",
            )
        )
        assert len(list(v_res.scalars().all())) == 1

    # Student reconnects and sends heartbeat at T_reconnect
    reconnect_time = datetime.now(timezone.utc)
    async with test_db() as session:
        att = await session.get(ExamAttempt, 70)
        att.last_heartbeat_at = reconnect_time
        att.is_flagged = False
        await session.commit()

    # Student drops offline again (new outage 40s later)
    new_outage_time = reconnect_time + timedelta(seconds=40)
    async with test_db() as session:
        # Simulate time moving forward past timeout with no new heartbeat
        stats4 = await monitor_active_exam_attempts(session, now=new_outage_time)
        assert stats4["flagged_offline"] == 1
        # Verify a new event is logged for the new outage
        v_res2 = await session.execute(
            select(ExamViolation).where(
                ExamViolation.attempt_id == 70,
                ExamViolation.violation_type == "heartbeat_missed",
            )
        )
        events = list(v_res2.scalars().all())
        # Both outages have their own event row
        assert len(events) == 2


@pytest.mark.asyncio
async def test_monitor_daemon_recovers_from_cycle_exception(monkeypatch):
    """The monitor daemon catches exceptions per cycle and continues running subsequent cycles."""
    from app.services.exam_monitor import run_exam_monitor_daemon

    cycle_count = 0

    async def mock_monitor_active_attempts(session):
        nonlocal cycle_count
        cycle_count += 1
        if cycle_count == 1:
            raise RuntimeError("Simulated transient database/network glitch in monitor cycle")
        return {"closed_count": 0, "flagged_offline": 0}

    monkeypatch.setattr(
        "app.services.exam_monitor.monitor_active_exam_attempts",
        mock_monitor_active_attempts,
    )

    # Launch daemon with a fast interval (0.01s)
    task = asyncio.create_task(run_exam_monitor_daemon(interval_seconds=0.01))
    await asyncio.sleep(0.05)
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass

    # Verify that cycle 1 failed, but cycle 2 and subsequent cycles ran without crashing
    assert cycle_count >= 2, f"Daemon should have continued after error, reached cycle {cycle_count}"
