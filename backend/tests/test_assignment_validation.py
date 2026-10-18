import pytest

from app.models.course import CLO
from app.schemas.assignment import AssignmentCreate, AssignmentUpdate


def test_default_clo_uses_the_current_clo_model_contract():
    clo = CLO(
        course_id=7,
        code="CLO-1",
        description="Understand and apply core course concepts and methodologies.",
    )

    assert clo.course_id == 7
    assert clo.code == "CLO-1"


def test_assignment_create_rejects_invalid_attempt_values():
    with pytest.raises(ValueError):
        AssignmentCreate(title="Exam", type="mcq", max_attempts=0)

    with pytest.raises(ValueError):
        AssignmentCreate(title="Exam", type="mcq", time_limit_minutes=-1)


def test_assignment_update_rejects_invalid_attempt_values():
    with pytest.raises(ValueError):
        AssignmentUpdate(max_attempts=0)

    with pytest.raises(ValueError):
        AssignmentUpdate(time_limit_minutes=-1)
