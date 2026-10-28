"""Seed 65 curriculum courses (Semesters 1.0 - 7.0) and 500 dummy students without marks.

Ensures:
- All 65 courses are assigned to prof@example.com (and all professors in DB).
- student@example.com is enrolled in demo courses.
- 500 dummy students are created with realistic Pakistani names, active, verified, approved.
- Students are realistically enrolled across the 7 semesters (~70-75 students per course).
- Absolutely NO marks, grades, or submissions are added.
"""

import asyncio
import os
import random
import secrets
from sqlalchemy import select, func
from sqlalchemy.orm import noload
from app.db.base import async_session
from app.models.user import User, UserRole
from app.models.course import Course, Enrollment
from app.core.security import hash_password

FIRST_NAMES = [
    "Ayesha", "Bilal", "Dania", "Eman", "Hamza", "Hira", "Ibrahim", "Iqra",
    "Javeria", "Kashif", "Laiba", "Mahnoor", "Maham", "Muneeb", "Nimra", "Omer",
    "Rabia", "Rayan", "Saad", "Sana", "Sarmad", "Sidra", "Talha", "Tooba",
    "Umer", "Usman", "Waleed", "Yumna", "Zain", "Zara", "Abdullah", "Amna",
    "Asad", "Bushra", "Danish", "Fatima", "Hassan", "Kiran", "Maryam", "Nadia",
    "Naveed", "Noor", "Rida", "Shoaib", "Sumaiya", "Taha", "Uzair", "Wajiha",
    "Yasir", "Zubair", "Faizan", "Haris", "Zeeshan", "Ahmed", "Ali", "Mustafa"
]

LAST_NAMES = [
    "Ahmed", "Ali", "Aslam", "Bashir", "Butt", "Chaudhry", "Farooq", "Hassan",
    "Hussain", "Iqbal", "Javed", "Khan", "Khalid", "Malik", "Masood", "Mehmood",
    "Mirza", "Nawaz", "Qureshi", "Rafiq", "Rashid", "Saeed", "Shah", "Shaikh",
    "Siddiqui", "Sohail", "Tariq", "Usman", "Yousaf", "Zahid", "Abbasi", "Raza"
]

CURRICULUM_COURSES = [
    # Semester 1.0
    ("Semester 1.0", "SEGC1112", "Applications of Information & Communication Technologies"),
    ("Semester 1.0", "SECC1123", "Programming Fundamentals"),
    ("Semester 1.0", "CSHU1113", "English composition & Comprehension"),
    ("Semester 1.0", "SEMC1003", "Remedial Mathematics-I"),
    ("Semester 1.0", "SEGC1111", "Applications of Information & Communication Technologies Lab"),
    ("Semester 1.0", "SECC1121", "Programming Fundamentals Lab"),
    ("Semester 1.0", "SEGC1133", "Discrete Structures"),

    # Semester 2.0
    ("Semester 2.0", "SECC1033", "Object Oriented Programming"),
    ("Semester 2.0", "SECC1031", "Object Oriented Programming Lab"),
    ("Semester 2.0", "SEMC1043", "Remedial Mathematics-II"),
    ("Semester 2.0", "SECC2123", "Database Systems"),
    ("Semester 2.0", "SECC2121", "Database Systems Lab"),
    ("Semester 2.0", "SECC1022", "Digital Logic Design"),
    ("Semester 2.0", "SECC1021", "Digital Logic Design Lab"),

    # Semester 3.0
    ("Semester 3.0", "AIGC1113", "Calculus & Analytic Geometry"),
    ("Semester 3.0", "SECC2113", "Data Structures"),
    ("Semester 3.0", "SECC2111", "Data Structures Lab"),
    ("Semester 3.0", "SECC4023", "Software Engineering"),
    ("Semester 3.0", "SECC2142", "Artificial Intelligence"),
    ("Semester 3.0", "SECC2141", "Artificial Intelligence Lab"),
    ("Semester 3.0", "SECC2032", "Computer Networks"),
    ("Semester 3.0", "SECC2031", "Computer Networks Lab"),
    ("Semester 3.0", "SECC1092", "Information Security"),
    ("Semester 3.0", "SECC1091", "Information Security Lab"),

    # Semester 4.0
    ("Semester 4.0", "SEGC1013", "Expository Writing"),
    ("Semester 4.0", "CYMC1023", "Multivariable Calculus"),
    ("Semester 4.0", "CYCC2182", "Computer Organization & Assembly Language"),
    ("Semester 4.0", "SECC2151", "Computer Organization & Assembly Language Lab"),
    ("Semester 4.0", "SEDC2102", "Software Requirement Engineering"),
    ("Semester 4.0", "SEDC2101", "Software Requirement Engineering Lab"),
    ("Semester 4.0", "SEEC3092", "Object Oriented Analysis and Design"),
    ("Semester 4.0", "SEEC3091", "Object Oriented Analysis and Design Lab"),
    ("Semester 4.0", "SEGC1122", "Applied Physics"),
    ("Semester 4.0", "SEGC1121", "Applied Physics Lab"),

    # Semester 5.0
    ("Semester 5.0", "SEGC1022", "Introduction to Management"),
    ("Semester 5.0", "SECC3122", "Operating Systems"),
    ("Semester 5.0", "SEMC2023", "Linear Algebra"),
    ("Semester 5.0", "SECC3121", "Operating Systems Lab"),
    ("Semester 5.0", "SEDC3113", "Software Design & Architecture"),
    ("Semester 5.0", "SEDC3033", "Software Engineering II"),
    ("Semester 5.0", "SEDC3031", "Software Quality Engineering Lab"),
    ("Semester 5.0", "SEEC3112", "Web Technologies"),
    ("Semester 5.0", "SEEC3111", "Web Technologies Lab"),
    ("Semester 5.0", "SEEC3102", "HCI & Computer Graphics"),
    ("Semester 5.0", "SEEC3101", "HCI & Computer Graphics Lab"),

    # Semester 6.0
    ("Semester 6.0", "AIMC1023", "Probability & Statistics"),
    ("Semester 6.0", "SESC2083", "Introduction to Marketing"),
    ("Semester 6.0", "SEDC2111", "Software Construction & Development Lab"),
    ("Semester 6.0", "SEDC2112", "Software Construction & Development"),
    ("Semester 6.0", "SEEC3223", "Machine Learning"),
    ("Semester 6.0", "SEEC3221", "Machine Learning Lab"),
    ("Semester 6.0", "SEDC3052", "Parallel & Distributed Computing"),
    ("Semester 6.0", "SEEC4103", "DevOps for Cloud Computing"),
    ("Semester 6.0", "CSEC3093", "Mobile Application Development"),
    ("Semester 6.0", "CSEC3091", "Mobile Application Development Lab"),
    ("Semester 6.0", "SEDC3051", "Parallel & Distributed Computing Lab"),

    # Semester 7.0
    ("Semester 7.0", "SEMC3022", "Technical & Business Writing"),
    ("Semester 7.0", "SEGC4122", "Islamic Studies"),
    ("Semester 7.0", "SECC4113", "Final Year Project-I"),
    ("Semester 7.0", "SECC2063", "Analysis of Algorithms"),
    ("Semester 7.0", "SEDC3112", "Software Project Management"),
    ("Semester 7.0", "SEDC3111", "Software Project Management Lab"),
    ("Semester 7.0", "CYGC4162", "Entrepreneurship"),
    ("Semester 7.0", "SEEC4092", "Software Verification and Validation"),
    ("Semester 7.0", "SEEC4091", "Software Verification and Validation Lab"),
]

def make_join_code(used_codes: set) -> str:
    while True:
        code = secrets.token_hex(3).upper()
        if code not in used_codes:
            used_codes.add(code)
            return code

async def main():
    async with async_session() as session:
        # 1. Identify primary professor
        prof_res = await session.execute(
            select(User).where(User.email == "prof@example.com")
        )
        prof = prof_res.scalar_one_or_none()
        if not prof:
            prof_any = await session.execute(
                select(User).where(User.role == UserRole.PROFESSOR.value)
            )
            prof = prof_any.scalars().first()
        if not prof:
            raise RuntimeError("No professor found in DB to own the courses.")
        print(f"Professor assigned to courses: {prof.full_name} ({prof.email})")

        # 2. Identify demo student (student@example.com)
        demo_student_res = await session.execute(
            select(User).where(User.email == "student@example.com")
        )
        demo_student = demo_student_res.scalar_one_or_none()

        # 3. Create / Fetch 500 dummy students
        print("Ensuring 500 dummy students exist...")
        default_pwd_hash = hash_password("password123")
        existing_students_res = await session.execute(
            select(User.email).where(User.role == UserRole.STUDENT.value)
        )
        existing_emails = set(existing_students_res.scalars().all())

        new_students = []
        dummy_students_list = []
        for i in range(1, 501):
            email = f"student.bsse.{i:03d}@demo.professoros.edu.pk"
            fn = FIRST_NAMES[(i - 1) % len(FIRST_NAMES)]
            ln = LAST_NAMES[(i * 7 - 1) % len(LAST_NAMES)]
            full_name = f"{fn} {ln}"

            if email not in existing_emails:
                st = User(
                    email=email,
                    full_name=full_name,
                    hashed_password=default_pwd_hash,
                    role=UserRole.STUDENT.value,
                    is_active=True,
                    is_verified=True,
                    is_approved=True,
                )
                session.add(st)
                new_students.append(st)
                existing_emails.add(email)

        if new_students:
            await session.flush()
            print(f"Created {len(new_students)} new dummy students.")

        # Re-fetch all 500 dummy students
        all_dummy_res = await session.execute(
            select(User).where(User.email.like("student.bsse.%@demo.professoros.edu.pk")).order_by(User.id)
        )
        dummy_students = all_dummy_res.scalars().all()
        print(f"Total dummy students ready: {len(dummy_students)}")

        # 4. Fetch existing courses & join codes
        existing_courses_res = await session.execute(select(Course))
        all_courses = existing_courses_res.scalars().all()
        used_join_codes = {c.join_code for c in all_courses if c.join_code}
        courses_by_key = {(c.code, c.semester): c for c in all_courses}

        # 5. Insert / update all 65 curriculum courses
        created_courses_count = 0
        semester_to_courses = {}
        for semester, code, title in CURRICULUM_COURSES:
            key = (code, semester)
            if key in courses_by_key:
                c = courses_by_key[key]
                c.title = title
                c.professor_id = prof.id
            else:
                c = Course(
                    code=code,
                    title=title,
                    semester=semester,
                    description=f"{title} ({code}) - Course for {semester}",
                    professor_id=prof.id,
                    join_code=make_join_code(used_join_codes),
                    is_archived=False,
                    at_risk_threshold=40.0,
                    quiz_weight=20,
                    assignment_weight=20,
                    midterm_weight=20,
                    final_weight=40,
                )
                session.add(c)
                courses_by_key[key] = c
                created_courses_count += 1
            semester_to_courses.setdefault(semester, []).append(c)

        await session.flush()
        print(f"Ensured {len(CURRICULUM_COURSES)} curriculum courses (newly created: {created_courses_count}).")

        # 6. Fetch existing enrollments
        existing_enrollments_res = await session.execute(select(Enrollment.course_id, Enrollment.user_id))
        existing_enrollments = set(existing_enrollments_res.all())

        # 7. Partition 500 students into 7 semester cohorts (~71-72 students per semester)
        # Semester 1: students 0..71
        # Semester 2: students 72..143
        # etc.
        semesters_ordered = [
            "Semester 1.0", "Semester 2.0", "Semester 3.0", "Semester 4.0",
            "Semester 5.0", "Semester 6.0", "Semester 7.0"
        ]
        cohort_size = len(dummy_students) // len(semesters_ordered)  # ~71
        new_enrollment_count = 0

        for idx, sem in enumerate(semesters_ordered):
            start_idx = idx * cohort_size
            end_idx = start_idx + cohort_size if idx < len(semesters_ordered) - 1 else len(dummy_students)
            cohort = dummy_students[start_idx:end_idx]
            sem_courses = semester_to_courses.get(sem, [])

            print(f"{sem}: Enrolling {len(cohort)} students into {len(sem_courses)} courses...")
            for course_obj in sem_courses:
                for student_obj in cohort:
                    key = (course_obj.id, student_obj.id)
                    if key not in existing_enrollments:
                        session.add(Enrollment(course_id=course_obj.id, user_id=student_obj.id, role="student"))
                        existing_enrollments.add(key)
                        new_enrollment_count += 1

                # Also enroll the primary demo student (student@example.com) in all courses of Semester 1.0 & Semester 2.0 & Semester 4.0
                if demo_student and sem in ("Semester 1.0", "Semester 2.0", "Semester 4.0"):
                    demo_key = (course_obj.id, demo_student.id)
                    if demo_key not in existing_enrollments:
                        session.add(Enrollment(course_id=course_obj.id, user_id=demo_student.id, role="student"))
                        existing_enrollments.add(demo_key)
                        new_enrollment_count += 1

        await session.commit()
        print(f"\nSUCCESS! Added {new_enrollment_count} new enrollments across 65 curriculum courses.")
        print(f"Total demo students enrolled: {len(dummy_students)} + primary demo student.")
        print("Zero marks / evaluations added (strictly clean courses and cohorts).")

if __name__ == "__main__":
    asyncio.run(main())
