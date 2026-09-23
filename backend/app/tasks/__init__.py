"""ProfessorOS – Celery app and background tasks across 6 designated queues."""

from celery import Celery
from app.config.settings import get_settings

settings = get_settings()

celery_app = Celery(
    "professor_os",
    broker=settings.REDIS_URL,
    backend=settings.REDIS_URL,
)

celery_app.conf.update(
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
    print(f"🔄 [CELERY:reporting_queue] Refreshing analytics for course {course_id}")
    return {"status": "completed", "course_id": course_id}


# ── Import Tasks so Celery Auto-Registers Them ────────────────────────
from app.services.document_ingestion import ingest_course_document_task  # noqa: E402, F401
from app.services.question_generation import generate_questions_task    # noqa: E402, F401
from app.services.grading_pipeline import grade_submission_task        # noqa: E402, F401
from app.services.clo_attainment import calculate_clo_attainment_task   # noqa: E402, F401
