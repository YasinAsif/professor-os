"""Phase 4 Deploy, Background Jobs, and DB Tests."""

import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.services import exam_monitor


@pytest.mark.asyncio
async def test_exam_monitor_daemon_recovers_after_exception(monkeypatch):
    """4.1: A cycle raising an unexpected exception must not terminate the supervisor loop."""
    fail_then_succeed = [RuntimeError("Simulated DB connection failure"), {"active_scanned": 1, "closed_count": 0, "flagged_offline": 0}]
    cycles_called = 0

    async def mock_monitor(session, now=None):
        nonlocal cycles_called
        cycles_called += 1
        if fail_then_succeed:
            val = fail_then_succeed.pop(0)
            if isinstance(val, Exception):
                raise val
            return val
        return {"active_scanned": 0, "closed_count": 0, "flagged_offline": 0}

    monkeypatch.setattr(exam_monitor, "monitor_active_exam_attempts", mock_monitor)

    # Launch daemon in a background task with very fast sleep
    daemon_task = asyncio.create_task(exam_monitor.run_exam_monitor_daemon(interval_seconds=0.01))
    await asyncio.sleep(0.08)
    daemon_task.cancel()
    try:
        await daemon_task
    except asyncio.CancelledError:
        pass

    assert cycles_called >= 2, f"Daemon should have recovered from exception and completed multiple cycles, got {cycles_called}"
    status = exam_monitor.get_monitor_status()
    assert "last_run_at" in status
    assert "last_stats" in status


@pytest.mark.asyncio
async def test_ready_and_monitor_health_endpoints():
    """4.1: /ready and /health/monitor report system and monitor status."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp_mon = await client.get("/health/monitor")
        assert resp_mon.status_code == 200
        data_mon = resp_mon.json()
        assert "status" in data_mon
        assert "last_run_at" in data_mon
        assert "last_stats" in data_mon

        resp_ready = await client.get("/ready")
        assert resp_ready.status_code in {200, 503}
        data_ready = resp_ready.json()
        assert "service" in data_ready
        assert "monitor" in data_ready


@pytest.mark.asyncio
async def test_spa_catchall_returns_404_json_for_api_paths():
    """4.5: SPA catch-all must return JSON 404 for nonexistent /api/* paths, never index.html."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/v1/non_existent_route_12345")
        assert resp.status_code == 404
        assert resp.headers.get("content-type", "").startswith("application/json")
        data = resp.json()
        assert "detail" in data


@pytest.mark.pg
@pytest.mark.asyncio
async def test_postgres_partial_unique_index_and_concurrency():
    """4.2: Opt-in Postgres test for partial unique index preventing double active attempts."""
    import os
    from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
    from sqlalchemy.exc import IntegrityError
    from sqlalchemy import select
    from app.models.exam_attempt import ExamAttempt

    pg_url = os.getenv("TEST_PG_URL")
    if not pg_url:
        pytest.skip("TEST_PG_URL environment variable not set; skipping live Postgres test.")

    engine = create_async_engine(pg_url)
    session_factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

    async with session_factory() as session:
        # Create first active attempt (submitted_at is NULL)
        att1 = ExamAttempt(assignment_id=9999, student_id=8888, submitted_at=None)
        session.add(att1)
        await session.commit()

        # Attempt to insert a second active attempt for the same assignment and student
        att2 = ExamAttempt(assignment_id=9999, student_id=8888, submitted_at=None)
        session.add(att2)
        with pytest.raises(IntegrityError):
            await session.commit()
        await session.rollback()

        # Clean up test row
        del_res = await session.execute(
            select(ExamAttempt).where(ExamAttempt.assignment_id == 9999, ExamAttempt.student_id == 8888)
        )
        for row in del_res.scalars().all():
            await session.delete(row)
        await session.commit()


def test_email_templates_html_escape_user_input():
    """4.6: Verify user-provided inputs in emails are properly HTML-escaped."""
    from app.services.email_service import verification_email_html, rejection_email_html

    html_v = verification_email_html("<script>alert('xss')</script>", "http://example.com/verify")
    assert "<script>" not in html_v
    assert "&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;" in html_v

    html_r = rejection_email_html("Alice <img src=x onerror=alert(1)>", "student", "<b>Disqualified</b>")
    assert "<img" not in html_r
    assert "&lt;img src=x onerror=alert(1)&gt;" in html_r
    assert "&lt;b&gt;Disqualified&lt;/b&gt;" in html_r


def test_email_empty_smtp_credentials_does_not_crash(monkeypatch):
    """4.6: Empty SMTP credentials return False and log a warning without crashing."""
    from types import SimpleNamespace
    from app.services import email_service

    dummy_settings = SimpleNamespace(
        SMTP_USER="",
        SMTP_PASSWORD="",
        SMTP_HOST="smtp.gmail.com",
        EMAIL_FROM="noreply@professoros.com",
    )
    monkeypatch.setattr(email_service, "get_settings", lambda: dummy_settings)

    # Should not raise any exception when called with missing credentials
    success = email_service._try_smtp("test@example.com", "Test Subject", "<p>Test Body</p>")
    assert success is False
