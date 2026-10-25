import io
import pytest
from httpx import AsyncClient, ASGITransport
from unittest.mock import patch
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.main import app
from app.core.security import create_access_token
from app.models.user import User
from app.models.course import Course, Enrollment, CLO
from app.models.assignment import Assignment
from app.db.base import get_db


@pytest.mark.asyncio
async def test_course_chat_endpoint_access_and_retrieval():
    """Item 6: Real course access check in course chat (only mock LLM and vector search)."""
    sqlite_engine = create_async_engine("sqlite+aiosqlite:///:memory:")
    async with sqlite_engine.begin() as conn:
        await conn.run_sync(User.__table__.create, checkfirst=True)
        await conn.run_sync(Course.__table__.create, checkfirst=True)
        await conn.run_sync(Enrollment.__table__.create, checkfirst=True)
        await conn.run_sync(CLO.__table__.create, checkfirst=True)
        await conn.run_sync(Assignment.__table__.create, checkfirst=True)

    session_factory = async_sessionmaker(sqlite_engine, expire_on_commit=False, class_=AsyncSession)

    prof = User(id=1, email="prof@test.com", full_name="Professor", hashed_password="pw", role="professor", is_verified=True, is_active=True)
    student_enrolled = User(id=22, email="enrolled@test.com", full_name="Enrolled Student", hashed_password="pw", role="student", is_verified=True, is_active=True)
    student_outsider = User(id=33, email="outsider@test.com", full_name="Outsider Student", hashed_password="pw", role="student", is_verified=True, is_active=True)
    course = Course(id=4, title="Operating Systems", code="CS301", semester="Fall 2026", professor_id=prof.id)
    enrollment = Enrollment(course_id=course.id, user_id=student_enrolled.id, role="student")

    async with session_factory() as session:
        session.add_all([prof, student_enrolled, student_outsider, course, enrollment])
        await session.commit()

    async def override_get_db():
        async with session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # 1. Unauthenticated request -> 401
            res_unauth = await client.post("/api/v1/courses/4/chat", json={"message": "What is a process?"})
            assert res_unauth.status_code == 401, f"Expected 401 for unauthenticated chat, got {res_unauth.status_code}"

            # 2. Unenrolled student -> 403 Forbidden via REAL access check
            outsider_token = create_access_token(user_id=student_outsider.id, role="student")
            res_outsider = await client.post(
                "/api/v1/courses/4/chat",
                json={"message": "Can I read course material?"},
                headers={"Authorization": f"Bearer {outsider_token}"},
            )
            assert res_outsider.status_code == 403, f"Expected 403 for unenrolled student, got {res_outsider.status_code}"

            # 3. Enrolled student -> passes real access check, returns 200 with mocked LLM/search
            enrolled_token = create_access_token(user_id=student_enrolled.id, role="student")
            with patch("app.services.document_ingestion.DoclingPipeline.search") as mock_search, \
                 patch("app.config.llm_config.LLMClient.acomplete") as mock_acomplete:

                mock_search.return_value = [
                    {
                        "chunk_id": 2,
                        "text": "The four Coffman conditions are mutual exclusion, hold and wait, no preemption, circular wait.",
                        "source_file": "Lecture_04.md",
                        "score": 0.89,
                    }
                ]
                mock_acomplete.return_value = "The four conditions for deadlock are: 1. Mutual Exclusion, 2. Hold and Wait, 3. No Preemption, 4. Circular Wait."

                chat_res = await client.post(
                    "/api/v1/courses/4/chat",
                    json={"message": "What are Coffman conditions?", "session_id": "test-sess"},
                    headers={"Authorization": f"Bearer {enrolled_token}"},
                )
                assert chat_res.status_code == 200, f"Expected 200, got {chat_res.status_code}: {chat_res.text}"
                body = chat_res.json()
                assert body["intent"] == "COURSE_QA"
                assert len(body["sources"]) == 1
                assert body["sources"][0]["source"] == "Lecture_04.md"
                assert "Mutual Exclusion" in body["response"]

                # 4. Multi-turn conversation with history
                chat_res2 = await client.post(
                    "/api/v1/courses/4/chat",
                    json={
                        "message": "Can you give an example of the first condition?",
                        "session_id": "test-sess",
                        "history": [
                            {"role": "user", "content": "What are Coffman conditions?"},
                            {"role": "assistant", "content": "The four conditions are Mutual Exclusion, Hold and Wait, No Preemption, Circular Wait."},
                        ],
                    },
                    headers={"Authorization": f"Bearer {enrolled_token}"},
                )
                assert chat_res2.status_code == 200
                assert mock_acomplete.call_count >= 2
                last_call_messages = mock_acomplete.call_args.kwargs["messages"]
                roles = [m["role"] for m in last_call_messages]
                assert "assistant" in roles, "Expected assistant turn in multi-turn history" 
    finally:
        app.dependency_overrides.pop(get_db, None)
        await sqlite_engine.dispose()
