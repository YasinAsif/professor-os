# ProfessorOS Architectural Context – Part 7: Test Suites & Verification

**Generated:** 2026-10-17  
**Scope:** Backend test suite (`backend/tests/`), Frontend test suite (`frontend/test/`), live test execution, gap analysis of untested areas, test modifications history, and audit of [`docs/PROCTORING_MANUAL_TEST.md`](file:///e:/FYP_YASIN/docs/PROCTORING_MANUAL_TEST.md).  
**Rules Applied:** Read-only inspection of source code files, exact line numbers, raw test execution outputs, blunt documentation of gaps and mock limitations, and strict `[CODE]`, `[RAN]`, `[ASSUMED]`, `[NOT DONE]` tagging.

---

## 1. Backend Test Catalog (Exams, Proctoring, Submissions)

[CODE] (`backend/tests/`)  
All backend tests execute either against **in-memory SQLite** (`sqlite+aiosqlite:///:memory:`), **temporary file-based SQLite** (`sqlite3` / `tmp_path`), or **in-memory mock objects** (`types.SimpleNamespace`). **ZERO backend tests execute against live PostgreSQL.**

### 1.1 Test Catalog & Assertion Verification

| Test Function | File & Lines | Database Used | Real Assertions (What It Actually Verifies) |
| :--- | :--- | :--- | :--- |
| `test_first_switch_does_not_flag` | `test_exam_attempt.py:30-34` | **None** (`SimpleNamespace`) | Asserts `attempt.tab_switch_count == 1` and `is_flagged is False` using a local in-file Python helper `_apply_flag_logic`. |
| `test_second_switch_does_not_flag` | `test_exam_attempt.py:37-41` | **None** (`SimpleNamespace`) | Asserts `attempt.tab_switch_count == 2` and `is_flagged is False` using local in-file helper. |
| `test_third_switch_triggers_flag` | `test_exam_attempt.py:44-49` | **None** (`SimpleNamespace`) | Asserts `tab_switch_count == 3`, `is_flagged is True`, and `"Flagged: 3"` is in `flag_reason`. |
| `test_already_flagged_attempt_stays_flagged...` | `test_exam_attempt.py:52-59` | **None** (`SimpleNamespace`) | Asserts switch count increments to 4, `is_flagged` remains `True`, and `flag_reason` is not overwritten by subsequent switches. |
| `test_invalidate_action_marks_attempt_disqualified` | `test_exam_attempt.py:84-88` | **None** (`SimpleNamespace`) | Asserts `is_flagged is True` and `"[DISQUALIFIED]"` is prepended to `flag_reason` via in-file helper `_apply_status_action`. |
| `test_clear_action_preserves_switches_and_unflags` | `test_exam_attempt.py:91-97` | **None** (`SimpleNamespace`) | Asserts `is_flagged is False`, `tab_switch_count == 4` (**verifies switches are preserved, not zeroed**), and `reviewed_at` is set. |
| `test_timed_attempt_is_expired_from_server_start_time` | `test_exam_attempt.py:100-112`| **None** (`SimpleNamespace`) | Asserts `is_attempt_expired(...) is True` when `now == started_at + 60m 1s`. |
| `test_timed_attempt_is_not_expired_before_server_deadline` | `test_exam_attempt.py:115-127`| **None** (`SimpleNamespace`) | Asserts `is_attempt_expired(...) is False` when `now == started_at + 59m 59s`. |
| `test_exam_start_query_locks_parent_assignment...` | `test_exam_attempt.py:130-136`| **None** (SQLAlchemy AST) | Asserts `query._for_update_arg is not None` on `select(Assignment).with_for_update()`. (AST check only; does not execute SQL). |
| `test_client_sent_auto_submitted_is_ignored` | `test_exam_concurrency.py:92-120` | **SQLite In-Memory** | Seeds `Submission` with `auto_submitted=True` in payload; asserts DB record has `auto_submitted == False`. |
| `test_expired_attempt_gets_autoclosed_by_background_job` | `test_exam_concurrency.py:123-159` | **SQLite In-Memory** | Creates expired attempt (`now - 35m`); calls `monitor_active_exam_attempts()`; asserts attempt has `submitted_at is not None` and `auto_submitted is True`. |
| `test_late_submission_is_rejected` | `test_exam_concurrency.py:162-200` | **SQLite In-Memory** | Calls `validate_timed_submission_attempt` on an expired attempt; asserts `HTTPException(400)` with `"Time limit expired"` is raised. |
| `test_heartbeat_timeout_creates_flag_and_event` | `test_exam_concurrency.py:203-239` | **SQLite In-Memory** | Stale heartbeat (`now - 45s`); calls `monitor_active_exam_attempts()`; asserts `attempt.is_flagged is True`, `"[OFFLINE]"` in reason, and `ExamViolation` with `type="heartbeat_missed"` created. |
| `test_duplicate_violations_within_dedupe_window_count_once` | `test_exam_concurrency.py:242-282` | **SQLite In-Memory** | Sends 2 violations of same type 500ms apart; asserts `tab_switch_count == 1` and only 1 `ExamViolation` row in DB. |
| `test_stale_or_crashed_attempt_resumed_without_extra_time` | `test_exam_concurrency.py:285-316` | **SQLite In-Memory** | Attempt started 10m ago on a 30m exam; asserts `compute_remaining_seconds(...) == 1200` (exact remaining 20 minutes; zero extra time). |
| `test_concurrent_violations_give_exact_count` | `test_exam_concurrency.py:319-354` | **SQLite In-Memory** | Fires 5 asynchronous coroutines calling `record_violation_atomic`; asserts final `tab_switch_count == 5`. |
| `test_heartbeat_missed_logged_once_per_outage_across_cycles` | `test_exam_concurrency.py:357-380` | **SQLite In-Memory** | Runs monitor loop across 3 consecutive cycles while student remains offline; asserts only 1 violation event created (no alert flood). |
| `test_monitor_daemon_recovers_from_cycle_exception` | `test_exam_concurrency.py:383-395` | **SQLite In-Memory** | Monkeypatches exception into monitor query; asserts exception is caught, logged, and does not crash monitor task. |
| `test_403_access_control_for_exam_management` | `test_exam_professor_and_audit.py:118-181` | **SQLite In-Memory** | Asserts non-owner professor receives `HTTPException(403)` when accessing `/attempts`, `/settings`, `/decision`, and `/export-csv`. |
| `test_clear_flags_preserves_violation_events_and_audits` | `test_exam_professor_and_audit.py:184-240` | **SQLite In-Memory** | Calls `update_exam_attempt_decision` with `action="clear"`; asserts `is_flagged == False`, `tab_switch_count` preserved, and `ExamAuditLog` created. |
| `test_allow_retake_decision_and_state` | `test_exam_professor_and_audit.py:243-324` | **SQLite In-Memory** | Calls `action="allow_retake"`; asserts `decision == "allow_retake"`, attempt 1 submitted, and student can start attempt #2. |
| `test_settings_lock_when_attempt_exists` | `test_exam_professor_and_audit.py:327-385` | **SQLite In-Memory** | Creates attempt; attempts `update_exam_settings`; asserts `HTTPException(409)` with `"cannot be altered after attempts have started"`. |
| `test_heartbeat_rejects_draft_saves_after_deadline_or_submitted` | `test_exam_professor_and_audit.py:388-460` | **SQLite In-Memory** | Heartbeat sent to submitted or expired attempt; asserts answers draft is rejected, `auto_closed: True` returned, and draft discarded. |
| `test_csv_export_format_and_data` | `test_exam_professor_and_audit.py:463-536` | **SQLite In-Memory** | Calls `export_exam_attempts_csv`; asserts CSV header columns, row count, and correct metadata formatting. |
| `test_real_os_threads_atomic_counter_increment` | `test_exam_threads_concurrency.py:15-84` | **SQLite File (WAL Mode)** | 8 real OS threads (`ThreadPoolExecutor`) increment counter concurrently; asserts final count is exactly 80 with zero lost updates. |
| `test_real_os_threads_worker_safety_auto_close` | `test_exam_threads_concurrency.py:87-150` | **SQLite File (WAL Mode)** | Multiple threads concurrently invoke CAS auto-close SQL; asserts exactly 1 thread succeeds and 0 double-submissions. |
| `test_migration_006_upgrade_and_downgrade` | `test_migration_006.py:23-121` | **SQLite File** | Runs Alembic migration 006 upgrade and downgrade; verifies table creation, column defaults, and drop operations. |
| `test_migration_005_upgrade_and_downgrade` | `test_proctoring_migration.py:23-95` | **SQLite File** | Runs Alembic migration 005 upgrade and downgrade; verifies `exam_attempts` and `exam_violations` schema creation. |

---

## 2. Frontend Test Catalog (Exams, Proctoring, Submissions)

[CODE] (`frontend/test/`)

| Test Name | File & Lines | Real Assertions (What It Actually Verifies) |
| :--- | :--- | :--- |
| `ExamScreen initially displays biometric verification gate when unverified` | `exam_screen_widget_test.dart:9-32` | Pumps `ExamScreen(initialBiometricPassed: false)`; asserts `find.text('Identity Verification Required')` and `find.byIcon(Icons.fingerprint)` find widgets. |
| `ExamScreen renders instructions screen and Start Exam button when biometric passes` | `exam_screen_widget_test.dart:34-58` | Pumps with `initialBiometricPassed: true`; asserts `find.text('Before You Start')`, duration text, and `find.text('Start Exam')` visible. |
| `ExamScreen renders instructions for programming assessment type` | `exam_screen_widget_test.dart:60-84` | Asserts programming title and time limit rendered on instructions screen. |
| `ExamScreen renders instructions for MCQ assessment type` | `exam_screen_widget_test.dart:86-110` | Asserts MCQ instructions screen rendered. |
| `ExamScreen renders fullscreen exit overlay with Return to Exam button...` | `exam_screen_widget_test.dart:112-142` | Pumps with `initialFullscreenExitActive: true`; asserts `Exam Locked: Fullscreen Focus Lost`, `Recorded Strikes:`, `Return to Exam` button, and taps it. |
| `ExamScreen renders offline banner when network drops` | `exam_screen_widget_test.dart:144-171` | Pumps with `initialIsOffline: true`; asserts amber banner text `Connection lost. Reconnecting...` and `Icons.wifi_off_rounded`. |
| `AssignmentDetailScreen renders live proctor console and filter chips...` | `exam_screen_widget_test.dart:173-282` | Overrides `authProvider` with professor; asserts `Live Proctoring Console`; taps filter chips `Flagged (1)`, `Auto-Submitted (1)`, `Has Violations`, `Offline (1)`, and `All (3)`; asserts student list filters correctly. |
| `ProctorDetector Deduplication ignores duplicate violations of same type...` | `proctor_detector_test.dart:10-38` | Fires 2 `tab_switch` events 500ms apart; asserts first returns `true`, second returns `false`. Fires after 1600ms; asserts returns `true`. |
| `ProctorDetector File Picker suppresses focus loss events and applies grace...` | `proctor_detector_test.dart:40-75` | Calls `startFilePicker()`; asserts `tab_switch` and `window_blur` return `false`. Calls `endFilePicker()`; asserts grace period timer ignores violations. |
| `ProctorDetector Restoring latch suppresses violations during fullscreen return` | `proctor_detector_test.dart:77-105` | Calls `startRestoring()`; asserts all violations return `false`. Calls `endRestoring()`; asserts violation handling resumes. |
| `emptyExamSubmission produces expected content payloads` | `exam_submission_test.dart:7-34` | Verifies fallback empty submission strings for `file`, `programming`, `mcq`, and `text` for both manual and auto-submitted modes. |
| `examRoutePath formats correctly` | `exam_route_test.dart:6-24` | Asserts `examRoutePath(1, 2)` produces `'/courses/1/assignments/2/exam'` and verifies dictionary keys in `examRouteExtra`. |
| `normalizeProctorAttempts handles null and mixed lists` | `proctor_attempts_test.dart:7-29` | Asserts non-map elements filtered out and valid maps returned. |
| `parseMcqDescription parses structured JSON format` | `mcq_description_test.dart:7-38` | Asserts structured JSON questions and options are correctly extracted into maps. |
| `renders every required triage reason` | `submission_triage_test.dart:10-45` | Asserts triage badges render for plagiarized, unreadable, and AI-flagged submissions. |
| `SubmissionRepository.submitFile sends multipart form data` | `submission_repository_test.dart:12-42` | Mocks Dio; asserts multipart submission payload sent. |

---

## 3. Real Live Test Suite Execution Output

[RAN] Executed on 2026-10-17.

### 3.1 Backend Test Suite (`pytest`)
```
Command: python -m pytest tests -v (Cwd: e:\FYP_YASIN\backend)
Result: 92 passed in 22.22s
Exit Code: 0
```
- **Total Tests Collected:** 92
- **Passed:** 92
- **Failed:** 0
- **Errors:** 0
- **Skipped:** 0
- **Warnings:** 0

### 3.2 Frontend Test Suite (`flutter test`)
```
Command: flutter test (Cwd: e:\FYP_YASIN\frontend)
Result: All tests passed! (+53) in 26.4s
Exit Code: 0
```
- **Total Tests Executed:** 53
- **Passed:** 53
- **Failed:** 0
- **Skipped:** 0

---

## 4. Gap Analysis: What is NOT Tested at All

[CODE] Inspection of `backend/tests/` and `frontend/test/`.

1. **Zero Real Browser End-to-End (E2E) Testing:**
   - No Playwright, Puppeteer, or Selenium tests exist.
   - HTML5 Fullscreen API calls (`docEl.requestFullscreen()`), physical Escape key intercept, F11 detection, and OS-level window blur on Alt-Tab are **never tested in a live browser engine**.
2. **The Critical MCQ Text-Drop Bug is Untested:**
   - There is **no test** verifying what happens when an MCQ assignment has a description with no `A) B) C)` option lines.
   - The fatal bug where `_buildMcqSection` renders a text box, student types text, but `_serializeMcqAnswers` returns `null` and sends `"[No answers selected]"` has zero test coverage.
3. **Zero PostgreSQL Concurrency Testing:**
   - All concurrency tests (`test_exam_concurrency.py`, `test_exam_threads_concurrency.py`) run on SQLite.
   - Real PostgreSQL locking behavior (`SELECT ... FOR UPDATE`), transaction isolation levels, connection pool exhaustion under multi-worker load, and foreign key cascades on PostgreSQL 18 are completely untested.
4. **Offline Queue Truncation Data Loss is Untested:**
   - There is **no test** simulating a partial network failure while draining `OfflineViolationQueue`.
   - The bug where items 3..N are dropped if item 2 fails has no test case.
5. **Browser Refresh / Deep-Link (F5) State Loss is Untested:**
   - No test verifies behavior when `state.extra == null` on `/courses/:id/assignments/:aid/exam`.
6. **Biometric Emergency Override Bypass is Untested:**
   - The 3-strike failure dialog that sets `_biometricPassed = true` without notifying the server is untested in widget tests.
7. **Professor / TA Course Isolation Leaks are Untested:**
   - There is no test asserting that a professor or TA is forbidden from querying `GET /attempts/{id}/state` or `GET /attempts/{id}/result` for attempts in courses they do not own. (In production code, they are not forbidden).
8. **Live CSV File Download on Web is Untested:**
   - The fact that CSV export opens a clipboard dialog rather than downloading a `.csv` file is not verified by UI tests.

---

## 5. Test Modifications & Renaming History

[CODE] (`git log -S "test_clear_action"`, `git diff backend/tests/test_exam_attempt.py`)

### 5.1 Renamed & Inverted Test: `test_clear_action`
In [`backend/tests/test_exam_attempt.py`](file:///e:/FYP_YASIN/backend/tests/test_exam_attempt.py):
- **Old Test Name:** `test_clear_action_resets_switches_and_unflags`
- **Old Assertion:** `assert attempt.tab_switch_count == 0`
- **New Test Name:** `test_clear_action_preserves_switches_and_unflags`
- **New Assertion:** `assert attempt.tab_switch_count == 4  # tab switch count is preserved, not zeroed`
- **Rationale for Change:** The architectural requirement was updated to ensure that clearing review flags does not erase the student's historical telemetry records. The test was renamed and its assertion inverted from expecting a reset to 0 to asserting that the strike count remains untouched.

### 5.2 Added Tests During Audit Remediation
1. `test_timed_attempt_is_expired_from_server_start_time` & `test_timed_attempt_is_not_expired_before_server_deadline`: Added to verify server-side deadline calculation independence from client clocks.
2. `test_exam_start_query_locks_parent_assignment_for_no_row_races`: Added to test AST generation of `with_for_update()`.
3. `test_real_os_threads_atomic_counter_increment` (`test_exam_threads_concurrency.py`): Added to prove SQLite WAL mode atomic increments across concurrent OS threads.
4. `test_migration_006_upgrade_and_downgrade` (`test_migration_006.py`): Added to test Alembic migration 006 rollback and upgrade paths.
5. `test_settings_lock_when_attempt_exists` (`test_exam_professor_and_audit.py`): Added to verify HTTP 409 lock when attempting to edit proctoring parameters post-start.

---

## 6. Audit of `docs/PROCTORING_MANUAL_TEST.md`

[CODE] ([`docs/PROCTORING_MANUAL_TEST.md:1-25`](file:///e:/FYP_YASIN/docs/PROCTORING_MANUAL_TEST.md#L1-L25))

### 6.1 Status Verification Table

| Scenario | Target Browser(s) | Status in Document | Real Execution Status | Human Run? |
| :--- | :--- | :--- | :--- | :--- |
| **Click Start: Goes Fullscreen** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** | **NO** |
| **Press Esc: Overlay shows, strike added, Return works** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** | **NO** |
| **Press F11 to Exit: Same overlay & strike** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** | **NO** |
| **Alt-Tab and Return: Exactly one strike** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** | **NO** |
| **Open File Picker, Pick File: Zero strikes** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** | **NO** |
| **Cancel File Picker: Zero strikes** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** | **NO** |
| **Close Tab Mid-Exam, Reopen: Resume correct time** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** (Backend unit tested; browser UI pending) | **NO** |
| **Go Offline for 60s, Return: Banner shows, flagged** | Chrome, Firefox, Edge | `NOT RUN` | **NOT RUN** (Backend unit tested; browser UI pending) | **NO** |
| **Timer Runs Out with Tab Closed: Server auto-submits** | Headless / Background | `PASS` (Automated backend) | Verified via `test_expired_attempt_gets_autoclosed_by_background_job` | **NO** (Automated Python test) |
| **DevTools Injection of `auto_submitted=true` Ignored** | Chrome / Edge DevTools | `PASS` (Automated backend) | Verified via `test_client_sent_auto_submitted_is_ignored` | **NO** (Automated Python test) |
| **iPhone Safari: Unsupported Fullscreen warning** | iOS Mobile Safari | `NOT RUN` | **NOT RUN** | **NO** |

### 6.2 Truthful Summary of Manual Verification
- **Total Manual Rows:** 11
- **Rows Verified by a Human in a Real Browser:** **0 (ZERO).**
- **Rows Verified via Automated Headless Tests:** **2** (Server-side auto-submit and DevTools injection protection).
- **Rows Pending Interactive Human Testing:** **9** (All interactive browser UI scenarios: physical Escape key, F11, Alt-Tab window blur, OS file dialog, network adapter disconnect, and iOS Safari).

---

PART 7 DONE
