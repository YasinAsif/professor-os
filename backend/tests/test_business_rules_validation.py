"""Comprehensive tests for ProfessorOS business rules and form validations.

Tests:
1. Teacher cannot create a course; only Admin creates and assigns.
2. Duplicate (master_course_id, professor_id, section) assignment blocked.
3. Course isolation: Two teachers teaching the same course in different sections cannot see each other's data.
4. Midterm: marks fixed at 20, max 4 main questions, short/long only, NO MCQs. Question marks must sum to 20.
5. Final: marks fixed at 50, max 5 main questions, short/long only, NO MCQs. Question marks must sum to 50.
6. Main questions with sub-parts: max question count enforced on main questions only.
7. Max 1 active Midterm and 1 active Final per offering.
8. Answer key validation: MCQ must have options and correct option; short/long questions and sub-parts must have non-empty reference answers.
9. Weightage rules: Internal capped at 30 marks; on violation block save with "Internal assessment weightage cannot exceed 30 marks."
10. Project/Presentation: No question builder and no MCQs, file upload only.
"""

import json
import pytest
from datetime import datetime, timezone
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.db.base import Base
from app.models.user import User, UserRole
from app.models.course import Course, MasterCourse, CLO, Enrollment
from app.models.assignment import Assignment, AssignmentStatus, assignment_clo_table, assignment_ta_table
from app.models.rubric import Rubric, RubricCriterion, RubricLevel
from app.schemas.course import CourseCreate
from app.schemas.assignment import AssignmentCreate
from app.services.course_service import CourseService
from app.services.assignment_service import AssignmentService, validate_assessment_rules


@pytest.fixture
async def rules_db():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    tables = [
        User.__table__,
        MasterCourse.__table__,
        Course.__table__,
        Enrollment.__table__,
        CLO.__table__,
        assignment_clo_table,
        assignment_ta_table,
        Assignment.__table__,
        Rubric.__table__,
        RubricCriterion.__table__,
        RubricLevel.__table__,
    ]
    async with engine.begin() as conn:
        for t in tables:
            await conn.run_sync(t.create, checkfirst=True)

    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)
    async with session_factory() as session:
        # Seed Admin
        admin = User(
            id=1, email="admin@professoros.edu.pk", full_name="System Admin",
            hashed_password="hash", role=UserRole.ADMIN.value, is_active=True, is_verified=True, is_approved=True
        )
        # Seed Professor 1
        prof1 = User(
            id=2, email="prof1@professoros.edu.pk", full_name="Dr. Alan Turing",
            hashed_password="hash", role=UserRole.PROFESSOR.value, is_active=True, is_verified=True, is_approved=True
        )
        # Seed Professor 2
        prof2 = User(
            id=3, email="prof2@professoros.edu.pk", full_name="Dr. Ada Lovelace",
            hashed_password="hash", role=UserRole.PROFESSOR.value, is_active=True, is_verified=True, is_approved=True
        )
        # Seed Master Course
        mc = MasterCourse(
            id=1, code="SECC1123", title="Programming Fundamentals", department="Computer Science", semester="Semester 1.0"
        )
        session.add_all([admin, prof1, prof2, mc])
        await session.commit()
        yield session

    await engine.dispose()


# ── Requirement A: Courses, Roles & Isolation ────────

@pytest.mark.asyncio
async def test_admin_creates_course_assigned_to_professor(rules_db: AsyncSession):
    svc = CourseService(rules_db)
    data = CourseCreate(
        title="Programming Fundamentals",
        code="SECC1123",
        semester="Fall 2026",
        master_course_id=1,
        section="Section A",
        professor_id=2,
        quiz_weight=15,
        assignment_weight=15,
        midterm_weight=20,
        final_weight=50,
    )
    course = await svc.create_course(data, professor_id=2)
    assert course.id is not None
    assert course.professor_id == 2
    assert course.section == "Section A"
    assert course.master_course_id == 1


@pytest.mark.asyncio
async def test_duplicate_same_teacher_assignment_rejected(rules_db: AsyncSession):
    svc = CourseService(rules_db)
    data = CourseCreate(
        title="Programming Fundamentals",
        code="SECC1123",
        semester="Fall 2026",
        master_course_id=1,
        section="Section A",
        professor_id=2,
        quiz_weight=15,
        assignment_weight=15,
        midterm_weight=20,
        final_weight=50,
    )
    await svc.create_course(data, professor_id=2)

    # Attempting to assign the exact same course offering and section to the same professor again
    with pytest.raises(ValueError, match="already assigned to this professor"):
        await svc.create_course(data, professor_id=2)


@pytest.mark.asyncio
async def test_two_teachers_on_same_course_different_sections_isolated(rules_db: AsyncSession):
    svc = CourseService(rules_db)
    # Teacher 1 teaches Section A
    c1 = await svc.create_course(
        CourseCreate(
            title="Programming Fundamentals", code="SECC1123", semester="Fall 2026",
            master_course_id=1, section="Section A", professor_id=2,
            quiz_weight=15, assignment_weight=15, midterm_weight=20, final_weight=50,
        ),
        professor_id=2,
    )
    # Teacher 2 teaches Section B of the same course
    c2 = await svc.create_course(
        CourseCreate(
            title="Programming Fundamentals", code="SECC1123", semester="Fall 2026",
            master_course_id=1, section="Section B", professor_id=3,
            quiz_weight=15, assignment_weight=15, midterm_weight=20, final_weight=50,
        ),
        professor_id=3,
    )

    prof1 = await rules_db.get(User, 2)
    prof2 = await rules_db.get(User, 3)

    # Prof 1 can access Section A
    assert (await svc.get_course_with_access_check(c1.id, prof1)).id == c1.id
    # Prof 1 cannot access Section B
    with pytest.raises(PermissionError):
        await svc.get_course_with_access_check(c2.id, prof1)

    # Prof 2 can access Section B
    assert (await svc.get_course_with_access_check(c2.id, prof2)).id == c2.id
    # Prof 2 cannot access Section A
    with pytest.raises(PermissionError):
        await svc.get_course_with_access_check(c1.id, prof2)


# ── Requirement B & C: Assessment Builder Rules ───────

def test_midterm_rejects_mcqs():
    with pytest.raises(ValueError, match="MCQs are not allowed in Midterm"):
        validate_assessment_rules(
            category="midterm",
            assignment_type="mcq",
            max_marks=20.0,
            weightage=20.0,
            description=None,
            existing_assignments=[],
        )


def test_final_rejects_mcqs():
    with pytest.raises(ValueError, match="MCQs are not allowed in Final"):
        validate_assessment_rules(
            category="final",
            assignment_type="mcq",
            max_marks=50.0,
            weightage=50.0,
            description=None,
            existing_assignments=[],
        )


def test_midterm_rejects_marks_other_than_20():
    with pytest.raises(ValueError, match="Midterm total marks must be fixed at 20"):
        validate_assessment_rules(
            category="midterm",
            assignment_type="text",
            max_marks=25.0,
            weightage=20.0,
            description=None,
            existing_assignments=[],
        )


def test_final_rejects_marks_other_than_50():
    with pytest.raises(ValueError, match="Final total marks must be fixed at 50"):
        validate_assessment_rules(
            category="final",
            assignment_type="text",
            max_marks=60.0,
            weightage=50.0,
            description=None,
            existing_assignments=[],
        )


def test_midterm_rejects_more_than_4_main_questions():
    questions = [
        {"question": f"Question {i}", "marks": 4.0, "reference_answer": "Valid ref"}
        for i in range(1, 6) # 5 questions
    ]
    payload = json.dumps({"questions": questions})
    with pytest.raises(ValueError, match="Midterm allows a maximum of 4 main questions"):
        validate_assessment_rules(
            category="midterm",
            assignment_type="text",
            max_marks=20.0,
            weightage=20.0,
            description=payload,
            existing_assignments=[],
        )


def test_final_rejects_more_than_5_main_questions():
    questions = [
        {"question": f"Question {i}", "marks": 8.0, "reference_answer": "Valid ref"}
        for i in range(1, 7) # 6 questions
    ]
    payload = json.dumps({"questions": questions})
    with pytest.raises(ValueError, match="Final allows a maximum of 5 main questions"):
        validate_assessment_rules(
            category="final",
            assignment_type="text",
            max_marks=50.0,
            weightage=50.0,
            description=payload,
            existing_assignments=[],
        )


def test_subparts_do_not_count_against_main_question_limit():
    # 3 main questions, each with 2 sub-parts (6 sub-parts total). Max main is 4 -> should pass!
    questions = [
        {
            "question": f"Main Q{i}",
            "parts": [
                {"part": "a", "question": "Part a", "marks": 3.0, "reference_answer": "Ref a"},
                {"part": "b", "question": "Part b", "marks": 3.0 if i < 3 else 4.0, "reference_answer": "Ref b"},
            ]
        }
        for i in range(1, 4)
    ]
    payload = json.dumps({"questions": questions})
    # Sum of parts = 3+3 + 3+3 + 3+4 = 19 (should fail on sum != 20, let's make it exactly 20)
    questions[2]["parts"][1]["marks"] = 5.0 # 6 + 6 + 8 = 20.0
    payload = json.dumps({"questions": questions})

    # Should not raise
    validate_assessment_rules(
        category="midterm",
        assignment_type="text",
        max_marks=20.0,
        weightage=20.0,
        description=payload,
        existing_assignments=[],
    )


def test_midterm_rejects_question_marks_sum_mismatch():
    questions = [
        {"question": "Q1", "marks": 5.0, "reference_answer": "Ref 1"},
        {"question": "Q2", "marks": 5.0, "reference_answer": "Ref 2"},
        {"question": "Q3", "marks": 5.0, "reference_answer": "Ref 3"},
        {"question": "Q4", "marks": 4.0, "reference_answer": "Ref 4"}, # Total 19 != 20
    ]
    payload = json.dumps({"questions": questions})
    with pytest.raises(ValueError, match="must equal 20 marks"):
        validate_assessment_rules(
            category="midterm",
            assignment_type="text",
            max_marks=20.0,
            weightage=20.0,
            description=payload,
            existing_assignments=[],
        )


# ── Requirement C: Answer Key Validation ─────────────

def test_mcq_rejects_missing_correct_option():
    questions = [
        {
            "type": "mcq",
            "question": "What is Python?",
            "options": ["A language", "A snake", "A vehicle", "A mineral"],
            "correct": None,
        }
    ]
    payload = json.dumps({"questions": questions})
    with pytest.raises(ValueError, match="MCQ must have a selected correct option"):
        validate_assessment_rules(
            category="quiz",
            assignment_type="mcq",
            max_marks=10.0,
            weightage=10.0,
            description=payload,
            existing_assignments=[],
        )


def test_short_question_rejects_empty_reference_answer():
    questions = [
        {"question": "Explain inheritance.", "marks": 5.0, "reference_answer": "   "}
    ]
    payload = json.dumps({"questions": questions})
    with pytest.raises(ValueError, match="Question 1 is missing a reference answer"):
        validate_assessment_rules(
            category="quiz",
            assignment_type="text",
            max_marks=5.0,
            weightage=5.0,
            description=payload,
            existing_assignments=[],
        )


def test_subpart_rejects_empty_reference_answer():
    questions = [
        {
            "question": "Main Question",
            "parts": [
                {"part": "a", "question": "Part a", "marks": 2.5, "reference_answer": "Valid"},
                {"part": "b", "question": "Part b", "marks": 2.5, "reference_answer": ""},
            ]
        }
    ]
    payload = json.dumps({"questions": questions})
    with pytest.raises(ValueError, match="Question 1 part \\(b\\) is missing a reference answer"):
        validate_assessment_rules(
            category="quiz",
            assignment_type="text",
            max_marks=5.0,
            weightage=5.0,
            description=payload,
            existing_assignments=[],
        )


# ── Requirement D: Weightage Rules ───────────────────

def test_internal_weightage_cannot_exceed_30_marks():
    # Existing assignment with weightage 20
    existing = [
        Assignment(id=101, course_id=1, title="Quiz 1", category="quiz", weightage=20.0, max_marks=20.0, status="published")
    ]
    # Adding another assignment with weightage 15 (20 + 15 = 35 > 30)
    with pytest.raises(ValueError, match="Internal assessment weightage cannot exceed 30 marks."):
        validate_assessment_rules(
            category="assignment",
            assignment_type="text",
            max_marks=15.0,
            weightage=15.0,
            description=None,
            existing_assignments=existing,
        )


def test_internal_weightage_within_30_marks_allowed():
    existing = [
        Assignment(id=101, course_id=1, title="Quiz 1", category="quiz", weightage=10.0, max_marks=10.0, status="published"),
        Assignment(id=102, course_id=1, title="Assignment 1", category="assignment", weightage=10.0, max_marks=10.0, status="published"),
    ]
    # Adding a project with weightage 10 (10 + 10 + 10 = 30 <= 30) -> should pass!
    validate_assessment_rules(
        category="project",
        assignment_type="file",
        max_marks=10.0,
        weightage=10.0,
        description=None,
        existing_assignments=existing,
    )


# ── Edge Case 3: Only 1 Midterm and 1 Final per offering ──

def test_second_midterm_on_same_course_rejected():
    existing = [
        Assignment(id=201, course_id=1, title="Midterm Examination", category="midterm", weightage=20.0, max_marks=20.0, status="published")
    ]
    with pytest.raises(ValueError, match="already has an active Midterm"):
        validate_assessment_rules(
            category="midterm",
            assignment_type="text",
            max_marks=20.0,
            weightage=20.0,
            description=None,
            existing_assignments=existing,
        )


# ── Requirement B: Project / Presentation Rules ───────

def test_project_rejects_questions():
    payload = json.dumps({"questions": [{"question": "Q1", "reference_answer": "ans"}]})
    with pytest.raises(ValueError, match="Project/Presentation does not allow questions"):
        validate_assessment_rules(
            category="project",
            assignment_type="file",
            max_marks=20.0,
            weightage=20.0,
            description=payload,
            existing_assignments=[],
        )


def test_project_requires_file_type():
    with pytest.raises(ValueError, match="Project/Presentation must be a file upload"):
        validate_assessment_rules(
            category="project",
            assignment_type="mcq",
            max_marks=20.0,
            weightage=20.0,
            description=None,
            existing_assignments=[],
        )
