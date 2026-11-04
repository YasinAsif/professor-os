"""ProfessorOS – Clean Demo Showcase Seeder.

Configures exactly 4 clean courses for:
  - Professor: prof@example.com (Dr. Yasin)
  - Student: student@example.com (Ali Student)

Pre-populates primary course (Data Structures) with:
  - HEC OBE CLOs (CLO-1, CLO-2, CLO-3)
  - 1 MCQ Quiz (10 marks / 10% weight) -> Student scored 8/10
  - 1 Assignment (20 marks / 20% weight) -> Student scored 16/20
  - 1 Midterm Exam (20 marks fixed / 20% weight) -> Student scored 10/20 (50%)
  - 1 Final Exam (50 marks fixed / 50% weight) -> Student scored 40/50 (80%)
  - Total composite score = 74/100 (Grade B)

Reassigns all other courses to secondary professor and removes extra enrollments for demo student.
"""

import asyncio
import json
import os
import sys
from datetime import datetime, timezone, timedelta

sys.path.insert(0, os.path.abspath('backend'))

from sqlalchemy import select, delete, text
from app.db.base import async_session
from app.models.user import User, UserRole
from app.models.course import Course, Enrollment, CLO
from app.models.assignment import Assignment, AssignmentType, AssignmentStatus
from app.models.submission import Submission, SubmissionStatus, SubmissionType
from app.models.rubric import Rubric, RubricCriterion, RubricLevel


async def seed_demo():
    print("==================================================")
    print(" ProfessorOS: Seeding Clean Demo Showcase Data")
    print("==================================================")

    async with async_session() as session:
        # 1. Identify Demo Professor & Student
        prof = (await session.execute(
            select(User).where(User.email == "prof@example.com")
        )).scalar_one_or_none()
        if not prof:
            raise RuntimeError("prof@example.com not found!")

        stud = (await session.execute(
            select(User).where(User.email == "student@example.com")
        )).scalar_one_or_none()
        if not stud:
            raise RuntimeError("student@example.com not found!")

        # Identify secondary professor to hold non-demo courses
        sec_prof = (await session.execute(
            select(User).where(User.email == "dr.tariq@professoros.edu.pk")
        )).scalar_one_or_none()
        if not sec_prof:
            # pick any other prof or admin
            other = (await session.execute(
                select(User).where(User.id != prof.id, User.role == UserRole.PROFESSOR.value)
            )).scalars().first()
            if not other:
                other = (await session.execute(
                    select(User).where(User.id != prof.id)
                )).scalars().first()
            sec_prof = other

        print(f"Primary Professor : {prof.full_name} (ID: {prof.id}, {prof.email})")
        print(f"Primary Student   : {stud.full_name} (ID: {stud.id}, {stud.email})")
        print(f"Secondary Owner   : {sec_prof.full_name} (ID: {sec_prof.id}, {sec_prof.email})")

        # 2. Select & Polish 4 Core Demo Courses
        # Primary: 97 (Data Structures), 117 (OS), 100 (AI), 92 (Database)
        c97 = await session.get(Course, 97)
        c117 = await session.get(Course, 117)
        c100 = await session.get(Course, 100)
        c92 = await session.get(Course, 92)

        demo_courses = [c97, c117, c100, c92]
        if any(c is None for c in demo_courses):
            raise RuntimeError("One or more target demo courses (97, 117, 100, 92) not found!")

        # Update metadata to look crisp and professional
        c97.code = "CS-301"
        c97.title = "Data Structures & Algorithms"
        c97.semester = "Spring 2027"
        c97.description = "Core course on fundamental linear & hierarchical data structures, sorting, trees, and graph algorithms with rigorous OBE alignment."
        c97.professor_id = prof.id
        c97.is_archived = False

        c117.code = "CS-302"
        c117.title = "Operating Systems"
        c117.semester = "Spring 2027"
        c117.description = "Process scheduling, thread concurrency, memory virtualization, synchronization primitives, and distributed file systems."
        c117.professor_id = prof.id
        c117.is_archived = False

        c100.code = "AI-214"
        c100.title = "Artificial Intelligence & Intelligent Systems"
        c100.semester = "Spring 2027"
        c100.description = "State-space heuristic search, adversarial game trees, knowledge representation, probabilistic inference, and machine learning foundations."
        c100.professor_id = prof.id
        c100.is_archived = False

        c92.code = "CS-212"
        c92.title = "Database Systems & Engineering"
        c92.semester = "Spring 2027"
        c92.description = "Relational database schema modeling, SQL query optimization, transactions, ACID properties, and normal forms."
        c92.professor_id = prof.id
        c92.is_archived = False

        demo_course_ids = {c97.id, c117.id, c100.id, c92.id}

        # 3. Reassign all OTHER courses owned by prof to secondary professor
        reassign_res = await session.execute(
            select(Course).where(Course.professor_id == prof.id, Course.id.notin_(demo_course_ids))
        )
        other_courses = reassign_res.scalars().all()
        for oc in other_courses:
            oc.professor_id = sec_prof.id
        print(f"Reassigned {len(other_courses)} other courses from Dr. Yasin to {sec_prof.full_name}.")

        # 4. Enforce Student Enrollments (Only in the 4 demo courses)
        # Delete student enrollments in non-demo courses
        await session.execute(
            delete(Enrollment).where(Enrollment.user_id == stud.id, Enrollment.course_id.notin_(demo_course_ids))
        )
        # Ensure student is enrolled in all 4 demo courses
        for cid in demo_course_ids:
            enr_check = (await session.execute(
                select(Enrollment).where(Enrollment.user_id == stud.id, Enrollment.course_id == cid)
            )).scalar_one_or_none()
            if not enr_check:
                session.add(Enrollment(course_id=cid, user_id=stud.id, role="student"))

        print("Enforced student enrollments strictly to the 4 demo courses.")

        # 5. Populate CLOs for Primary Course (CS-301 Data Structures)
        existing_clos = (await session.execute(
            select(CLO).where(CLO.course_id == c97.id)
        )).scalars().all()
        clo_map = {c.code: c for c in existing_clos}

        clo_specs = [
            ("CLO-1", "Analyze and implement linear data structures, heaps, and tree traversal algorithms."),
            ("CLO-2", "Evaluate time and space complexity using asymptotic Big-O notation for complex algorithms."),
            ("CLO-3", "Design and optimize balanced search trees and shortest path graph algorithms under strict constraints."),
        ]
        clos_list = []
        for code, desc in clo_specs:
            if code in clo_map:
                clo_obj = clo_map[code]
                clo_obj.description = desc
            else:
                clo_obj = CLO(course_id=c97.id, code=code, description=desc)
                session.add(clo_obj)
            clos_list.append(clo_obj)
        await session.flush()
        print(f"Ensured {len(clos_list)} CLOs for CS-301.")

        # 6. Populate Complete 4-Component OBE Assessments in CS-301
        # Delete old assignments for c97 to make it fresh and clean
        old_assigns = (await session.execute(
            select(Assignment).where(Assignment.course_id == c97.id)
        )).scalars().all()
        for oa in old_assigns:
            await session.delete(oa)
        await session.flush()

        now = datetime.now(timezone.utc)
        past_week = now - timedelta(days=7)
        past_2weeks = now - timedelta(days=14)
        past_month = now - timedelta(days=30)
        future_week = now + timedelta(days=7)

        # ── (A) Quiz 01 (MCQs Only) ──────────────────────────────────
        mcq_payload = json.dumps({
            "type": "mcq",
            "category": "quiz",
            "instructions": "Attempt all multiple choice questions. Each question carries 2 marks.",
            "questions": [
                {
                    "question": "What is the worst-case time complexity of searching in an AVL Tree?",
                    "options": ["O(1)", "O(log N)", "O(N)", "O(N log N)"],
                    "correct": 1
                },
                {
                    "question": "Which data structure operates on a Last-In First-Out (LIFO) basis?",
                    "options": ["Queue", "Stack", "Binary Heap", "Hash Table"],
                    "correct": 1
                },
                {
                    "question": "What is the worst-case time complexity of standard QuickSort?",
                    "options": ["O(log N)", "O(N)", "O(N log N)", "O(N^2)"],
                    "correct": 3
                },
                {
                    "question": "Which data structure is typically used to implement Breadth-First Search (BFS)?",
                    "options": ["Queue", "Stack", "Priority Queue", "Disjoint Set"],
                    "correct": 0
                },
                {
                    "question": "What is the space complexity of an adjacency list graph representation with V vertices and E edges?",
                    "options": ["O(V^2)", "O(E^2)", "O(V + E)", "O(V * E)"],
                    "correct": 2
                }
            ]
        })
        a_quiz = Assignment(
            course_id=c97.id,
            title="Quiz 01: Core Concepts & Complexity (MCQs)",
            description=mcq_payload,
            type=AssignmentType.MCQ,
            category="quiz",
            max_marks=10.0,
            weightage=10.0,
            time_limit_minutes=20,
            allow_late=False,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=past_2weeks,
            show_results_after=True,
            created_at=past_month,
        )
        a_quiz.clos = [clos_list[0], clos_list[1]]
        session.add(a_quiz)
        await session.flush()

        # Submission for Quiz: Score 8.0 / 10.0
        sub_quiz = Submission(
            assignment_id=a_quiz.id,
            student_id=stud.id,
            submission_type=SubmissionType.MCQ.value,
            content=json.dumps({"answers": {"0": 1, "1": 1, "2": 3, "3": 0, "4": 0}}),  # 4 correct, 1 wrong
            status=SubmissionStatus.GRADED.value,
            score=8.0,
            feedback="Strong conceptual foundation. 4 out of 5 questions answered accurately.",
            graded_by_id=prof.id,
            submitted_at=past_2weeks - timedelta(hours=2),
            graded_at=past_2weeks - timedelta(hours=1),
        )
        session.add(sub_quiz)

        # ── (B) Assignment 01 (Written / Code) ───────────────────────
        assign_payload = json.dumps({
            "type": "text",
            "category": "assignment",
            "instructions": "Implement self-balancing AVL rotation methods and analyze balance factor invariants.",
            "questions": [
                {
                    "question": "Implement left and right rotation methods for an AVL tree node to restore height balance invariant.",
                    "reference_answer": "Node rightRotate(Node y) { Node x = y.left; Node T2 = x.right; x.right = y; y.left = T2; updateHeight(y); updateHeight(x); return x; }",
                    "marks": 10.0
                },
                {
                    "question": "Explain how Dijkstra's algorithm determines shortest paths using a Min-Heap priority queue.",
                    "reference_answer": "Initialize distances to infinity except source at 0. Push (0, source) into min-heap. Iteratively extract minimum distance vertex and relax outgoing edges.",
                    "marks": 10.0
                }
            ]
        })
        a_assign = Assignment(
            course_id=c97.id,
            title="Assignment 01: Self-Balancing Trees & Graph Traversal",
            description=assign_payload,
            type=AssignmentType.TEXT,
            category="assignment",
            max_marks=20.0,
            weightage=20.0,
            time_limit_minutes=None,
            allow_late=True,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=past_week,
            show_results_after=True,
            created_at=past_month,
        )
        a_assign.clos = [clos_list[0], clos_list[2]]
        session.add(a_assign)
        await session.flush()

        # Add Rubric for Assignment 01
        rub = Rubric(assignment_id=a_assign.id)
        session.add(rub)
        await session.flush()
        crit1 = RubricCriterion(rubric_id=rub.id, name="Implementation Correctness", weight=40.0)
        crit2 = RubricCriterion(rubric_id=rub.id, name="Algorithmic Complexity", weight=30.0)
        crit3 = RubricCriterion(rubric_id=rub.id, name="Code Documentation & Style", weight=30.0)
        session.add_all([crit1, crit2, crit3])

        # Submission for Assignment: Score 16.0 / 20.0
        sub_assign = Submission(
            assignment_id=a_assign.id,
            student_id=stud.id,
            submission_type=SubmissionType.TEXT.value,
            content="""### AVL Tree Rotation Implementation
```python
def right_rotate(y):
    x = y.left
    t2 = x.right
    x.right = y
    y.left = t2
    y.height = 1 + max(get_height(y.left), get_height(y.right))
    x.height = 1 + max(get_height(x.left), get_height(x.right))
    return x
```
Dijkstra's shortest path runs in O((V + E) log V) using a binary min-heap.""",
            status=SubmissionStatus.GRADED.value,
            score=16.0,
            feedback="Excellent implementation of AVL rotation logic. Code is well modularized.",
            graded_by_id=prof.id,
            submitted_at=past_week - timedelta(hours=5),
            graded_at=past_week - timedelta(hours=2),
        )
        session.add(sub_assign)

        # ── (C) Midterm Examination (20 marks fixed) ─────────────────
        # Exactly 4 questions of 5.0 marks each as required by HEC rules
        midterm_payload = json.dumps({
            "type": "text",
            "category": "midterm",
            "instructions": "Midterm Examination covering Asymptotic Analysis, Hash Tables, and Heaps. Answer all 4 questions.",
            "questions": [
                {
                    "question": "Apply the Master Theorem to solve T(n) = 2T(n/2) + O(n). State the case and final asymptotic bound.",
                    "reference_answer": "a=2, b=2, log_b(a)=1, f(n)=O(n). Case 2 applies. T(n) = Theta(n log n).",
                    "marks": 5.0
                },
                {
                    "question": "Compare separate chaining and open addressing with linear probing for hash table collision resolution.",
                    "reference_answer": "Chaining uses auxiliary linked lists per bucket with unbounded capacity. Open addressing stores all entries directly in array but degrades under high load factors.",
                    "marks": 5.0
                },
                {
                    "question": "Demonstrate the construction of a Min-Heap from array [12, 5, 78, 1, 33] using the bottom-up heapify algorithm.",
                    "reference_answer": "Represent as tree. Apply percolate-down starting at last internal parent. Resulting heap array: [1, 5, 78, 12, 33].",
                    "marks": 5.0
                },
                {
                    "question": "Analyze the trade-offs between singly and doubly linked lists regarding memory consumption and deletion time complexity.",
                    "reference_answer": "Singly linked lists save pointer space (one pointer per node). Doubly linked lists permit O(1) node deletion given a pointer to the node.",
                    "marks": 5.0
                }
            ]
        })
        a_mid = Assignment(
            course_id=c97.id,
            title="Midterm Examination (Spring 2027)",
            description=midterm_payload,
            type=AssignmentType.TEXT,
            category="midterm",
            max_marks=20.0,
            weightage=20.0,
            time_limit_minutes=60,
            allow_late=False,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=past_week - timedelta(days=3),
            show_results_after=True,
            created_at=past_month,
        )
        a_mid.clos = [clos_list[0], clos_list[1]]
        session.add(a_mid)
        await session.flush()

        # Submission for Midterm: Score 10.0 / 20.0 (50%) as requested!
        sub_mid = Submission(
            assignment_id=a_mid.id,
            student_id=stud.id,
            submission_type=SubmissionType.TEXT.value,
            content="Student written exam submission for Midterm 2027. Completed questions 1 through 4 with step-by-step mathematical proofs.",
            status=SubmissionStatus.GRADED.value,
            score=10.0,
            feedback="Satisfactory performance. Q1 and Q4 solved accurately. Need to review heap percolate-down steps.",
            graded_by_id=prof.id,
            submitted_at=past_week - timedelta(days=3, hours=1),
            graded_at=past_week - timedelta(days=2),
        )
        session.add(sub_mid)

        # ── (D) Final Examination (50 marks fixed) ───────────────────
        # Exactly 5 questions of 10.0 marks each as required by HEC rules
        final_payload = json.dumps({
            "type": "text",
            "category": "final",
            "instructions": "Comprehensive Final Examination covering all course learning outcomes. Answer all 5 questions.",
            "questions": [
                {
                    "question": "Prove the correctness of Bellman-Ford algorithm and demonstrate negative cycle detection.",
                    "reference_answer": "Relax all |V|-1 edges. A further relaxation indicating decrease in distance confirms negative weight cycle reachable from source.",
                    "marks": 10.0
                },
                {
                    "question": "Detail the Red-Black Tree balancing invariants and explain node recoloring vs rotation during insertion.",
                    "reference_answer": "Invariants: Root is black, leaves are black, red nodes have black children, all root-leaf paths have same black-height. Uncle color determines case.",
                    "marks": 10.0
                },
                {
                    "question": "Solve the 0/1 Knapsack problem using dynamic programming with optimal substructure proof and state transition table.",
                    "reference_answer": "dp[i][w] = max(dp[i-1][w], val[i-1] + dp[i-1][w-wt[i-1]]). Space can be optimized to 1D array.",
                    "marks": 10.0
                },
                {
                    "question": "Explain Disjoint Set Union (DSU) data structure with Union by Rank and Path Compression optimizations.",
                    "reference_answer": "Find flattens tree path. Union attaches shallower tree under deeper root. Achieves O(alpha(N)) inverse Ackermann time per operation.",
                    "marks": 10.0
                },
                {
                    "question": "Design a Trie (Prefix Tree) supporting insert, search, and prefix matching with runtime complexity proofs.",
                    "reference_answer": "Each node contains array/map of child pointers and is_end flag. Insert and search run in O(L) where L is key length.",
                    "marks": 10.0
                }
            ]
        })
        a_final = Assignment(
            course_id=c97.id,
            title="Final Comprehensive Examination (Spring 2027)",
            description=final_payload,
            type=AssignmentType.TEXT,
            category="final",
            max_marks=50.0,
            weightage=50.0,
            time_limit_minutes=120,
            allow_late=False,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=past_week + timedelta(days=1),
            show_results_after=True,
            created_at=past_month,
        )
        a_final.clos = [clos_list[0], clos_list[1], clos_list[2]]
        session.add(a_final)
        await session.flush()

        # Submission for Final: Score 40.0 / 50.0 (80%) as requested!
        sub_final = Submission(
            assignment_id=a_final.id,
            student_id=stud.id,
            submission_type=SubmissionType.TEXT.value,
            content="Student complete final exam answers for questions 1 through 5 with code snippets and asymptotic complexity charts.",
            status=SubmissionStatus.GRADED.value,
            score=40.0,
            feedback="Commendable exam attempt! Rigorous dynamic programming formulation and accurate Disjoint Set heuristics.",
            graded_by_id=prof.id,
            submitted_at=past_week,
            graded_at=past_week + timedelta(hours=6),
        )
        session.add(sub_final)

        # ── (E) Add lightweight assignments to other 3 courses ───────
        # Course 117: Operating Systems
        a_os_quiz = Assignment(
            course_id=c117.id,
            title="Quiz 01: Process Synchronization & Threads (MCQs)",
            description=json.dumps({
                "type": "mcq",
                "category": "quiz",
                "questions": [
                    {"question": "What is a race condition in concurrent programming?", "options": ["Deadlock", "Shared memory corruption due to unsynchronized access", "Infinite loop", "Cache miss"], "correct": 1},
                    {"question": "Which primitive provides mutual exclusion and signaling?", "options": ["Mutex", "Counting Semaphore", "Spinlock", "Barrier"], "correct": 1}
                ]
            }),
            type=AssignmentType.MCQ,
            category="quiz",
            max_marks=10.0,
            weightage=10.0,
            time_limit_minutes=15,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=future_week,
        )
        session.add(a_os_quiz)

        # Course 100: Artificial Intelligence
        a_ai_quiz = Assignment(
            course_id=c100.id,
            title="Quiz 01: A* Search & Admissibility (MCQs)",
            description=json.dumps({
                "type": "mcq",
                "category": "quiz",
                "questions": [
                    {"question": "A heuristic h(n) is admissible if:", "options": ["It never underestimates cost to goal", "It never overestimates cost to goal", "It equals the true cost", "It is negative"], "correct": 1},
                    {"question": "What is the space complexity of standard Breadth-First Search (BFS)?", "options": ["O(d)", "O(b^d)", "O(b*d)", "O(1)"], "correct": 1}
                ]
            }),
            type=AssignmentType.MCQ,
            category="quiz",
            max_marks=10.0,
            weightage=10.0,
            time_limit_minutes=15,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=future_week,
        )
        session.add(a_ai_quiz)

        # Course 92: Database Systems
        a_db_assign = Assignment(
            course_id=c92.id,
            title="Assignment 01: E-R Relational Schema & 3NF Normalization",
            description="Design normalized 3NF schemas for high-concurrency university registration system.",
            type=AssignmentType.TEXT,
            category="assignment",
            max_marks=20.0,
            weightage=20.0,
            status=AssignmentStatus.PUBLISHED.value,
            deadline=future_week,
        )
        session.add(a_db_assign)

        await session.commit()

        print("\n==================================================")
        print(" SUCCESS: Demo showcase data populated!")
        print("  1. Dr. Yasin now sees EXACTLY 4 courses:")
        print(f"     - [CS-301] {c97.title}")
        print(f"     - [CS-302] {c117.title}")
        print(f"     - [AI-214] {c100.title}")
        print(f"     - [CS-212] {c92.title}")
        print("  2. Ali Student is enrolled in EXACTLY the same 4 courses.")
        print("  3. CS-301 Primary Showcase Course has:")
        print("     - Quiz 01 (MCQs, 10 marks, weight 10%) -> Graded: 8/10")
        print("     - Assignment 01 (Text, 20 marks, weight 20%) -> Graded: 16/20")
        print("     - Midterm Exam (Text, 20 marks, weight 20%) -> Graded: 10/20 (50%)")
        print("     - Final Exam (Text, 50 marks, weight 50%) -> Graded: 40/50 (80%)")
        print("     - Composite OBE Score: 10 + 40 + (8 + 16) = 74 / 100 (Grade B)")
        print("==================================================")


if __name__ == "__main__":
    asyncio.run(seed_demo())
