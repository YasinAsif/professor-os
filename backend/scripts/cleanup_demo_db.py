"""ProfessorOS Demo Database Cleanup Script.

Idempotently normalizes demo data:
1. Clears existing attempts & submissions for Assignment 12 (Assignment 01 in Course 69/60)
   so student@example.com can freshly start the quiz.
2. Updates Assignment 12 with 3 realistic Parallel Computing MCQs (15 pts total).
3. Safely cascades deletions for junk/test assignments (IDs 6, 7, 10, 14, 15).
4. Safely removes dummy master courses (Test1 CS11 and TEST2).
5. Normalizes all active course weightages to standard OBE: 20/50/15/15.
6. Cleans up faculty display names in users table.
"""

import asyncio
import json
import logging
from sqlalchemy import text
from app.db.base import async_session

logger = logging.getLogger("professor_os.cleanup")


async def run_demo_cleanup():
    async with async_session() as session:
        try:
            # 1. Clear any student attempts/submissions for Assignment 12 (Assignment 01)
            await session.execute(text("""
                DELETE FROM exam_violations 
                WHERE attempt_id IN (
                    SELECT id FROM exam_attempts WHERE assignment_id = 12
                )
            """))
            await session.execute(text("""
                DELETE FROM grade_appeals 
                WHERE submission_id IN (
                    SELECT id FROM submissions WHERE assignment_id = 12
                )
            """))
            await session.execute(text("""
                DELETE FROM submissions WHERE assignment_id = 12
            """))
            await session.execute(text("""
                DELETE FROM exam_attempts WHERE assignment_id = 12
            """))

            # 2. Update Assignment 12 with 3 realistic Parallel Computing MCQs (15 pts)
            mcq_payload = json.dumps({
                "type": "mcq",
                "instructions": "Attempt all 3 questions. Each question carries 5 marks (Total: 15 Marks). Proctored focus mode active.",
                "questions": [
                    {
                        "question": "According to Amdahl's Law, if 80% of a program can be parallelized, what is the theoretical maximum speedup achievable on an infinite number of processors?",
                        "options": ["4x", "5x", "8x", "10x"],
                        "correct": 1
                    },
                    {
                        "question": "Which programming model relies on explicit message passing between distinct nodes with private address spaces rather than shared global memory?",
                        "options": [
                            "OpenMP",
                            "POSIX Threads (pthreads)",
                            "MPI (Message Passing Interface)",
                            "CUDA Unified Memory"
                        ],
                        "correct": 2
                    },
                    {
                        "question": "In concurrent programming, what fundamental synchronization primitive is designed to enforce mutual exclusion on a shared critical section?",
                        "options": [
                            "Barrier",
                            "Mutex (Mutual Exclusion Lock)",
                            "Atomic Spinlock",
                            "Condition Variable"
                        ],
                        "correct": 1
                    }
                ]
            })

            await session.execute(text("""
                UPDATE assignments
                SET title = 'Assignment 01',
                    max_marks = 15.0,
                    weightage = 15.0,
                    category = 'assignment',
                    type = 'mcq',
                    description = :payload
                WHERE id = 12
            """), {"payload": mcq_payload})

            # 3. Cascading removal of junk/test assessments (IDs 6, 7, 10, 14, 15)
            junk_ids = [6, 7, 10, 14, 15]
            await session.execute(text("""
                DELETE FROM exam_violations 
                WHERE attempt_id IN (
                    SELECT id FROM exam_attempts WHERE assignment_id = ANY(:jids)
                )
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM grade_appeals 
                WHERE submission_id IN (
                    SELECT id FROM submissions WHERE assignment_id = ANY(:jids)
                )
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM submissions WHERE assignment_id = ANY(:jids)
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM exam_attempts WHERE assignment_id = ANY(:jids)
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM assignment_clos WHERE assignment_id = ANY(:jids)
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM rubric_criteria WHERE rubric_id IN (
                    SELECT id FROM rubrics WHERE assignment_id = ANY(:jids)
                )
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM rubrics WHERE assignment_id = ANY(:jids)
            """), {"jids": junk_ids})
            await session.execute(text("""
                DELETE FROM assignments WHERE id = ANY(:jids)
            """), {"jids": junk_ids})

            # 4. Safe removal of dummy master courses (Test1 CS11 and TEST2)
            await session.execute(text("""
                UPDATE courses 
                SET master_course_id = NULL 
                WHERE master_course_id IN (69, 70) 
                   OR master_course_id IN (
                       SELECT id FROM master_courses 
                       WHERE code IN ('CS11', 'TEST2') OR title ILIKE 'test%'
                   )
            """))
            await session.execute(text("""
                DELETE FROM master_courses 
                WHERE code IN ('CS11', 'TEST2') OR title ILIKE 'test%' OR id IN (69, 70)
            """))

            # 5. Course Weightage Normalization (Midterm=20, Final=50, Quiz=15, Assignment=15)
            await session.execute(text("""
                UPDATE courses
                SET midterm_weight = 20,
                    final_weight = 50,
                    quiz_weight = 15,
                    assignment_weight = 15
                WHERE is_archived IS NOT TRUE
            """))

            # 6. Faculty Names Cleanup
            await session.execute(text("""
                UPDATE users 
                SET full_name = 'Engr. Rayyan Shahid' 
                WHERE email = 'rayyanmirza368@gmail.com' OR full_name ILIKE '%rayyan shahid%'
            """))
            await session.execute(text("""
                UPDATE users 
                SET full_name = 'Dr. Yasin Asif' 
                WHERE email = 'yasif9155@gmail.com' OR (role = 'professor' AND full_name = 'Yasin Asif')
            """))
            await session.execute(text("""
                UPDATE users 
                SET full_name = 'Dr. Waseem' 
                WHERE email = 'waseem.ssc@stmu.edu.pk' OR full_name = 'Dr Waseem'
            """))

            await session.commit()
            logger.info("Demo database cleanup executed successfully.")
        except Exception as e:
            await session.rollback()
            logger.warning("Demo cleanup notice: %s", e)


if __name__ == "__main__":
    import sys
    sys.path.insert(0, ".")
    asyncio.run(run_demo_cleanup())
