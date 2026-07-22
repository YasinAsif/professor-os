"""ProfessorOS – Celery app and background tasks."""

from celery import Celery
from app.core.config import get_settings

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
)


@celery_app.task(name="refresh_analytics")
def refresh_analytics_task(course_id: int):
    """Background task to recompute analytics for a course.
    This runs in a sync Celery worker, so we use sync DB calls here."""
    print(f"🔄 [CELERY] Refreshing analytics for course {course_id}")
    # In production, this would:
    # 1. Query all graded submissions for the course
    # 2. Compute statistics
    # 3. Save AnalyticsSnapshot
    # 4. Detect at-risk students
    # 5. Invalidate Redis cache
    # For now, this is a placeholder that will be wired when Submissions module lands.
    return {"status": "completed", "course_id": course_id}
