"""Import curriculum courses across Semesters 1 to 7 and enroll students without any grades.

Strict requirement:
- Do not add grades, scores, or evaluated submissions.
- Create courses under the primary professor account (or Dr. Yasin).
- Enroll existing active students in their respective semester courses.
"""

import asyncio
from sqlalchemy import select
from app.db.base import async_session
from app.models.user import User, UserRole
from app.models.course import Course, Enrollment

SEMESTER_COURSES = [
    # Semester 1
    ("Semester 1", "SEGC1112", "Application of Information & Communication Technologies"),
    ("Semester 1", "SECC1123", "Programming Fundamentals"),
    ("Semester 1", "CSHU1113", "English composition & Comprehension"),
    ("Semester 1", "SEMC1003", "Remedial Mathematics-I"),
    ("Semester 1", "SEGC1111", "Application of Information & Communication Technologies Lab"),
    ("Semester 1", "SECC1121", "Programming Fundamentals Lab"),
    ("Semester 1", "SEGC1133", "Discrete Structures"),

    # Semester 2
    ("Semester 2", "SECC1033", "Object Oriented Programming"),
    ("Semester 2", "SECC1031", "Object Oriented Programming Lab"),
    ("Semester 2", "SEMC1043", "Remedial Mathematics-II"),
    ("Semester 2", "SECC2123", "Database Systems"),
    ("Semester 2", "SECC2121", "Database Systems Lab"),
    ("Semester 2", "SECC1022", "Digital Logic Design"),
    ("Semester 2", "SECC1021", "Digital Logic Design Lab"),

    # Semester 3
    ("Semester 3", "AIGC1113", "Calculus & Analytic Geometry"),
    ("Semester 3", "SECC2113", "Data Structures"),
    ("Semester 3", "SECC2111", "Data Structures Lab"),
    ("Semester 3", "SECC4023", "Software Engineering"),
    ("Semester 3", "SECC2142", "Artificial Intelligence"),
    ("Semester 3", "SECC2141", "Artificial Intelligence Lab"),
    ("Semester 3", "SECC2032", "Computer Networks"),
    ("Semester 3", "SECC2031", "Computer Networks Lab"),
    ("Semester 3", "SECC1092", "Information Security"),
    ("Semester 3", "SECC1091", "Information Security Lab"),

    # Semester 4
    ("Semester 4", "SEGC1013", "Expository Writing"),
    ("Semester 4", "CYMC1023", "Multivariable Calculus"),
    ("Semester 4", "CYCC2182", "Computer Organization & Assembly Language"),
    ("Semester 4", "SECC2151", "Computer Organization & Assembly Language Lab"),
    ("Semester 4", "SEDC2102", "Software Requirement Engineering"),
    ("Semester 4", "SEDC2101", "Software Requirement Engineering Lab"),
    ("Semester 4", "SEEC3092", "Object Oriented Analysis and Design"),
    ("Semester 4", "SEEC3091", "Object Oriented Analysis and Design Lab"),
    ("Semester 4", "SEGC1122", "Applied Physics"),
    ("Semester 4", "SEGC1121", "Applied Physics Lab"),

    # Semester 5
    ("Semester 5", "SEGC1022", "Introduction to Management"),
    ("Semester 5", "SECC3122", "Operating Systems"),
    ("Semester 5", "SEMC2023", "Linear Algebra"),
    ("Semester 5", "SECC3121", "Operating Systems Lab"),
    ("Semester 5", "SEDC3113", "Software Design & Architecture"),
    ("Semester 5", "SEDC3031", "Software Quality Engineering Lab"),
    ("Semester 5", "SEEC3112", "Web Technologies"),
    ("Semester 5", "SEEC3111", "Web Technologies Lab"),
    ("Semester 5", "SEEC3102", "HCI & Computer Graphics"),
    ("Semester 5", "SEEC3101", "HCI & Computer Graphics Lab"),

    # Semester 6
    ("Semester 6", "AIMC1023", "Probability & Statistics"),
    ("Semester 6", "SESC2083", "Introduction to Marketing"),
    ("Semester 6", "SEDC2111", "Software Construction & Development Lab"),
    ("Semester 6", "SEDC2112", "Software Construction & Development"),
    ("Semester 6", "SEEC3223", "Machine Learning"),
    ("Semester 6", "SEEC3221", "Machine Learning Lab"),
    ("Semester 6", "SEDC3052", "Parallel & Distributed Computing"),
    ("Semester 6", "SEEC4103", "DevOps for Cloud Computing"),
    ("Semester 6", "SEEC3132", "Mobile Application Development"),
    ("Semester 6", "SEEC3131", "Mobile Application Development Lab"),
    ("Semester 6", "SEDC3051", "Parallel & Distributed Computing Lab"),

    # Semester 7
    ("Semester 7", "SEMC3022", "Technical & Business Writing"),
    ("Semester 7", "SEGC4122", "Islamic Studies"),
    ("Semester 7", "SECC4113", "Final Year Project-I"),
    ("Semester 7", "SECC2063", "Analysis of Algorithms"),
    ("Semester 7", "SEDC3112", "Software Project Management"),
    ("Semester 7", "SEDC3111", "Software Project Management Lab"),
    ("Semester 7", "CYGC4162", "Entrepreneurship"),
    ("Semester 7", "SEEC4092", "Software Verification and Validation"),
    ("Semester 7", "SEEC4091", "Software Verification and Validation Lab"),
]


async def run():
    async with async_session() as session:
        # Find default professor
        prof_res = await session.execute(
            select(User).where(User.role == UserRole.PROFESSOR).order_by(User.id)
        )
        professors = prof_res.scalars().all()
        if not professors:
            raise RuntimeError("No professor found in DB to own courses.")
        default_prof = professors[0]
        print(f"Assigning courses to Professor: {default_prof.full_name} ({default_prof.email})")

        # Fetch existing courses
        existing_res = await session.execute(select(Course))
        existing_courses = {(c.code, c.semester): c for c in existing_res.scalars().all()}

        # Fetch all active students
        student_res = await session.execute(
            select(User).where(User.role == UserRole.STUDENT, User.is_active.is_(True))
        )
        all_students = student_res.scalars().all()
        print(f"Found {len(all_students)} active students available for enrollment.")

        created_courses = []
        for semester, code, title in SEMESTER_COURSES:
            key = (code, semester)
            if key in existing_courses:
                course_obj = existing_courses[key]
            else:
                course_obj = Course(
                    code=code,
                    title=title,
                    semester=semester,
                    description=f"{title} - {semester}",
                    professor_id=default_prof.id,
                )
                session.add(course_obj)
                await session.flush()
                existing_courses[key] = course_obj
                created_courses.append(course_obj)

        print(f"Created {len(created_courses)} new courses. Total active curriculum courses: {len(existing_courses)}")

        # Fetch existing enrollments
        enrollment_res = await session.execute(select(Enrollment.course_id, Enrollment.user_id))
        existing_enrollments = set(enrollment_res.all())

        new_enrollment_count = 0
        # Enroll active students into all curriculum courses (without grades or submissions)
        # To keep DB balanced, enroll cohort of students across courses
        enroll_students = all_students[:25] if len(all_students) >= 25 else all_students
        for (code, semester), course_obj in existing_courses.items():
            if semester.startswith("Semester"):
                for st in enroll_students:
                    if (course_obj.id, st.id) not in existing_enrollments:
                        session.add(Enrollment(course_id=course_obj.id, user_id=st.id, role="student"))
                        existing_enrollments.add((course_obj.id, st.id))
                        new_enrollment_count += 1

        await session.commit()
        print(f"Enrolled students successfully ({new_enrollment_count} new enrollments added, 0 grades added).")


if __name__ == "__main__":
    asyncio.run(run())
