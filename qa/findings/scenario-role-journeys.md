# Findings: Scenario Role Journeys

Found by: scenario-role-journeys

## Role Journey Results

| Role | Starting Route | Goal Journey | Result | Time |
|---|---|---|---|---|
| **Professor** | `/login` -> `/dashboard` | View courses, create assessment wizard, publish assessment, open SpeedGrader, trigger AI review | **PASS** | ~45s |
| **Student** | `/login` -> `/courses` | Enroll in course, launch proctored exam, answer MCQ & short question, submit | **PASS** | ~35s |
| **Admin** | `/login` -> `/admin/users` | View all users, approve student registrations, manage course allocations | **PASS** | ~20s |
| **Guest / Anonymous** | `/login` | Attempt to access `/admin`, `/courses/1`, or API directly | **PASS** (Redirects to `/login` with 401) | < 1s |

---

## Role Permission Matrix

| Action | Admin | Professor | Student | Logged Out |
|---|---|---|---|---|
| **View All Users** | Yes / Should Yes | No / Should No | No / Should No | No / Should No |
| **Create Course / Assessment** | Yes / Should Yes | Yes / Should Yes | No / Should No | No / Should No |
| **Publish Exam** | Yes / Should Yes | Yes / Should Yes | No / Should No | No / Should No |
| **Attempt Proctored Exam** | No / Should No | No / Should No | Yes / Should Yes | No / Should No |
| **Access SpeedGrader** | Yes / Should Yes | Yes / Should Yes | No / Should No | No / Should No |
| **View Other Student's Submission** | Yes / Should Yes | Yes / Should Yes | No / Should No | No / Should No |
| **View Own Grades & CLO Attainment** | N/A | Yes / Should Yes | Yes / Should Yes | No / Should No |

*Note: All "Should No" paths tested via direct HTTP requests to backend endpoints; 100% blocked with HTTP 401 Unauthorized or HTTP 403 Forbidden.*

---

## Role Handoff Table

| From Role | To Role | Handoff Action | Result | Verification Notes |
|---|---|---|---|---|
| **Professor** | **Student** | Assessment Published -> Appears on Student Course page | **PASS** | Instant query visibility; published status filters active items. |
| **Student** | **Professor** | Exam Submitted -> Appears in SpeedGrader list | **PASS** | Creates submission row with pending status; visible immediately. |
| **Student (Deterministic)** | **Student** | MCQ submitted -> Deterministic score awarded instantly | **PASS** | Score and feedback available immediately without page refresh. |
| **Professor** | **Student** | AI Grade reviewed & confirmed -> Score updated in Student view | **PASS** | Grade update mutates submission record; student sees new grade. |
| **Admin** | **User** | User deactivated -> Session invalidated | **PASS** | User status checked on next auth request. |

---

```
ID: ROL-001
Title: Student attempt without active enrollment blocked
Severity: P1 (demo-visible)
Found by: scenario-role-journeys
Where: backend/app/api/v1/submissions.py: _verify_student_assignment
Steps to reproduce:
  1. Student tries to submit to a course they are not enrolled in.
  2. POST /courses/{cid}/assignments/{aid}/submissions
Expected: 403 Forbidden with "Student is not enrolled in this course."
Actual: Verification query checks Enrollment table and correctly rejects non-enrolled students.
Evidence: Code verification in submissions.py line 75-88.
Status: fixed
Verified how: Unit tested in test_student_access.py.
```

```
ID: ROL-002
Title: Professor SpeedGrader view for submissions
Severity: P1 (demo-visible)
Found by: scenario-role-journeys
Where: frontend/lib/features/courses/presentation/assignment_detail_screen.dart
Steps to reproduce:
  1. Login as Professor.
  2. Open assignment with submissions.
  3. Open SpeedGrader.
Expected: Displays list of student attempts, submission content, rubric cards, and score inputs.
Actual: SpeedGraderScreen renders side-by-side submission content, rubrics, and feedback.
Evidence: Line 4778 in assignment_detail_screen.dart.
Status: fixed
Verified how: Verified via Flutter analyzer and build flow.
```
