# Findings: Scenario Role Journeys

Found by: scenario-role-journeys

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
