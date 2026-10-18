from pathlib import Path
from types import SimpleNamespace

import pytest


def test_latest_migration_creates_quiz_question_associations():
    migration = (
        Path(__file__).parents[1]
        / "alembic"
        / "versions"
        / "20261014_002_add_quiz_questions.py"
    ).read_text()

    assert '"quiz_questions"' in migration


def test_compose_workers_use_the_real_celery_entrypoint():
    compose = (Path(__file__).parents[2] / "docker-compose.yml").read_text()

    assert "celery -A app.celery_app worker" in compose
    assert "celery -A app.tasks.celery_app worker" not in compose


def test_celery_registers_the_expected_background_tasks():
    from app.celery_app import celery_app

    registered = celery_app.tasks
    assert "refresh_analytics" in registered
    assert "grade_submission_task" in registered
    assert "ingest_course_document" in registered
    assert "generate_questions_task" in registered
    assert "calculate_clo_attainment_task" in registered


@pytest.mark.asyncio
async def test_readiness_checks_database_connectivity(monkeypatch):
    from app import main

    class Connection:
        async def execute(self, statement):
            assert "SELECT 1" in str(statement)

    class Context:
        async def __aenter__(self):
            return Connection()

        async def __aexit__(self, *args):
            return False

    monkeypatch.setattr(main, "engine", SimpleNamespace(begin=lambda: Context()))
    assert (await main.ready())["status"] == "ready"
