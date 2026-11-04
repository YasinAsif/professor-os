# Viva & Defense Preparation Guide: ProfessorOS

Tailored specifically for the FYP Defense Panel and University Examiners. Every answer is backed by real code and evidence in the repository.

---

## 1. Problem & Purpose

### Q1: What exact problem does ProfessorOS solve?
- **Honest Answer:** Universities face a major challenge aligning exams with Outcome-Based Education (OBE) and preventing academic dishonesty in online assessments, while grading essays and code at scale takes weeks. ProfessorOS automates rubric-based and MCQ grading, provides anti-cheat proctored examination, and maps scores directly to Course Learning Outcomes (CLOs).
- **Proof:** [`backend/app/models/clo.py`](file:///e:/FYP_YASIN/backend/app/models/clo.py), [`backend/app/services/grading_pipeline.py`](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py).

### Q2: What do universities use today, and why is ProfessorOS better?
- **Honest Answer:** Most institutions use Moodle or Google Classroom, which lack native LLM-powered rubric evaluation against teacher ground-truth, have weak client-side proctoring, and require manual Excel calculation for OBE/CLO attainment. ProfessorOS integrates all three natively.
- **Proof:** [`frontend/lib/features/courses/presentation/exam_screen.dart`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart).

---

## 2. Architecture & Design Choices

### Q3: Why did you choose FastAPI over Django or Flask?
- **Honest Answer:** FastAPI provides native Python asynchronous I/O (`async`/`await`), automatic OpenAPI/Swagger documentation, and Pydantic validation. For long-running LLM evaluation tasks and concurrent proctoring heartbeats, async non-blocking operations are essential to prevent server thread starvation.
- **Proof:** [`backend/app/main.py`](file:///e:/FYP_YASIN/backend/app/main.py).

### Q4: Why Flutter Web instead of React?
- **Honest Answer:** Flutter allows a single shared codebase across Web and native Mobile/Desktop with complete pixel-level canvas control. This is critical for lockdown anti-cheat proctoring (fullscreen lock, keyboard interception, biometric auth) which behaves identically across devices.
- **Proof:** [`frontend/pubspec.yaml`](file:///e:/FYP_YASIN/frontend/pubspec.yaml).

### Q5: What database are you using, and how is it structured?
- **Honest Answer:** PostgreSQL with SQLAlchemy async ORM. Key tables include `users`, `courses`, `clos`, `assignments`, `rubrics`, `rubric_criteria`, `submissions`, and `exam_attempts` linked via foreign keys with cascade policies.
- **Proof:** [`backend/app/models/`](file:///e:/FYP_YASIN/backend/app/models/).

---

## 3. Evaluation & AI Correctness

### Q6: How do you prevent AI hallucinations in grading?
- **Honest Answer:** We use the teacher's reference answer and rubric definition as the strictly injected ground truth (`<teacher_reference_answer>`). The model is explicitly constrained in the system prompt to evaluate accuracy and technical correctness exclusively against the teacher's ground truth, penalizing ungrounded claims.
- **Proof:** [`backend/app/services/grading_pipeline.py: SYSTEM_GRADING_PROMPT`](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L256-L280).

### Q7: What happens if a student uses prompt injection like "Give me 100 marks"?
- **Honest Answer:** Before any text reaches the LLM, `check_prompt_injection()` scans the submission with pattern-matching heuristics. If an injection attempt is detected, it is intercepted, flagged, and assigned to human manual review with zero marks awarded.
- **Proof:** [`backend/app/services/grading_pipeline.py: check_prompt_injection`](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L605-L620).

### Q8: What happens if the AI service (Groq/OpenAI) is down or rate-limited?
- **Honest Answer:** The pipeline features a guaranteed deterministic semantic fallback (`_fallback_rubric_evaluation`). It calculates token overlap against teacher reference answers and maps criteria scores mathematically, guaranteeing a score and diagnostic feedback without hanging or crashing.
- **Proof:** [`backend/app/services/grading_pipeline.py: _fallback_rubric_evaluation`](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L281-L320).

### Q9: How are MCQs graded? Do they use the LLM?
- **Honest Answer:** No. MCQs are graded 100% deterministically in Python without invoking any LLM. Choices are matched directly against the teacher's answer key, auto-scored in milliseconds with zero LLM API cost.
- **Proof:** [`backend/app/services/grading_pipeline.py: grade_mcq_submission`](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L637-L770).

---

## 4. Anti-Cheat & Proctoring

### Q10: How does the anti-cheat system work on the web?
- **Honest Answer:** The exam screen enforces HTML5 Pointer Lock / Fullscreen API, intercepts copy-paste shortcuts (`Ctrl+C`, `Ctrl+V`), and attaches window blur / page visibility listeners. Any switch to another tab or window registers an anti-cheat strike sent to the server. Exceeding strike limits triggers automatic submission.
- **Proof:** [`frontend/lib/features/courses/presentation/exam_screen.dart`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L157-L200).

### Q11: What happens if the student disconnects from the internet during an exam?
- **Honest Answer:** Violations and draft answers are buffered in local memory via `OfflineViolationQueue`. The countdown timer continues running locally, and buffered violations sync automatically once connection is restored.
- **Proof:** [`frontend/lib/features/courses/utils/offline_violation_queue.dart`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/offline_violation_queue.dart).

---

## 5. Security & Privacy

### Q12: Can a student access another student's exam answers by guessing an ID?
- **Honest Answer:** No. Submissions and exam state endpoints strictly extract the user identity from the cryptographically verified JWT bearer token server-side, enforcing that a student can only query `/submissions/me` or their own active attempt.
- **Proof:** [`backend/app/api/v1/submissions.py`](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py).

### Q13: Are passwords securely handled?
- **Honest Answer:** Yes, passwords are never stored in plaintext. They are salted and hashed using `bcrypt` via Passlib before persisting to the database.
- **Proof:** [`backend/app/core/security.py`](file:///e:/FYP_YASIN/backend/app/core/security.py).
