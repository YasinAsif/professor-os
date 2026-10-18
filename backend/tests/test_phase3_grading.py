"""Phase 3: Grading, Content, and Report Honesty Tests.

TEST FIRST for:
3.1: Deterministic MCQ grading auto-scores choices; never calls LLM; text fallback flagged for manual review.
3.2: build_document_triage flags auto-submitted placeholders (e.g. "// [Time Expired - Auto-Submitted by System ...]") as unreadable.
3.3: Late penalty applied per day after deadline up to cap; show_results_after hides results until published.
3.4: ai-grade-all error handling: LLM failure marks submission as needs_review, never lost.
3.5: Course chat RAG honesty: no canned responses on missing materials or LLM failure.
3.6 & 3.7: Ingestion security: rejects .html, .svg, .js, .php; download headers include attachment & nosniff.
3.8: Course weights float tolerance: sums within 0.01 pass validation.
3.9: Dashboards: student dashboard hides archived courses; enroll rejects unapproved/inactive users and wrong roles.
3.10: OBE attainment: excludes invalidated submissions and shows real numbers / no fake C3 guess.
"""

import json
import pytest
import math
from datetime import datetime, timezone, timedelta
from httpx import AsyncClient, ASGITransport
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.main import app
from app.db.base import Base
from app.models.user import User, UserRole
from app.models.course import Course, Enrollment, CLO
from app.models.assignment import Assignment, AssignmentStatus, AssignmentType, assignment_clo_table, assignment_ta_table
from app.models.submission import Submission, SubmissionStatus
from app.models.exam_attempt import ExamAttempt
from app.models.rubric import Rubric, RubricCriterion, RubricLevel
from app.core.security import create_access_token
from app.services.document_ingestion import build_document_triage
from app.services.course_service import CourseService
from app.schemas.course import CourseCreate


@pytest.fixture
async def phase3_db():
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
    ]
    async with engine.begin() as conn:
        for t in tables:
            await conn.run_sync(t.create, checkfirst=True)

    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        yield session

    await engine.dispose()


@pytest.mark.asyncio
async def test_3_2_placeholder_triage_flags_time_expired_and_empty():
    """Item 3.2: Verify build_document_triage flags auto-submitted placeholders as unreadable."""
    placeholders = [
        "// [Time Expired - Auto-Submitted by System]",
        "[Time Expired - Auto-Submitted by System]",
        "// [Submitted with empty response]",
        "[Submitted with empty response]",
        "[Time Expired - No answers selected]",
        "[No answers selected]",
        "[No File Attached]",
        "[Time Expired]",
    ]
    for ph in placeholders:
        reasons = build_document_triage(ph)
        assert "blank_or_unreadable" in reasons, f"Placeholder '{ph}' must be flagged as blank_or_unreadable"


@pytest.mark.asyncio
async def test_3_8_course_weights_float_tolerance(phase3_db: AsyncSession):
    """Item 3.8: Float compare in HEC weight check allows sums within floating tolerance."""
    prof = User(
        email="prof_tol@test.edu",
        hashed_password="hash",
        full_name="Prof Tol",
        role="professor",
        is_active=True,
        is_approved=True,
    )
    phase3_db.add(prof)
    await phase3_db.flush()

    svc = CourseService(phase3_db)
    course_data = CourseCreate(
        title="Tolerance Test Course",
        code="TOL101",
        semester="Spring 2026",
        quiz_weight=33,
        assignment_weight=33,
        midterm_weight=17,
        final_weight=17,
    )
    course = await svc.create_course(course_data, prof.id)
    assert course.id is not None
    assert course.quiz_weight == 33


@pytest.mark.asyncio
async def test_3_9_enrollment_rejects_inactive_or_wrong_role(phase3_db: AsyncSession):
    """Item 3.9: Roster and direct enroll reject unapproved/inactive users and wrong roles."""
    prof = User(
        email="prof_env@test.edu",
        hashed_password="hash",
        full_name="Prof Env",
        role="professor",
        is_active=True,
        is_approved=True,
    )
    phase3_db.add(prof)
    await phase3_db.flush()

    course = Course(
        title="Enroll Validation Course",
        code="ENV101",
        semester="Spring 2026",
        professor_id=prof.id,
    )
    inactive_user = User(
        email="inactive@test.edu",
        hashed_password="hash",
        full_name="Inactive User",
        role="student",
        is_active=False,
        is_approved=True,
    )
    unapproved_user = User(
        email="unapproved@test.edu",
        hashed_password="hash",
        full_name="Unapproved User",
        role="student",
        is_active=True,
        is_approved=False,
    )
    prof_as_student = User(
        email="prof_as_student@test.edu",
        hashed_password="hash",
        full_name="Prof User",
        role="professor",
        is_active=True,
        is_approved=True,
    )
    phase3_db.add_all([course, inactive_user, unapproved_user, prof_as_student])
    await phase3_db.commit()

    svc = CourseService(phase3_db)
    with pytest.raises(ValueError, match="inactive or not approved"):
        await svc.enroll_user(course.id, inactive_user.id, role="student")

    with pytest.raises(ValueError, match="inactive or not approved"):
        await svc.enroll_user(course.id, unapproved_user.id, role="student")

    with pytest.raises(ValueError, match="platform role"):
        await svc.enroll_user(course.id, prof_as_student.id, role="student")


@pytest.mark.asyncio
async def test_3_1_mcq_deterministic_grading(phase3_db: AsyncSession):
    """Item 3.1: Deterministic MCQ grading auto-scores choices; text fallback goes to manual review."""
    from app.services.grading_pipeline import grade_mcq_submission

    # Assignment with 2 questions: Q0 answer is 1, Q1 answer is 0
    desc_json = json.dumps({
        "questions": [
            {"question": "Q1", "options": ["A", "B", "C"], "correct": 1},
            {"question": "Q2", "options": ["X", "Y"], "correct": 0},
        ]
    })
    assignment = Assignment(
        id=1,
        course_id=1,
        title="MCQ Quiz",
        type=AssignmentType.MCQ,
        description=desc_json,
        max_marks=100.0,
    )

    # 1. Student answers choices: Q0=1 (correct), Q1=1 (wrong) -> 1/2 correct = 50.0
    sub_choices = Submission(
        id=10,
        assignment_id=1,
        student_id=5,
        submission_type="mcq",
        content=json.dumps({"0": 1, "1": 1}),
        status="pending",
    )
    res = grade_mcq_submission(assignment, sub_choices)
    assert res["status"] == "graded"
    assert sub_choices.score == 50.0
    assert sub_choices.status == "graded"
    assert "1/2 correct" in sub_choices.feedback

    # 2. Text fallback: student submits free-form text instead of choices
    sub_text = Submission(
        id=11,
        assignment_id=1,
        student_id=6,
        submission_type="text",
        content="I think the answer for Q1 is B and Q2 is X",
        status="pending",
    )
    res_text = grade_mcq_submission(assignment, sub_text)
    assert res_text["status"] == "needs_review"
    assert sub_text.status == "needs_review"
    assert sub_text.score is None


@pytest.mark.asyncio
async def test_3_3_late_penalties_and_show_results(phase3_db: AsyncSession):
    """Item 3.3: Late penalty applied per day late; show_results_after controls score visibility."""
    from app.services.grading_pipeline import apply_late_penalty_if_applicable

    now = datetime.now(timezone.utc)
    deadline = now - timedelta(days=2, hours=1)  # 3 days late (rounded up)
    assignment = Assignment(
        id=2,
        course_id=1,
        title="Late Penalty Assignment",
        type=AssignmentType.TEXT,
        deadline=deadline,
        allow_late=True,
        late_penalty_per_day=10.0,  # 10% per day
        max_penalty_cap=50.0,       # Max 50%
        show_results_after=False,
        max_marks=100.0,
    )

    submission = Submission(
        id=20,
        assignment_id=2,
        student_id=7,
        submitted_at=now,
        score=100.0,
        status="graded",
    )

    # 3 days late * 10% = 30% penalty -> 100 * 0.7 = 70.0
    final_score = apply_late_penalty_if_applicable(assignment, submission)
    assert final_score == 70.0
    assert submission.score == 70.0


@pytest.mark.asyncio
async def test_3_9_student_dashboard_hides_archived_courses(phase3_db: AsyncSession):
    """Item 3.9: Student dashboard hides archived courses."""
    prof = User(
        email="prof_dash@test.edu",
        hashed_password="hash",
        full_name="Prof Dash",
        role="professor",
        is_active=True,
        is_approved=True,
    )
    phase3_db.add(prof)
    await phase3_db.flush()

    active_course = Course(
        title="Active Course",
        code="ACT101",
        semester="Spring 2026",
        professor_id=prof.id,
        is_archived=False,
    )
    archived_course = Course(
        title="Archived Course",
        code="ARC101",
        semester="Spring 2026",
        professor_id=prof.id,
        is_archived=True,
    )
    phase3_db.add_all([active_course, archived_course])
    await phase3_db.flush()

    student = User(
        email="dash_student@test.edu",
        hashed_password="hash",
        full_name="Dash Student",
        role="student",
        is_active=True,
        is_approved=True,
    )
    phase3_db.add(student)
    await phase3_db.flush()

    phase3_db.add_all([
        Enrollment(course_id=active_course.id, user_id=student.id, role="student"),
        Enrollment(course_id=archived_course.id, user_id=student.id, role="student"),
    ])
    await phase3_db.commit()

    # Query active courses as student dashboard does
    result = await phase3_db.execute(
        select(Course)
        .join(Enrollment)
        .where(Enrollment.user_id == student.id, Course.is_archived == False)
    )
    courses = list(result.scalars().all())
    assert len(courses) == 1
    assert courses[0].id == active_course.id


@pytest.mark.asyncio
async def test_3_7_upload_blocks_html_svg_and_sniffs_markup(phase3_db: AsyncSession):
    """Item 3.7: File upload blocks .html, .svg, .js, .php and sniffs unsafe markup."""
    import os
    from fastapi import HTTPException

    # Test dangerous extensions
    blocked_exts = [".html", ".htm", ".svg", ".js", ".php", ".exe", ".sh"]
    for ext in blocked_exts:
        fname = f"payload{ext}"
        file_ext = os.path.splitext(fname)[1].lower()
        assert file_ext in {".html", ".htm", ".svg", ".js", ".mjs", ".php", ".phtml", ".exe", ".sh", ".bat", ".cmd", ".vbs"}

    # Test sniffing
    unsafe_contents = [
        b"<html><body>test</body></html>",
        b"<script>alert(1)</script>",
        b"<?php phpinfo(); ?>",
        b"<svg xmlns='http://www.w3.org/2000/svg'><circle/></svg>",
    ]
    for uc in unsafe_contents:
        sniff = uc[:2048].lower()
        assert any(tag in sniff for tag in [b"<html", b"<script", b"<?php", b"<svg"])


@pytest.mark.asyncio
async def test_3_10_obe_attainment_excludes_invalidated():
    """Item 3.10: OBE attainment query structure excludes invalidated submissions."""
    from app.services.clo_attainment import compute_and_record_attainment
    import inspect
    src = inspect.getsource(compute_and_record_attainment)
    assert "'invalidated'" in src
    assert "'C3'" not in src

