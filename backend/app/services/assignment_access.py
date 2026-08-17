"""Authorization helpers for assignment-level professor/TA access."""


def can_access_assignment(*, user_role: str, user_id: int, assignment, delegated_ta_ids: set[int]) -> bool:
    role = getattr(user_role, "value", user_role)
    if role == "admin":
        return True
    if role == "professor":
        return assignment.course.professor_id == user_id
    return role == "ta" and user_id in delegated_ta_ids
