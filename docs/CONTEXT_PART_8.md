# CONTEXT PART 8: KNOWN PROBLEMS & HONEST STATUS (REVISED & AUDITED)
**Date:** 2026-10-17  
**Status:** FORENSIC AUDIT & CORRECTIONS COMPLETE  
**Repository:** ProfessorOS (`backend/` and `frontend/`)  

---

## 1. Feature Status Matrix

| Feature | In Code? | Tested How? | Tested in Real Browser? | Known Bugs / Limitations |
|:---|:---|:---|:---|:---|
| **Fullscreen Start** | `[CODE]` ([`web_window_listener_web.dart:29`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/web_window_listener_web.dart#L29), [`exam_screen.dart:559`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L559)) | Unit tested via stub (`proctor_detector_test.dart`); backend unit tests | `NOT RUN` (Manual checklist row 2.1 marked `NOT RUN`) | Requires synchronous user gesture. If permission is denied or browser unsupported (e.g. iOS Safari), banner shows but exam starts unproctored. |
| **Esc Key Handling** | `[CODE]` ([`web_window_listener_web.dart:41`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/web_window_listener_web.dart#L41), [`exam_screen.dart:509-516`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L509-L516)) | Dart unit test (`proctor_detector_test.dart`); backend violation test | `NOT RUN` (Requires physical Esc key on desktop) | `navigator.keyboard.lock(['Escape'])` is Chrome/Edge only. On Firefox/Safari, Esc exits fullscreen immediately; overlay locks screen with no option to exit except clicking "Return to Exam". |
| **Tab Switch Dedupe** | `[CODE]` ([`exams.py:207-236`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L207-L236), [`proctor_detector.dart:77-79`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/proctor_detector.dart#L77-L79)) | `pytest` concurrency suite (`test_duplicate_violations_within_dedupe_window_count_once`) `[RAN]` | `NOT RUN` | **Alt-Tab Double Strike Risk**: Frontend uses 1.5s window; backend uses 1.5s window. If network delay or event queuing causes delivery to take >1.5s, multiple strikes are recorded on server for a single Alt-Tab. |
| **File Picker Grace** | `[CODE]` ([`proctor_detector.dart:30-47`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/proctor_detector.dart#L30-L47), [`exam_screen.dart:738`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L738)) | Flutter unit test (`proctor_detector_test.dart`) `[RAN]` | `NOT RUN` | Hardcoded 60s max safety timer ([`proctor_detector.dart:10`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/proctor_detector.dart#L10)). If student searches OS directory >60s, flag clears while window is blurred, triggering false strikes upon return. |
| **Heartbeat & Draft Save** | `[CODE]` ([`exams.py:513-575`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L513-L575), [`exam_screen.dart:500-530`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L500-L530)) | `pytest` test (`test_heartbeat_timeout_creates_flag_and_event`) `[RAN]` | `NOT RUN` | No max length validation on `HeartbeatRequest.answers` JSON text. Client local timer never resyncs from heartbeat `remaining_seconds` response. |
| **Offline Queue** | `[CODE]` ([`offline_violation_queue.dart:1-35`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/offline_violation_queue.dart#L1-L35), [`exam_screen.dart:466-494`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L466-L494)) | Pure Dart unit test on queue class `[RAN]` | `NOT RUN` | **Critical Data Loss**: `drainQueue()` clears list; if an item fails during loop, it re-enqueues only that item and breaks, permanently dropping all subsequent queued violations. Client timestamps discarded by server. |
| **Auto-Submit** | `[CODE]` ([`exams.py:121-180`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L121-L180), [`exam_monitor.py:30-90`](file:///e:/FYP_YASIN/backend/app/services/exam_monitor.py#L30-L90), [`exam_screen.dart:422-425`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L422-L425)) | `pytest` test (`test_expired_attempt_gets_autoclosed_by_background_job`) `[RAN]` | `NOT RUN` | Monitor inserts placeholder `// [Time Expired - Auto-Submitted by System]` which breaks downstream AI code evaluation pipelines expecting valid executable code. |
| **Server Authoritative Timer** | `[CODE]` ([`exams.py:141-160`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L141-L160), [`exam_monitor.py:35-45`](file:///e:/FYP_YASIN/backend/app/services/exam_monitor.py#L35-L45)) | `pytest` test (`test_stale_or_crashed_attempt_resumed_without_extra_time`) `[RAN]` | `NOT RUN` | Client local countdown drifts independently from server clock. Monitor daemon sweep frequency is 15 seconds. |
| **Exam Resume** | `[CODE]` ([`exams.py:365-420`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L365-L420), [`exam_screen.dart:250-320`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L250-L320)) | Backend unit tested `[RAN]` | `NOT RUN` | **Critical UX Bug**: Browser reload (F5) wipes `state.extra`, leaving title, description, and time limit empty. |
| **Allow Retake** | `[CODE]` ([`exams.py:910-940`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L910-L940), [`assignment_detail_screen.dart:3680-3720`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/assignment_detail_screen.dart#L3680-L3720)) | Backend unit tested `[RAN]` | `NOT RUN` | Creates second attempt, but does not archive prior submission in `submissions` table. Subsequent submission overwrites existing record. |
| **Clear Flags** | `[CODE]` ([`exams.py:890-908`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L890-L908)) | `test_clear_action_preserves_switches_and_unflags` `[RAN]` | `NOT RUN` | Sets `is_flagged = False`, but preserves `tab_switch_count`. The next violation immediately re-flags or auto-submits student if threshold is reached. |
| **Invalidate Attempt** | `[CODE]` ([`exams.py:883-887`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L883-L887)) | Backend unit tested `[RAN]` | `NOT RUN` | Only updates `reviewed_by_id`, `reviewed_at`, `decision`, `decision_reason`, `is_flagged = True`, `flag_reason`, and `submitted_at`. Does NOT alter `submissions` table, score, gradebook, or OBE attainment. |
| **Settings Lock** | `[CODE]` ([`exams.py:1011-1038`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L1011-L1038)) | Backend unit tested on PUT route `[RAN]` | `NOT RUN` | **Security Bypass**: Enforced on `PUT /courses/{cid}/assignments/{aid}/exam/settings`, but completely bypassed on general `PUT /courses/{cid}/assignments/{aid}` for `time_limit_minutes`. |
| **Settings Propagation** | `[NOT DONE]` ([`app_router.dart:178-193`](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L178-L193)) | Code inspection | `NOT RUN` | **Settings Never Reach ExamScreen**: `app_router.dart` never passes `fullscreenRequired`, `blockClipboard`, `unsupportedBrowserPolicy`, or strike limits to `ExamScreen`; hardcoded widget defaults are always used. |
| **CSV Export** | `[CODE]` ([`exams.py:929-1008`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L929-L1008), [`assignment_detail_screen.dart:1980-2050`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/assignment_detail_screen.dart#L1980-L2050)) | Backend and frontend code inspection | `NOT RUN` | **Vulnerability**: Formula injection on unescaped student names and text (`=`, `+`, `-`, `@`). |
| **Live Proctor Console** | `[CODE]` ([`assignment_detail_screen.dart:380-450`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/assignment_detail_screen.dart#L380-L450)) | Flutter widget tests `[RAN]` | `NOT RUN` | Polls every 10s via unmanaged timer; causes UI rebuilds and lacks pagination for large classes. |
| **Proctor Filters** | `[CODE]` ([`assignment_detail_screen.dart:500-560`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/assignment_detail_screen.dart#L500-L560)) | Flutter widget tests `[RAN]` | `NOT RUN` | Client-side filtering over in-memory list; missing server pagination on `GET /proctor/attempts`. |
| **Anti-Copy / Paste Block** | `[CODE]` ([`web_window_listener_web.dart:126-150`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/web_window_listener_web.dart#L126-L150)) | Manual checklist row marked `NOT RUN` | `NOT RUN` | Listens only on DOM `document`. Does not block virtual keyboard paste or canvas drag-and-drop. |
| **Multi-Monitor Detection** | `[CODE]` ([`web_window_listener_web.dart:80-95`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/web_window_listener_web.dart#L80-L95)) | Pure Dart stub tested `[RAN]` | `NOT RUN` | Requires experimental Chrome Window Management API; prompts user for permission. Defaults to 1 if unsupported or denied. |
| **Unsupported Browser Policy** | `[CODE]` ([`web_window_listener_web.dart:18-25`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/web_window_listener_web.dart#L18-L25), [`exam_screen.dart:52`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L52)) | Feature detection unit test `[RAN]` | `NOT RUN` | Parameter `unsupportedBrowserPolicy` is never passed from assignment configuration (defaults to `warn_allow`). |
| **MCQ Text Fallback** | `[CODE]` ([`exam_screen.dart:578-584, 1451-1463`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L578-L584)) | Live DB query verified `[RAN]` | `NOT RUN` | **Critical Bug**: When MCQ has no parsed options, UI shows text input, but `_submitExam` submits `[No answers selected]`, dropping typed text. |
| **Universal Safeguard 1-4** | `[NOT DONE]` (Not implemented in code) | N/A | N/A | **RETRACTED**: No "Universal Safeguards 1-4" framework or classes exist. Procedural endpoint logic exists in `exams.py` under the function name `record_violation` and in `proctor_detector.dart` under `ProctorDetector`. |

---

## 2. Real Implementation: What Exists Instead of "Universal Safeguard 1-4"

No specification, protocol, or abstraction named "Universal Safeguard 1-4" exists anywhere in the repository. Instead, the proctoring logic consists of procedural checks spread across backend endpoints and frontend utility classes:

1. **`record_violation()` in [`backend/app/api/v1/exams.py:184-280`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L184-L280)**:
   - **Procedural Expiration Check** ([`exams.py:196`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L196)): Calls `is_attempt_expired()`. If expired, invokes `auto_close_attempt(attempt, assignment, db, reason="time_expired")`.
   - **Procedural Sliding-Window Deduplication** ([`exams.py:207-236`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L207-L236)): Queries `ExamViolation` for the most recent violation of the same type. If `(now - last_t).total_seconds() < 1.5`, returns an early deduplicated response without incrementing strikes.
   - **Atomic SQL Counter Increment** ([`exams.py:240-243`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L240-L243)): Executes `update(ExamAttempt).values(tab_switch_count=ExamAttempt.tab_switch_count + 1)`.
   - **Audit Record Creation** ([`exams.py:247-253`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L247-L253)): Inserts an `ExamViolation` event row.
   - **Procedural Threshold Flags & Auto-Submit** ([`exams.py:255-272`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L255-L272)): Compares `tab_switch_count` against `strike_limit_flag` (default 3) and `strike_limit_autosubmit` (default 5). If $\ge 5$, marks `auto_closed = True` and auto-submits.

2. **`ProctorDetector` in [`frontend/lib/features/courses/utils/proctor_detector.dart:5-91`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/proctor_detector.dart#L5-L91)**:
   - Client-side debounce state machine with `dedupeWindow = const Duration(milliseconds: 1500)`.
   - `filePickerGrace = const Duration(milliseconds: 1500)` with `maxFilePickerTimeout = const Duration(seconds: 60)`.
   - `maxRestoringTimeout = const Duration(seconds: 3)`.

---

## 3. Re-Checked & Corrected Technical Details

### A. Invalidate Columns (`exams.py:883-887`)
`ExamAttempt` **does NOT have a `status` column**. When an instructor calls `/decision` with `action="invalidate"`, the backend executes:
```python
attempt.reviewed_by_id = user.id
attempt.reviewed_at = now
attempt.decision = "invalidate"
attempt.decision_reason = reason
attempt.is_flagged = True
attempt.flag_reason = f"[DISQUALIFIED] {reason}"
if not attempt.submitted_at:
    attempt.submitted_at = now
```
- Columns modified: `reviewed_by_id`, `reviewed_at`, `decision`, `decision_reason`, `is_flagged`, `flag_reason`, `submitted_at`.
- Columns NOT touched: It does **not** touch the `submissions` table, does **not** reset or zero out `submissions.score`, does **not** remove the submission from the gradebook, and does **not** adjust OBE attainment.

### B. Settings Route Name & HTTP Method
- **Method & Path:** `PUT /courses/{course_id}/assignments/{assignment_id}/exam/settings` ([`exams.py:1011`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L1011))
- It is **NOT** `PATCH /assignments/{aid}/exam-settings`.
- Enforces lock:
```python
attempt_check = await db.execute(
    select(ExamAttempt.id)
    .where(ExamAttempt.assignment_id == assignment_id)
    .limit(1)
)
if attempt_check.scalar_one_or_none() is not None:
    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail="Exam settings are locked because student attempts have already started.",
    )
```

### C. Monitor Interval & Constants Location
- **Monitor Sweep Interval:** **15 seconds** (passed as `interval_seconds=15` in [`backend/app/main.py:28`](file:///e:/FYP_YASIN/backend/app/main.py#L28) into `run_exam_monitor_daemon()` in [`backend/app/services/exam_monitor.py:94`](file:///e:/FYP_YASIN/backend/app/services/exam_monitor.py#L94)).
- **Where Constants Live:** Centrally defined in **[`backend/app/core/proctor_config.py`](file:///e:/FYP_YASIN/backend/app/core/proctor_config.py)**:
```python
HEARTBEAT_TIMEOUT_SECONDS: int = 30
SUBMISSION_GRACE_SECONDS: int = 10
VIOLATION_DEDUPE_WINDOW_SECONDS: float = 1.5
DEFAULT_STRIKE_LIMIT_FLAG: int = 3
DEFAULT_STRIKE_LIMIT_AUTOSUBMIT: int = 5
MAX_RESTORING_WINDOW_SECONDS: int = 3
FILE_PICKER_GRACE_SECONDS: float = 1.5
```

### D. Decision Reason Validation
- Validated declaratively via Pydantic model [`ExamDecisionRequest`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L72-L75):
```python
class ExamDecisionRequest(BaseModel):
    action: str = Field(..., pattern="^(accept|invalidate|allow_retake|clear)$")
    reason: str = Field(..., min_length=3, max_length=1000, description="Mandatory instructor rationale")
```
Validation is enforced by FastAPI/Pydantic (`min_length=3`, `max_length=1000`).

### E. Which Fields `PUT /assignments` Can Change
- General assignment endpoint: `PUT /courses/{course_id}/assignments/{aid}` ([`assignments.py:82-106`](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L82-L106)).
- Schema: [`AssignmentUpdate`](file:///e:/FYP_YASIN/backend/app/schemas/assignment.py#L25-L37).
- **Fields it CAN change:** `title`, `description`, `max_marks`, `deadline`, `allow_late`, `late_penalty_per_day`, `max_penalty_cap`, `time_limit_minutes`, `max_attempts`, `randomize_questions`, `show_results_after`, `clo_ids`.
- **Fields it CANNOT change:** `strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, `unsupported_browser_policy`, `type`, `status`.
- **Vulnerability:** `PUT /courses/{cid}/assignments/{aid}` has zero checks for active student attempts. A professor can edit `time_limit_minutes` while an exam is actively running, bypassing the lock on `PUT /courses/{cid}/assignments/{aid}/exam/settings`.

---

## 4. Comprehensive Bug & Risk Ranking

### High Severity (Critical / Data Loss / Security / Broken UX)
1. **MCQ Text Fallback Answer Dropped (Data Loss)**:  
   [`exam_screen.dart:578-584, 1451-1463`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L578-L584). When an MCQ has no standard `A) B) C)` options, UI renders a text box, but `_submitExam` calls `_serializeMcqAnswers()`, returns `null`, and sends `[No answers selected]`, dropping typed text. (Verified with live DB record: student 23 on assignment 37).
2. **Offline Queue Truncation Data Loss**:  
   [`exam_screen.dart:475-494`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L475-L494). `drainQueue()` empties the queue. If an error occurs on item $k$, only item $k$ is re-enqueued before `break;`, permanently losing all items from $k+1$ to $N$.
3. **F5 / Browser Refresh State Wipeout**:  
   [`app_router.dart:178-193`](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L178-L193). Exam route reads `assignmentTitle`, `timeLimitMinutes`, and `description` from ephemeral `state.extra`. On browser refresh, `state.extra` is null, wiping all exam metadata.
4. **Pre-Start Question Exposure**:  
   [`assignments.py:45-70`](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L45-L70). `GET /courses/{cid}/assignments/{aid}` returns the full `description` (which contains all exam questions) to any enrolled student before they click "Start Exam" and before any proctoring attempt begins.
5. **Failed-Submit Frozen Timers**:  
   [`exam_screen.dart:533-537`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L533-L537). `_submitExam` cancels `_timer` and `_heartbeatTimer` at entry. If the network call throws an error, the catch block sets `_error`, but never restarts the countdown or heartbeat timers. The student is stranded with frozen timers and cannot retry.
6. **Retake / Submission Overwrite Conflict**:  
   [`exams.py:910-940`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L910-L940), [`submission_service.py:64-80`](file:///e:/FYP_YASIN/backend/app/services/submission_service.py#L64-L80). "Allow Retake" allows creating a new attempt row, but does not archive the prior submission record. Subsequent submission calls in `submission_service.py` overwrite the pending submission row, destroying attempt #1's artifact.
7. **Proctoring Settings Never Reach ExamScreen**:  
   [`app_router.dart:178-193`](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L178-L193). `app_router.dart` constructs `ExamScreen` without passing `fullscreenRequired`, `blockClipboard`, `unsupportedBrowserPolicy`, or strike limits. `ExamScreen` always falls back to hardcoded constructor defaults regardless of professor configuration.
8. **Never-Heartbeat Blind Spot**:  
   [`exam_monitor.py:55-60`](file:///e:/FYP_YASIN/backend/app/services/exam_monitor.py#L55-L60). `start_exam` creates an attempt with `last_heartbeat_at = None`. The background monitor checks `if attempt.last_heartbeat_at is not None:`. If a student crashes before their first heartbeat, they are never detected as offline and never flagged.
9. **Staff Reading Any Attempt Across University**:  
   [`exams.py:645-665`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L645-L665). `GET /attempts/{attempt_id}/state` checks role `professor` or `ta`, but never verifies course ownership. Any instructor or TA can query any student's live attempt state.
10. **TA Permission Lockout on Exam Decisions (403 Forbidden)**:  
    [`exams.py:847`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L847) vs [`course_service.py:114`](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L114). Route dependency accepts role `ta`, but `verify_course_management_access` strictly asserts `user.role == "professor" and course.professor_id == user.id`. TAs receive 403 Forbidden.
11. **Invalidate Attempt Does Not Touch Submissions or Grades**:  
    [`exams.py:883-887`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L883-L887). Setting decision to `invalidate` flags the attempt, but leaves the submission in `submissions` untouched. The submission is still auto-graded by AI and included in gradebook averages.
12. **Assignment Edit Bypasses Proctoring Settings Lock**:  
    [`assignments.py:82-106`](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L82-L106). `PUT /courses/{cid}/assignments/{aid}` permits changing `time_limit_minutes` without checking for active attempts.
13. **Hardcoded Secrets & Production DB Credentials in Repository**:  
    [`backend/app/config/settings.py:30, 39`](file:///e:/FYP_YASIN/backend/app/config/settings.py#L30). Plaintext secret key and default database connection string committed in code.
14. **CSV Formula Injection in Backend and Frontend**:  
    [`exams.py:982-999`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L982-L999), [`user_service.py:231-235`](file:///e:/FYP_YASIN/backend/app/services/user_service.py#L231-L235), [`assignment_detail_screen.dart:1980-2050`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/assignment_detail_screen.dart#L1980-L2050). No escaping of leading formula characters (`=`, `+`, `-`, `@`).

### Medium Severity (Inconsistencies / Ineffective Guards / State Sync)
15. **Alt-Tab Double Strike Vulnerability**:  
    [`exams.py:207-236`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L207-L236). Browser fires `visibilitychange` and `blur` nearly simultaneously. If network delay or retry queuing causes them to arrive >1.5s apart, 2 strikes are recorded on server for 1 switch.
16. **Clear Flags Preserves Strike Counter**:  
    [`exams.py:891-894`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L891-L894). Resetting flags clears `is_flagged`, but preserves `tab_switch_count`. The next violation immediately triggers auto-submit if at limit.
17. **Client Countdown Timer Never Resyncs With Server Clock**:  
    [`exam_screen.dart:366`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L366). Client ticker runs independently; heartbeat returns `remaining_seconds`, but client ignores it.
18. **Offline Queue Timestamps Discarded by Backend**:  
    [`exam_screen.dart:480-484`](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L480-L484), [`exams.py:192`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L192). Backend overwrites violation timestamps with server receipt time.
19. **File Picker Grace Period Hard Cutoff (60s)**:  
    [`proctor_detector.dart:10, 34`](file:///e:/FYP_YASIN/frontend/lib/features/courses/utils/proctor_detector.dart#L10). Causes false strikes if user searches filesystem > 60s.
20. **Unbounded Heartbeat Answers Payload**:  
    [`exams.py:518`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L518). No max length validation on `HeartbeatRequest.answers`.
21. **Start Exam Bypasses Assignment Deadline Validation**:  
    [`exams.py:280-340`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L280-L340). Does not verify `now <= assignment.deadline`.
22. **AI Grading Pipeline Passes Unhandled Timeout Placeholder**:  
    [`submission_service.py:310-340`](file:///e:/FYP_YASIN/backend/app/services/submission_service.py#L310-L340). Timeout string passed directly to DeepSeek-R1.

---

## 5. Database Architecture: Real Dev DB & Connection Strings

### Real Dev DB Identification
- **Real Dev DB:** **Windows Service on port 5432** (`postgresql.exe`).
- **Docker is NOT running**: The command `docker` is not recognized on the host OS. Docker container `fyp_yasin-db-1` is offline / non-existent.
- **Application Connection String:**  
  Configured in [`backend/.env:1`](file:///e:/FYP_YASIN/backend/.env#L1):  
  ```ini
  DATABASE_URL=postgresql+asyncpg://postgres:admin@127.0.0.1:5432/professor_os_db
  ```
  Fallback in [`app/config/settings.py:30`](file:///e:/FYP_YASIN/backend/app/config/settings.py#L30):  
  ```python
  DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/professor_os"
  ```
- **Tests Connection String:**  
  Tests do **NOT** connect to PostgreSQL! All automated concurrency and unit tests run against in-memory SQLite:  
  - [`backend/tests/test_exam_concurrency.py:38`](file:///e:/FYP_YASIN/backend/tests/test_exam_concurrency.py#L38): `"sqlite+aiosqlite:///:memory:"`  
  - [`backend/tests/test_exam_professor_and_audit.py:47`](file:///e:/FYP_YASIN/backend/tests/test_exam_professor_and_audit.py#L47): `"sqlite+aiosqlite:///:memory:"`  
  - [`backend/tests/test_exam_threads_concurrency.py:23`](file:///e:/FYP_YASIN/backend/tests/test_exam_threads_concurrency.py#L23): temporary file-based SQLite database with WAL mode.

---

## 6. Backend CSV Writer & Formula Injection Audit

### A. Exam Attempts CSV Writer ([`backend/app/api/v1/exams.py:957-1008`](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L957-L1008))
```python
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Attempt ID",
        "Student ID",
        "Student Name",
        "Student Email",
        "Attempt Number",
        "Started At",
        "Submitted At",
        "Duration Limit (min)",
        "Strikes",
        "Flagged",
        "Auto-Submitted",
        "Total Violations",
        "Decision",
        "Decision Reason",
        "Reviewed By",
        "Reviewed At",
    ])

    for a in attempts:
        student_name = a.student.full_name if a.student else f"Student #{a.student_id}"
        student_email = a.student.email if a.student else ""
        reviewer_name = a.reviewer.full_name if (getattr(a, "reviewer", None) and a.reviewer) else ""
        writer.writerow([
            a.id,
            a.student_id,
            student_name,
            student_email,
            getattr(a, "attempt_number", 1) or 1,
            a.started_at.isoformat() if a.started_at else "",
            a.submitted_at.isoformat() if a.submitted_at else "",
            a.duration_minutes or assignment.time_limit_minutes or "",
            a.tab_switch_count,
            "YES" if a.is_flagged else "NO",
            "YES" if a.auto_submitted else "NO",
            len(a.violations or []),
            getattr(a, "decision", "") or "",
            getattr(a, "decision_reason", "") or "",
            reviewer_name,
            a.reviewed_at.isoformat() if getattr(a, "reviewed_at", None) else "",
        ])

    csv_data = output.getvalue()
    return StreamingResponse(
        iter([csv_data]),
        media_type="text/csv",
        headers={
            "Content-Disposition": f"attachment; filename=exam_attempts_assignment_{assignment_id}.csv"
        },
    )
```

### B. User Export CSV Writer ([`backend/app/services/user_service.py:225-236`](file:///e:/FYP_YASIN/backend/app/services/user_service.py#L225-L236))
```python
    async def export_users_csv(self, role_filter: Optional[str] = None, search: Optional[str] = None) -> str:
        """Export filtered users list as CSV string."""
        users, _ = await self.list_users(page=1, page_size=10000, role_filter=role_filter, search=search)
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["id", "email", "full_name", "role", "is_active", "is_verified", "created_at"])
        for u in users:
            writer.writerow([
                u.id, u.email, u.full_name, u.role, u.is_active, u.is_verified,
                u.created_at.isoformat() if u.created_at else ""
            ])
        return output.getvalue()
```

### Is Formula Injection Escaped?
**NO.** Neither writer performs formula injection sanitization.
- In `export_exam_attempts_csv`: `student_name`, `student_email`, `decision_reason`, and `reviewer_name` are passed raw to `writer.writerow()`.
- In `export_users_csv`: `u.full_name` and `u.email` are passed raw to `writer.writerow()`.
- If any string starts with `=`, `+`, `-`, or `@`, spreadsheet applications (Excel, LibreOffice) will execute the payload as an active cell formula when opened by instructors or administrators.

---

## 7. Affected-Students Queries & Remote Database Status

### Non-Dev / Deployed Database Status
**The deployed database is UNREACHABLE.**  
- The live production app is deployed on Railway (`https://professor-os-production-65b2.up.railway.app`).
- No Railway API tokens, Railway CLI credentials, or remote PostgreSQL connection strings are present in local environment variables, `.env`, or configuration files.
- Therefore, the queries cannot be run against the Railway production database from this environment.

### Results on Local Development PostgreSQL (`127.0.0.1:5432/professor_os_db`)

#### Query 1: Submissions with `"[No answers selected]"` (MCQ Text Fallback Bug)
```sql
SELECT 
    s.id AS submission_id,
    s.assignment_id,
    s.student_id,
    u.full_name AS student_name,
    u.email AS student_email,
    a.title AS assignment_title,
    a.type AS assignment_type,
    s.content,
    s.submitted_at
FROM submissions s
JOIN assignments a ON s.assignment_id = a.id
JOIN users u ON s.student_id = u.id
WHERE s.content LIKE '%[No answers selected]%'
   OR s.content LIKE '%[Time Expired - No answers selected]%'
ORDER BY s.submitted_at DESC;
```
*Live Dev DB Result:* **1 record found**:
- `submission_id: 2`
- `assignment_id: 37` ("Quiz 01: Concurrency & Deadlocks", `type: 'mcq'`)
- `student_id: 23` ("Hamza Khan", `student2@fast.edu`)
- `content: '[No answers selected]'`

#### Query 2: Submissions Where Typed Text May Have Been Lost (Empty Attempt vs Populated Submission)
```sql
SELECT 
    s.id AS submission_id,
    s.assignment_id,
    s.student_id,
    u.full_name AS student_name,
    ea.id AS attempt_id,
    ea.current_answers,
    s.content,
    s.submitted_at
FROM submissions s
JOIN users u ON s.student_id = u.id
LEFT JOIN exam_attempts ea ON ea.assignment_id = s.assignment_id AND ea.student_id = s.student_id
WHERE (ea.current_answers IS NULL OR trim(ea.current_answers) IN ('', '{}', '[]'))
  AND s.content IS NOT NULL 
  AND length(trim(s.content)) > 0
ORDER BY s.submitted_at DESC;
```
*Live Dev DB Result:* **2 records found**:
- `submission_id: 2`, `student_id: 23`, `assignment_id: 37`: Attempt `current_answers` was `'{}'` and submission content was `'[No answers selected]'`.
- `submission_id: 1`, `student_id: 22`, `assignment_id: 37`: Attempt was `None` (legacy manual submission before attempt tracking was required).
