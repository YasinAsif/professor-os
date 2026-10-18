"""Phase 1 Data Loss & Exam Correctness Tests.

TEST FIRST for items 1.5, 1.9, 1.10.
"""

import pytest
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

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
from app.models.rubric import Rubric, RubricCriterion, RubricLevel
from app.models.exam_attempt import ExamAttempt, ExamViolation, ExamAuditLog
from app.api.v1.exams import (
    record_violation,
    start_exam,
    attempt_heartbeat,
    ViolationRequest,
    report_attempt_violation,
    submit_exam,
    SubmitExamRequest,
    auto_close_attempt,
)
from app.services.assignment_service import AssignmentService
from app.services.exam_monitor import monitor_active_exam_attempts


@pytest.fixture
async def phase1_db():
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
        RubricCriterion.__table__,
        RubricLevel.__table__,
        Submission.__table__,
        ExamAttempt.__table__,
        ExamViolation.__table__,
        ExamAuditLog.__table__,
    ]
    async with engine.begin() as conn:
        for t in tables:
            await conn.run_sync(t.create, checkfirst=True)

    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        yield session

    await engine.dispose()


@pytest.fixture
async def phase1_env(phase1_db: AsyncSession):
    student = User(
        id=10,
        email="student_p1@exam.pk",
        full_name="P1 Student",
        hashed_password="hash",
        role=UserRole.STUDENT.value,
        is_active=True,
        is_verified=True,
        is_approved=True,
    )
    prof = User(
        id=20,
        email="prof_p1@exam.pk",
        full_name="P1 Prof",
        hashed_password="hash",
        role=UserRole.PROFESSOR.value,
        is_active=True,
        is_verified=True,
        is_approved=True,
    )
    phase1_db.add_all([student, prof])
    await phase1_db.flush()

    course = Course(
        id=100,
        title="Distributed Systems",
        code="CS-401",
        semester="Spring-2026",
        professor_id=prof.id,
    )
    phase1_db.add(course)
    await phase1_db.flush()

    enr = Enrollment(course_id=course.id, user_id=student.id, role="student")
    phase1_db.add(enr)

    assignment = Assignment(
        id=200,
        course_id=course.id,
        title="Final Exam",
        type=AssignmentType.TEXT.value,
        status=AssignmentStatus.PUBLISHED.value,
        max_marks=100.0,
        time_limit_minutes=60,
        strike_limit_flag=3,
        strike_limit_autosubmit=5,
    )
    phase1_db.add(assignment)
    await phase1_db.flush()

    return {
        "student": student,
        "prof": prof,
        "course": course,
        "assignment": assignment,
    }


@pytest.mark.asyncio
async def test_alt_tab_double_strike_deduped_by_focus_loss_group(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.5: tab_switch and window_blur within 1.5s belong to 'focus_loss' group and produce only 1 strike."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    now = datetime.now(timezone.utc)

    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now,
        duration_minutes=60,
        last_heartbeat_at=now,
        tab_switch_count=0,
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    # 1. First event: window_blur
    res1 = await record_violation(attempt, assignment, "window_blur", "Lost focus", phase1_db)
    assert res1["strike_count"] == 1
    assert attempt.tab_switch_count == 1

    # 2. Second event: tab_switch 30ms later -> must be deduplicated under focus_loss group!
    res2 = await record_violation(attempt, assignment, "tab_switch", "Tab hidden", phase1_db)
    assert res2.get("deduplicated") is True, "tab_switch within 1.5s of window_blur must be deduplicated as focus_loss!"
    assert attempt.tab_switch_count == 1, "Strike count must remain 1 for blur + tab_switch within 1.5s"


@pytest.mark.asyncio
async def test_copy_paste_and_multi_monitor_log_events_without_strikes(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.5: copy_paste and multi_monitor store an audit event but do not add a strike count."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    now = datetime.now(timezone.utc)

    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now,
        duration_minutes=60,
        last_heartbeat_at=now,
        tab_switch_count=0,
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    res_cp = await record_violation(attempt, assignment, "copy_paste", "Pasted text", phase1_db)
    assert res_cp["strike_count"] == 0, "copy_paste must not increment strikes"
    assert attempt.tab_switch_count == 0

    res_mon = await record_violation(attempt, assignment, "multi_monitor", "2 screens", phase1_db)
    assert res_mon["strike_count"] == 0, "multi_monitor must not increment strikes"
    assert attempt.tab_switch_count == 0


@pytest.mark.asyncio
async def test_client_sent_heartbeat_missed_is_rejected_422(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.5: Clients cannot self-report heartbeat_missed; server returns 422 Unprocessable Entity."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    now = datetime.now(timezone.utc)

    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now,
        duration_minutes=60,
        last_heartbeat_at=now,
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    import httpx
    from app.main import app
    from app.db.base import get_db
    from app.core.security import create_access_token

    token = create_access_token(user_id=student.id, role="student")
    app.dependency_overrides[get_db] = lambda: phase1_db
    transport = httpx.ASGITransport(app=app)
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            res = await client.post(
                f"/api/v1/attempts/{attempt.id}/violations",
                json={"type": "heartbeat_missed", "details": "fake missed heartbeat"},
                headers={"Authorization": f"Bearer {token}"},
            )
            assert res.status_code == 422, f"Expected 422 Unprocessable Entity, got {res.status_code}: {res.text}"
    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_never_heartbeat_blind_spot_handled_by_monitor(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.9: start_exam sets last_heartbeat_at = started_at, and monitor flags attempts with no heartbeat."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    t0 = datetime(2026, 10, 18, 10, 0, 0, tzinfo=timezone.utc)

    # Attempt started 45 seconds ago with last_heartbeat_at == started_at
    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=t0,
        last_heartbeat_at=t0,
        duration_minutes=60,
        is_flagged=False,
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    now_scan = t0 + timedelta(seconds=45)
    stats = await monitor_active_exam_attempts(phase1_db, now=now_scan)
    assert stats["flagged_offline"] == 1
    assert attempt.is_flagged is True
    assert "[OFFLINE]" in attempt.flag_reason


@pytest.mark.asyncio
async def test_heartbeat_preserves_existing_flag_reason_when_restored(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.9: When heartbeat returns, clear offline-only flag but preserve any existing prior strike flag reasons."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    now = datetime.now(timezone.utc)

    # Attempt had 3 strikes (flagged), then experienced an offline outage
    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now - timedelta(minutes=10),
        duration_minutes=60,
        tab_switch_count=3,
        is_flagged=True,
        flag_reason="Flagged: 3 violations detected (tab_switch). [OFFLINE] Heartbeat missed (40s without signal).",
        last_heartbeat_at=now - timedelta(seconds=40),
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    res = await attempt_heartbeat(attempt_id=attempt.id, user=student, db=phase1_db)
    assert res["is_live"] is True
    # Attempt must STILL be flagged because tab_switch_count >= 3
    assert attempt.is_flagged is True
    assert "[OFFLINE]" not in attempt.flag_reason
    assert "3 violations detected" in attempt.flag_reason


@pytest.mark.asyncio
async def test_start_exam_rejects_past_deadline_unless_allow_late(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.10: start_exam must reject after assignment.deadline unless allow_late."""
    student = phase1_env["student"]
    course = phase1_env["course"]
    now = datetime.now(timezone.utc)

    # 1. Assignment with deadline in past and allow_late=False
    past_assignment = Assignment(
        id=301,
        course_id=course.id,
        title="Past Deadline Exam",
        type=AssignmentType.TEXT.value,
        status=AssignmentStatus.PUBLISHED.value,
        max_marks=100.0,
        time_limit_minutes=60,
        deadline=now - timedelta(minutes=5),
        allow_late=False,
    )
    phase1_db.add(past_assignment)
    await phase1_db.flush()

    with pytest.raises(HTTPException) as exc_info:
        await start_exam(
            course_id=course.id,
            assignment_id=past_assignment.id,
            user=student,
            db=phase1_db,
        )
    assert exc_info.value.status_code == 400
    assert "deadline" in exc_info.value.detail.lower()


@pytest.mark.asyncio
async def test_start_exam_caps_duration_to_deadline_unless_allow_late(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.10: Attempt time window is capped at the deadline when remaining time is less than time limit."""
    student = phase1_env["student"]
    course = phase1_env["course"]
    now = datetime.now(timezone.utc)

    # 2. Assignment deadline is 25 minutes from now, but time_limit_minutes is 60
    imminent_assignment = Assignment(
        id=302,
        course_id=course.id,
        title="Imminent Deadline Exam",
        type=AssignmentType.TEXT.value,
        status=AssignmentStatus.PUBLISHED.value,
        max_marks=100.0,
        time_limit_minutes=60,
        deadline=now + timedelta(minutes=25),
        allow_late=False,
    )
    phase1_db.add(imminent_assignment)
    await phase1_db.flush()

    payload = await start_exam(
        course_id=course.id,
        assignment_id=imminent_assignment.id,
        user=student,
        db=phase1_db,
    )
    # Attempt duration must be capped at 25 minutes
    assert payload["time_limit_minutes"] == 25
    assert payload["remaining_seconds"] <= 25 * 60


@pytest.mark.asyncio
async def test_auto_close_unpacks_all_draft_formats(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.1: auto_close_attempt builds Submission from ANY draft format (text, code, mcq, file, legacy)."""
    student = phase1_env["student"]
    course = phase1_env["course"]
    now = datetime.now(timezone.utc)

    # 1. Text tagged envelope
    a_text = Assignment(id=401, course_id=course.id, title="A1", type="text", status="published", max_marks=100.0)
    att1 = ExamAttempt(id=501, assignment_id=a_text.id, student_id=student.id, started_at=now, duration_minutes=60,
                       current_answers='{"v":1,"kind":"text","data":"my essay content"}')
    phase1_db.add_all([a_text, att1])
    await phase1_db.flush()

    await auto_close_attempt(att1, a_text, phase1_db, reason="time_expired")
    res1 = await phase1_db.execute(select(Submission).where(Submission.attempt_id == att1.id))
    s1 = res1.scalar_one()
    assert s1.submission_type == "text"
    assert s1.content == "my essay content"
    assert s1.auto_submitted is True

    # 2. Code tagged envelope
    a_code = Assignment(id=402, course_id=course.id, title="A2", type="programming", status="published", max_marks=100.0)
    att2 = ExamAttempt(id=502, assignment_id=a_code.id, student_id=student.id, started_at=now, duration_minutes=60,
                       current_answers='{"v":1,"kind":"programming","data":"def solve(): return 42"}')
    phase1_db.add_all([a_code, att2])
    await phase1_db.flush()

    await auto_close_attempt(att2, a_code, phase1_db, reason="time_expired")
    res2 = await phase1_db.execute(select(Submission).where(Submission.attempt_id == att2.id))
    s2 = res2.scalar_one()
    assert s2.submission_type == "programming"
    assert "def solve():" in s2.content

    # 3. Legacy compatibility: student who typed "{}" on MCQ with no options -> must not crash, treated as text
    a_mcq_no_opts = Assignment(id=403, course_id=course.id, title="A3", type="mcq", status="published", max_marks=100.0, description="What is X?")
    att3 = ExamAttempt(id=503, assignment_id=a_mcq_no_opts.id, student_id=student.id, started_at=now, duration_minutes=60,
                       current_answers="{}")
    phase1_db.add_all([a_mcq_no_opts, att3])
    await phase1_db.flush()

    await auto_close_attempt(att3, a_mcq_no_opts, phase1_db, reason="time_expired")
    res3 = await phase1_db.execute(select(Submission).where(Submission.attempt_id == att3.id))
    s3 = res3.scalar_one()
    assert s3.submission_type == "text"
    assert s3.content == "{}"


@pytest.mark.asyncio
async def test_publish_assignment_blocks_mcq_without_options(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.2: Block publishing an mcq/quiz assignment that has no parsed options (clear 422 message)."""
    course = phase1_env["course"]
    prof = phase1_env["prof"]

    mcq_empty = Assignment(
        id=404,
        course_id=course.id,
        title="Empty MCQ",
        type="mcq",
        status="draft",
        max_marks=100.0,
        description="Question without any choices A) B) C)",
    )
    # Add rubric so rubric check passes
    rubric = Rubric(id=404, assignment_id=mcq_empty.id)
    phase1_db.add_all([mcq_empty, rubric])
    await phase1_db.flush()

    for i in range(3):
        crit = RubricCriterion(id=4040 + i, rubric_id=rubric.id, name=f"C{i}", weight=33.333 if i < 2 else 33.334)
        phase1_db.add(crit)
        await phase1_db.flush()
        level_names = ["excellent", "satisfactory", "developing", "insufficient"]
        for j in range(4):
            lvl = RubricLevel(criterion_id=crit.id, level=level_names[j], description=f"desc {j}")
            phase1_db.add(lvl)
    await phase1_db.flush()

    svc = AssignmentService(phase1_db)
    with pytest.raises(ValueError) as exc:
        await svc.publish_assignment(mcq_empty.id)
    assert "options" in str(exc.value).lower()


@pytest.mark.asyncio
async def test_atomic_submit_exam_persists_submission_and_closes_attempt(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.7: Submit is ONE atomic server call saving submission (with attempt_id) and closing attempt. Idempotent."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    course = phase1_env["course"]
    now = datetime.now(timezone.utc)

    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now,
        duration_minutes=60,
        last_heartbeat_at=now,
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    req = SubmitExamRequest(submission_type="text", content="Final exam answer text")
    res1 = await submit_exam(course_id=course.id, assignment_id=assignment.id, user=student, db=phase1_db, body=req)
    assert res1["attempt_id"] == attempt.id
    assert attempt.submitted_at is not None

    sub_res = await phase1_db.execute(select(Submission).where(Submission.attempt_id == attempt.id))
    sub = sub_res.scalar_one()
    assert sub.content == "Final exam answer text"
    assert sub.attempt_id == attempt.id

    # Idempotent second submit call succeeds without error
    res2 = await submit_exam(course_id=course.id, assignment_id=assignment.id, user=student, db=phase1_db, body=req)
    assert res2["attempt_id"] == attempt.id
    assert res2["submission_id"] == sub.id


@pytest.mark.asyncio
async def test_retake_granted_allows_new_attempt_and_creates_new_submission(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.11 & 1.12: retake_granted allows new attempt and creates a new submission without overwriting earlier."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    course = phase1_env["course"]
    now = datetime.now(timezone.utc)

    # 1. Attempt 1 completed
    att1 = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now - timedelta(minutes=70),
        submitted_at=now - timedelta(minutes=10),
        duration_minutes=60,
        attempt_number=1,
    )
    phase1_db.add(att1)
    await phase1_db.flush()

    sub1 = Submission(
        assignment_id=assignment.id,
        student_id=student.id,
        attempt_id=att1.id,
        submission_type="text",
        content="Attempt 1 answer",
        status="graded",
        score=75.0,
    )
    phase1_db.add(sub1)
    await phase1_db.flush()

    # Without retake_granted, starting exam raises 400 (max_attempts reached)
    with pytest.raises(HTTPException) as exc:
        await start_exam(course_id=course.id, assignment_id=assignment.id, user=student, db=phase1_db)
    assert exc.value.status_code == 400

    # 2. Instructor grants retake
    att1.retake_granted = True
    await phase1_db.flush()

    # Now starting exam succeeds and creates Attempt 2
    res_start = await start_exam(course_id=course.id, assignment_id=assignment.id, user=student, db=phase1_db)
    assert res_start["attempt_id"] != att1.id

    # Submit Attempt 2
    req2 = SubmitExamRequest(submission_type="text", content="Attempt 2 answer")
    await submit_exam(course_id=course.id, assignment_id=assignment.id, user=student, db=phase1_db, body=req2)

    # Verify both submissions exist independently and sub1 was not overwritten
    await phase1_db.refresh(sub1)
    assert sub1.content == "Attempt 1 answer"
    assert sub1.score == 75.0

    all_subs_res = await phase1_db.execute(select(Submission).where(Submission.assignment_id == assignment.id, Submission.student_id == student.id))
    all_subs = all_subs_res.scalars().all()
    assert len(all_subs) == 2


@pytest.mark.asyncio
async def test_pre_start_question_exposure_hidden_for_proctored_assignment(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.15: Student GET assignment before start has no questions; after start has them. Instructors always see."""
    student = phase1_env["student"]
    prof = phase1_env["prof"]
    course = phase1_env["course"]

    proc_assignment = Assignment(
        id=405,
        course_id=course.id,
        title="Midterm Exam",
        type="text",
        status="published",
        max_marks=100.0,
        time_limit_minutes=60,
        description="Secret exam questions 1 to 5",
    )
    phase1_db.add(proc_assignment)
    await phase1_db.flush()

    from app.main import app
    from app.db.base import get_db
    from app.core.security import create_access_token
    import httpx

    student_token = create_access_token(user_id=student.id, role="student")
    prof_token = create_access_token(user_id=prof.id, role="professor")

    app.dependency_overrides[get_db] = lambda: phase1_db
    transport = httpx.ASGITransport(app=app)
    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            # 1. Student GET before start -> description must be None
            res_student_pre = await client.get(
                f"/api/v1/courses/{course.id}/assignments/{proc_assignment.id}",
                headers={"Authorization": f"Bearer {student_token}"},
            )
            assert res_student_pre.status_code == 200
            assert res_student_pre.json()["description"] is None
            assert res_student_pre.json()["is_proctored"] is True

            # 2. Prof GET -> description always visible
            res_prof = await client.get(
                f"/api/v1/courses/{course.id}/assignments/{proc_assignment.id}",
                headers={"Authorization": f"Bearer {prof_token}"},
            )
            assert res_prof.status_code == 200
            assert res_prof.json()["description"] == "Secret exam questions 1 to 5"

            # 3. Student starts exam
            start_res = await client.post(
                f"/api/v1/courses/{course.id}/assignments/{proc_assignment.id}/exam/start",
                headers={"Authorization": f"Bearer {student_token}"},
            )
            assert start_res.status_code == 200

            # 4. Student GET after start -> description is now visible!
            res_student_post = await client.get(
                f"/api/v1/courses/{course.id}/assignments/{proc_assignment.id}",
                headers={"Authorization": f"Bearer {student_token}"},
            )
            assert res_student_post.status_code == 200
            assert res_student_post.json()["description"] == "Secret exam questions 1 to 5"
    finally:
        app.dependency_overrides.pop(get_db, None)


@pytest.mark.asyncio
async def test_exam_answers_and_content_capped_at_200kb(phase1_db: AsyncSession, phase1_env: dict):
    """Item 1.17: Heartbeat answers and Submission content exceeding 200KB are rejected with 422."""
    student = phase1_env["student"]
    assignment = phase1_env["assignment"]
    course = phase1_env["course"]
    now = datetime.now(timezone.utc)

    attempt = ExamAttempt(
        assignment_id=assignment.id,
        student_id=student.id,
        started_at=now,
        duration_minutes=60,
        last_heartbeat_at=now,
    )
    phase1_db.add(attempt)
    await phase1_db.flush()

    from app.main import app
    from app.db.base import get_db
    from app.core.security import create_access_token
    import httpx

    token = create_access_token(user_id=student.id, role="student")
    app.dependency_overrides[get_db] = lambda: phase1_db
    transport = httpx.ASGITransport(app=app)
    huge_payload = "A" * 250_000

    try:
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
            # Heartbeat answers > 200 KB
            res_hb = await client.post(
                f"/api/v1/attempts/{attempt.id}/heartbeat",
                json={"answers": huge_payload},
                headers={"Authorization": f"Bearer {token}"},
            )
            assert res_hb.status_code == 422

            # Submission content > 200 KB
            res_sub = await client.post(
                f"/api/v1/courses/{course.id}/assignments/{assignment.id}/submissions",
                json={"submission_type": "text", "content": huge_payload},
                headers={"Authorization": f"Bearer {token}"},
            )
            assert res_sub.status_code == 422
    finally:
        app.dependency_overrides.pop(get_db, None)

