"""Tests for professor exam console, authorization (403s), audit trail, decisions, settings lock, and heartbeat draft rejection.

Runs entirely against an isolated SQLite test database.
"""

import pytest
from datetime import datetime, timedelta, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from fastapi import HTTPException

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db.base import Base
from app.models.user import User, UserRole
from app.models.course import Course, CLO, Enrollment
from app.models.assignment import (
    Assignment,
    AssignmentType,
    AssignmentStatus,
    assignment_clo_table,
    assignment_ta_table,
)
from app.models.submission import Submission
from app.models.rubric import Rubric
from app.models.exam_attempt import ExamAttempt, ExamViolation, ExamAuditLog
from app.services.course_service import CourseService
from app.api.v1.exams import (
    ExamDecisionRequest,
    ExamSettingsRequest,
    HeartbeatRequest,
    list_exam_attempts,
    update_exam_attempt_decision,
    export_exam_attempts_csv,
    update_exam_settings,
    attempt_heartbeat,
    record_violation,
    start_exam,
)
from app.core.proctor_config import HEARTBEAT_TIMEOUT_SECONDS


@pytest.fixture
async def audit_test_db():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    tables = [
        User.__table__,
        Course.__table__,
        Enrollment.__table__,
        CLO.__table__,
        assignment_clo_table,
        assignment_ta_table,
        Assignment.__table__,
        Rubric.__table__,
        Submission.__table__,
        ExamAttempt.__table__,
        ExamViolation.__table__,
        ExamAuditLog.__table__,
    ]
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all, tables=tables)

    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        yield session

    await engine.dispose()


@pytest.fixture
async def test_env(audit_test_db: AsyncSession):
    now = datetime.now(timezone.utc)
    # Instructor of course 1
    prof1 = User(
        id=101,
        email="prof1@uni.edu",
        full_name="Professor One",
        hashed_password="dummy_hash_prof1",
        role=UserRole.PROFESSOR.value,
        is_active=True,
    )
    # Instructor of course 2 (unauthorized for course 1)
    prof2 = User(
        id=102,
        email="prof2@uni.edu",
        full_name="Professor Two",
        hashed_password="dummy_hash_prof2",
        role=UserRole.PROFESSOR.value,
        is_active=True,
    )
    # Student
    student = User(
        id=201,
        email="student@uni.edu",
        full_name="Alice Student",
        hashed_password="dummy_hash_student",
        role=UserRole.STUDENT.value,
        is_active=True,
    )
    audit_test_db.add_all([prof1, prof2, student])
    await audit_test_db.flush()

    # Course 1 owned by prof1
    course1 = Course(
        id=1,
        code="CS101",
        title="Intro to CS",
        semester="Fall 2026",
        professor_id=prof1.id,
    )
    # Course 2 owned by prof2
    course2 = Course(
        id=2,
        code="CS202",
        title="Advanced CS",
        semester="Fall 2026",
        professor_id=prof2.id,
    )
    audit_test_db.add_all([course1, course2])
    await audit_test_db.flush()

    # Assignment in course 1
    assignment = Assignment(
        id=1,
        course_id=course1.id,
        title="Midterm Exam",
        type=AssignmentType.MCQ,
        status=AssignmentStatus.PUBLISHED,
        time_limit_minutes=60,
        max_attempts=1,
        strike_limit_flag=3,
        strike_limit_autosubmit=5,
        fullscreen_required=True,
        block_copy_paste=True,
        unsupported_browser_policy="block",
    )
    audit_test_db.add(assignment)
    await audit_test_db.flush()

    return {
        "prof1": prof1,
        "prof2": prof2,
        "student": student,
        "course1": course1,
        "course2": course2,
        "assignment": assignment,
    }


@pytest.mark.asyncio
async def test_403_access_control_for_exam_management(audit_test_db: AsyncSession, test_env: dict):
    """Students and instructors from other courses must be strictly denied with 403."""
    prof1 = test_env["prof1"]
    prof2 = test_env["prof2"]
    student = test_env["student"]
    course1 = test_env["course1"]
    assignment = test_env["assignment"]

    # 1. Other-course instructor trying to view attempts -> 403
    with pytest.raises(HTTPException) as exc_info:
        await list_exam_attempts(
            course_id=course1.id,
            assignment_id=assignment.id,
            user=prof2,
            db=audit_test_db,
        )
    assert exc_info.value.status_code == 403

    # 2. Other-course instructor trying to export CSV -> 403
    with pytest.raises(HTTPException) as exc_info:
        await export_exam_attempts_csv(
            course_id=course1.id,
            assignment_id=assignment.id,
            user=prof2,
            db=audit_test_db,
        )
    assert exc_info.value.status_code == 403

    # 3. Other-course instructor trying to modify settings -> 403
    settings_payload = ExamSettingsRequest(
        time_limit_minutes=90,
        strike_limit_flag=2,
        strike_limit_autosubmit=4,
        fullscreen_required=True,
        block_copy_paste=True,
        unsupported_browser_policy="warn_allow",
    )
    with pytest.raises(HTTPException) as exc_info:
        await update_exam_settings(
            course_id=course1.id,
            assignment_id=assignment.id,
            payload=settings_payload,
            user=prof2,
            db=audit_test_db,
        )
    assert exc_info.value.status_code == 403

    # 4. Legitimate course professor -> 200 OK
    attempts = await list_exam_attempts(
        course_id=course1.id,
        assignment_id=assignment.id,
        user=prof1,
        db=audit_test_db,
    )
    assert isinstance(attempts, list)


@pytest.mark.asyncio
async def test_clear_flags_preserves_violation_events_and_audits(audit_test_db: AsyncSession, test_env: dict):
    """Clearing flags resets strike count and unflags, but preserves all raw violation event rows and writes to ExamAuditLog."""
    prof1 = test_env["prof1"]
    student = test_env["student"]
    course1 = test_env["course1"]
    assignment = test_env["assignment"]
    now = datetime.now(timezone.utc)

    # Create flagged attempt with violations
    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now - timedelta(minutes=10),
        duration_minutes=60,
        tab_switch_count=3,
        is_flagged=True,
        flag_reason="Flagged: 3 violations detected (tab_switch).",
        last_heartbeat_at=now,
    )
    audit_test_db.add(attempt)
    await audit_test_db.flush()

    v1 = ExamViolation(attempt_id=attempt.id, violation_type="tab_switch", occurred_at=now - timedelta(minutes=5), details="Switched tab")
    v2 = ExamViolation(attempt_id=attempt.id, violation_type="copy_paste", occurred_at=now - timedelta(minutes=3), details="Pasted text")
    v3 = ExamViolation(attempt_id=attempt.id, violation_type="fullscreen_exit", occurred_at=now - timedelta(minutes=1), details="Exited fullscreen")
    audit_test_db.add_all([v1, v2, v3])
    await audit_test_db.flush()

    # Professor clears flags with mandatory reason
    req = ExamDecisionRequest(action="clear", reason="Student demonstrated technical glitch caused tab switch.")
    resp = await update_exam_attempt_decision(
        course_id=course1.id,
        assignment_id=assignment.id,
        attempt_id=attempt.id,
        payload=req,
        user=prof1,
        db=audit_test_db,
    )

    assert resp["is_flagged"] is False
    assert resp["tab_switch_count"] == 3  # Tab switch count is preserved!
    assert resp["strike_count"] == 3      # Strike count is preserved!
    assert resp["reviewed_by_id"] == prof1.id
    assert resp["reviewed_at"] is not None
    assert resp["decision"] == "clear"
    assert "technical glitch" in resp["flag_reason"]

    # CRITICAL: Verify violation event rows were NOT deleted from the database
    v_res = await audit_test_db.execute(select(ExamViolation).where(ExamViolation.attempt_id == attempt.id))
    persisted_violations = list(v_res.scalars().all())
    assert len(persisted_violations) == 3, "Clear flags must preserve all raw violation events!"

    # Verify ExamAuditLog entry exists
    audit_res = await audit_test_db.execute(select(ExamAuditLog).where(ExamAuditLog.attempt_id == attempt.id))
    log = audit_res.scalar_one_or_none()
    assert log is not None
    assert log.instructor_id == prof1.id
    assert log.action == "clear"
    assert "technical glitch" in log.reason


@pytest.mark.asyncio
async def test_allow_retake_decision_and_state(audit_test_db: AsyncSession, test_env: dict):
    """Decision allow_retake grants a per-student extra-attempt allowance without mutating assignment.max_attempts for everyone."""
    prof1 = test_env["prof1"]
    student_a = test_env["student"]
    course1 = test_env["course1"]
    assignment = test_env["assignment"]
    now = datetime.now(timezone.utc)

    # Student B setup
    student_b = User(
        id=202,
        email="bob@uni.edu",
        full_name="Bob Student",
        hashed_password="dummy_hash_bob",
        role=UserRole.STUDENT.value,
        is_active=True,
    )
    enrollment_a = Enrollment(course_id=course1.id, user_id=student_a.id, role="student")
    enrollment_b = Enrollment(course_id=course1.id, user_id=student_b.id, role="student")
    audit_test_db.add_all([student_b, enrollment_a, enrollment_b])
    await audit_test_db.flush()

    # Student A completed attempt 1
    attempt_a1 = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student_a.id,
        started_at=now - timedelta(minutes=20),
        duration_minutes=60,
        tab_switch_count=5,
        is_flagged=True,
        flag_reason="Disqualified",
        submitted_at=now - timedelta(minutes=5),
        auto_submitted=True,
    )
    # Student B completed attempt 1
    attempt_b1 = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student_b.id,
        started_at=now - timedelta(minutes=30),
        duration_minutes=60,
        tab_switch_count=0,
        is_flagged=False,
        submitted_at=now - timedelta(minutes=10),
        auto_submitted=False,
    )
    audit_test_db.add_all([attempt_a1, attempt_b1])
    await audit_test_db.flush()

    assert assignment.max_attempts == 1

    # Professor grants retake specifically to Student A's attempt
    req = ExamDecisionRequest(action="allow_retake", reason="Power outage confirmed by university IT.")
    resp = await update_exam_attempt_decision(
        course_id=course1.id,
        assignment_id=assignment.id,
        attempt_id=attempt_a1.id,
        payload=req,
        user=prof1,
        db=audit_test_db,
    )

    assert resp["decision"] == "allow_retake"
    # CRITICAL: assignment.max_attempts must NOT be increased globally!
    assert assignment.max_attempts == 1

    # Verify audit entry recorded
    audit_res = await audit_test_db.execute(select(ExamAuditLog).where(ExamAuditLog.attempt_id == attempt_a1.id))
    log = audit_res.scalar_one_or_none()
    assert log is not None
    assert log.action == "allow_retake"
    assert "Power outage" in log.reason

    # Test double-click: Professor calls allow_retake again on attempt_a1
    req2 = ExamDecisionRequest(action="allow_retake", reason="Clicked again by accident.")
    resp2 = await update_exam_attempt_decision(
        course_id=course1.id,
        assignment_id=assignment.id,
        attempt_id=attempt_a1.id,
        payload=req2,
        user=prof1,
        db=audit_test_db,
    )
    assert resp2["decision"] == "allow_retake"

    # Student A starts a new attempt -> ALLOWED (attempt 2 of 2)
    retake_payload = await start_exam(
        course_id=course1.id,
        assignment_id=assignment.id,
        user=student_a,
        db=audit_test_db,
    )
    assert retake_payload["attempt_number"] == 2
    # CRITICAL: max_attempts is exactly 2 (base 1 + 1 allowance), NOT 3 despite clicking twice!
    assert retake_payload["max_attempts"] == 2

    # Student B tries to start a second attempt -> DENIED (400) because max_attempts=1 was not bumped for everyone
    with pytest.raises(HTTPException) as exc_b:
        await start_exam(
            course_id=course1.id,
            assignment_id=assignment.id,
            user=student_b,
            db=audit_test_db,
        )
    assert exc_b.value.status_code == 400
    assert "Maximum attempts reached" in exc_b.value.detail
    assert assignment.max_attempts == 1


@pytest.mark.asyncio
async def test_settings_lock_when_attempt_exists(audit_test_db: AsyncSession, test_env: dict):
    """Exam settings cannot be altered once a student has started an attempt (returns 409 Conflict)."""
    prof1 = test_env["prof1"]
    student = test_env["student"]
    course1 = test_env["course1"]
    assignment = test_env["assignment"]
    now = datetime.now(timezone.utc)

    # 1. Before any student starts, updating settings is allowed
    payload1 = ExamSettingsRequest(
        time_limit_minutes=45,
        strike_limit_flag=3,
        strike_limit_autosubmit=6,
        fullscreen_required=True,
        block_copy_paste=True,
        unsupported_browser_policy="block",
    )
    ok_resp = await update_exam_settings(
        course_id=course1.id,
        assignment_id=assignment.id,
        payload=payload1,
        user=prof1,
        db=audit_test_db,
    )
    assert ok_resp["time_limit_minutes"] == 45
    assert ok_resp["strike_limit_autosubmit"] == 6

    # 2. Student starts an attempt
    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now,
        duration_minutes=45,
        last_heartbeat_at=now,
    )
    audit_test_db.add(attempt)
    await audit_test_db.flush()

    # 3. Attempting to update settings now must raise 409 Conflict
    payload2 = ExamSettingsRequest(
        time_limit_minutes=90,
        strike_limit_flag=2,
        strike_limit_autosubmit=5,
        fullscreen_required=False,
        block_copy_paste=False,
        unsupported_browser_policy="warn_allow",
    )
    with pytest.raises(HTTPException) as exc_info:
        await update_exam_settings(
            course_id=course1.id,
            assignment_id=assignment.id,
            payload=payload2,
            user=prof1,
            db=audit_test_db,
        )
    assert exc_info.value.status_code == 409
    assert "locked because student attempts have already started" in exc_info.value.detail


@pytest.mark.asyncio
async def test_heartbeat_rejects_draft_saves_after_deadline_or_submitted(audit_test_db: AsyncSession, test_env: dict):
    """Heartbeat endpoint must reject draft saves with 409 Conflict if attempt is expired or already submitted."""
    student = test_env["student"]
    assignment = test_env["assignment"]
    now = datetime.now(timezone.utc)

    # 1. Submitted attempt
    attempt_sub = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now - timedelta(minutes=40),
        duration_minutes=30,
        submitted_at=now - timedelta(minutes=10),
    )
    audit_test_db.add(attempt_sub)
    await audit_test_db.flush()

    with pytest.raises(HTTPException) as exc_info:
        await attempt_heartbeat(
            attempt_id=attempt_sub.id,
            user=student,
            db=audit_test_db,
            body=HeartbeatRequest(answers='{"q1": "A"}'),
        )
    assert exc_info.value.status_code == 409
    assert "already been submitted" in exc_info.value.detail

    # 2. Expired attempt (past deadline + grace) with answers -> 409 Conflict
    attempt_exp = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now - timedelta(minutes=75),
        duration_minutes=60,
    )
    audit_test_db.add(attempt_exp)
    await audit_test_db.flush()

    with pytest.raises(HTTPException) as exc_info_exp:
        await attempt_heartbeat(
            attempt_id=attempt_exp.id,
            user=student,
            db=audit_test_db,
            body=HeartbeatRequest(answers='{"q1": "A"}'),
        )
    assert exc_info_exp.value.status_code == 409
    assert "Exam deadline has passed" in exc_info_exp.value.detail
    assert attempt_exp.auto_submitted is True


@pytest.mark.asyncio
async def test_csv_export_format_and_data(audit_test_db: AsyncSession, test_env: dict):
    """Exporting attempts CSV produces properly formatted CSV with all headers and data."""
    prof1 = test_env["prof1"]
    student = test_env["student"]
    course1 = test_env["course1"]
    assignment = test_env["assignment"]
    now = datetime.now(timezone.utc)

    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now - timedelta(minutes=30),
        duration_minutes=60,
        submitted_at=now - timedelta(minutes=5),
        tab_switch_count=2,
        is_flagged=False,
        auto_submitted=False,
    )
    audit_test_db.add(attempt)
    await audit_test_db.flush()

    v = ExamViolation(attempt_id=attempt.id, violation_type="tab_switch", occurred_at=now - timedelta(minutes=15), details="tab")
    audit_test_db.add(v)
    await audit_test_db.flush()

    response = await export_exam_attempts_csv(
        course_id=course1.id,
        assignment_id=assignment.id,
        user=prof1,
        db=audit_test_db,
    )
    assert response.headers["Content-Disposition"].startswith("attachment; filename=")

    chunks = []
    async for chunk in response.body_iterator:
        chunks.append(chunk.encode("utf-8") if isinstance(chunk, str) else chunk)
    content = b"".join(chunks)

    text = content.decode("utf-8")
    assert "Attempt ID" in text
    assert "Student Email" in text
    assert "Strikes" in text
    assert "Auto-Submitted" in text
    assert student.email in text

