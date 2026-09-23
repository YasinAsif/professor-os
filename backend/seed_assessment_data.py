"""ProfessorOS – Assessment & OBE Test Data Seeder.

Populates realistic sample data for end-to-end testing:
  1. Professor & Student accounts
  2. Course CS301 (Advanced Operating Systems) with enrollments
  3. Formal OBE CLO definitions (CLO-1, CLO-2, CLO-3)
  4. Assignment and linked QuizConfig
  5. Calibrated question bank items (C1 to C4) passing Bloom's Quality Gate
  6. Student test attempts with item-level telemetry for CLO attainment reports
"""

import asyncio
import json
import uuid
from datetime import datetime, timezone
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

from app.config.settings import get_settings
from app.core.security import hash_password
from app.models.user import User, UserRole
from app.models.course import Course, Enrollment
from app.models.assignment import Assignment, AssignmentType, AssignmentStatus
from app.models.quiz_obe import (
    CLODefinition,
    QuizConfig,
    QuestionBankItem,
    StudentQuizAttempt,
)

settings = get_settings()


async def seed():
    print("[SEED] Starting Assessment & OBE data population...")
    engine = create_async_engine(settings.DATABASE_URL)
    
    # Ensure legacy tables have all updated columns
    async with engine.begin() as conn:
        await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS is_approved BOOLEAN DEFAULT TRUE;"))
        await conn.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(255);"))
        await conn.execute(text("ALTER TABLE courses ADD COLUMN IF NOT EXISTS join_code VARCHAR(10);"))
        await conn.execute(text("ALTER TABLE assignments ADD COLUMN IF NOT EXISTS time_limit_minutes INT;"))
        await conn.execute(text("ALTER TABLE assignments ADD COLUMN IF NOT EXISTS max_attempts INT DEFAULT 1;"))
        await conn.execute(text("ALTER TABLE assignments ADD COLUMN IF NOT EXISTS randomize_questions BOOLEAN DEFAULT FALSE;"))
        await conn.execute(text("ALTER TABLE assignments ADD COLUMN IF NOT EXISTS show_results_after BOOLEAN DEFAULT TRUE;"))

    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # ── 1. Seed Professor & Students ──────────────────────────────
        res_prof = await session.execute(
            select(User).where(User.email == "dr.tariq@professoros.edu.pk")
        )
        prof = res_prof.scalar_one_or_none()
        if not prof:
            prof = User(
                email="dr.tariq@professoros.edu.pk",
                full_name="Dr. Tariq Mahmood",
                hashed_password=hash_password("professor123"),
                role=UserRole.PROFESSOR,
                is_active=True,
                is_verified=True,
                is_approved=True,
            )
            session.add(prof)
            await session.flush()
            print(f"  [OK] Created Professor: {prof.full_name} ({prof.email})")

        # Students
        students = []
        for i in range(1, 6):
            s_email = f"student{i}@professoros.edu.pk"
            res_s = await session.execute(select(User).where(User.email == s_email))
            s_user = res_s.scalar_one_or_none()
            if not s_user:
                s_user = User(
                    email=s_email,
                    full_name=f"Student {i} Khan",
                    hashed_password=hash_password("student123"),
                    role=UserRole.STUDENT,
                    is_active=True,
                    is_verified=True,
                    is_approved=True,
                )
                session.add(s_user)
                await session.flush()
            students.append(s_user)
        print(f"  [OK] Verified {len(students)} student accounts.")

        # ── 2. Seed Course CS301 ──────────────────────────────────────
        res_course = await session.execute(
            select(Course).where(Course.code == "CS301")
        )
        course = res_course.scalar_one_or_none()
        if not course:
            course = Course(
                title="Advanced Operating Systems",
                code="CS301",
                semester="Spring-2026",
                description="Process concurrency, memory virtualization, distributed systems, and real-time kernels.",
                quiz_weight=20,
                assignment_weight=20,
                midterm_weight=20,
                final_weight=40,
                professor_id=prof.id,
            )
            session.add(course)
            await session.flush()
            print(f"  [OK] Created Course: {course.code} – {course.title} (ID: {course.id})")

            # Enroll students
            for s in students:
                enrollment = Enrollment(
                    course_id=course.id,
                    user_id=s.id,
                    role="student",
                )
                session.add(enrollment)
            await session.flush()
            print(f"  [OK] Enrolled {len(students)} students in {course.code}.")

        # ── 3. Seed CLO Definitions ───────────────────────────────────
        clo_specs = [
            ("CLO-1", "Explain process scheduling, context switching, and concurrency primitives.", "C2"),
            ("CLO-2", "Design and implement deadlock-free multi-threaded synchronization algorithms.", "C3"),
            ("CLO-3", "Analyze race conditions and evaluate lock-free data structures.", "C4"),
        ]

        clos = []
        for code, desc, b_level in clo_specs:
            res_clo = await session.execute(
                select(CLODefinition).where(
                    CLODefinition.course_id == course.id,
                    CLODefinition.code == code,
                )
            )
            clo_entry = res_clo.scalar_one_or_none()
            if not clo_entry:
                clo_entry = CLODefinition(
                    clo_id=uuid.uuid4(),
                    course_id=course.id,
                    code=code,
                    description=desc,
                    bloom_target_level=b_level,
                )
                session.add(clo_entry)
                await session.flush()
            clos.append(clo_entry)
        print(f"  [OK] Seeded {len(clos)} Course Learning Outcomes (CLOs) in clo_definitions.")

        # ── 4. Seed Assignment & QuizConfig ───────────────────────────
        res_assign = await session.execute(
            select(Assignment).where(
                Assignment.course_id == course.id,
                Assignment.title == "Quiz 01: Concurrency & Deadlocks",
            )
        )
        assignment = res_assign.scalar_one_or_none()
        if not assignment:
            assignment = Assignment(
                course_id=course.id,
                title="Quiz 01: Concurrency & Deadlocks",
                description="Timed proctored quiz testing critical sections, semaphores, and Banker's algorithm.",
                type=AssignmentType.MCQ,
                status=AssignmentStatus.PUBLISHED,
                max_marks=20.0,
                time_limit_minutes=20,
            )
            session.add(assignment)
            await session.flush()

        res_qc = await session.execute(
            select(QuizConfig).where(QuizConfig.assignment_id == assignment.id)
        )
        quiz_config = res_qc.scalar_one_or_none()
        if not quiz_config:
            quiz_config = QuizConfig(
                quiz_id=uuid.uuid4(),
                assignment_id=assignment.id,
                time_limit_minutes=20,
                randomize_order=True,
                max_attempts=1,
                show_answers_after=True,
                bloom_gate_passed=True,
            )
            session.add(quiz_config)
            await session.flush()
            print(f"  [OK] Created QuizConfig: ID={quiz_config.quiz_id} for Assignment '{assignment.title}'")

        # ── 5. Seed Question Bank (Balanced: 25% C1, 25% C2, 25% C3, 25% C4)
        sample_questions = [
            # C1 Questions (Remembering)
            {
                "text": "Which of the following is NOT one of Coffman's four necessary conditions for deadlock?",
                "type": "MCQ",
                "options": ["Mutual Exclusion", "Hold and Wait", "Preemptive Scheduling", "Circular Wait"],
                "answer": "Preemptive Scheduling",
                "bloom": "C1",
                "clo": clos[0],
                "diff": 0.2,
                "explanation": "The condition is 'No Preemption', meaning resources cannot be forcibly seized.",
            },
            {
                "text": "In Dijkstra's semaphore definition, what does the 'P' operation traditionally stand for?",
                "type": "MCQ",
                "options": ["Proberen (to test)", "Passeren (to pass)", "Prevent (to block)", "Process (to run)"],
                "answer": "Proberen (to test)",
                "bloom": "C1",
                "clo": clos[0],
                "diff": 0.3,
                "explanation": "P stands for the Dutch word 'proberen', meaning to test or wait.",
            },
            # C2 Questions (Understanding)
            {
                "text": "What is the primary operational difference between a counting semaphore and a binary semaphore?",
                "type": "MCQ",
                "options": [
                    "A binary semaphore's integer value is strictly bounded between 0 and 1, whereas counting semaphore values can be arbitrarily positive.",
                    "Counting semaphores prevent deadlocks, whereas binary semaphores cannot.",
                    "Binary semaphores require hardware support, while counting semaphores are pure software.",
                    "Counting semaphores can only be used by two processes simultaneously."
                ],
                "answer": "A binary semaphore's integer value is strictly bounded between 0 and 1, whereas counting semaphore values can be arbitrarily positive.",
                "bloom": "C2",
                "clo": clos[0],
                "diff": 0.4,
                "explanation": "Counting semaphores manage finite resource pools (size N), whereas binary semaphores manage mutual exclusion.",
            },
            {
                "text": "Why does the naïve Dining Philosophers solution suffer from catastrophic deadlock?",
                "type": "MCQ",
                "options": [
                    "If all philosophers attempt to acquire their left chopstick simultaneously, a circular wait chain is established.",
                    "Chopsticks are consumed when a philosopher eats.",
                    "Philosophers experience priority inversion when thinking.",
                    "The operating system context switch limit is exceeded."
                ],
                "answer": "If all philosophers attempt to acquire their left chopstick simultaneously, a circular wait chain is established.",
                "bloom": "C2",
                "clo": clos[1],
                "diff": 0.5,
                "explanation": "Simultaneous acquisition of left chopsticks fulfills all four Coffman conditions.",
            },
            # C3 Questions (Applying)
            {
                "text": "In the Producer-Consumer bounded buffer problem, what occurs if the producer executes wait(mutex) BEFORE wait(empty) when the buffer is full?",
                "type": "MCQ",
                "options": [
                    "Deadlock: The producer holds the mutex while blocked on empty, preventing the consumer from ever freeing a slot.",
                    "Data race: The consumer overwrites the unconsumed buffer slot.",
                    "Starvation: The consumer process terminates abruptly.",
                    "Nothing: Semaphore ordering is commutative and has no effect."
                ],
                "answer": "Deadlock: The producer holds the mutex while blocked on empty, preventing the consumer from ever freeing a slot.",
                "bloom": "C3",
                "clo": clos[1],
                "diff": 0.7,
                "explanation": "Swapping the wait orders causes the producer to sleep holding the buffer lock.",
            },
            {
                "text": "Given Available=[3, 3, 2] and Process P1 with Allocation=[2, 0, 0] and Need=[1, 2, 2], can P1 safely be granted its request under Banker's Algorithm?",
                "type": "MCQ",
                "options": [
                    "Yes, because Need[1, 2, 2] <= Available[3, 3, 2], so the system can transition to a safe execution sequence.",
                    "No, because Available resources would drop below zero.",
                    "No, because P1 is not the highest priority process in the runqueue.",
                    "Yes, but only if P1 releases its allocated resources immediately."
                ],
                "answer": "Yes, because Need[1, 2, 2] <= Available[3, 3, 2], so the system can transition to a safe execution sequence.",
                "bloom": "C3",
                "clo": clos[1],
                "diff": 0.7,
                "explanation": "Since Need <= Available, P1 can finish and release its allocation back into the pool.",
            },
            # C4 Questions (Analyzing)
            {
                "text": "Analyze the following thread sequence: Thread A acquires Lock 1 then Lock 2. Thread B acquires Lock 2 then Lock 1. Which architectural intervention permanently breaks the circular wait condition?",
                "type": "MCQ",
                "options": [
                    "Enforce strict total resource hierarchy ordering (both threads must acquire Lock 1 before Lock 2).",
                    "Increase thread priority for Thread A.",
                    "Increase the number of CPU cores allocated to the virtual machine.",
                    "Replace both locks with standard spinlocks."
                ],
                "answer": "Enforce strict total resource hierarchy ordering (both threads must acquire Lock 1 before Lock 2).",
                "bloom": "C4",
                "clo": clos[2],
                "diff": 0.8,
                "explanation": "Imposing a total order on all resource acquisitions structurally eliminates the circular wait condition.",
            },
            {
                "text": "In a real-time system, a low-priority task holds a mutex required by a high-priority task, while medium-priority tasks starve the high-priority task. What is this phenomenon and its fix?",
                "type": "MCQ",
                "options": [
                    "Priority Inversion; resolved via Priority Inheritance Protocol.",
                    "Deadlock; resolved via Dijkstra's Banker Algorithm.",
                    "Convoy Effect; resolved via Round Robin scheduling.",
                    "Thrashing; resolved via working-set model."
                ],
                "answer": "Priority Inversion; resolved via Priority Inheritance Protocol.",
                "bloom": "C4",
                "clo": clos[2],
                "diff": 0.85,
                "explanation": "Priority Inheritance boosts the lock-holder's priority to match the highest waiting task.",
            },
        ]

        q_count = 0
        for q_data in sample_questions:
            res_q = await session.execute(
                select(QuestionBankItem).where(
                    QuestionBankItem.course_id == course.id,
                    QuestionBankItem.question_text == q_data["text"],
                )
            )
            if not res_q.scalar_one_or_none():
                q_item = QuestionBankItem(
                    question_id=uuid.uuid4(),
                    course_id=course.id,
                    created_by=prof.id,
                    question_text=q_data["text"],
                    question_type=q_data["type"],
                    options=q_data["options"],
                    correct_answer=q_data["answer"],
                    bloom_level=q_data["bloom"],
                    clo_id=q_data["clo"].clo_id,
                    difficulty=q_data["diff"],
                    status="APPROVED",
                    metadata_json={
                        "explanation": q_data["explanation"],
                        "recommended_points": 2.5,
                    },
                )
                session.add(q_item)
                q_count += 1
        await session.flush()
        print(f"  [OK] Seeded {q_count} calibrated questions into question_bank (C1: 25%, C2: 25%, C3: 25%, C4: 25%).")

        # ── 6. Seed Student Quiz Attempts for OBE Analytics ───────────
        res_attempts = await session.execute(
            select(StudentQuizAttempt).where(StudentQuizAttempt.quiz_id == quiz_config.quiz_id)
        )
        if not res_attempts.scalars().first():
            # Create synthetic attempts for students
            scores_map = [18.0, 16.0, 14.5, 11.0, 8.0]  # Realistic grade distribution
            for idx, student in enumerate(students):
                s_score = scores_map[idx]
                attempt_entry = StudentQuizAttempt(
                    attempt_id=uuid.uuid4(),
                    quiz_id=quiz_config.quiz_id,
                    student_id=student.id,
                    started_at=datetime.now(timezone.utc),
                    submitted_at=datetime.now(timezone.utc),
                    auto_score=s_score,
                    answers=[
                        {"clo_id": str(clos[0].clo_id), "earned_score": s_score * 0.35, "max_score": 7.0},
                        {"clo_id": str(clos[1].clo_id), "earned_score": s_score * 0.40, "max_score": 8.0},
                        {"clo_id": str(clos[2].clo_id), "earned_score": s_score * 0.25, "max_score": 5.0},
                    ],
                )
                session.add(attempt_entry)
            await session.flush()
            print(f"  [OK] Seeded {len(students)} student test attempts with CLO telemetry.")

        await session.commit()

    print("\n[SEED COMPLETE] All assessment and OBE test entities populated successfully!")
    print(f"   Course ID:    {course.id} ({course.code})")
    print(f"   Quiz ID:      {quiz_config.quiz_id}")
    print(f"   Professor:    {prof.email} (password: professor123)")
    print(f"   Student:      student1@professoros.edu.pk (password: student123)")


if __name__ == "__main__":
    asyncio.run(seed())
