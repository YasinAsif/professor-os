import pytest
import httpx
from unittest.mock import AsyncMock, patch, MagicMock
from app.main import app
from app.core.security import create_access_token
from app.models.user import User, UserRole
from app.models.course import Course, Enrollment


@pytest.mark.asyncio
async def test_course_chat_endpoint_access_and_retrieval():
    """Verify M-09 chat endpoint enforces enrollment access check and returns formatted response."""
    # Test unauthorized access (user not enrolled or invalid token)
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. Unauthenticated request -> 401
        res = await client.post("/api/v1/courses/4/chat", json={"message": "What is a process?"})
        assert res.status_code == 401

        # 2. Authenticated enrolled student -> 200 with vector context
        token = create_access_token(user_id=22, role="student")
        headers = {"Authorization": f"Bearer {token}"}

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
                headers=headers,
            )
            assert chat_res.status_code == 200
            body = chat_res.json()
            assert body["intent"] == "COURSE_QA"
            assert len(body["sources"]) == 1
            assert body["sources"][0]["source"] == "Lecture_04.md"
            assert "Mutual Exclusion" in body["response"]
