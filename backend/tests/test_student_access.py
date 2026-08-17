from types import SimpleNamespace

from app.services.student_access import can_student_login, can_student_join_course


def test_student_login_requires_verification_approval_and_active_account():
    approved = SimpleNamespace(is_verified=True, is_approved=True, is_active=True)
    assert can_student_login(approved) is True
    assert can_student_login(SimpleNamespace(is_verified=False, is_approved=True, is_active=True)) is False
    assert can_student_login(SimpleNamespace(is_verified=True, is_approved=False, is_active=True)) is False
    assert can_student_login(SimpleNamespace(is_verified=True, is_approved=True, is_active=False)) is False


def test_only_approved_active_students_can_join_courses():
    student = SimpleNamespace(role="student", is_approved=True, is_active=True)
    assert can_student_join_course(student) is True
    assert can_student_join_course(SimpleNamespace(role="ta", is_approved=True, is_active=True)) is False
    assert can_student_join_course(SimpleNamespace(role="student", is_approved=False, is_active=True)) is False
