"""ProfessorOS – Celery app and background tasks across 6 designated queues."""

import asyncio

from celery import Celery
from app.config.settings import get_settings
from app.db.base import async_session
from app.services.analytics_service import AnalyticsService

settings = get_settings()

celery_app = Celery(
    "professor_os",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
    task_always_eager=getattr(settings, "CELERY_ALWAYS_EAGER", False),
    task_eager_propagates=getattr(settings, "CELERY_ALWAYS_EAGER", False),
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    # ── Task Routing Across 6 Dedicated Queues ────────────────────────
    task_routes={
        "grade_submission_task": {"queue": settings.QUEUE_GRADING_NORMAL},
        "ingest_course_document": {"queue": settings.QUEUE_RAG},
        "generate_questions_task": {"queue": settings.QUEUE_QUESTION_GEN},
        "calculate_clo_attainment_task": {"queue": settings.QUEUE_REPORTING},
        "refresh_analytics": {"queue": settings.QUEUE_REPORTING},
    },
)


@celery_app.task(name="refresh_analytics", queue=settings.QUEUE_REPORTING)
def refresh_analytics_task(course_id: int):
    """Background task to recompute analytics for a course."""
    async def refresh() -> dict:
        async with async_session() as session:
            snapshot = await AnalyticsService(session).compute_analytics_from_db(course_id)
            await session.commit()
            return {
                "status": "completed",
                "course_id": course_id,
                "total_students": snapshot.total_students if snapshot else 0,
            }

    return asyncio.run(refresh())


@celery_app.task(name="monitor_exams_task", queue=settings.QUEUE_REPORTING)
def monitor_exams_task():
    """Celery background task to auto-close expired exam attempts and flag missing heartbeats."""
    from app.services.exam_monitor import monitor_active_exam_attempts

    async def run_monitor() -> dict:
        async with async_session() as session:
            return await monitor_active_exam_attempts(session)

    return asyncio.run(run_monitor())


# ── Import Tasks so Celery Auto-Registers Them ────────────────────────
from app.services.document_ingestion import ingest_course_document_task  # noqa: E402, F401
from app.services.question_generation import generate_questions_task    # noqa: E402, F401
from app.services.grading_pipeline import grade_submission_task        # noqa: E402, F401
from app.services.clo_attainment import calculate_clo_attainment_task   # noqa: E402, F401
