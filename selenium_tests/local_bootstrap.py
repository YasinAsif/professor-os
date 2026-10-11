"""Create deterministic local browser-test identities and workflow data."""

import asyncio
from datetime import datetime, timedelta, timezone

from sqlalchemy import insert, select

from app.core.security import hash_password
from app.db.base import async_session
from app.models.assignment import Assignment, AssignmentStatus, AssignmentType, assignment_ta_table
from app.models.course import Course, Enrollment
from app.models.user import User, UserRole


PASSWORD = "BrowserTest@2026"
USERS = {
    "admin": ("browser.admin@e2e.example.com", "Browser Admin", UserRole.ADMIN.value),
    "professor": ("browser.professor@e2e.example.com", "Browser Professor", UserRole.PROFESSOR.value),
    "student": ("browser.student@e2e.example.com", "Browser Student", UserRole.STUDENT.value),
    "ta": ("browser.ta@e2e.example.com", "Browser Teaching Assistant", UserRole.TA.value),
}


async def main() -> None:
    async with async_session() as session:
        users = {}
        for role, (email, name, role_value) in USERS.items():
            user = (await session.execute(select(User).where(User.email == email))).scalar_one_or_none()
            if user is None:
                user = User(email=email, full_name=name, hashed_password=hash_password(PASSWORD))
                session.add(user)
            user.full_name = name
            user.role = role_value
            user.is_active = True
            user.is_verified = True
            user.is_approved = True
            users[role] = user

        await session.flush()
        course = (await session.execute(select(Course).where(Course.code == "E2E101"))).scalar_one_or_none()
        if course is None:
            course = Course(
                title="Browser E2E Course",
                code="E2E101",
                semester="Browser Tests",
                description="Deterministic browser verification course.",
                professor_id=users["professor"].id,
            )
            session.add(course)
            await session.flush()
        course.professor_id = users["professor"].id

        assignment = (await session.execute(
            select(Assignment).where(Assignment.course_id == course.id, Assignment.title == "Browser E2E Assignment")
        )).scalar_one_or_none()
        if assignment is None:
            assignment = Assignment(
                course_id=course.id,
                title="Browser E2E Assignment",
                description="Explain the deterministic browser verification workflow.",
                type=AssignmentType.TEXT.value,
                status=AssignmentStatus.PUBLISHED.value,
                max_marks=100,
                deadline=datetime.now(timezone.utc) + timedelta(days=7),
            )
            session.add(assignment)
            await session.flush()
        for role in ("student", "ta"):
            exists = (await session.execute(select(Enrollment).where(
                Enrollment.course_id == course.id,
                Enrollment.user_id == users[role].id,
            ))).scalar_one_or_none()
            if exists is None:
                session.add(Enrollment(course_id=course.id, user_id=users[role].id, role=role))
        delegated = await session.execute(select(assignment_ta_table).where(
            assignment_ta_table.c.assignment_id == assignment.id,
            assignment_ta_table.c.user_id == users["ta"].id,
        ))
        if delegated.first() is None:
            await session.execute(insert(assignment_ta_table).values(
                assignment_id=assignment.id,
                user_id=users["ta"].id,
            ))
        await session.commit()


if __name__ == "__main__":
    asyncio.run(main())
