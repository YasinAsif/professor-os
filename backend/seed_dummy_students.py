"""Seed realistic, idempotent student cohorts for every course semester.

Examples:
    python seed_dummy_students.py --dry-run
    DUMMY_STUDENT_PASSWORD='...' python seed_dummy_students.py
    python seed_dummy_students.py --count 50 --semester Spring-2026
"""

from __future__ import annotations

import argparse
import asyncio
import os
import re
from collections import defaultdict

from sqlalchemy import select
from sqlalchemy.orm import noload

from app.config.settings import get_settings
from app.core.security import hash_password
from app.models import assignment, analytics, course, rubric, submission, user  # noqa: F401
from app.models.course import Course, Enrollment
from app.models.user import User, UserRole
from app.db.base import async_session


FIRST_NAMES = [
    "Ayesha", "Bilal", "Dania", "Eman", "Hamza", "Hira", "Ibrahim", "Iqra",
    "Javeria", "Kashif", "Laiba", "Mahnoor", "Maham", "Muneeb", "Nimra", "Omer",
    "Rabia", "Rayan", "Saad", "Sana", "Sarmad", "Sidra", "Talha", "Tooba",
    "Umer", "Usman", "Waleed", "Yumna", "Zain", "Zara", "Abdullah", "Amna",
    "Asad", "Bushra", "Danish", "Fatima", "Hassan", "Kiran", "Maryam", "Nadia",
    "Naveed", "Noor", "Rida", "Shoaib", "Sumaiya", "Taha", "Uzair", "Wajiha",
    "Yasir", "Zubair",
]

LAST_NAMES = [
    "Ahmed", "Ali", "Aslam", "Bashir", "Butt", "Chaudhry", "Farooq", "Hassan",
    "Hussain", "Iqbal", "Javed", "Khan", "Khalid", "Malik", "Masood", "Mehmood",
    "Mirza", "Nawaz", "Qureshi", "Rafiq", "Rashid", "Saeed", "Shah", "Shaikh",
    "Siddiqui", "Sohail", "Tariq", "Usman", "Yousaf", "Zahid",
]


def semester_slug(semester: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", semester.lower()).strip("-") or "unspecified"


def student_identity(semester: str, index: int) -> tuple[str, str]:
    """Return deterministic identity data so repeated runs never create duplicates."""
    first = FIRST_NAMES[(index - 1) % len(FIRST_NAMES)]
    last = LAST_NAMES[(index * 7 - 1) % len(LAST_NAMES)]
    slug = semester_slug(semester)
    return f"student.{slug}.{index:03d}@demo.professoros.edu.pk", f"{first} {last}"


async def seed_dummy_students(
    count: int = 50,
    semester_filter: str | None = None,
    dry_run: bool = False,
) -> dict[str, dict[str, int]]:
    settings = get_settings()
    if settings.ENVIRONMENT.lower() in {"production", "prod"} and not dry_run and os.getenv("ALLOW_DUMMY_SEED") != "true":
        raise RuntimeError("Refusing dummy data writes in production. Set ALLOW_DUMMY_SEED=true explicitly.")
    if count < 1 or count > 500:
        raise ValueError("count must be between 1 and 500")

    password = os.getenv("DUMMY_STUDENT_PASSWORD", "Student@2026!")
    if len(password) < 8:
        raise ValueError("DUMMY_STUDENT_PASSWORD must contain at least 8 characters")

    async with async_session() as session:
        # Select only scalar course fields so SQLAlchemy does not eager-load unrelated
        # assignment/submission relationships while preparing the seed plan.
        course_rows = (
            await session.execute(
                select(Course.id, Course.semester, Course.code)
                .order_by(Course.semester, Course.code)
            )
        ).all()
        grouped: dict[str, list] = defaultdict(list)
        for course_row in course_rows:
            if semester_filter and course_row.semester != semester_filter:
                continue
            grouped[course_row.semester].append(course_row)
        if not grouped:
            requested = f" '{semester_filter}'" if semester_filter else ""
            raise ValueError(f"No courses found for semester{requested}.")

        summary: dict[str, dict[str, int]] = {}
        for semester, semester_courses in grouped.items():
            emails = [student_identity(semester, i)[0] for i in range(1, count + 1)]
            existing_users = {
                student.email: student
                for student in (
                    await session.execute(
                        select(User)
                        .options(noload(User.enrollments), noload(User.courses_owned))
                        .where(User.email.in_(emails))
                    )
                ).scalars().all()
            }

            students: list[User] = []
            created_students = 0
            for index in range(1, count + 1):
                email, full_name = student_identity(semester, index)
                student = existing_users.get(email)
                if student is None:
                    created_students += 1
                    if not dry_run:
                        student = User(
                            email=email,
                            full_name=full_name,
                            hashed_password=hash_password(password),
                            role=UserRole.STUDENT.value,
                            is_active=True,
                            is_verified=True,
                            is_approved=True,
                        )
                        session.add(student)
                else:
                    student.full_name = full_name
                    student.role = UserRole.STUDENT.value
                    student.is_active = True
                    student.is_verified = True
                    student.is_approved = True
                if not dry_run:
                    students.append(student)

            if dry_run:
                existing_user_ids = [student.id for student in existing_users.values()]
                existing_enrollment_count = 0
                if existing_user_ids:
                    course_ids = [course_row.id for course_row in semester_courses]
                    existing_enrollment_count = len(
                        (
                            await session.execute(
                                select(Enrollment.course_id, Enrollment.user_id).where(
                                    Enrollment.course_id.in_(course_ids),
                                    Enrollment.user_id.in_(existing_user_ids),
                                )
                            )
                        ).all()
                    )
                summary[semester] = {
                    "courses": len(semester_courses),
                    "students": count,
                    "new_students": created_students,
                    "new_enrollments": count * len(semester_courses) - existing_enrollment_count,
                }
                continue

            await session.flush()
            user_ids = [student.id for student in students]
            course_ids = [course_row.id for course_row in semester_courses]
            existing_enrollments = {
                (row.course_id, row.user_id)
                for row in (
                    await session.execute(
                        select(Enrollment.course_id, Enrollment.user_id).where(
                            Enrollment.course_id.in_(course_ids),
                            Enrollment.user_id.in_(user_ids),
                        )
                    )
                ).all()
            }

            created_enrollments = 0
            for course_row in semester_courses:
                for student in students:
                    key = (course_row.id, student.id)
                    if key not in existing_enrollments:
                        session.add(Enrollment(course_id=course_row.id, user_id=student.id, role="student"))
                        created_enrollments += 1
            await session.commit()
            summary[semester] = {
                "courses": len(semester_courses),
                "students": count,
                "new_students": created_students,
                "new_enrollments": created_enrollments,
            }

        return summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed idempotent dummy student cohorts by course semester.")
    parser.add_argument("--count", type=int, default=50, help="Students per semester (default: 50)")
    parser.add_argument("--semester", help="Only seed this exact Course.semester value")
    parser.add_argument("--dry-run", action="store_true", help="Show planned changes without writing to the database")
    return parser.parse_args()


async def main() -> None:
    args = parse_args()
    summary = await seed_dummy_students(args.count, args.semester, args.dry_run)
    mode = "DRY RUN" if args.dry_run else "SEEDED"
    print(f"[{mode}] Dummy student cohorts")
    for semester, values in summary.items():
        print(
            f"  {semester}: {values['students']} students across {values['courses']} courses; "
            f"new students={values['new_students']}, new enrollments={values['new_enrollments']}"
        )


if __name__ == "__main__":
    asyncio.run(main())
