# PART 2: DATABASE ARCHITECTURE, TABLES & MIGRATIONS

---

## 1. Complete Database Tables (All 23 Tables)

[CODE] Verified directly from SQLAlchemy ORM metadata in `backend/app/models/` and live PostgreSQL database:

### 1. `users`
[CODE: `backend/app/models/user.py:15-46`]
- **Table Name:** `users`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `email`: `VARCHAR(255)`, unique, indexed (`ix_users_email`), NOT NULL
  - `full_name`: `VARCHAR(255)`, NOT NULL
  - `hashed_password`: `TEXT`, NOT NULL
  - `role`: `VARCHAR(9)` (Enum: `student`, `ta`, `professor`, `admin`), NOT NULL, default=`student`
  - `avatar_url`: `VARCHAR(512)`, nullable
  - `is_active`: `BOOLEAN`, NOT NULL, default=`True`
  - `is_verified`: `BOOLEAN`, NOT NULL, default=`False`
  - `is_approved`: `BOOLEAN`, NOT NULL, default=`True` (student accounts require admin approval when policy enabled)
  - `failed_attempts`: `INTEGER`, NOT NULL, default=`0`
  - `locked_until`: `DATETIME(timezone=True)`, nullable
  - `token_valid_after`: `DATETIME(timezone=True)`, nullable (used for global session invalidation/logout)
  - `created_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
  - `updated_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
- **Relationships:** Courses taught, enrollments, submissions, TA delegations, graded submissions, exam attempts.

### 2. `courses`
[CODE: `backend/app/models/course.py:14-49`]
- **Table Name:** `courses`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `title`: `VARCHAR(255)`, NOT NULL
  - `code`: `VARCHAR(50)`, NOT NULL
  - `join_code`: `VARCHAR(20)`, unique, indexed (`ix_courses_join_code`), NOT NULL
  - `semester`: `VARCHAR(50)`, NOT NULL
  - `description`: `TEXT`, nullable
  - `at_risk_threshold`: `FLOAT`, NOT NULL, default=`50.0`
  - `is_archived`: `BOOLEAN`, NOT NULL, default=`False`
  - `quiz_weight`: `FLOAT`, NOT NULL, default=`15.0`
  - `assignment_weight`: `FLOAT`, NOT NULL, default=`15.0`
  - `midterm_weight`: `FLOAT`, NOT NULL, default=`30.0`
  - `final_weight`: `FLOAT`, NOT NULL, default=`40.0`
  - `professor_id`: `INTEGER`, FK -> `users.id` (ondelete=`RESTRICT`), NOT NULL, indexed
  - `created_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
  - `updated_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
- **Constraints / Indexes:** Unique join code (`ix_courses_join_code`), FK on `professor_id`.

### 3. `clos` (Course Learning Outcomes)
[CODE: `backend/app/models/course.py:52-67`]
- **Table Name:** `clos`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), NOT NULL, indexed
  - `code`: `VARCHAR(20)`, NOT NULL (e.g. `CLO-1`, `CLO-2`)
  - `description`: `TEXT`, NOT NULL

### 4. `enrollments`
[CODE: `backend/app/models/course.py:70-87`]
- **Table Name:** `enrollments`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), NOT NULL, indexed
  - `user_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), NOT NULL, indexed
  - `role`: `VARCHAR(20)`, NOT NULL, default=`student` (`student`, `ta`)
  - `enrolled_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
- **Constraints:** Unique constraint `uq_course_user` on `(course_id, user_id)`.

### 5. `assignments` (Unified Assessment Model)
[CODE: `backend/app/models/assignment.py:46-103`]
- **Table Name:** `assignments`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), NOT NULL, indexed
  - `title`: `VARCHAR(255)`, NOT NULL
  - `description`: `TEXT`, nullable
  - `type`: `VARCHAR(11)` (Enum: `text`, `file`, `mcq`, `programming`), NOT NULL
  - `status`: `VARCHAR(9)` (Enum: `draft`, `published`, `closed`), NOT NULL, default=`draft`
  - `max_marks`: `FLOAT`, NOT NULL, default=`100.0`
  - `deadline`: `DATETIME(timezone=True)`, nullable
  - `allow_late`: `BOOLEAN`, default=`False`
  - `late_penalty_per_day`: `FLOAT`, default=`0.0`
  - `max_penalty_cap`: `FLOAT`, default=`100.0`
  - `time_limit_minutes`: `INTEGER`, nullable (None = un-timed take-home work; > 0 = timed proctored exam)
  - `max_attempts`: `INTEGER`, default=`1`
  - `randomize_questions`: `BOOLEAN`, default=`False`
  - `show_results_after`: `BOOLEAN`, default=`True`
  - `strike_limit_flag`: `INTEGER`, NOT NULL, default=`3`, server_default=`3`
  - `strike_limit_autosubmit`: `INTEGER`, NOT NULL, default=`5`, server_default=`5`
  - `fullscreen_required`: `BOOLEAN`, NOT NULL, default=`True`, server_default=`true`
  - `block_copy_paste`: `BOOLEAN`, NOT NULL, default=`True`, server_default=`true`
  - `unsupported_browser_policy`: `VARCHAR(32)`, NOT NULL, default=`warn_allow`, server_default=`warn_allow`
  - `created_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
  - `updated_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`

### 6. `assignment_clos` (Junction Table)
[CODE: `backend/app/models/assignment.py:29-34`]
- **Table Name:** `assignment_clos`
- **Columns:**
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), Primary Key
  - `clo_id`: `INTEGER`, FK -> `clos.id` (ondelete=`CASCADE`), Primary Key

### 7. `assignment_tas` (TA Delegation Junction Table)
[CODE: `backend/app/models/assignment.py:37-43`]
- **Table Name:** `assignment_tas`
- **Columns:**
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), Primary Key
  - `user_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), Primary Key
  - `batch_size`: `INTEGER`, nullable (None = all submissions assigned to this TA)

### 8. `rubrics`
[CODE: `backend/app/models/rubric.py:13-25`]
- **Table Name:** `rubrics`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), unique, indexed (`ix_rubrics_assignment_id`), NOT NULL

### 9. `rubric_criteria`
[CODE: `backend/app/models/rubric.py:28-44`]
- **Table Name:** `rubric_criteria`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `rubric_id`: `INTEGER`, FK -> `rubrics.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `name`: `VARCHAR(255)`, NOT NULL
  - `weight`: `FLOAT`, NOT NULL
  - `order`: `INTEGER`, NOT NULL, default=`0`

### 10. `rubric_levels`
[CODE: `backend/app/models/rubric.py:47-62`]
- **Table Name:** `rubric_levels`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `criterion_id`: `INTEGER`, FK -> `rubric_criteria.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `level`: `VARCHAR(12)` (Enum: `exemplary`, `proficient`, `developing`, `beginning`), NOT NULL
  - `description`: `TEXT`, NOT NULL, default=`""`

### 11. `submissions`
[CODE: `backend/app/models/submission.py:25-79`]
- **Table Name:** `submissions`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `student_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `submission_type`: `VARCHAR(11)` (Enum: `text`, `file`, `programming`, `mcq`), NOT NULL, default=`text`
  - `content`: `TEXT`, nullable (Raw text, source code, or serialized MCQ payload)
  - `file_path`: `VARCHAR(512)`, nullable (Relative storage path)
  - `file_name`: `VARCHAR(255)`, nullable
  - `status`: `VARCHAR(7)` (Enum: `pending`, `graded`), NOT NULL, default=`pending`
  - `score`: `FLOAT`, nullable
  - `feedback`: `TEXT`, nullable
  - `graded_by_id`: `INTEGER`, FK -> `users.id` (ondelete=`SET NULL`), nullable
  - `submitted_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
  - `graded_at`: `DATETIME(timezone=True)`, nullable
  - `auto_submitted`: `BOOLEAN`, NOT NULL, default=`False`, server_default=`false`
  - `evaluation_metadata`: `TEXT`, nullable (JSON payload of criteria breakdown and reasoning)
  - `evaluator_model`: `VARCHAR(255)`, nullable (Model used: e.g. `deepseek-r1-distill-llama-70b`)

### 12. `exam_attempts`
[CODE: `backend/app/models/exam_attempt.py:12-52`]
- **Table Name:** `exam_attempts`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `student_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `started_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
  - `submitted_at`: `DATETIME(timezone=True)`, nullable
  - `duration_minutes`: `INTEGER`, nullable (Frozen snapshot of assignment duration at start)
  - `auto_submitted`: `BOOLEAN`, NOT NULL, default=`False`, server_default=`false`
  - `last_heartbeat_at`: `DATETIME(timezone=True)`, nullable
  - `current_answers`: `TEXT`, nullable (In-flight draft saved every 10s)
  - `tab_switch_count`: `INTEGER`, default=`0` (Total cumulative strikes recorded)
  - `is_flagged`: `BOOLEAN`, default=`False`
  - `flag_reason`: `VARCHAR(255)`, nullable
  - `attempt_number`: `INTEGER`, default=`1`, server_default=`1`
  - `reviewed_by_id`: `INTEGER`, FK -> `users.id` (ondelete=`SET NULL`), nullable
  - `reviewed_at`: `DATETIME(timezone=True)`, nullable
  - `decision`: `VARCHAR(32)`, nullable (`accept`, `invalidate`, `allow_retake`, `clear`)
  - `decision_reason`: `TEXT`, nullable

### 13. `exam_violations`
[CODE: `backend/app/models/exam_attempt.py:54-71`]
- **Table Name:** `exam_violations`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `attempt_id`: `INTEGER`, FK -> `exam_attempts.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `violation_type`: `VARCHAR(64)`, indexed, NOT NULL (`tab_switch`, `window_blur`, `fullscreen_exit`, `heartbeat_missed`, `auto_close`)
  - `occurred_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`
  - `details`: `VARCHAR(255)`, nullable

### 14. `exam_audit_logs`
[CODE: `backend/app/models/exam_attempt.py:73-99`]
- **Table Name:** `exam_audit_logs`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `attempt_id`: `INTEGER`, FK -> `exam_attempts.id` (ondelete=`SET NULL`), indexed, nullable
  - `instructor_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `action`: `VARCHAR(64)`, NOT NULL (`accept_attempt`, `invalidate_attempt`, `allow_retake`, `clear_flags`, `update_settings`)
  - `reason`: `TEXT`, NOT NULL
  - `created_at`: `DATETIME(timezone=True)`, NOT NULL, default=`now(utc)`

### 15. `analytics_snapshots`
[CODE: `backend/app/models/analytics.py:14-36`]
- **Table Name:** `analytics_snapshots`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `snapshot_date`: `DATETIME(timezone=True)`, default=`now(utc)`
  - `total_students`: `INTEGER`, default=`0`
  - `average_score`: `FLOAT`, default=`0.0`
  - `submission_rate`: `FLOAT`, default=`0.0`
  - `at_risk_count`: `INTEGER`, default=`0`
  - `clo_attainment_json`: `TEXT`, nullable (JSON map of CLO attainments)
  - `grade_distribution_json`: `TEXT`, nullable (JSON bucket counts: A, B, C, D, F)

### 16. `at_risk_records`
[CODE: `backend/app/models/analytics.py:39-65`]
- **Table Name:** `at_risk_records`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `student_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `risk_score`: `FLOAT`, NOT NULL
  - `reasons`: `TEXT`, nullable (Comma-separated risk factors)
  - `flagged_at`: `DATETIME(timezone=True)`, default=`now(utc)`
  - `is_resolved`: `BOOLEAN`, default=`False`

### 17. `clo_definitions` (OBE Accreditation)
[CODE: `backend/app/models/quiz_obe.py:32-47`]
- **Table Name:** `clo_definitions`
- **Columns:**
  - `clo_id`: `UUID`, Primary Key, default=`uuid4`
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `code`: `VARCHAR(20)`, NOT NULL
  - `description`: `TEXT`, NOT NULL
  - `bloom_target_level`: `VARCHAR(2)` (Enum: `C1`, `C2`, `C3`, `C4`, `C5`, `C6`), NOT NULL, default=`C3`
  - `created_at`: `DATETIME(timezone=True)`, default=`now(utc)`

### 18. `quiz_configs`
[CODE: `backend/app/models/quiz_obe.py:50-68`]
- **Table Name:** `quiz_configs`
- **Columns:**
  - `quiz_id`: `UUID`, Primary Key, default=`uuid4`
  - `assignment_id`: `INTEGER`, FK -> `assignments.id` (ondelete=`CASCADE`), unique, indexed, NOT NULL
  - `time_limit_minutes`: `INTEGER`, nullable
  - `randomize_order`: `BOOLEAN`, default=`False`
  - `max_attempts`: `INTEGER`, default=`1`
  - `show_answers_after`: `BOOLEAN`, default=`True`
  - `bloom_gate_passed`: `BOOLEAN`, default=`False`
  - `created_at`: `DATETIME(timezone=True)`, default=`now(utc)`

### 19. `question_bank`
[CODE: `backend/app/models/quiz_obe.py:71-105`]
- **Table Name:** `question_bank`
- **Columns:**
  - `question_id`: `UUID`, Primary Key, default=`uuid4`
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `clo_id`: `UUID`, FK -> `clo_definitions.clo_id` (ondelete=`SET NULL`), indexed, nullable
  - `bloom_level`: `VARCHAR(2)` (Enum: `C1` to `C6`), NOT NULL, default=`C2`
  - `question_type`: `VARCHAR(12)` (Enum: `MCQ`, `SHORT_ANSWER`, `ESSAY`), NOT NULL, default=`MCQ`
  - `stem`: `TEXT`, NOT NULL
  - `options`: `JSONB`, nullable (For MCQs: `[{"text": "...", "correct": true}]`)
  - `rubric`: `JSONB`, nullable
  - `status`: `VARCHAR(8)` (Enum: `DRAFT`, `APPROVED`, `ARCHIVED`), NOT NULL, default=`DRAFT`
  - `created_at`: `DATETIME(timezone=True)`, default=`now(utc)`

### 20. `quiz_questions` (Junction Table)
[CODE: `backend/app/models/quiz_obe.py:108-124`]
- **Table Name:** `quiz_questions`
- **Columns:**
  - `id`: `INTEGER`, Primary Key, autoincrement, NOT NULL
  - `quiz_id`: `UUID`, FK -> `quiz_configs.quiz_id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `question_id`: `UUID`, FK -> `question_bank.question_id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `points`: `FLOAT`, default=`1.0`
  - `order_index`: `INTEGER`, default=`0`

### 21. `student_quiz_attempts`
[CODE: `backend/app/models/quiz_obe.py:127-147`]
- **Table Name:** `student_quiz_attempts`
- **Columns:**
  - `attempt_id`: `UUID`, Primary Key, default=`uuid4`
  - `quiz_id`: `UUID`, FK -> `quiz_configs.quiz_id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `student_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `started_at`: `DATETIME(timezone=True)`, default=`now(utc)`
  - `submitted_at`: `DATETIME(timezone=True)`, nullable
  - `answers`: `JSONB`, NOT NULL, default=`[]`
  - `auto_score`: `NUMERIC(6, 2)`, nullable
  - `proctor_session_id`: `UUID`, nullable

### 22. `question_generation_jobs`
[CODE: `backend/app/models/quiz_obe.py:150-169`]
- **Table Name:** `question_generation_jobs`
- **Columns:**
  - `job_id`: `UUID`, Primary Key, default=`uuid4`
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `status`: `VARCHAR(10)` (Enum: `QUEUED`, `PROCESSING`, `DONE`, `FAILED`), NOT NULL, default=`QUEUED`
  - `error_message`: `TEXT`, nullable
  - `document_name`: `VARCHAR(255)`, NOT NULL
  - `generated_count`: `INTEGER`, default=`0`
  - `created_at`: `DATETIME(timezone=True)`, default=`now(utc)`

### 23. `attainment_records` (HEC OBE Attainment)
[CODE: `backend/app/models/quiz_obe.py:172-192`]
- **Table Name:** `attainment_records`
- **Columns:**
  - `record_id`: `UUID`, Primary Key, default=`uuid4`
  - `course_id`: `INTEGER`, FK -> `courses.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `clo_id`: `UUID`, FK -> `clo_definitions.clo_id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `student_id`: `INTEGER`, FK -> `users.id` (ondelete=`CASCADE`), indexed, NOT NULL
  - `attained`: `BOOLEAN`, NOT NULL
  - `score_achieved`: `NUMERIC(5, 2)`, NOT NULL
  - `evaluated_at`: `DATETIME(timezone=True)`, default=`now(utc)`

---

## 2. Alembic Migrations in Sequence

[CODE: `backend/alembic/versions/`]
The migration history forms a linear, unbroken chain from `<base>` to `20261017_006` (head):

1. **`20260921_001` (`20260921_001_foundation_schema.py`)**
   - **Revises:** `<base>`
   - **Changes:** Creates initial core schema: `users`, `courses`, `clos`, `enrollments`, `assignments`, `assignment_clos`, `assignment_tas`, `rubrics`, `rubric_criteria`, `rubric_levels`, `submissions`, `analytics_snapshots`, `at_risk_records`, and basic `exam_attempts`.
2. **`20260922_001` (`add_quiz_and_obe_tables.py`)**
   - **Revises:** `20260921_001`
   - **Changes:** Creates OBE/Quiz subsystem: `clo_definitions`, `quiz_configs`, `question_bank`, `student_quiz_attempts`, `question_generation_jobs`, `attainment_records`. Creates PostgreSQL Enums for Bloom levels and job statuses.
3. **`20261014_002` (`20261014_002_add_quiz_questions.py`)**
   - **Revises:** `20260922_001`
   - **Changes:** Creates `quiz_questions` junction table linking `quiz_configs` and `question_bank` with point weights and order indices.
4. **`20261014_003` (`20261014_003_integrity_constraints.py`)**
   - **Revises:** `20261014_002`
   - **Changes:** Adds `evaluation_metadata` and `evaluator_model` columns to `submissions`. Adds `time_limit_minutes`, `max_attempts`, `randomize_questions`, and `show_results_after` to `assignments`. Enforces unique constraint on `enrollments (course_id, user_id)`.
5. **`20261014_004` (`20261014_004_reconcile_legacy_schema.py`)**
   - **Revises:** `20261014_003`
   - **Changes:** Reconciles early manual `create_all` databases with Alembic: adds missing columns `users.token_valid_after` and `users.is_approved` if missing, ensures safe defaults.
6. **`20261017_005` (`20261017_005_exam_proctoring_schema.py`)**
   - **Revises:** `20261014_004`
   - **Changes:** Adds server-controlled `auto_submitted` (default `false`) to `submissions` and `exam_attempts`. Adds `last_heartbeat_at` and `current_answers` to `exam_attempts`. Creates `exam_violations` table.
7. **`20261017_006` (`20261017_006_exam_professor_audit_and_settings.py`)**
   - **Revises:** `20261017_005`
   - **Changes:** Adds exam settings to `assignments`: `strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, `unsupported_browser_policy`. Adds decision metadata to `exam_attempts`: `attempt_number`, `reviewed_by_id`, `reviewed_at`, `decision`, `decision_reason`. Creates `exam_audit_logs` table.

---

## 3. Drift Analysis: Models vs. Migrations

[RAN: Verified via metadata comparison script]
- **Schema Drift Result: ZERO DRIFT.**
- All 23 tables in SQLAlchemy models match the columns, nullability, defaults, foreign keys, and indexes created in Alembic migration `20261017_006`.
- Live PostgreSQL database `localhost:5432/professor_os` is at version `20261017_006` (`alembic_version` table confirmed).

---

## 4. Special Focus & Source of Truth: Proctoring & Settings

### Question: Is there an `exam_settings` table?
[CODE: `backend/app/models/assignment.py:72-81`, `backend/app/api/v1/exams.py:978-1036`]
- **NO.** There is no `exam_settings` table in the database or ORM.
- **The source of truth for all assessment settings is the `assignments` table:**
  - `time_limit_minutes` $\to$ `assignments.time_limit_minutes`
  - `max_attempts` $\to$ `assignments.max_attempts`
  - `strike_limit_flag` $\to$ `assignments.strike_limit_flag`
  - `strike_limit_autosubmit` $\to$ `assignments.strike_limit_autosubmit`
  - `fullscreen_required` $\to$ `assignments.fullscreen_required`
  - `block_copy_paste` $\to$ `assignments.block_copy_paste`
  - `unsupported_browser_policy` $\to$ `assignments.unsupported_browser_policy`

### Question: Is `duration_minutes` duplicated on `exam_attempts`?
[CODE: `backend/app/models/exam_attempt.py:27`, `backend/app/api/v1/exams.py:461`, `backend/app/api/v1/exams.py:84-86`]
- **YES, by design (frozen attempt snapshot):**
  - When a student begins an exam, `exam_attempts.duration_minutes` is copied from `assignments.time_limit_minutes`.
  - When calculating remaining seconds:
    ```python
    limit_minutes = getattr(attempt, "duration_minutes", None) or getattr(assignment, "time_limit_minutes", None)
    ```
  - **Why:** If an instructor edits an assignment's duration while a student is in the middle of writing their exam, the student's active attempt remains locked to the duration granted when they clicked Start.

---

## 5. Part 2 Follow-Up Audit & Live Verifications

### 5.1 Alembic Migration Commands Output [RAN]
- `alembic heads`:
  ```
  20261017_006 (head)
  ```
- `alembic history`:
  ```
  20261017_005 -> 20261017_006 (head), Exam professor audit trail, settings lock, and decision metadata.
  20261014_004 -> 20261017_005, Exam proctoring & anti-cheat schema hardening.
  20261014_003 -> 20261014_004, Reconcile legacy create_all schema with ORM constraints.
  20261014_002 -> 20261014_003, Persist grading metadata and enforce assignment integrity rules.
  20260922_001 -> 20261014_002, Add quiz-question associations required by the ORM.
  20260921_001 -> 20260922_001, Add quiz configurations, question bank, attempts, and OBE accreditation tables.
  <base> -> 20260921_001, Create the foundation tables required by the application models.
  ```
- `alembic check`:
  ```
  INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
  INFO  [alembic.runtime.migration] Will assume transactional DDL.
  ...
  No new upgrade operations detected.
  ```
  **Drift Verdict:** Confirmed `No new upgrade operations detected` (Exit code 0). Zero drift between live PostgreSQL database `localhost:5432/professor_os_db` and SQLAlchemy ORM models.

---

### 5.2 Backup Audit & pg_dump [RAN]
- **Tables in `backend/backups/dev_db_backup.json`:**
  - `alembic_version`: 1 row
  - `assignments`: 1 row
  - `courses`: 1 row
  - `enrollments`: 2 rows
  - `grade_records`: 2 rows
  - `rubric_criteria`: 2 rows
  - `rubrics`: 1 row
  - `users`: 3 rows
  **Missing Tables (16 of 23):** `submissions`, `assignment_tas`, `rubric_levels`, `clos`, `analytics_snapshots`, `at_risk_records`, `exam_attempts`, `exam_violations`, `exam_audit_logs`, `quizzes`, `question_bank_items`, `quiz_questions`, `student_quiz_attempts`, `student_answers`, `clo_definitions`, `obe_attainment_records`.
- **Live `pg_dump` taken:**
  - Dumped using: `E:\SETUPS\PostgreSQL\18\bin\pg_dump.exe`
  - Output file: `backend/backups/professor_os_live.sql` (254,517 bytes).
  - Git status: Verified gitignored by `git check-ignore backend/backups/professor_os_live.sql`.

---

### 5.3 Assignment `time_limit_minutes = null` Exam Classification [CODE]
- **Backend Condition:** [CODE `backend/app/api/v1/submissions.py:43-48`]:
  ```python
  if not getattr(assignment, "time_limit_minutes", None):
      return
  if attempt is None or getattr(attempt, "submitted_at", None) is not None:
      raise ValueError("An active exam attempt is required for this submission.")
  ```
  If `time_limit_minutes` is `None` or `0`, the backend treats it as an untimed regular assignment; no exam attempt is required to submit.
- **Frontend Condition:** [CODE `frontend/lib/features/courses/presentation/assignment_detail_screen.dart:2608-2612`]:
  ```dart
  final timeLimitMinutes = _assignment?['time_limit_minutes'] as int?;
  final isQuizOrExam = assignmentType == 'quiz' ||
      assignmentType == 'exam' ||
      assignmentType == 'mcq' ||
      (timeLimitMinutes != null && timeLimitMinutes > 0);
  ```
  If `type == 'mcq'`, `'quiz'`, or `'exam'`, the frontend evaluates `isQuizOrExam = true` and shows the "Exam Mode" button even if `time_limit_minutes` is `null`!
  If `type == 'text'`, `'programming'`, or `'file'` with `time_limit_minutes = null`, it is rendered as a regular assignment.
- **Migration 006 Effect on Existing Rows:**
  - Added `strike_limit_flag` (default 3), `strike_limit_autosubmit` (default 5), `fullscreen_required` (default true), `block_copy_paste` (default true), `unsupported_browser_policy` (default 'warn_allow') to ALL existing assignment rows via server defaults.
  - `time_limit_minutes` was NOT altered by migration 006 (`NULL` remained `NULL`).

---

### 5.4 Settings Editing & Attempt Lock Bypass Loophole [CODE]
1. `PUT /courses/{course_id}/assignments/{assignment_id}/exam/settings` (`exams.py:1011-1070`):
   - Edits: `time_limit_minutes`, `strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, `unsupported_browser_policy`.
   - **Enforces Lock:** [CODE `exams.py:1029-1038`]:
     ```python
     attempt_check = await db.execute(
         select(ExamAttempt.id).where(ExamAttempt.assignment_id == assignment_id).limit(1)
     )
     if attempt_check.scalar_one_or_none() is not None:
         raise HTTPException(status_code=409, detail="Exam settings are locked because student attempts have already started.")
     ```
2. `PUT /courses/{course_id}/assignments/{aid}` (`assignments.py:82-106` calling `assignment_service.py:203-219`):
   - Can edit `time_limit_minutes`.
   - **LOCK BYPASS LOOPHOLE:** [CODE `assignment_service.py:203-219`] Does **NOT** check `exam_attempts` at all. An instructor can update `time_limit_minutes` while an exam is actively running, bypassing the 409 lock.

---

### 5.5 Submissions vs Exam Attempts Linkage [CODE]
- **Is there an `attempt_id` link?** NO. Neither `submissions` nor `exam_attempts` has a foreign key to the other. They are only implicitly correlated by `(assignment_id, student_id)`.
- **How multiple attempts / resubmissions are handled:**
  - [CODE `backend/app/services/submission_service.py:64-79`]:
    There is only **ONE** `Submission` record per student per assignment.
    If a student takes Attempt 2 (retake):
    - If Attempt 1 is still in `status == 'pending'`, submitting Attempt 2 **overwrites** the single `Submission` record in place, wiping the student's text/file from Attempt 1.
    - If Attempt 1 was already graded (`status == 'graded'`), line 66 throws `ValueError: This assignment has already been evaluated and graded. Submissions can no longer be modified.`, preventing the student from submitting Attempt 2 at all.

---

### 5.6 Attempt Tables: `exam_attempts` vs `student_quiz_attempts` [CODE]
- `exam_attempts`: Used strictly for the assignment-based proctored exam flow (`backend/app/api/v1/exams.py`, `backend/app/services/exam_monitor.py`, `backend/app/api/v1/submissions.py`, `frontend/lib/.../exam_screen.dart`). Tracks proctoring telemetry, heartbeat timestamp, fullscreen/tab-switch strikes, and professor reviews.
- `student_quiz_attempts`: Used strictly for the AI-generated quiz system (`backend/app/models/quiz_obe.py`, `backend/app/api/v1/quizzes.py`, `frontend/lib/.../quiz_attempt_screen.dart`). Stores answers JSON array, per-question score, Bloom cognitive levels, and feeds OBE attainment.

---

### 5.7 `clos` vs `clo_definitions` [CODE]
- **Connection:** None. `clos` uses integer PKs (`id`) linked to `assignments`. `clo_definitions` uses UUID PKs (`clo_id`) linked to `question_bank_items`.
- **Which one does attainment read?** [CODE `backend/app/services/clo_attainment.py:80-97`]:
  Attainment queries `clo_definitions cd` first. If `clo_definitions` has no rows for that course, it executes a fallback query against legacy `clos`, casting `id` as `clo_id` and hardcoding `'C3' as bloom_target_level`.

---

### 5.8 Telemetry Violation Validation [CODE]
- [CODE `backend/app/api/v1/exams.py:48-55`]:
  ```python
  class ViolationRequest(BaseModel):
      type: str = Field(
          ...,
          pattern="^(tab_switch|window_blur|fullscreen_exit|copy_paste|multi_monitor|heartbeat_missed)$",
          description="Type of anti-cheat telemetry violation",
      )
      details: Optional[str] = Field(None, max_length=255)
  ```
  Strict Pydantic regex pattern validation. Any other string is rejected with `HTTP 422 Unprocessable Entity`.

---

### 5.9 Exact Live Nullability: `exam_attempts` and `submissions` [RAN]
Queried directly from PostgreSQL `information_schema.columns` on `localhost:5432/professor_os_db`:

#### `exam_attempts`
| Column Name | Data Type | Nullable | Default |
| :--- | :--- | :--- | :--- |
| `id` | `integer` | **NO** | `nextval('exam_attempts_id_seq'::regclass)` |
| `assignment_id` | `integer` | **NO** | `None` |
| `student_id` | `integer` | **NO** | `None` |
| `started_at` | `timestamp with time zone` | **NO** | `None` |
| `submitted_at` | `timestamp with time zone` | **YES** | `None` |
| `tab_switch_count` | `integer` | **NO** | `None` |
| `is_flagged` | `boolean` | **NO** | `None` |
| `flag_reason` | `character varying` | **YES** | `None` |
| `duration_minutes` | `integer` | **YES** | `None` |
| `auto_submitted` | `boolean` | **NO** | `false` |
| `last_heartbeat_at` | `timestamp with time zone` | **YES** | `None` |
| `current_answers` | `text` | **YES** | `None` |
| `attempt_number` | `integer` | **NO** | `1` |
| `reviewed_by_id` | `integer` | **YES** | `None` |
| `reviewed_at` | `timestamp with time zone` | **YES** | `None` |
| `decision` | `character varying` | **YES** | `None` |
| `decision_reason` | `text` | **YES** | `None` |

#### `submissions`
| Column Name | Data Type | Nullable | Default |
| :--- | :--- | :--- | :--- |
| `id` | `integer` | **NO** | `nextval('submissions_id_seq'::regclass)` |
| `assignment_id` | `integer` | **NO** | `None` |
| `student_id` | `integer` | **NO** | `None` |
| `submission_type` | `USER-DEFINED (submission_type)` | **NO** | `None` |
| `content` | `text` | **YES** | `None` |
| `file_path` | `character varying` | **YES** | `None` |
| `file_name` | `character varying` | **YES** | `None` |
| `status` | `USER-DEFINED (submission_status)` | **NO** | `None` |
| `score` | `double precision` | **YES** | `None` |
| `feedback` | `text` | **YES** | `None` |
| `graded_by_id` | `integer` | **YES** | `None` |
| `submitted_at` | `timestamp with time zone` | **NO** | `None` |
| `graded_at` | `timestamp with time zone` | **YES** | `None` |
| `evaluation_metadata` | `text` | **YES** | `None` |
| `evaluator_model` | `character varying` | **YES** | `None` |
| `auto_submitted` | `boolean` | **NO** | `false` |

---

PART 2 FOLLOW-UP DONE
