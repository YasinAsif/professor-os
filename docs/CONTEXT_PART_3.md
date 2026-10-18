# PART 3: BACKEND API (Every Endpoint Catalog, Proctoring Flow & Auth Deep-Dive)

- **Audit Date:** 2026-10-17
- **Verification Baseline:** Live AST and runtime introspection of `backend/app/main.py` and `backend/app/api/v1/*.py`
- **Total Registered Endpoints:** 109 (105 application endpoints + 4 FastAPI OpenAPI/docs routes)
- **Rules applied:** Zero assumptions, all routes traced directly from code with line numbers, error codes, auth dependencies, and side effects.

---

## 1. Exam & Proctoring Endpoints (In-Depth Technical Audit)

[CODE] Traced from `backend/app/api/v1/exams.py:1-1070`.

### 1.1 Summary of Exam Routes

| Method | Endpoint Path | Handler Function | Line | Allowed Roles | Request Body | Response Schema |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/start` | `start_exam` | L347-432 | `student` | None | Dict (`_make_attempt_payload`) |
| `POST` | `/api/v1/attempts/{attempt_id}/violations` | `report_attempt_violation` | L434-463 | `student` | `ViolationRequest` | Dict (`record_violation`) |
| `POST` | `/api/v1/attempts/{attempt_id}/switch-tab` | `report_attempt_switch_tab` | L465-478 | `student` | None | Dict (`record_violation`) |
| `POST` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/flag` | `flag_exam_switch` | L480-511 | `student` | None | Dict (`record_violation`) |
| `POST` | `/api/v1/attempts/{attempt_id}/heartbeat` | `attempt_heartbeat` | L513-591 | `student` | `Optional[HeartbeatRequest]` | Dict (status, remaining, live) |
| `POST` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/heartbeat` | `exam_heartbeat_legacy` | L593-618 | `student` | `Optional[HeartbeatRequest]` | Dict (status, remaining, live) |
| `GET` | `/api/v1/attempts/{attempt_id}/state` | `get_attempt_state` | L620-652 | `student`, `prof`, `admin`, `ta` | None | Dict (`_make_attempt_payload`) |
| `GET` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/state` | `get_exam_state` | L654-687 | `student` | None | Dict (`_make_attempt_payload` or `{}`) |
| `POST` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/submit` | `submit_exam` | L689-722 | `student` | None | Dict (confirmation message) |
| `GET` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/attempts` | `list_exam_attempts` | L726-838 | `prof`, `admin`, `ta` | Query: `status_filter` | List of enriched attempt dicts |
| `POST` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/attempts/{attempt_id}/decision` | `update_exam_attempt_decision` | L840-927 | `prof`, `admin`, `ta` | `ExamDecisionRequest` | Dict (decision audit record) |
| `POST` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/attempts/{attempt_id}/status` | `update_exam_attempt_decision` | L841 | `prof`, `admin`, `ta` | `ExamDecisionRequest` | Dict (decision audit record) |
| `GET` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/export-csv` | `export_exam_attempts_csv` | L929-1009 | `prof`, `admin`, `ta` | None | `StreamingResponse` (text/csv) |
| `PUT` | `/api/v1/courses/{course_id}/assignments/{assignment_id}/exam/settings` | `update_exam_settings` | L1011-1070 | `prof`, `admin` | `ExamSettingsRequest` | Dict (updated settings) |

---

### 1.2 Deep-Dive: Atomicity, Concurrency & Double-Submit Protection

#### A. Starting an Exam (`start_exam`, L347-432)
- **Locking & Atomicity:** [CODE `exams.py:355-380`] Executes `SELECT ... FROM assignments WHERE id = :assignment_id WITH FOR UPDATE`, followed by `SELECT ... FROM exam_attempts WHERE assignment_id = :assignment_id AND student_id = :user_id WITH FOR UPDATE`.
- **What stops duplicate concurrent attempts?** Row-level `FOR UPDATE` serializes simultaneous `start_exam` clicks. If an active attempt exists (`submitted_at IS NULL`), it checks if it is expired. If not expired, it returns the existing active attempt with `resumed=True` without creating a new row.
- **Deadline check at start:** If an active attempt has expired past `started_at + duration_minutes`, it immediately invokes `auto_close_attempt` (L396) and only permits a new attempt if `completed_count < allowed_attempts`.
- **Retake allowance math:** [CODE `exams.py:389-392`]:
  ```python
  retakes_allowed = len([a for a in existing_attempts if a.decision == "allow_retake"])
  allowed_attempts = (assignment.max_attempts or 1) + retakes_allowed
  ```
  If `completed_count >= allowed_attempts`, returns `HTTP 400: Maximum attempts reached for this exam.`

#### B. Submitting an Exam (`submit_exam`, L689-722)
- **Locking & Atomicity:** [CODE `exams.py:697-706`]:
  ```python
  result = await db.execute(
      select(ExamAttempt)
      .options(selectinload(ExamAttempt.assignment))
      .where(
          ExamAttempt.assignment_id == assignment_id,
          ExamAttempt.student_id == user.id,
          ExamAttempt.submitted_at.is_(None),
      )
      .with_for_update()
  )
  ```
- **What stops double-submit?** The predicate `ExamAttempt.submitted_at.is_(None)` under `with_for_update()`. The first request sets `attempt.submitted_at = datetime.now(timezone.utc)`. Any concurrent or subsequent request finds no matching row and raises `HTTP 404: No active exam attempt found.`

#### C. Auto-Closing an Attempt (`auto_close_attempt`, L116-181)
- **CAS Concurrency Protection:** [CODE `exams.py:126-132`]:
  ```python
  res = await db.execute(
      update(ExamAttempt)
      .where(ExamAttempt.id == attempt.id, ExamAttempt.submitted_at.is_(None))
      .values(submitted_at=now, auto_submitted=True)
  )
  if res.rowcount == 0:
      return False
  ```
  If two background workers or a worker and student submit at the exact same instant, the atomic Compare-And-Swap (CAS) ensures only one succeeds. The loser gets `rowcount == 0` and exits immediately without corrupting submission records.
- **Submission reconciliation:** [CODE `exams.py:147-179`] Locks existing `Submission` record with `with_for_update()`. If missing, creates a `Submission` with `auto_submitted=True` and populates `content` with `attempt.current_answers` (or fallback marker).

#### D. Telemetry & Violation Recording (`record_violation`, L184-286)
- **Deduplication Window:** [CODE `exams.py:208-236`] Queries most recent `ExamViolation` for the same `attempt_id` and `violation_type`. If `(now - last_t).total_seconds() < 1.5`, it returns `deduplicated=True` and ignores the strike.
- **Atomic Counter Increment:** [CODE `exams.py:238-243`]:
  ```python
  await db.execute(
      update(ExamAttempt)
      .where(ExamAttempt.id == attempt.id)
      .values(tab_switch_count=ExamAttempt.tab_switch_count + 1)
  )
  ```
  Direct in-database increment avoids lost-update anomalies.
- **Auto-Submission on Strike Ceiling:** [CODE `exams.py:267-272`] If `attempt.tab_switch_count >= strike_limit_autosubmit` (default 5), it flags the attempt and invokes `auto_close_attempt(attempt, assignment, db, reason="excessive_violations")`.

#### E. Heartbeat & Draft Auto-Save (`attempt_heartbeat`, L513-591)
- **Submitted Gate:** [CODE `exams.py:535-539`] If `submitted_at IS NOT NULL`, raises `HTTP 409 Conflict: Exam attempt has already been submitted. Draft answer saves are rejected.`
- **Expired Gate:** [CODE `exams.py:544-551`] If expired, calls `auto_close_attempt` and raises `HTTP 409 Conflict` if draft answers were provided.
- **Draft Persistence:** [CODE `exams.py:566-567`] Writes `attempt.current_answers = body.answers`.

#### F. Settings Lock (`update_exam_settings`, L1011-1070)
- **Lock Check:** [CODE `exams.py:1029-1038`] Queries `SELECT id FROM exam_attempts WHERE assignment_id = :assignment_id LIMIT 1`. If ANY attempt exists, raises `HTTP 409 Conflict: Exam settings are locked because student attempts have already started.`

---

### 1.3 Permitted Violation Types: Backend vs Frontend Comparison

[CODE `exams.py:51`]:
Backend regex: `^(tab_switch|window_blur|fullscreen_exit|copy_paste|multi_monitor|heartbeat_missed)$`

| Telemetry Violation Type | Backend Pydantic Allowed? | Frontend Emitted? | Frontend Source Line | Description |
| :--- | :--- | :--- | :--- | :--- |
| `tab_switch` | Yes (`exams.py:51`) | Yes | `web_window_listener_web.dart:108` | Fired on `visibilitychange` when `document.hidden == true` |
| `window_blur` | Yes (`exams.py:51`) | Yes | `web_window_listener_web.dart:113`, `exam_screen.dart:434` | Fired when browser window loses OS focus |
| `fullscreen_exit` | Yes (`exams.py:51`) | Yes | `web_window_listener_web.dart:118`, `exam_screen.dart:513` | Fired when student exits HTML5 fullscreen |
| `copy_paste` | Yes (`exams.py:51`) | Yes | `web_window_listener_web.dart:130-155`, `exam_screen.dart:521` | Fired on copy, cut, or paste keyboard/context-menu actions |
| `multi_monitor` | Yes (`exams.py:51`) | Yes | `web_window_listener_web.dart:80-94`, `exam_screen.dart:416` | Fired via Screen Details API if >1 display connected |
| `heartbeat_missed` | Yes (`exams.py:51`) | No (Backend Daemon) | `exam_monitor.py:145-148` | Injected by backend daemon when student heartbeat stops for >45s |

**Parity Verdict:** 100% matched. Every string accepted by the backend regex has a corresponding emitter.

---

## 2. Complete Catalog of All Application Endpoints

### 2.1 Authentication Router (`backend/app/api/v1/auth.py:1-174`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L48 | `POST` | `/api/v1/auth/register` | None | Public | `RegisterRequest` | `RegisterResponse` (201) | 400 | Inserts `users` row. If unverified, dispatches email verification token. |
| L68 | `POST` | `/api/v1/auth/login` | None | Public | `LoginRequest` | `TokenResponse` | 401, 403, 429 | Checks Redis rate-limit (5 fails/15m). Verifies Argon2id hash (`app/core/security.py:15-35`). Returns JWT. |
| L96 | `POST` | `/api/v1/auth/refresh` | None | Public | `RefreshRequest` | `TokenResponse` | 401 | Decodes JWT refresh token. Returns new access token. |
| L106 | `POST` | `/api/v1/auth/logout` | `get_current_user` | Any auth | None | `MessageResponse` | 401 | Blacklists token in Redis cache (if Redis available). |
| L127 | `GET` | `/api/v1/auth/verify-email` | None | Public | Query: `token` | `MessageResponse` | 400 | Validates token, sets `users.is_verified = True`. |
| L137 | `POST` | `/api/v1/auth/resend-verification` | None | Public | `ResendVerificationRequest` | `MessageResponse` | 400 | Dispatches new email verification email asynchronously. |
| L150 | `POST` | `/api/v1/auth/forgot-password` | None | Public | `ForgotPasswordRequest` | `MessageResponse` | None (safe) | Dispatches password reset email with 24h JWT. |
| L160 | `POST` | `/api/v1/auth/reset-password` | None | Public | `ResetPasswordRequest` | `MessageResponse` | 400 | Validates token, sets new `users.hashed_password`. |

---

### 2.2 Users & Admin Router (`backend/app/api/v1/users.py:1-287`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L47 | `GET` | `/api/v1/users/me` | `get_current_user` | Any auth | None | `UserResponse` | 401 | None (read user profile). |
| L52 | `GET` | `/api/v1/users/me/student-dashboard` | `require_roles("student")` | `student` | None | `StudentDashboardResponse` | 401, 403 | Aggregates enrollments, pending assignments, recent submissions. |
| L79 | `PUT` | `/api/v1/users/me` | `get_current_user` | Any auth | `UserUpdateRequest` | `UserResponse` | 401 | Updates `users.full_name`. |
| L95 | `PUT` | `/api/v1/users/me/password` | `get_current_user` | Any auth | `ChangePasswordRequest` | None | 400, 401 | Verifies old password, updates `users.hashed_password`. |
| L108 | `DELETE` | `/api/v1/users/me/sessions` | `get_current_user` | Any auth | None | None | 401 | Increments session revocation counter / clears active JWTs. |
| L121 | `GET` | `/api/v1/admin/users` | `require_roles("admin")` | `admin` | Query: `page`, `page_size`, `role` | `UserListResponse` | 401, 403 | Paginated read of user directory. |
| L138 | `POST` | `/api/v1/admin/users/import` | `require_roles("admin")` | `admin` | File: CSV | `CSVImportResult` | 400, 401, 403 | Batch inserts user accounts from uploaded CSV. |
| L149 | `PATCH` | `/api/v1/admin/users/{user_id}/status` | `require_roles("admin")` | `admin` | `UserStatusUpdate` | `UserResponse` | 401, 403, 404 | Sets `users.is_active` (activate or suspend). |
| L164 | `DELETE` | `/api/v1/admin/users/{user_id}` | `require_roles("admin")` | `admin` | None | None | 401, 403, 404 | Deletes user record and cascades to enrollments/tokens. |
| L178 | `POST` | `/api/v1/admin/users` | `require_roles("admin")` | `admin` | `AdminCreateUserRequest` | `UserResponse` (201) | 400, 401, 403 | Creates verified and pre-approved user account with designated role. |
| L197 | `GET` | `/api/v1/admin/users/stats` | `require_roles("admin")` | `admin` | None | `UserStatsResponse` | 401, 403 | Returns aggregate counts of users grouped by role and status. |
| L206 | `GET` | `/api/v1/admin/users/export` | `require_roles("admin")` | `admin` | Query: `role`, `search` | `StreamingResponse` | 401, 403 | Streams CSV export of user accounts. |
| L222 | `PATCH` | `/api/v1/admin/users/{user_id}/role` | `require_roles("admin")` | `admin` | `RoleUpdateRequest` | `UserResponse` | 400, 401, 403, 404 | Changes `users.role` (`student`, `professor`, `ta`, `admin`). |
| L236 | `POST` | `/api/v1/admin/users/{user_id}/reset-password` | `require_roles("admin")` | `admin` | `AdminResetPasswordRequest` | None | 401, 403, 404 | Directly sets new password without requiring email link. |
| L253 | `GET` | `/api/v1/admin/users/pending` | `require_roles("admin")` | `admin` | None | `list[UserResponse]` | 401, 403 | Lists all users where `is_approved == False`. |
| L262 | `PATCH` | `/api/v1/admin/users/{user_id}/approve` | `require_roles("admin")` | `admin` | None | `UserResponse` | 400, 401, 403, 404 | Sets `is_approved = True`, dispatches welcome email. |
| L275 | `PATCH` | `/api/v1/admin/users/{user_id}/reject` | `require_roles("admin")` | `admin` | `ApprovalActionRequest` | None | 401, 403, 404 | Rejects account, marks inactive or deletes. |

---

### 2.3 Courses Router (`backend/app/api/v1/courses.py:1-535`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L40 | `GET` | `/api/v1/courses/` | `get_current_user` | Any auth | None | `CourseListResponse` | 401 | Returns user-scoped active courses. |
| L57 | `POST` | `/api/v1/courses/` | `require_roles("admin", "professor")` | `admin`, `prof` | `CourseCreate` | `CourseResponse` (201) | 400, 401, 403 | Inserts `courses` row with unique 6-character uppercase `join_code`. |
| L74 | `GET` | `/api/v1/courses/{course_id}` | `get_current_user` | Any auth (checked) | None | `CourseResponse` | 401, 403, 404 | Verifies student enrollment or professor ownership. |
| L94 | `PUT` | `/api/v1/courses/{course_id}` | `get_current_user` | Owner/Admin | `CourseUpdate` | `CourseResponse` | 400, 401, 403 | Verifies ownership in service. Validates HEC weights sum to 100. |
| L109 | `DELETE` | `/api/v1/courses/{course_id}` | `get_current_user` | Owner/Admin | None | None | 401, 403, 404 | Sets `courses.is_archived = True`. |
| L124 | `DELETE` | `/api/v1/courses/{course_id}/permanent` | `require_roles("professor", "admin")` | Owner/Admin | None | None | 401, 403, 404 | Hard deletes course and cascades to all materials, exams, assignments. |
| L142 | `GET` | `/api/v1/courses/{course_id}/enrollments` | `get_current_user` | Owner/Admin | None | `list[EnrollmentResponse]` | 401, 403, 404 | Calls `verify_course_management_access`. |
| L165 | `POST` | `/api/v1/courses/{course_id}/enroll` | `require_roles("professor", "admin")` | Owner/Admin | `EnrollRequest` | `EnrollmentResponse` (201) | 400, 401, 403 | Enrolls student or TA into course. |
| L197 | `POST` | `/api/v1/courses/join` | `require_roles("student")` | `student` | `CourseJoinRequest` | `EnrollmentResponse` (201) | 400, 401, 403 | Enrolls student via valid `join_code`. |
| L215 | `DELETE` | `/api/v1/courses/{course_id}/enroll/{uid}` | `require_roles("professor", "admin")` | Owner/Admin | None | None | 401, 403, 404 | Removes enrollment record. |
| L232 | `POST` | `/api/v1/courses/{course_id}/enroll/csv` | `require_roles("professor", "admin")` | Owner/Admin | File: CSV | None | 400, 401, 403 | Batch enrolls students from uploaded CSV roster. |
| L252 | `GET` | `/api/v1/courses/{course_id}/clos` | `get_current_user` | Enrolled/Staff | None | `list[CLOResponse]` | 401, 403 | Reads course CLOs. |
| L269 | `POST` | `/api/v1/courses/{course_id}/clos` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | `CLOCreate` | `CLOResponse` (201) | 400, 401, 403 | Inserts `clos` row mapped to course and PLO. |
| L286 | `DELETE` | `/api/v1/courses/{course_id}/clos/{clo_id}` | `require_roles("professor", "admin")` | Owner/Admin | None | None | 401, 403, 404 | Deletes CLO (TA cannot delete). |
| L303 | `POST` | `/api/v1/courses/{course_id}/ta` | `require_roles("professor", "admin")` | Owner/Admin | `EnrollRequest` | `EnrollmentResponse` (201) | 400, 401, 403 | Delegates TA privileges to user for this course. |
| L326 | `POST` | `/api/v1/courses/{course_id}/chat` | `get_current_user` | Enrolled/Staff | `CourseChatRequest` | `CourseChatResponse` | 401, 403, 404 | RAG Q&A query against course materials vector store. |
| L469 | `GET` | `/api/v1/courses/{course_id}/gradebook/csv` | `require_roles("professor", "admin")` | Owner/Admin | None | `StreamingResponse` | 401, 403 | Generates full course gradebook CSV matrix. |

---

### 2.4 Assignments Router (`backend/app/api/v1/assignments.py:1-496`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L22 | `GET` | `/api/v1/courses/{course_id}/assignments` | `get_current_user` | Enrolled/Staff | Query: `status`, `page` | `AssignmentListResponse` | 401, 403 | If student, filters `status == 'published'`. |
| L61 | `POST` | `/api/v1/courses/{course_id}/assignments` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | `AssignmentCreate` | `AssignmentResponse` (201) | 400, 401, 403 | Inserts assignment row. Defaults `status = 'draft'`. |
| L82 | `PUT` | `/api/v1/courses/{course_id}/assignments/{aid}` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | `AssignmentUpdate` | `AssignmentResponse` | 400, 401, 403 | Updates assignment parameters. |
| L108 | `POST` | `/api/v1/courses/{course_id}/assignments/{aid}/publish` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | None | `AssignmentResponse` | 400, 401, 403 | Sets `assignments.status = 'published'`. |
| L134 | `GET` | `/api/v1/courses/{course_id}/assignments/{aid}` | `get_current_user` | Enrolled/Staff | None | `AssignmentResponse` | 401, 403, 404 | Returns single assignment. |
| L154 | `GET` | `/api/v1/courses/{course_id}/assignments/{aid}/tas` | `require_roles("professor", "admin")` | `prof`, `admin` | None | `list[AssignmentTAResponse]` | 401, 403 | Reads delegated TAs for this assignment. |
| L173 | `POST` | `/api/v1/courses/{course_id}/assignments/{aid}/tas` | `require_roles("professor", "admin")` | `prof`, `admin` | `AssignmentTARequest` | `AssignmentTAResponse` (201) | 400, 401, 403 | Inserts `assignment_tas` row. |
| L193 | `DELETE` | `/api/v1/courses/{course_id}/assignments/{aid}/tas/{ta_user_id}` | `require_roles("professor", "admin")` | `prof`, `admin` | None | None | 401, 403, 404 | Removes TA delegation row. |
| L216 | `GET` | `/api/v1/courses/{course_id}/assignments/{aid}/rubric` | `get_current_user` | Enrolled/Staff | None | `RubricResponse` | 401, 403, 404 | Fetches rubric and criteria for assignment. |
| L243 | `POST` | `/api/v1/courses/{course_id}/assignments/{aid}/rubric` | `require_roles("professor", "admin")` | `prof`, `admin` | `RubricCreate` | `RubricResponse` (201) | 400, 401, 403 | Creates rubric and criteria rows. |
| L267 | `PUT` | `/api/v1/courses/{course_id}/assignments/{aid}/rubric` | `require_roles("professor", "admin")` | `prof`, `admin` | `RubricCreate` | `RubricResponse` | 400, 401, 403 | Replaces rubric criteria rows. |
| L291 | `DELETE` | `/api/v1/courses/{course_id}/assignments/{aid}` | `require_roles("professor", "admin")` | `prof`, `admin` | None | None | 401, 403, 404, 500 | Deletes assignment and cascades to submissions. |
| L320 | `DELETE` | `/api/v1/courses/{course_id}/assignments/{aid}/rubric` | `require_roles("professor", "admin")` | `prof`, `admin` | None | None | 401, 403, 404, 500 | Deletes rubric and child criteria. |
| L357 | `GET` | `/api/v1/assignments/{aid}/rubric` | `get_current_user` | Enrolled/Staff | None | `RubricResponse` | 401, 403, 404 | Direct ID alias for rubric retrieval. |
| L382 | `POST` | `/api/v1/assignments/{aid}/rubric` | `require_roles("professor", "admin")` | `prof`, `admin` | `RubricCreate` | `RubricResponse` (201) | 400, 401, 403, 404 | Direct ID alias for rubric creation. |
| L406 | `DELETE` | `/api/v1/assignments/{aid}/rubric` | `require_roles("professor", "admin")` | `prof`, `admin` | None | None | 401, 403, 404 | Direct ID alias for rubric deletion. |
| L431 | `GET` | `/api/v1/courses/{course_id}/assignments/{aid}/export-csv` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | None | `StreamingResponse` | 401, 403, 404 | Exports grades CSV for single assignment. |

---

### 2.5 Submissions Router (`backend/app/api/v1/submissions.py:1-609`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L115 | `POST` | `/api/v1/courses/{course_id}/assignments/{aid}/submissions` | `require_roles("student")` | `student` | `SubmissionCreate` | `SubmissionResponse` (201) | 400, 401, 403 | Inserts text/code/link submission. Checks deadline and attempt limit. |
| L141 | `POST` | `/api/v1/courses/{course_id}/assignments/{aid}/submissions/file` | `require_roles("student")` | `student` | File: `UploadFile` (<=10MB) | `SubmissionResponse` (201) | 400, 401, 403, 413 | Writes file to disk (`uploads/assignments/`), records `file_path`. |
| L195 | `GET` | `/api/v1/courses/{course_id}/assignments/{aid}/submissions/me` | `require_roles("student")` | `student` | None | `SubmissionResponse` | 401, 404 | Retrieves authenticated student's submission. |
| L215 | `GET` | `/api/v1/courses/{course_id}/assignments/{aid}/submissions` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | None | `SubmissionListResponse` | 401, 403, 404 | Lists all submissions for assignment. |
| L248 | `PUT` | `/api/v1/submissions/{sid}/grade` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | `SubmissionGrade` | `SubmissionResponse` | 400, 401, 403, 404 | Records manual marks, feedback, sets `status = 'graded'`. |
| L269 | `POST` | `/api/v1/submissions/{sid}/ai-grade` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | Query: `sync: bool` | Dict / `SubmissionResponse` | 401, 403, 404, 502 | Invokes Groq DeepSeek-R1 model against rubric. Stores evaluation JSON. |
| L450 | `POST` | `/api/v1/courses/{course_id}/assignments/{aid}/ai-grade-all` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | None | Dict (batch summary) | 401, 403 | Iterates all pending submissions, runs LLM evaluator, commits results. |
| L568 | `GET` | `/api/v1/submissions/{sid}/file` | `get_current_user` | Owner or Staff | None | `FileResponse` | 401, 403, 404 | Streams submitted file to authorized student or instructor. |

---

### 2.6 Quizzes Router (`backend/app/api/v1/quizzes.py:1-1251`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L220 | `POST` | `/api/v1/courses/{course_id}/materials/ingest` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | File: `UploadFile` (<=50MB) | Dict (202 Accepted) | 400, 401, 403, 413 | Ingests PDF/DOCX into background task: chunking & vector indexing. |
| L310 | `GET` | `/api/v1/courses/{course_id}/materials` | `get_current_user` | Enrolled/Staff | None | Dict (material list) | 401, 403 | Lists all uploaded course lecture materials. |
| L379 | `GET` | `/api/v1/courses/{course_id}/materials/{material_id}/download` | `get_current_user` | Enrolled/Staff | None | `FileResponse` | 401, 403, 404 | Streams course material file. |
| L416 | `DELETE` | `/api/v1/courses/{course_id}/materials/{material_id}` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | None | Dict | 401, 403, 404 | Deletes file from disk and removes chunk embeddings from vector store. |
| L475 | `POST` | `/api/v1/quizzes/{quiz_id}/generate-questions` | `require_roles("professor", "admin")` | `prof`, `admin` | `GenerateQuestionsRequest` | `GenerateQuestionsResponse` | 400, 401, 403, 404 | Queries RAG vector DB, prompts LLM for Bloom-mapped questions. |
| L535 | `GET` | `/api/v1/quizzes/{quiz_id}/validate-blooms` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | None | `BloomsGateResult` | 400, 401, 403, 404 | Compares question Bloom levels against course target distribution. |
| L571 | `POST` | `/api/v1/quizzes/{quiz_id}/publish` | `require_roles("professor", "admin")` | `prof`, `admin` | Query: `force`, `exception_note` | `QuizPublishResponse` | 400, 401, 403, 404 | Publishes quiz; blocks if Bloom check fails unless `force=True`. |
| L638 | `GET` | `/api/v1/courses/{course_id}/clo-attainment` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | Query: `semester`, `quiz_id` | `CourseAttainmentReport` | 401, 403 | Computes OBE CLO attainment percentages from quiz attempt scores. |
| L664 | `GET` | `/api/v1/courses/{course_id}/question-bank` | `require_roles("professor", "admin", "ta")` | `prof`, `admin`, `ta` | Query: `status`, `bloom_level` | `List[QuestionBankItemResponse]` | 400, 401, 403 | Reads question repository filtered by status and Bloom cognitive tier. |
| L717 | `POST` | `/api/v1/question-bank/{question_id}/approve` | `require_roles("professor", "admin")` | `prof`, `admin` | None | Dict | 400, 401, 403, 404 | Sets `question_bank_items.status = 'APPROVED'`. |
| L751 | `POST` | `/api/v1/question-bank/{question_id}/reject` | `require_roles("professor", "admin")` | `prof`, `admin` | None | Dict | 400, 401, 403, 404 | Sets `question_bank_items.status = 'ARCHIVED'`. |
| L785 | `PATCH` | `/api/v1/question-bank/{question_id}` | `require_roles("professor", "admin")` | `prof`, `admin` | `QuestionBankUpdateRequest` | `QuestionBankItemResponse` | 400, 401, 403, 404 | Edits question text, options, correct answer, or Bloom level. |
| L845 | `POST` | `/api/v1/quizzes/{quiz_id}/questions` | `require_roles("professor", "admin")` | `prof`, `admin` | `AddQuestionsToQuizRequest` | None | 400, 401, 403, 404 | Links approved question bank items to quiz questions join table. |
| L920 | `POST` | `/api/v1/quizzes/{quiz_id}/attempts/start` | `get_current_user` | Enrolled student | `Optional[StartAttemptRequest]` | `StartAttemptResponse` | 400, 401, 403, 404 | Creates `quiz_attempts` row. Returns randomized questions. |
| L1049 | `POST` | `/api/v1/attempts/{attempt_id}/submit` | `get_current_user` | Attempt owner | `SubmitAttemptRequest` | `SubmitAttemptResponse` | 400, 401, 403, 404 | Auto-grades submitted answers against answer key, calculates score. |
| L1133 | `GET` | `/api/v1/attempts/{attempt_id}/result` | `get_current_user` | Owner or Staff | None | `AttemptResultResponse` | 400, 401, 403, 404 | Returns student quiz score and per-question breakdown. |
| L1218 | `GET` | `/api/v1/courses/{course_id}/hec-dossier` | `require_roles("professor", "admin")` | `prof`, `admin` | Query: `semester` | `FileResponse` / Dict | 401, 403, 404, 500 | Generates formal HEC Course Dossier PDF for accreditation. |

---

### 2.7 Analytics Router (`backend/app/api/v1/analytics.py:1-432`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Raised Codes | Side Effects |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L23 | `GET` | `/api/v1/courses/{course_id}/analytics` | `get_current_user` | Enrolled/Staff | None | `AnalyticsDashboardResponse` | 401, 404 | Aggregates class averages, submission distributions, pass rates. |
| L121 | `POST` | `/api/v1/courses/{course_id}/analytics/refresh` | `require_roles("professor", "admin")` | `prof`, `admin` | None | Dict | 401, 403 | Invalidates and recomputes analytics cache for course. |
| L142 | `GET` | `/api/v1/courses/{course_id}/analytics/at-risk` | `require_roles("professor", "admin")` | `prof`, `admin` | None | `list[AtRiskStudentResponse]` | 401, 403, 404 | Detects students scoring below 50% or with consecutive missed work. |
| L170 | `GET` | `/api/v1/courses/{course_id}/analytics/pdf` | `require_roles("professor", "admin")` | `prof`, `admin` | None | `StreamingResponse` | 401, 403, 404 | Generates multi-page course performance report PDF. |

---

### 2.8 System & SPA Router (`backend/app/main.py:1-165`)

| Line | Method | Path | Auth Dependency | Roles | Request Model | Response Model | Description |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| L77 | `GET` | `/health` | None | Public | None | `{"status": "ok", ...}` | Liveness check endpoint. |
| L81 | `GET` | `/ready` | None | Public | None | `{"status": "ready", ...}` | Readiness probe: executes `SELECT 1` on PostgreSQL (returns 503 if down). |
| L134 | `GET` | `/{full_path:path}` | None | Public | None | `FileResponse` | Static web file server with SPA fallback (`index.html`). |

---

## 3. Security Analysis: Permission Gaps & Potential Risks

[CODE] Verified by inspecting route definitions, dependencies, and service-layer assertions.

1. **Self-Service Registration Privilege Escalation Guard:**
   - [CODE `backend/app/schemas/auth.py:10`]: `RegisterRequest.role` is strictly constrained via `pattern="^(professor|student|ta)$"`.
   - Any attempt to pass `"admin"` at `POST /register` is rejected by Pydantic validation with `HTTP 422 Unprocessable Entity`.
   - Furthermore, [CODE `backend/app/services/registration_policy.py:5`] marks `needs_approval=True` and `is_approved=False` for all self-registered users. They cannot sign in until an existing admin calls `/api/v1/admin/users/{user_id}/approve`.

2. **Direct Assignment Rubric Access vs Course Isolation:**
   - [CODE `backend/app/api/v1/assignments.py:357-425`]: Routes `/api/v1/assignments/{aid}/rubric` do not take `course_id` in the URL path.
   - **Audit finding:** Handlers explicitly fetch `assignment = await svc.get_assignment(aid)` and then immediately invoke `course_svc.verify_course_management_access(assignment.course_id, user)`. Thus, tenant/course isolation is properly preserved.

3. **Submission File Download Authorization:**
   - [CODE `backend/app/api/v1/submissions.py:581-604`]:
     - If `user.role == "student"`, explicitly enforces `sub.student_id == user.id`. A student cannot download another student's file.
     - If `user.role == "professor"`, queries the course and verifies `course.professor_id == user.id`. A professor cannot download files from courses they do not teach.
     - If `user.role == "ta"`, checks `enrollments` table for role `"ta"` in that course.
     - If `user.role == "admin"`, access is granted globally.

4. **Weak / Inconsistent Check Identified:**
   - [CODE `backend/app/api/v1/quizzes.py:426`]: `DELETE /courses/{course_id}/materials/{material_id}` calls `course_svc.get_course_with_access_check(course_id, user)` instead of `verify_course_management_access`.
   - **Risk:** While `require_roles("professor", "admin", "ta")` blocks students, `get_course_with_access_check` allows ANY TA enrolled in the course to delete lecture materials and purge their vector index chunks, not just the course professor owner or admin.

---

## 4. Part 3 Follow-Up Audit & Technical Deep-Dive

### 4.1 Authorization on `/attempts/{id}/*` Endpoints [CODE]
1. `POST /attempts/{attempt_id}/violations` (`exams.py:434-463`):
   - Dependency: `require_roles("student")`.
   - Ownership check:
     ```python
     select(ExamAttempt)
     .where(
         ExamAttempt.id == attempt_id,
         ExamAttempt.student_id == user.id,
         ExamAttempt.submitted_at.is_(None),
     )
     ```
     Enforces `student_id == user.id`. Professors/TAs cannot call this endpoint (blocked by `require_roles("student")` with 403).
2. `POST /attempts/{attempt_id}/heartbeat` (`exams.py:514-540`):
   - Dependency: `require_roles("student")`.
   - Ownership check: Enforces `ExamAttempt.student_id == user.id`. Professors/TAs cannot call this endpoint (blocked with 403).
3. `GET /attempts/{attempt_id}/state` (`exams.py:620-652`):
   - Dependency: `require_roles("student", "professor", "admin", "ta")`.
   - Check in code:
     ```python
     if user.role == "student" and attempt.student_id != user.id:
         raise HTTPException(status_code=403, detail="Access denied.")
     ```
   - **SECURITY VULNERABILITY FOUND [CODE `exams.py:638-640`]:**
     If `user.role` is `"professor"` or `"ta"`, there is **NO course access check whatsoever**! Any professor or TA can view any student's exam state and full draft answers across the entire institution.

---

### 4.2 Routes Taking Only an ID: Course Ownership Audit Table [CODE]

| Route Path | Auth Dependency | Entity & Field Checked | Scoped to Course? | Exploit / Leakage Risk |
| :--- | :--- | :--- | :--- | :--- |
| `GET /attempts/{attempt_id}/state` | `student`, `prof`, `admin`, `ta` | `attempt.student_id == user.id` (students only) | **NO for Prof/TA** | **HIGH**: Any prof/TA can read draft answers and telemetry of any attempt. |
| `POST /attempts/{attempt_id}/violations` | `student` | `attempt.student_id == user.id` | **YES** | Scoped to owning student. |
| `POST /attempts/{attempt_id}/heartbeat` | `student` | `attempt.student_id == user.id` | **YES** | Scoped to owning student. |
| `PUT /submissions/{sid}/grade` | `prof`, `admin`, `ta` | `AssignmentService.verify_assignment_access` | **YES** | Verified against course/TA assignment. |
| `POST /submissions/{sid}/ai-grade` | `prof`, `admin`, `ta` | `AssignmentService.verify_assignment_access` | **YES** | Verified against course/TA assignment. |
| `GET /submissions/{sid}/file` | Any auth | Student: `sub.student_id == user.id`<br>Prof: `course.professor_id == user.id`<br>TA: `Enrollment.role == 'ta'` | **YES** | Verified against student ownership or instructor course assignment. |
| `POST /quizzes/{quiz_id}/generate-questions` | `prof`, `admin` | `course_svc.get_course_with_access_check` | **YES** | Verified against owning course instructor. |
| `GET /quizzes/{quiz_id}/validate-blooms` | `prof`, `admin`, `ta` | `course_svc.get_course_with_access_check` | **YES** | Verified against owning course staff. |
| `POST /quizzes/{quiz_id}/publish` | `prof`, `admin` | `course_svc.get_course_with_access_check` | **YES** | Verified against owning course instructor. |
| `POST /quizzes/{quiz_id}/questions` | `prof`, `admin` | `course_svc.get_course_with_access_check` | **YES** | Verified against owning course instructor. |
| `POST /quizzes/{quiz_id}/attempts/start` | `get_current_user` | `course_svc.get_course_with_access_check` | **YES** | Verified against course enrollment. |
| `POST /question-bank/{question_id}/approve` | `prof`, `admin` | `course_svc.get_course_with_access_check` | **YES** | Verified against question's `course_id`. |
| `POST /question-bank/{question_id}/reject` | `prof`, `admin` | `course_svc.get_course_with_access_check` | **YES** | Verified against question's `course_id`. |
| `PATCH /question-bank/{question_id}` | `prof`, `admin` | `course_svc.get_course_with_access_check` | **YES** | Verified against question's `course_id`. |
| `POST /attempts/{attempt_id}/submit` | `get_current_user` | `attempt.student_id == user.id` | **YES** | Scoped to attempt owner. |
| `GET /attempts/{attempt_id}/result` | `get_current_user` | Student: `attempt.student_id == user.id`<br>Staff: `user.role in ['professor', 'admin', 'ta']` | **NO for Staff** | **HIGH**: Any prof/TA from any course can inspect quiz scores and breakdown. |
| `GET /assignments/{aid}/rubric` | `get_current_user` | `course_svc.get_course_with_access_check` | **YES** | Scoped to enrolled students or course instructor. |
| `POST /assignments/{aid}/rubric` | `prof`, `admin` | `course_svc.verify_course_management_access` | **YES** | Scoped to course professor owner. |
| `DELETE /assignments/{aid}/rubric` | `prof`, `admin` | `course_svc.verify_course_management_access` | **YES** | Scoped to course professor owner. |

---

### 4.3 Assignment Update vs Settings Lock [CODE]
- [CODE `backend/app/schemas/assignment.py:25-38`]:
  `AssignmentUpdate` contains `time_limit_minutes`, but does **NOT** contain `strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, or `unsupported_browser_policy`.
- [CODE `backend/app/services/assignment_service.py:203-219`]:
  `PUT /courses/{course_id}/assignments/{aid}` does **NOT** check if attempts exist.
  **Conclusion:** `strike_limit_*` and proctoring policies cannot be edited here, but `time_limit_minutes` CAN be edited here while an exam is running, bypassing the 409 lock.

---

### 4.4 Questions Leakage: Full Description Exposed Before Start [CODE]
- [CODE `backend/app/api/v1/assignments.py:134-148`]:
  ```python
  @router.get("/courses/{course_id}/assignments/{aid}", response_model=AssignmentResponse)
  async def get_assignment(course_id: int, aid: int, ...):
      assignment = await svc.verify_assignment_access(aid, user)
      resp = AssignmentResponse.model_validate(assignment)
      return resp
  ```
- **Finding:** `AssignmentResponse` serializes `description: Optional[str] = None`.
  For MCQ and exam assignments where questions are placed in `description`, the full text containing all questions and answer choices is delivered to the student's browser immediately upon loading the assignment detail screen—**long before the student clicks "Start Exam", accepts fullscreen, or starts the timer**.

---

### 4.5 Alt-Tab Double Strike & Deduplication Flaw [CODE]
1. **Frontend Flow:**
   In `frontend/lib/features/courses/utils/web_window_listener_web.dart:106-115`, an Alt+Tab out of the browser triggers two distinct browser events almost simultaneously:
   - `window.onBlur` $\to$ sends `window_blur`
   - `document.onVisibilityChange` (`document.hidden == true`) $\to$ sends `tab_switch`
2. **Backend Deduplication Logic [CODE `exams.py:208-228`]:**
   ```python
   recent_res = await db.execute(
       select(ExamViolation)
       .where(
           ExamViolation.attempt_id == attempt.id,
           ExamViolation.violation_type == violation_type,  # <-- Type-specific match!
       )
       .order_by(ExamViolation.occurred_at.desc())
       .limit(1)
   )
   ```
   Because the deduplication queries `ExamViolation.violation_type == violation_type`, `window_blur` is only checked against prior `window_blur` events, and `tab_switch` is only checked against prior `tab_switch` events.
   **Result:** The backend treats them as two distinct violation events and increments `tab_switch_count` by **2 strikes** for a single Alt+Tab!
3. **Excluded Types:**
   **None.** In `record_violation` (`exams.py:238-243`), every incoming violation increments `tab_switch_count += 1`. No violation types are excluded from the strike count.

---

### 4.6 Exam Monitor Heartbeat Timeout & Strike Logic [CODE]
- [CODE `backend/app/core/proctor_config.py:4`]:
  `HEARTBEAT_TIMEOUT_SECONDS: int = 30` (Single constant; not 35, not 45).
- [CODE `backend/app/services/exam_monitor.py:74-85`]:
  ```python
  if can_log:
      event = ExamViolation(
          attempt_id=attempt.id,
          violation_type="heartbeat_missed",
          occurred_at=now,
          details=f"No heartbeat received for {int(elapsed)}s.",
      )
      db.add(event)
      attempt.is_flagged = True
      attempt.flag_reason = f"[OFFLINE] Heartbeat missed ({int(elapsed)}s without signal)."
      flagged_offline_count += 1
  ```
  **Finding:** The monitor's `heartbeat_missed` handler sets `attempt.is_flagged = True` and inserts an `ExamViolation` record, but **NEVER increments `tab_switch_count`**. It does not add strikes.

---

### 4.7 Rejection of Second Submission for Proctored Assignments [CODE]
- [CODE `backend/app/api/v1/submissions.py:45-48`, `130-134`]:
  ```python
  validate_timed_submission_attempt(
      assignment,
      await _get_timed_attempt(aid, user.id, db),
      allow_expired=False,
  )
  ```
  Where `_get_timed_attempt` queries:
  ```python
  where(
      ExamAttempt.assignment_id == assignment_id,
      ExamAttempt.student_id == student_id,
      ExamAttempt.submitted_at.is_(None),  # Must be currently unsubmitted
  )
  ```
  And `validate_timed_submission_attempt` asserts:
  ```python
  if attempt is None or getattr(attempt, "submitted_at", None) is not None:
      raise ValueError("An active exam attempt is required for this submission.")
  ```
  **Verdict:** Once an attempt is submitted or auto-closed, there is no unsubmitted attempt row. A second submission call to `POST /courses/{course_id}/assignments/{aid}/submissions` fails with `HTTP 400: An active exam attempt is required for this submission.`

---

### 4.8 `start_exam` Status and Deadline Verification [CODE]
- [CODE `backend/app/api/v1/exams.py:367-368`]:
  ```python
  if assignment.status != "published":
      raise HTTPException(status_code=400, detail="Assignment is not published.")
  ```
  `start_exam` **DOES** check `status == "published"`.
- **CRITICAL GAP:** `start_exam` **NEVER** checks `assignment.deadline`!
  A student can invoke `start_exam` weeks after the course deadline has passed, and the server will grant an active attempt with a fresh timer.

---

### 4.9 Password Hashing Correction [CODE]
- [CODE `backend/app/core/security.py:7-35`]:
  Password hashing uses **Argon2id** (`from argon2 import PasswordHasher, Type`), not bcrypt.
  Configured with: `time_cost=2`, `memory_cost=65536` (64 MB), `parallelism=1`, `hash_len=32`, `type=Type.ID`.

---

PART 3 FOLLOW-UP DONE

