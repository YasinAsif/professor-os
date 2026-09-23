"""ProfessorOS – Celery application entrypoint.

Exposes celery_app instance for CLI:
  celery -A app.celery_app worker --loglevel=info -Q grading_high,grading_normal,xai_queue,rag_queue,question_gen_queue,reporting_queue
"""

from app.tasks import celery_app

__all__ = ["celery_app"]
