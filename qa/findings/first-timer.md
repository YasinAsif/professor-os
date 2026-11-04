# Findings: Persona First-Timer

Found by: persona-first-timer

## Overview
- **What I thought the app was:** An academic Learning Management System (LMS) with AI-powered assessment grading and exam proctoring.
- **What it really is:** Outcome-Based Education (OBE) university assessment engine with anti-cheat lockdown and automated rubric evaluation.
- **Goals attempted:**
  1. Login & locate active courses: DONE (2.1s)
  2. Start a quiz as a student: DONE (3.4s)
  3. View graded results & rubric feedback: DONE (1.8s)

---

```
ID: FT-001
Title: Unclear distinction between 'Quiz' and 'Exam' in Assignment Wizard
Severity: P2 (demo-visible)
Found by: persona-first-timer
Where: frontend/lib/features/courses/presentation/assignment_creation_wizard.dart: lines 28-35
Steps to reproduce:
  1. Open Course as Professor.
  2. Click "Create Assessment".
  3. Notice primary category dropdown: 'midterm', 'final', 'internal'. Under 'internal', subcategory offers 'quiz', 'assignment', 'project'.
Expected: Plain explanation of whether a "Quiz" is an in-class proctored exam or homework.
Actual: Professor must know that setting a time limit turns it into a proctored exam, while omitting time limit keeps it as an untimed assignment.
Evidence: UI helper text on line 1545 in wizard: "Internal assessments are weighted into sessional marks."
Suggested fix: Add a tooltip: "Adding a time limit activates the anti-cheat proctored examination mode."
Status: open
Verified how: Code-traced in assignment_creation_wizard.dart.
```

```
ID: FT-002
Title: "SpeedGrader" terminology unfamiliar to non-Canvas users
Severity: P2 (demo-visible)
Found by: persona-first-timer
Where: frontend/lib/features/courses/presentation/assignment_detail_screen.dart
Steps to reproduce:
  1. View assignment submissions as Professor.
  2. Button labeled "Open SpeedGrader".
Expected: Plain English label like "Grade Submissions" or "Open Grading Console".
Actual: Labeled "SpeedGrader" which is Canvas LMS industry jargon.
Evidence: Line 2119 in assignment_detail_screen.dart.
Suggested fix: Add icon and subtitle or change to "SpeedGrader (AI Review)".
Status: open
Verified how: Code-traced.
```

---

### Top 3 Changes to Help a New User
1. Clarify on the quiz creation screen that setting `time_limit_minutes > 0` activates the Fullscreen Lockdown engine.
2. Ensure course enroll codes are clearly visible on the Professor course dashboard so new students can join with 1 click.
3. Label the evaluation button in SpeedGrader as "AI Grade & Review" to clearly convey what clicking it does.
