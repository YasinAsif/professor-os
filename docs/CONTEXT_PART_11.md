# CONTEXT PART 11: ASSIGNMENTS, SUBMISSIONS & AI GRADING PIPELINE

> **Forensic Audit Standard:** Strictly read-only analysis of `backend/` and `frontend/`. Every claim is verified with exact file paths and line ranges (`file:line`). All statements are tagged `[CODE]`, `[RAN]`, `[ASSUMED]`, or `[NOT DONE]`.

---

## 1. Assignment Architecture & Data Model

### 1.1 Types and Status Lifecycle
`[CODE]` Defined in [backend/app/models/assignment.py:15-26](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L15-L26):
- **Assignment Types**:
  - `text`: Written response or inline text.
  - `file`: Document upload (PDF, DOCX, code files up to 25 MB).
  - `mcq`: Multiple-choice assessment.
  - `programming`: Code submission.
- **Status Enum**:
  - `draft`: Only visible to professors and administrators; hidden from enrolled students ([assignments.py:43](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L43)).
  - `published`: Visible to enrolled students; open for submissions if not closed.
  - `closed`: Explicitly closed for submissions ([submission_service.py:52-53](file:///e:/FYP_YASIN/backend/app/services/submission_service.py#L52-L53)).

### 1.2 Dead and Unenforced Database Fields
`[CODE]` Several fields defined in `assignments` table ([backend/app/models/assignment.py:67-75](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L67-L75)) are exposed in Pydantic schemas but are **never read, calculated, or enforced in business logic**:

| Column / Field | Read in Backend Logic? | Actual Code Status |
| :--- | :--- | :--- |
| `late_penalty_per_day` | **NO** | `[CODE]` Defined in model [assignment.py:68](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L68) and schema [assignment.py:16](file:///e:/FYP_YASIN/backend/app/schemas/assignment.py#L16). `submission_service.py` checks `now > dl and not assignment.allow_late` but never calculates or deducts daily late penalties. |
| `max_penalty_cap` | **NO** | `[CODE]` Defined in model [assignment.py:69](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L69). Zero references exist anywhere in `submission_service.py` or `grading_pipeline.py`. |
| `randomize_questions` | **NO** | `[CODE]` Stored on `assignments` [assignment.py:74](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L74). Zero references in quiz or exam question generators. |
| `show_results_after` | **NO** | `[CODE]` Stored on `assignments` [assignment.py:75](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L75). Results exposure in UI is not gated by this flag. |

### 1.3 Update Limitations & Route Segregation
`[CODE]`
- General assignment properties (title, description, marks, deadline, allow_late, time_limit_minutes, clo_ids) are updated via `PUT /courses/{course_id}/assignments/{aid}` ([assignments.py:82-106](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L82-L106)).
- Proctoring parameters (`strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, `unsupported_browser_policy`) cannot be altered via `AssignmentUpdate`. They require a separate route: `PUT /assignments/{aid}/proctoring-settings` in [backend/app/api/v1/exams.py:47-90](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L47-L90).

---

## 2. Assignment Access Control & TA Delegation

### 2.1 Access Control Matrix
`[CODE]` Implemented across [assignments.py:22-59](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L22-L59) and [assignment_service.py:122-143](file:///e:/FYP_YASIN/backend/app/services/assignment_service.py#L122-L143):
- **Admins & Owning Professors**: Unrestricted read/write access to all assignments in the course.
- **Students**:
  - Can only list assignments if enrolled in the course ([assignment_service.py:128](file:///e:/FYP_YASIN/backend/app/services/assignment_service.py#L128)).
  - Draft assignments are filtered out (`status != "draft"`).
- **Teaching Assistants (TAs)**:
  - TAs only see assignments to which they have been explicitly delegated via the `assignment_tas` junction table ([assignments.py:40-41](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L40-L41)).
  - TA delegation table schema [assignment.py:37-43](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L37-L43):
    `assignment_tas(assignment_id, user_id, batch_size)`.

### 2.2 TA Lockout Architecture Bug in Course Management
`[CODE]` As documented in Part 9 and Part 10:
While `POST /courses/{course_id}/assignments`, `PUT .../assignments/{aid}`, and `POST .../publish` specify `user: require_roles("professor", "admin", "ta")` ([assignments.py:64, 85, 111](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L64)), the first line in each handler executes:
```python
await course_svc.verify_course_management_access(course_id, user)
```
In [course_service.py:114](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L114), this method strictly verifies:
```python
if user.role != "professor" or course.professor_id != user.id:
    raise PermissionError("No permission to manage this course.")
```
**Outcome**: TAs receive `HTTP 403 No permission to manage this course` whenever they attempt to create, edit, or publish assignments.

---

## 3. Rubric Architecture & Validation

### 3.1 Rubric Data Model
`[CODE]` Implemented in [backend/app/models/rubric.py](file:///e:/FYP_YASIN/backend/app/models/rubric.py):
- **1:1 Assignment Relationship**: `Rubric.assignment_id` is unique and non-nullable ([rubric.py:24-26](file:///e:/FYP_YASIN/backend/app/models/rubric.py#L24-L26)).
- **Criteria**: `RubricCriterion` table ([rubric.py:39-57](file:///e:/FYP_YASIN/backend/app/models/rubric.py#L39-L57)). Each criterion contains `name`, `weight`, and `order`.
- **Levels**: `RubricLevel` table ([rubric.py:59-75](file:///e:/FYP_YASIN/backend/app/models/rubric.py#L59-L75)). Exactly 4 standardized levels per criterion: `excellent`, `satisfactory`, `developing`, `insufficient`.

### 3.2 Weight Validation Rules
`[CODE]` Handled in [backend/app/services/assignment_service.py:255-265](file:///e:/FYP_YASIN/backend/app/services/assignment_service.py#L255-L265):
- The sum of criterion weights must equal exactly 100%:
  ```python
  total_weight = sum(c.weight for c in body.criteria)
  if abs(total_weight - 100.0) > 0.01:
      raise ValueError(f"Rubric criteria weights must sum to 100 (got {total_weight:.1f}).")
  ```
- Criteria count must be between 3 and 10 criteria.
- Each criterion must supply definitions for all 4 performance levels.

---

## 4. Submission Processing & Lifecycle

### 4.1 Endpoints & File Handling
`[CODE]` Handled in [backend/app/api/v1/submissions.py](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py):
- **Text Submission**: `POST /courses/{course_id}/assignments/{aid}/submissions` ([submissions.py:115-139](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L115-L139)). Accepts `SubmissionCreate(submission_type, content)`.
- **File Submission**: `POST /courses/{course_id}/assignments/{aid}/submissions/file` ([submissions.py:141-191](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L141-L191)).
  - Enforces 25 MB limit: `MAX_SUBMISSION_BYTES = 25 * 1024 * 1024` ([submissions.py:30, 162-164](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L30)).
  - Writes file to disk at `STORAGE_ROOT/submissions/{uuid}_{safe_filename}`.
  - Immediately parses text from PDF, DOCX, Code, or Text via `extract_text_from_submission_file(sub.file_path)` ([submissions.py:175-178](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L175-L178)) so that downstream graders do not require raw disk file parsing.
  - Runs deterministic triage check: `build_document_triage(extracted_txt, sub.file_path)` ([submissions.py:179-185](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L179-L185)).

### 4.2 Timed Exam Submission Validation
`[CODE]` For timed exams, submission routes call `validate_timed_submission_attempt`:

```python
# backend/app/api/v1/submissions.py:34-48
def validate_timed_submission_attempt(
    assignment,
    attempt,
    now=None,
    *,
    allow_expired: bool = False,
    grace_seconds: int = 10,
) -> None:
    """Require a live server-side attempt before accepting timed-exam content."""
    if not getattr(assignment, "time_limit_minutes", None):
        return
    if attempt is None or getattr(attempt, "submitted_at", None) is not None:
        raise ValueError("An active exam attempt is required for this submission.")
    if is_attempt_expired(attempt, assignment, now=now, grace_seconds=grace_seconds) and not allow_expired:
        raise ValueError("The exam time limit has expired and the grace period has ended.")
```
- Query `_get_timed_attempt` selects `ExamAttempt.submitted_at.is_(None)` with row-locking (`with_for_update()`) ([submissions.py:51-63](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L51-L63)).
- Once an attempt has been marked as submitted, any subsequent submission attempt returns `ValueError("An active exam attempt is required for this submission.")`.

### 4.3 Resubmission / Overwrite Behavior
`[CODE]` In [backend/app/services/submission_service.py:64-80](file:///e:/FYP_YASIN/backend/app/services/submission_service.py#L64-L80):
- If a submission already exists for the student and assignment:
  - If `existing.status == "graded"`: Resubmission is rejected with `ValueError("This assignment has already been evaluated and graded...")` ([submission_service.py:66-67](file:///e:/FYP_YASIN/backend/app/services/submission_service.py#L66-L67)).
  - If `existing.status == "pending"`: **Existing submission is overwritten in-place**. `content`, `submitted_at` are replaced, and `score`, `feedback`, `graded_by_id`, `graded_at` are reset to `None` ([submission_service.py:69-78](file:///e:/FYP_YASIN/backend/app/services/submission_service.py#L69-L78)).

---

## 5. AI Grading Pipeline (DeepSeek-R1-Distill-70B)

### 5.1 Service Location Clarification
`[CODE]` Note on historical nomenclature: There is **no file named `ai_grading_service.py`** in `backend/app/services/`. The entire AI rubric grading pipeline is implemented in:
- [backend/app/services/grading_pipeline.py](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py) (403 lines)

### 5.2 Rationale-Before-Score Pattern
`[CODE]` In [grading_pipeline.py:61-105](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L61-L105), the Pydantic v2 `GradingEvaluationSchema` strictly enforces that the LLM emits reasoning before scoring:

```python
# backend/app/services/grading_pipeline.py:61-100
class GradingEvaluationSchema(BaseModel):
    # 1. RATIONALE FIRST (Mandatory reasoning before numeric scores)
    diagnostic_reasoning: str = Field(...)

    # 2. PER-CRITERIA EVIDENCE & SCORES
    criteria_evaluations: List[CriterionGradingResult] = Field(...)

    # 3. OVERALL AGGREGATED SCORES
    total_score: float = Field(...)
    max_marks: float = Field(default=100.0)
    percentage: float = Field(...)

    # 4. HUMAN-IN-THE-LOOP QUALITY GATING
    needs_review: bool = Field(default=False)
    review_reasons: List[str] = Field(default_factory=list)

    # 5. ACTIONABLE FORMATIVE FEEDBACK
    student_feedback: str = Field(...)
```

The system prompt explicitly commands ([grading_pipeline.py:186](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L186)):
> *"RATIONALE-BEFORE-SCORE: You MUST thoroughly deliberate and articulate your pedagogical rationale and cite exact student evidence BEFORE deciding any numeric score. Never output a score without prior evidence."*

### 5.3 Mathematical Integrity Validator
`[CODE]` The schema includes an `@model_validator(mode="after")` ([grading_pipeline.py:149-171](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L149-L171)) that rejects invalid model responses:
- Criterions cannot have negative scores or exceed their individual `max_score`.
- Sum of `criterion.score_awarded` must equal `total_score` within 0.01 tolerance.
- `percentage` must match `(total_score / max_marks) * 100.0` within 0.1% tolerance.

### 5.4 Human-in-the-Loop Quality Gating (`needs_review`)
`[CODE]` Submissions are automatically flagged for human educator review under any of the following conditions ([grading_pipeline.py:191-201](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L191-L201)):
1. **Borderline Pass/Fail Boundary**: Total percentage is between **48.0% and 52.0%**.
2. **Deterministic Triage**: Submission is empty, unreadable, or consists solely of exam timeout placeholders (e.g., `"[Time Expired - Auto-Submitted by ProfessorOS Exam Guard]"`, [document_ingestion.py:34-45](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L34-L45)).
3. **Prompt Injection**: Student submission contains adversarial prompt override strings detected by `detect_prompt_injection` ([grading_pipeline.py:174-180, 215-217](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L174-L180)). When detected, `PromptInjectionDetected` is raised, preventing untrusted text from ever reaching the LLM provider.

### 5.5 Celery Asynchronous Dispatch vs. Synchronous Execution
`[CODE]`
- Route: `POST /submissions/{sid}/ai-grade` ([submissions.py:269-380](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L269-L380)).
- If `sync=True`: Executes `_grade_submission_core` synchronously in the request loop ([submissions.py:356-380](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L356-L380)).
- If `sync=False`: Dispatches Celery task `grade_submission_task.delay(...)` to queue `grading_normal` ([grading_pipeline.py:283-289](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L283-L289)).
- **Database Engine Pool Safety**: Celery worker uses a singleton pooled engine `_get_sync_engine()` ([grading_pipeline.py:267-280](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L267-L280)) with `pool_pre_ping=True` to prevent connection leaks during high-throughput background grading.

### 5.6 Manual Override & SpeedGrader
`[CODE]` `PUT /submissions/{sid}/grade` in [submissions.py:248-265](file:///e:/FYP_YASIN/backend/app/api/v1/submissions.py#L248-L265).
- Allows professors, administrators, and assigned TAs to manually enter `score` and `feedback`.
- Sets `status = "graded"`, `graded_by_id = user.id`, and `graded_at = NOW()`.
- Overrides any AI evaluation and clears pending review states.

---

PART 11 DONE
