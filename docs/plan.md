# Plan: Critical Demo-Blockers & UI/Flow Fixes (docs/plan.md)

## 1. Problem
- **Who has this problem:** Students attempting exams/quizzes, Professors creating assessments and running AI evaluations, and users logging in.
- **What they do today instead:**
  - Students opening exams see a blank question area or unparsed JSON and only 1 answer field for multi-question exams.
  - Professors triggering AI grading encounter pipeline validation failures.
  - Assessment category selection and semester dropdowns show confusing/unconstrained options.
  - Students and faculty manually retype credentials without browser autocomplete.
- **Why it is painful enough to switch:** Critical demo-blocker for upcoming presentation/defense; live evaluation cannot proceed if students cannot take exams and AI cannot grade submissions.

## 2. Solution in one paragraph
Resolve exam rendering for both structured written questions and MCQs by parsing rich JSON descriptions (including instructions and multiple questions), rendering dedicated per-question submission boxes for multi-question exams (e.g. 4-question Midterm), robustly serializing multi-question answers into submission drafts, patching AI grading schema aliases and rounding tolerance, hiding rubric builder when configuring MCQs, reordering category selector to (1. Internal Assessment, 2. Midterm, 3. Final Exam), locking the semester dropdown to Fall 2026 and Spring 2027, and enabling browser autofill on the login screen.

## 3. Scope
In:
- Exam Screen rendering: correctly parse `_effectiveDescription`, handle both MCQ and structured multi-question text exams (midterm/final).
- Multi-question submission UI: render individual text fields for each question in a multi-question midterm/final exam, collecting all responses on save/heartbeat/submit.
- AI Grading Pipeline: add missing schema aliases (`criterion_evaluations`, `points_earned`, `max_points`, `overall_feedback`), clarify JSON output prompt, and reconcile floating-point score rounding differences gracefully.
- MCQ Rubric visibility: hide Rubric Builder step when creating MCQs and allow MCQ publish without manual rubric setup.
- Category sorting: reorder UI cards to 1. Internal Assessment, 2. Midterm, 3. Final Exam.
- Academic semester lockdown: restrict semester dropdown in course creation to 'Fall 2026' and 'Spring 2027', with Fall 2026 as active default.
- Login autocomplete: add `AutofillGroup` and `autofillHints: [AutofillHints.email, AutofillHints.username]` to the login screen.

Out (not now):
- Dropping MCQ models completely from database schema (retaining backward compatibility while hiding rubrics for MCQs).
- Full redesign of question builder.

## 4. Acceptance criteria
- [x] AC1: When a student opens a multi-question exam (e.g., 4-question Midterm), each question's prompt, marks, and individual answer text box render cleanly.
- [x] AC2: When an exam has MCQs, the MCQ questions and options render with selectable radio buttons.
- [x] AC3: When taking a 4-question Midterm, answers for each question are captured, autosaved via heartbeat, and submitted in full.
- [x] AC4: AI grading pipeline successfully completes structured evaluation for submissions without Pydantic schema validation errors.
- [x] AC5: In Assessment Creation Wizard, when building an MCQ assessment, the Rubric Builder step is completely hidden.
- [x] AC6: In Assessment Creation Wizard, the primary categories are ordered: 1. Internal Assessment, 2. Midterm, 3. Final Exam.
- [x] AC7: In Create Course Screen, the semester dropdown only allows selecting 'Fall 2026' or 'Spring 2027', defaulting to 'Fall 2026'.
- [x] AC8: The login screen's email input has browser autocomplete enabled with appropriate autofill hints.

## 5. Slices (build order)
1. **Slice 1: AI Engine Patch** — Update `GradingEvaluationSchema`, `CriterionGradingResult`, and user prompt in `backend/app/services/grading_pipeline.py` to handle all model outputs robustly and prevent crashes.
2. **Slice 2: Exam Rendering & Multi-Question Submission Boxes** — Update `ExamScreen` in `frontend/lib/features/courses/presentation/exam_screen.dart` to parse multi-question payloads, render individual answer text boxes for each question, and serialize them seamlessly into drafts and submissions.
3. **Slice 3: Assessment Creation UI Tweaks (Category Order & MCQ Rubric Hiding)** — Update `frontend/lib/features/courses/presentation/assignment_creation_wizard.dart` and backend publish validation to hide rubric for MCQs and reorder categories.
4. **Slice 4: Semester Dropdown Lockdown & Login Autofill** — Restrict semesters in `create_course_screen.dart` and add autofill hints to `login_screen.dart`.
5. **Slice 5: Verification & Tests** — Execute backend test suites and Flutter test suites to ensure zero regressions.

## 6. Tradeoffs and open questions
| Question | Options | Recommendation | Cost if wrong |
|----------|---------|----------------|---------------|
| Delete MCQs or keep & hide rubrics? | A: Delete MCQ models from DB; B: Keep MCQ support but hide rubric builder in UI. | B: Keep MCQ support, hide Rubric builder when building MCQs. | Low; avoids breaking existing database records and tests. |
| Multi-question answer draft format | A: JSON array in draft; B: Tagged envelope formatted text. | B: Keep tagged envelope compatible with backend `unpack_draft_answers` while supporting multi-question text blocks. | Low; ensures backend and speedgrader render correctly without migration. |

## 7. Risks
- Technical: Flutter exam state machine and proctor listeners must remain intact during multi-question rendering.
- Time: Fast turnaround needed for upcoming demo.

## 9. Phase 2: Full Student & Professor Flow Hardening

### Acceptance Criteria (Phase 2)
- [x] AC9: In `ExamScreen`, starting a fresh proctored exam immediately populates the question description without requiring an F5 page reload.
- [x] AC10: When an exam attempt is terminated/invalidated by the instructor or expired by the server, student heartbeat receives 409 and cleanly closes the exam instead of getting stuck in an infinite "offline" loop.
- [x] AC11: `grade_mcq_submission()` auto-grades both structured JSON and formatted plain text (`Question 1: Option A` or `Option A`) and parses plaintext questions.
- [x] AC12: In `AssignmentCreationWizard`, creating an MCQ skips `saveRubric()` so the backend does not reject the submission with a 422 criteria length error.
- [x] AC13: In `SpeedGrader`, clicking rubric criteria scales the calculated score by `max_marks / 100.0` so scores never exceed `max_marks` (e.g. 20-mark Midterm), and structured multi-question answers render cleanly in distinct cards.
- [x] AC14: Student Dashboard Action Queue and Recent Feedback items have clickable `onTap` navigation handlers, and the `feedback_ready` filter functions properly.
- [x] AC15: In `courses.py`, the HEC internal assessment calculation correctly weights internal assessments up to 30.0 marks instead of capping at 10.0, and the professor UI aligns with standard HEC 30/20/50 breakdown.
- [x] AC16: Course detail screen for professors displays pending grade dispute indicator badges on assessments with unresolved appeals.

### Slices (Phase 2 Build Order)
1. **Slice 6: Backend Exam Start & MCQ Deterministic Auto-Grader** — Update `exams.py` to return `description` in `start_exam` payload; update `grading_pipeline.py` to parse plain text / regex MCQ responses and markdown questions; update `courses.py` for 30% internal weighting.
2. **Slice 7: Student Exam Screen Live Synchronization** — Update `exam_screen.dart` to adopt `start_exam` description immediately, and handle 409 in `_sendHeartbeat` by terminating cleanly.
3. **Slice 8: Creation Wizard & SpeedGrader Hardening** — In `assignment_creation_wizard.dart`, skip `saveRubric` when `_type == 'mcq'`; in `assignment_detail_screen.dart`, scale `SpeedGrader` rubric score by `max_marks / 100.0`, and render multi-question text cleanly.
4. **Slice 9: Dashboard & Feedback Navigation** — In `student_dashboard_screen.dart` and `recent_feedback_widget.dart`, add `onTap` navigation and fix `feedback_ready` filter.
5. **Slice 10: Full Test Suite Verification** — Backend pytest + Flutter widget tests.
