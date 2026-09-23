import pytest
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_enrollment_role_validation():
    from unittest.mock import AsyncMock, MagicMock
    from app.services.course_service import CourseService

    db_mock = AsyncMock()
    exec_res = MagicMock()
    exec_res.scalar_one_or_none.return_value = None
    db_mock.execute.return_value = exec_res
    course_svc = CourseService(db_mock)

    # Valid roles
    try:
        await course_svc.enroll_user(1, 1, "student")
        await course_svc.enroll_user(1, 1, "ta")
    except ValueError as e:
        pytest.fail(f"Unexpected ValueError: {e}")

    # Invalid role
    try:
        await course_svc.enroll_user(1, 1, "admin")
        assert False, "Should raise ValueError for invalid role"
    except ValueError as e:
        assert "Invalid enrollment role" in str(e)
