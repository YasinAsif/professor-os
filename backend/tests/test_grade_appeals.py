import pytest
from httpx import AsyncClient, ASGITransport
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker
from app.db.base import Base, get_db
from app.main import app
from app.models.user import User
from app.models.course import Course, Enrollment, CLO
from app.models.assignment import Assignment, AssignmentType, AssignmentStatus, assignment_clo_table, assignment_ta_table
from app.models.submission import Submission, SubmissionStatus, GradeAppeal
from app.models.exam_attempt import ExamAttempt, ExamViolation, ExamAuditLog
from app.models.rubric import Rubric, RubricCriterion, RubricLevel
from app.core.security import create_access_token


@pytest.fixture
async def appeals_db():
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
        ExamAttempt.__table__,
        ExamViolation.__table__,
        ExamAuditLog.__table__,
        Submission.__table__,
        GradeAppeal.__table__,
    ]
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all, tables=tables)

    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        yield session_factory
    finally:
        await engine.dispose()


@pytest.mark.asyncio
async def test_grade_appeal_full_lifecycle(appeals_db):
    async with appeals_db() as db:
        prof = User(email="prof_appeal@example.com", hashed_password="hash", full_name="Dr. Prof", role="professor", is_active=True, is_verified=True, is_approved=True)
        student1 = User(email="student1_appeal@example.com", hashed_password="hash", full_name="Student One", role="student", is_active=True, is_verified=True, is_approved=True)
        student2 = User(email="student2_appeal@example.com", hashed_password="hash", full_name="Student Two", role="student", is_active=True, is_verified=True, is_approved=True)
        db.add_all([prof, student1, student2])
        await db.flush()

        course = Course(title="Algorithms", code="CS301", semester="Fall 2026", professor_id=prof.id, join_code="ALGO301")
        db.add(course)
        await db.flush()

        db.add_all([
            Enrollment(course_id=course.id, user_id=student1.id, role="student"),
            Enrollment(course_id=course.id, user_id=student2.id, role="student"),
        ])

        assignment = Assignment(
            course_id=course.id,
            title="Recursion Lab",
            type=AssignmentType.TEXT.value,
            status=AssignmentStatus.PUBLISHED.value,
            max_marks=100.0,
        )
        db.add(assignment)
        await db.flush()

        sub1 = Submission(
            assignment_id=assignment.id,
            student_id=student1.id,
            submission_type="text",
            content="My recursion implementation with memoization.",
            status=SubmissionStatus.GRADED.value,
            score=65.0,
            feedback="Initial feedback: lacks pruning.",
        )
        db.add(sub1)
        await db.commit()
        await db.refresh(sub1)

    s1_token = create_access_token(student1.id, "student")
    s2_token = create_access_token(student2.id, "student")
    prof_token = create_access_token(prof.id, "professor")

    async def override_get_db():
        async with appeals_db() as session:
            yield session

    app.dependency_overrides[get_db] = override_get_db

    try:
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # 1. Student 2 cannot appeal student 1's submission
            res = await client.post(
                f"/api/v1/submissions/{sub1.id}/appeal",
                json={"challenged_criterion": "Efficiency & Complexity", "justification": "I did memoize."},
                headers={"Authorization": f"Bearer {s2_token}"},
            )
            assert res.status_code == 403

            # 2. Student 1 submits appeal
            res = await client.post(
                f"/api/v1/submissions/{sub1.id}/appeal",
                json={
                    "challenged_criterion": "Efficiency & Complexity",
                    "justification": "The AI feedback states my solution is exponential, but I implemented memoization reducing complexity.",
                },
                headers={"Authorization": f"Bearer {s1_token}"},
            )
            assert res.status_code == 201
            appeal_data = res.json()
            appeal_id = appeal_data["id"]
            assert appeal_data["status"] == "pending"

            # 3. Duplicate appeal rejected
            res_dup = await client.post(
                f"/api/v1/submissions/{sub1.id}/appeal",
                json={"justification": "Another dispute reason"},
                headers={"Authorization": f"Bearer {s1_token}"},
            )
            assert res_dup.status_code == 400

            # 4. Student reads appeal
            res_get = await client.get(
                f"/api/v1/submissions/{sub1.id}/appeal",
                headers={"Authorization": f"Bearer {s1_token}"},
            )
            assert res_get.status_code == 200
            assert res_get.json()["id"] == appeal_id

            # 5. Professor lists appeals for assignment
            res_list = await client.get(
                f"/api/v1/submissions/assignments/{assignment.id}/appeals",
                headers={"Authorization": f"Bearer {prof_token}"},
            )
            assert res_list.status_code == 200
            appeals_list = res_list.json()
            assert len(appeals_list) == 1
            assert appeals_list[0]["student_name"] == "Student One"

            # 6. Professor resolves appeal and adjusts score
            res_resolve = await client.patch(
                f"/api/v1/submissions/appeals/{appeal_id}",
                json={
                    "status": "accepted",
                    "adjusted_score": 85.0,
                    "professor_feedback": "Verified memoization dictionary in lines 12-18. Score adjusted from 65 to 85.",
                },
                headers={"Authorization": f"Bearer {prof_token}"},
            )
            assert res_resolve.status_code == 200
            assert res_resolve.json()["status"] == "accepted"
            assert res_resolve.json()["adjusted_score"] == 85.0

        # 7. Verify submission score updated in DB
        async with appeals_db() as db:
            updated_sub = await db.get(Submission, sub1.id)
            assert updated_sub.score == 85.0
            assert "Grade Adjusted via Appeal" in updated_sub.feedback
    finally:
        app.dependency_overrides.pop(get_db, None)
