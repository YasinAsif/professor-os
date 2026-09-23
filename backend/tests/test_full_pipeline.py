"""ProfessorOS – Full End-to-End OBE & AI Assessment Pipeline Test Suite.

Validates the complete lifecycle:
  1. Professor & Student Authentication and RBAC Isolation
  2. Question Bank Querying, Filtering, Approval, and Updating
  3. Linking Questions, Cognitive Quality Gate Analysis & Quiz Publishing
  4. Student Attempt Lifecycle (Sanitized questions, Answer Submission, Auto-Scoring)
  5. OBE CLO Attainment Analytics and HEC Accreditation PDF Dossier Generation
"""

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from app.main import app

COURSE_ID = 4
QUIZ_ID = "8e3a7888-347a-4784-a1d0-71b2c5ec2f66"
PROFESSOR_EMAIL = "dr.tariq@professoros.edu.pk"
PROFESSOR_PASSWORD = "professor123"
STUDENT_EMAIL = "student1@professoros.edu.pk"
STUDENT_PASSWORD = "student123"


@pytest_asyncio.fixture(autouse=True)
async def setup_test_engine():
    from app.db.base import engine
    from sqlalchemy import text
    try:
        async with engine.begin() as conn:
            await conn.execute(text("DELETE FROM student_quiz_attempts WHERE student_id = 22"))
    except Exception:
        pass
    await engine.dispose()
    yield
    await engine.dispose()


@pytest_asyncio.fixture
async def client():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.mark.asyncio
async def test_complete_obe_assessment_pipeline(client: AsyncClient):
    """Executes the full assessment workflow sequentially to prevent asyncpg event loop fragmentation."""
    # Obtain tokens
    res_p = await client.post("/api/v1/auth/login", json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD})
    assert res_p.status_code == 200, f"Professor login failed: {res_p.text}"
    professor_token = res_p.json()["access_token"]

    res_s = await client.post("/api/v1/auth/login", json={"email": STUDENT_EMAIL, "password": STUDENT_PASSWORD})
    assert res_s.status_code == 200, f"Student login failed: {res_s.text}"
    student_token = res_s.json()["access_token"]

    prof_headers = {"Authorization": f"Bearer {professor_token}"}
    student_headers = {"Authorization": f"Bearer {student_token}"}

    # ─────────────────────────────────────────────────────────────
    # Stage 1: Role-Based Access Control (RBAC)
    # ─────────────────────────────────────────────────────────────
    # Student cannot publish quiz
    res_pub_forbidden = await client.post(
        f"/api/v1/quizzes/{QUIZ_ID}/publish",
        headers=student_headers,
    )
    assert res_pub_forbidden.status_code == 403, "Student must receive 403 on publish endpoint"

    # Professor can access question bank
    res_bank = await client.get(f"/api/v1/courses/{COURSE_ID}/question-bank", headers=prof_headers)
    assert res_bank.status_code == 200, f"Professor question bank fetch failed: {res_bank.text}"
    all_questions = res_bank.json()
    assert len(all_questions) > 0, "Question bank should not be empty"

    # ─────────────────────────────────────────────────────────────
    # Stage 2: Question Bank Filtering, Approval & Modification
    # ─────────────────────────────────────────────────────────────
    sample_q = all_questions[0]
    q_id = sample_q["question_id"]

    # Filter by Bloom Level
    bloom_lvl = sample_q["bloom_level"]
    res_bloom = await client.get(
        f"/api/v1/courses/{COURSE_ID}/question-bank?bloom_level={bloom_lvl}",
        headers=prof_headers,
    )
    assert res_bloom.status_code == 200
    assert all(q["bloom_level"] == bloom_lvl for q in res_bloom.json())

    # Approve question
    res_app = await client.post(f"/api/v1/question-bank/{q_id}/approve", headers=prof_headers)
    assert res_app.status_code == 200
    assert res_app.json()["status"] == "APPROVED"

    # Update question
    res_patch = await client.patch(
        f"/api/v1/question-bank/{q_id}",
        headers=prof_headers,
        json={"difficulty": 0.75},
    )
    assert res_patch.status_code == 200
    assert res_patch.json()["difficulty"] == 0.75

    # ─────────────────────────────────────────────────────────────
    # Stage 3: Question Linking & Bloom Cognitive Gate Check
    # ─────────────────────────────────────────────────────────────
    res_approved = await client.get(
        f"/api/v1/courses/{COURSE_ID}/question-bank?status=APPROVED",
        headers=prof_headers,
    )
    assert res_approved.status_code == 200
    approved_list = res_approved.json()
    assert len(approved_list) >= 3

    selected_ids = [q["question_id"] for q in approved_list[:4]]

    # Link selected questions to quiz
    res_link = await client.post(
        f"/api/v1/quizzes/{QUIZ_ID}/questions",
        headers=prof_headers,
        json={"question_ids": selected_ids, "points_per_question": 2.0},
    )
    assert res_link.status_code == 200
    link_info = res_link.json()
    assert "bloom_distribution" in link_info

    # Audit Bloom Gate
    res_gate = await client.get(f"/api/v1/quizzes/{QUIZ_ID}/validate-blooms", headers=prof_headers)
    assert res_gate.status_code == 200
    gate_data = res_gate.json()
    assert "is_approved" in gate_data
    assert "bloom_distribution" in gate_data
    assert "C1" in gate_data["bloom_distribution"]

    # Publish assessment
    res_pub = await client.post(f"/api/v1/quizzes/{QUIZ_ID}/publish", headers=prof_headers)
    if gate_data["is_approved"]:
        assert res_pub.status_code == 200
        assert res_pub.json()["is_published"] is True
    else:
        assert res_pub.status_code == 400
        assert "violations" in res_pub.json()["detail"]

    # ─────────────────────────────────────────────────────────────
    # Stage 4: Student Attempt, Sanitization & Auto-Scoring
    # ─────────────────────────────────────────────────────────────
    res_start = await client.post(
        f"/api/v1/quizzes/{QUIZ_ID}/attempts/start",
        headers=student_headers,
        json={},
    )
    assert res_start.status_code == 200
    start_data = res_start.json()
    attempt_id = start_data["attempt_id"]
    questions = start_data["questions"]
    assert len(questions) > 0

    # Ensure sensitive fields are stripped
    for q in questions:
        assert "correct_answer" not in q
        assert "distractor_rationale" not in q

    # Prepare answers
    answers = []
    for q in questions:
        opt_choice = "A"
        if isinstance(q.get("options"), list) and len(q["options"]) > 0:
            item = q["options"][0]
            opt_choice = item if isinstance(item, str) else item.get("label", "A")
        answers.append({
            "question_id": q["question_id"],
            "selected_option": opt_choice,
            "text_answer": None,
        })

    # Submit attempt
    res_submit = await client.post(
        f"/api/v1/attempts/{attempt_id}/submit",
        headers=student_headers,
        json={"answers": answers},
    )
    assert res_submit.status_code == 200
    submit_res = res_submit.json()
    assert "auto_score" in submit_res
    assert "total_possible" in submit_res
    assert submit_res["percentage"] >= 0.0

    # Fetch result breakdown
    res_res = await client.get(f"/api/v1/attempts/{attempt_id}/result", headers=student_headers)
    assert res_res.status_code == 200
    result_breakdown = res_res.json()
    assert result_breakdown["attempt_id"] == attempt_id
    assert len(result_breakdown["breakdown"]) == len(questions)

    # ─────────────────────────────────────────────────────────────
    # Stage 5: CLO Attainment & HEC Accreditation PDF Dossier
    # ─────────────────────────────────────────────────────────────
    res_attain = await client.get(
        f"/api/v1/courses/{COURSE_ID}/clo-attainment?semester=Spring-2026",
        headers=prof_headers,
    )
    assert res_attain.status_code == 200
    attain_data = res_attain.json()
    assert attain_data["course_id"] == COURSE_ID
    assert "overall_obe_compliance_status" in attain_data
    assert "clos" in attain_data
    assert len(attain_data["clos"]) > 0

    # Export HEC Dossier PDF
    res_pdf = await client.get(
        f"/api/v1/courses/{COURSE_ID}/hec-dossier?semester=Spring-2026",
        headers=prof_headers,
    )
    assert res_pdf.status_code == 200
    assert res_pdf.headers.get("content-type") == "application/pdf"
    assert res_pdf.content.startswith(b"%PDF"), "Response is valid binary PDF"
    assert len(res_pdf.content) > 1000
