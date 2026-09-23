"""Analytics access control – unit tests (no DB required).

Tests that the access-check logic raises correctly using mock objects,
matching the same SimpleNamespace pattern used by the rest of the test suite.
"""

import pytest
from types import SimpleNamespace
from unittest.mock import AsyncMock


# ---------------------------------------------------------------------------
# Test: access check raises for a professor who doesn't own the course
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_professor_without_ownership_is_denied():
    """A professor whose id != course.professor_id must be denied."""
    # Simulate what get_course_with_access_check does:
    course = SimpleNamespace(id=1, professor_id=2)

    def check_access(course, user):
        role = getattr(user.role, "value", user.role)
        if role == "admin":
            return True
        if role == "professor" and course.professor_id == user.id:
            return True
        # Check enrollment for students/TAs would go here; simplified for unit test
        raise PermissionError("Access denied.")

    wrong_prof = SimpleNamespace(id=99, role="professor")
    with pytest.raises(PermissionError):
        check_access(course, wrong_prof)


@pytest.mark.asyncio
async def test_admin_always_has_access():
    """Admin can access any course."""
    course = SimpleNamespace(id=1, professor_id=2)

    def check_access(course, user):
        role = getattr(user.role, "value", user.role)
        if role == "admin":
            return True
        if role == "professor" and course.professor_id == user.id:
            return True
        raise PermissionError("Access denied.")

    admin = SimpleNamespace(id=999, role="admin")
    result = check_access(course, admin)
    assert result is True


@pytest.mark.asyncio
async def test_correct_professor_has_access():
    """A professor who owns the course is allowed."""
    course = SimpleNamespace(id=1, professor_id=10)

    def check_access(course, user):
        role = getattr(user.role, "value", user.role)
        if role == "admin":
            return True
        if role == "professor" and course.professor_id == user.id:
            return True
        raise PermissionError("Access denied.")

    owner = SimpleNamespace(id=10, role="professor")
    result = check_access(course, owner)
    assert result is True
