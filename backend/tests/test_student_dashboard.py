from datetime import datetime, timezone, timedelta
from types import SimpleNamespace

from app.services.student_dashboard_service import build_student_dashboard


def test_dashboard_contains_only_published_assignments_and_real_submission_state():
    now = datetime.now(timezone.utc)
    course = SimpleNamespace(id=1, title="Web Technology", code="SEEC3112", semester="Fall 2026")
    assignments = [
        SimpleNamespace(id=11, course_id=1, title="Lab 1", status="published", deadline=now + timedelta(days=2), max_marks=20),
        SimpleNamespace(id=12, course_id=1, title="Draft", status="draft", deadline=now + timedelta(days=1), max_marks=20),
    ]
    submissions = {
        11: SimpleNamespace(status="graded", score=18, feedback="Strong work", graded_at=now),
    }

    dashboard = build_student_dashboard([course], assignments, submissions, now=now)

    assert dashboard["stats"]["enrolled_courses"] == 1
    assert dashboard["stats"]["graded"] == 1
    assert dashboard["upcoming"][0]["assignment_id"] == 11
    assert len(dashboard["upcoming"]) == 1
    assert dashboard["feedback"][0]["feedback"] == "Strong work"
