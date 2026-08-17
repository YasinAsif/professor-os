"""Shared account checks for student authentication and enrollment."""


def can_student_login(user) -> bool:
    return bool(user.is_verified and user.is_approved and user.is_active)


def can_student_join_course(user) -> bool:
    role = getattr(user.role, "value", user.role)
    return role == "student" and bool(user.is_approved and user.is_active)
