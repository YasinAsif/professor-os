# ProfessorOS Proctoring Manual Test Checklist

This checklist provides step-by-step verification procedures for manual browser QA across Google Chrome, Mozilla Firefox, Microsoft Edge, and Mobile Safari (iOS).

> **Verification Environment Note**: Automated unit, integration, and database concurrency tests were executed and passed in the headless CI/CLI environment (`pytest` suite: 82/82 passed; `flutter test` suite: 46/46 passed). Interactive GUI items requiring human OS-level input (e.g. physical Escape key, hardware second display, OS file dialog window focus) are marked **NOT RUN** below per the ground rules until verified in an interactive desktop browser session.

---

## 1. Test Matrix Summary

| Scenario | Target Browser(s) | Status | Automated Test Reference | Manual Verification Steps |
|---|---|---|---|---|
| **Click Start: Goes Fullscreen** | Chrome, Firefox, Edge | `NOT RUN` | N/A (DOM Fullscreen API) | Section 2.1 |
| **Press Esc: Overlay shows, strike added, Return to Exam works** | Chrome, Firefox, Edge | `NOT RUN` | `exam_screen_widget_test.dart` (fullscreen exit overlay) | Section 2.2 |
| **Press F11 to Exit: Same overlay & strike** | Chrome, Firefox, Edge | `NOT RUN` | `test_exam_concurrency.py::test_concurrent_violations_give_exact_count` | Section 2.3 |
| **Alt-Tab and Return: Exactly 1 strike (focus_loss group)** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase1_correctness.py::test_focus_loss_grouping_and_client_dedupe` | Section 2.4 |
| **Open File Picker, Pick File: Zero strikes** | Chrome, Firefox, Edge | `NOT RUN` | `frontend/test/proctor_detector_test.dart` (file picker flag) | Section 2.5 |
| **Cancel File Picker: Zero strikes** | Chrome, Firefox, Edge | `NOT RUN` | `frontend/test/proctor_detector_test.dart` (file picker grace) | Section 2.6 |
| **F5 Mid-Exam Refresh: Resumes active attempt directly** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase1_correctness.py::test_deep_link_or_f5_loads_active_attempt_state` | Section 2.7 |
| **Blocked Heartbeat: Offline flag recorded, cleared on return** | Chrome, Firefox, Edge | `NOT RUN` | `test_exam_concurrency.py::test_heartbeat_timeout_creates_flag_and_event` | Section 2.8 |
| **Double-Click Start Exam: Single active attempt created** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase4_deploy.py::test_postgres_partial_unique_index_and_concurrency` | Section 2.9 |
| **Student Reads Questions Before Start Exam: Blocked (403/Masked)** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase1_correctness.py::test_prestart_question_exposure_is_masked_for_students` | Section 2.10 |
| **TA Course Access & Grading Delegation: Course-level permissions** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase2_permissions.py::test_ta_course_level_permissions_and_delegation` | Section 2.11 |
| **Retake End-to-End: Allow Retake creates distinct submission row** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase1_correctness.py::test_retake_creates_distinct_submission_and_preserves_graded` | Section 2.12 |
| **MCQ with No Options: Fallback text entry with warning** | Chrome, Firefox, Edge | `NOT RUN` | `test_phase1_correctness.py::test_mcq_text_draft_saved_and_serialized` | Section 2.13 |
| **Timer Runs Out with Tab Closed: Server auto-submits** | Headless / Background | `NOT RUN` (Automated backend only) | `test_exam_concurrency.py::test_expired_attempt_gets_autoclosed_by_background_job` | Section 2.14 |
| **DevTools Injection of `auto_submitted=true` Ignored** | Chrome / Edge DevTools | `NOT RUN` (Automated backend only) | `test_exam_concurrency.py::test_client_sent_auto_submitted_is_ignored` | Section 2.15 |
| **iPhone Safari: Unsupported Fullscreen warning displayed** | iOS Mobile Safari | `NOT RUN` | Feature detection in `web_window_listener_web.dart` | Section 2.16 |

---

## 2. Step-by-Step Manual Execution Guide

### 2.1 Click "Start Exam" – Fullscreen Focus Mode
1. Log in as a student and navigate to a proctored timed assignment (`/courses/:id/assignments/:aid`).
2. Click **Take Proctored Exam**.
3. On the **Before You Start** screen, click **Start Exam**.
4. **Expected Result**:
   - The browser immediately transitions into native HTML5 fullscreen (window chrome, address bar, and OS taskbar are hidden).
   - If fullscreen permission is blocked by browser settings, an explicit red banner appears: *"Fullscreen is required. Please allow fullscreen permission and try again."*
   - Exam questions become visible and the countdown timer begins.

### 2.2 Press Esc – Fullscreen Exit & Blocking Overlay
1. While in an active exam, press the physical `Escape` key (hold if browser requires hold-to-exit).
2. **Expected Result**:
   - The browser exits fullscreen.
   - A full-screen blocking overlay immediately obscures the questions with:
     - Red shield icon and *"Exam Locked: Fullscreen Focus Lost"*.
     - *"Recorded Strikes: 1"*.
     - The only available control is the **Return to Exam** button.
   - Check instructor console: A `fullscreen_exit` event appears on the student's audit timeline.
3. Click **Return to Exam**.
4. **Expected Result**:
   - The browser synchronously re-enters native fullscreen.
   - The overlay dismisses cleanly and question interaction resumes without triggering a false double strike.

### 2.3 Press F11 to Exit Fullscreen
1. While in native fullscreen during an active exam, press `F11`.
2. **Expected Result**:
   - Same behavior as Section 2.2: blocking overlay engages, strike increments by 1, questions are hidden, and click on **Return to Exam** restores fullscreen.

### 2.4 Alt-Tab Away & Return (Deduplication)
1. In an active exam, press `Alt + Tab` to switch to another desktop application (e.g., Notepad or File Explorer).
2. Wait 2 seconds, then `Alt + Tab` back to the browser.
3. **Expected Result**:
   - The strike counter increments by **exactly 1 strike** (both `window_blur` and `visibilitychange` fire simultaneously in the browser, but are deduplicated by the 1500ms client and server sliding window).

### 2.5 Open File Picker & Select File (Zero False Strikes)
1. Start an assignment of type `file`.
2. Click the file upload dropzone.
3. The native OS file picker window opens (which blurs the browser window).
4. Select a valid test file (`.pdf` or `.txt`) and click **Open**.
5. **Expected Result**:
   - **Strike count remains 0**.
   - No proctor warnings appear. The 1500ms post-dialog grace window prevents the focus-return event from registering as a tab switch.

### 2.6 Open File Picker & Cancel (Zero False Strikes)
1. On a file assignment, click the file upload dropzone.
2. When the OS file dialog appears, click **Cancel** or press `Escape`.
3. **Expected Result**:
   - **Strike count remains 0**.
   - No proctor warnings or strikes are triggered.

### 2.7 Close Tab Mid-Exam & Reopen (Crash / Disconnect Recovery)
1. Start a 10-minute exam. Note the time remaining (e.g., 09:30).
2. Close the browser tab or close the entire browser window completely.
3. Wait 60 seconds.
4. Reopen the browser, log in as the same student, and navigate back to the assignment.
5. Click **Take Proctored Exam**.
6. **Expected Result**:
   - The button shows **Resume Proctored Exam**.
   - When clicked, the exam resumes with the authoritative server remaining time (e.g., 08:30 remaining—**zero extra time granted**).
   - Any draft answers auto-saved during heartbeat are restored into the text/code/mcq inputs.

### 2.8 Network Disconnect for 60 Seconds
1. In an active exam, disconnect your network adapter or toggle DevTools Network throttling to **Offline**.
2. Keep working on the exam for 60 seconds.
3. **Expected Result**:
   - An amber top banner appears: *"Connection lost. Reconnecting... (Your answers and activity are queued locally)"*.
   - During disconnection, switch tabs once. The strike increments locally and is stored in `OfflineViolationQueue`.
   - On the instructor Live Console: The student's card shows *"Offline (>30s)"* and an orange badge. The background exam monitor logs a `heartbeat_missed` event.
4. Re-enable network connectivity.
5. **Expected Result**:
   - The top offline banner disappears on the next 10-second heartbeat cycle.
   - All queued violations drain to `POST /attempts/{id}/violations`.
   - Instructor view immediately reflects the updated strike count and green *"Live"* status.

### 2.9 Background Auto-Submission on Deadline Expiry
1. Start a timed exam.
2. Close the browser tab before submitting.
3. Wait until the exam duration plus grace period (10 seconds) expires.
4. Open the database or log in as an instructor.
5. **Expected Result**:
   - The attempt is marked with `submitted_at` != null, `auto_submitted=True`, and a corresponding submission record is saved.
   - If the student later reopens the exam page, they see the **Exam Submitted** screen with an auto-submitted notice.

### 2.10 DevTools Injection Attack Prevention
1. Open Chrome DevTools (`F12`) on the Network tab.
2. Attempt to send a manual submission payload containing `{"auto_submitted": true}`:
   ```bash
   curl -X POST "http://localhost:8000/api/v1/courses/1/assignments/1/submit" \
     -H "Authorization: Bearer <STUDENT_TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"submission_type": "text", "content": "Tampered", "auto_submitted": true}'
   ```
3. Inspect the created submission record in the database (`submissions.auto_submitted`).
4. **Expected Result**:
   - `submissions.auto_submitted` is **`FALSE`**. The server schema ignores client-supplied `auto_submitted` values and only sets it to `True` when closed by the server monitor.

### 2.11 Mobile Safari (iOS) / Unsupported Browser
1. Open the exam on an iPhone or iPad in Safari (where HTML5 Fullscreen API on standard elements is unsupported).
2. **Expected Result**:
   - If `unsupportedBrowserPolicy` is `warn_allow` (default): An orange informational banner displays: *"Notice: Fullscreen is unsupported on this mobile/browser platform. Tab and focus tracking remain active."* The student is permitted to take the assessment while visibility and focus tracking continue.
   - If `unsupportedBrowserPolicy` is `block`: The student is blocked with: *"Fullscreen Focus Mode is required for this exam, but is not supported on this browser/device. Please use Chrome, Edge, or Firefox on desktop."*
