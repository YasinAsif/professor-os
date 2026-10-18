"""ProfessorOS – Core authorization helpers and security utilities."""

from typing import Any, Optional
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.course import Course, Enrollment
from app.models.assignment import Assignment, assignment_ta_table
from app.models.user import User


async def verify_course_staff_access(
    db: AsyncSession,
    course_id: int,
    user: User,
    allow_ta: bool = True,
    assignment_id: Optional[int] = None,
) -> bool:
    """Verifies that a user is course staff (admin, course professor owner, or course TA).

    Decisions already made:
    - TA model: a TA is an Enrollment with role="ta" for THAT course.
    - Admin and professor owner of the course always pass.
    - TA passes only if enrolled as role="ta" in that course.
    - If assignment_id is provided, TA additionally must be delegated in assignment_ta_table for that assignment.
    """
    user_role = getattr(user.role, "value", user.role)
    if user_role == "admin":
        return True

    course = await db.get(Course, course_id)
    if not course:
        raise HTTPException(status_code=404, detail="Course not found.")

    if user_role == "professor" and course.professor_id == user.id:
        return True

    if allow_ta:
        # Check if enrolled as TA in this course
        enroll_res = await db.execute(
            select(Enrollment).where(
                Enrollment.course_id == course_id,
                Enrollment.user_id == user.id,
                Enrollment.role == "ta",
            )
        )
        is_course_ta = enroll_res.scalar_one_or_none() is not None
        if is_course_ta:
            if assignment_id is not None:
                # Must also be delegated in assignment_tas for this assignment
                ta_res = await db.execute(
                    select(assignment_ta_table.c.user_id).where(
                        assignment_ta_table.c.assignment_id == assignment_id,
                        assignment_ta_table.c.user_id == user.id,
                    )
                )
                if not ta_res.first():
                    raise HTTPException(
                        status_code=403,
                        detail="TA is not delegated to grade or manage this specific assignment.",
                    )
            return True

    raise HTTPException(status_code=403, detail="Access denied. Course staff privileges required.")


def escape_csv_cell(value: Any) -> Any:
    """Neutralize CSV formula injection attacks by prepending a single quote to dangerous trigger characters.

    Protects against spreadsheet formula execution when opening exported CSVs in Excel / Calc / Sheets.
    Triggers: =, +, -, @, \t, \r
    """
    if value is None:
        return ""
    val_str = str(value)
    if not val_str:
        return ""
    if val_str[0] in ("=", "+", "-", "@", "\t", "\r"):
        return f"'{val_str}"
    return value


# Simple in-memory rate limiter for course join attempts: max 5 attempts per 60s per user
_join_attempts: dict[int, list[float]] = {}

def check_join_rate_limit(user_id: int, max_attempts: int = 5, window_seconds: float = 60.0) -> None:
    """Rate limit join course calls to prevent brute-forcing course join codes."""
    import time
    now = time.monotonic()
    attempts = _join_attempts.setdefault(user_id, [])
    # Filter out timestamps older than window
    attempts = [t for t in attempts if now - t < window_seconds]
    _join_attempts[user_id] = attempts
    if len(attempts) >= max_attempts:
        raise HTTPException(
            status_code=429,
            detail="Too many join course attempts. Please wait a minute before trying again.",
        )
    attempts.append(now)
