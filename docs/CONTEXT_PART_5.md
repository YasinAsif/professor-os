# ProfessorOS Architectural Context – Part 5: Frontend Student Exam Screen

**Generated:** 2026-10-17  
**Scope:** `frontend/lib/features/courses/presentation/exam_screen.dart` and proctoring utilities (`proctor_detector.dart`, `offline_violation_queue.dart`, `web_window_listener_web.dart`, `web_window_listener_stub.dart`, `exam_state_machine.dart`, `exam_submission.dart`, `mcq_parser.dart`).  
**Rules Applied:** Read-only inspection of source code files, exact line numbers, raw code snippets, blunt documentation of bugs and vulnerabilities, and strict `[CODE]`, `[RAN]`, `[ASSUMED]`, `[NOT DONE]` tagging.

---

## 1. `exam_screen.dart` Architecture & Overview

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:1-1644`)  
[RAN] `Get-Item 'frontend/lib/features/courses/presentation/exam_screen.dart' | Select-Object Length` $\to$ **62,887 bytes, 1,644 lines**.

### 1.1 Structural Hierarchy
`ExamScreen` is a `ConsumerStatefulWidget` mounted outside Flutter's main navigation shell (`ShellRoute`) at route `/courses/:id/assignments/:aid/exam` (`frontend/lib/core/router/app_router.dart:175-194`). It manages the student-facing proctored examination environment across four assignment types (`text`, `programming`, `file`, `mcq`).

The state class `_ExamScreenState` mixes in `WidgetsBindingObserver` to track native application lifecycle changes (`didChangeAppLifecycleState`) and integrates browser event listeners via conditional compilation (`web_window_listener.dart`).

```
ExamScreen (ConsumerStatefulWidget)
 └── _ExamScreenState (State<ExamScreen> with WidgetsBindingObserver)
      ├── Subsystems:
      │    ├── ProctorDetector (debounce, grace timers, restoring latch)
      │    ├── OfflineViolationQueue (in-memory queue for offline events)
      │    ├── ExamStateMachine (state transitions)
      │    └── LocalAuthentication (biometric / device PIN check)
      ├── Screen Modes:
      │    ├── 1. Biometric Gate Screen (!biometricPassed)
      │    ├── 2. Pre-Exam Instructions & Fullscreen Request Screen (!examStarted && !submitted)
      │    ├── 3. Active Proctored Exam Interface (examStarted && !submitted)
      │    │    ├── Header: Proctored badge, Fullscreen button, Countdown timer, Submit button
      │    │    ├── Offline Banner (visible when _isOffline == true)
      │    │    ├── Strikes Banner (visible when _tabSwitchCount > 0)
      │    │    ├── Question / Prompt Card (parsed from widget.description)
      │    │    ├── Dynamic Answer Widget (_buildAnswerSection)
      │    │    └── Fullscreen Exit Lock Overlay (visible when _fullscreenExitActive == true)
      │    └── 4. Submission Confirmation & Result Screen (submitted)
```

---

### 1.2 State Variables Catalog

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:79-116`)

| Variable Name | Type | Initial Value | Purpose / Description |
| :--- | :--- | :--- | :--- |
| `_biometricPassed` | `bool` | `false` | Gatekeeper flag. Must be `true` before student sees exam instructions or questions. |
| `_examStarted` | `bool` | `false` | Indicates student has clicked "Start Exam", entered fullscreen, and received backend `attempt_id`. |
| `_submitted` | `bool` | `false` | Set to `true` when exam attempt and submission are recorded or auto-closed. Shows result view. |
| `_submitting` | `bool` | `false` | In-flight submission lock to prevent concurrent double-submissions. |
| `_error` | `String?` | `null` | Displays banner/inline error message on biometric, start, or submit failure. |
| `_attemptId` | `int?` | `null` | Active `exam_attempts.id` returned by `POST /courses/{id}/assignments/{aid}/exam/start`. |
| `_attemptResumed` | `bool` | `false` | Set to `true` if `_checkInitialState()` discovers an existing in-flight `is_active` attempt. Changes button label to "Resume Proctored Exam". |
| `_isOffline` | `bool` | `false` | Toggled when heartbeats or violation reports fail; displays amber top banner. |
| `_fullscreenExitActive` | `bool` | `false` | When `true`, renders opaque full-screen blocking overlay requiring user to click "Return to Exam". |
| `_detector` | `ProctorDetector` | `ProctorDetector()` | Pure Dart helper tracking debouncing, restoring latch, and file-picker focus grace periods. |
| `_violationQueue` | `OfflineViolationQueue` | `OfflineViolationQueue()` | In-memory retry queue buffering violation events when disconnected. |
| `_stateMachine` | `ExamStateMachine` | `ExamStateMachine()` | Pure Dart finite state machine tracking formal exam lifecycle phases. |
| `_timer` | `Timer?` | `null` | 1-second periodic timer decrementing `_remainingSeconds`. |
| `_heartbeatTimer` | `Timer?` | `null` | 10-second periodic timer dispatching `sendHeartbeat` with serialized draft answers. |
| `_remainingSeconds` | `int` | `0` | Number of seconds left before client-side `_autoSubmit()` is triggered. |
| `_tabSwitchCount` | `int` | `0` | Local strike counter synchronized with backend server response. |
| `_isFlagged` | `bool` | `false` | Set to `true` when strike count reaches threshold or backend returns `is_flagged: true`. |
| `_biometricFailures` | `int` | `0` | Tracks consecutive biometric authentication failures to surface emergency override bypass. |
| `_textCtrl` | `TextEditingController` | `TextEditingController()` | Controls answer input for `text` assignments and fallback MCQ text input. |
| `_codeCtrl` | `TextEditingController` | `TextEditingController()` | Controls code input for `programming` assignments. |
| `_mcqAnswers` | `Map<int, int>` | `{}` | Key: zero-based question index; Value: 1-based option index (1=A, 2=B, etc.). |
| `_selectedFileName` | `String?` | `null` | Stores basename of uploaded file for `file` assignments. |
| `_selectedFileBytes` | `List<int>?` | `null` | Stores binary byte buffer of selected file before upload. |
| `_localAuth` | `LocalAuthentication` | `LocalAuthentication()` | Device biometric / hardware authentication interface. |
| `_repo` | `CourseRepository` | `CourseRepository()` | Network data access layer interfacing with Dio HTTP client. |

---

### 1.3 Method Catalog

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:118-1642`)

| Method Name | Return Type | Caller(s) | Functionality |
| :--- | :--- | :--- | :--- |
| `initState()` | `void` | Flutter runtime | Attaches `WidgetsBindingObserver`, attaches web event listeners, checks release mode flags, runs initial state query and biometric auth. |
| `dispose()` | `void` | Flutter runtime | Detaches web event listeners, removes observer, cancels `_timer` and `_heartbeatTimer`, disposes detector and controllers, calls `_exitFullscreen()`. |
| `_checkInitialState()` | `Future<void>` | `initState()` | Calls `GET /courses/{id}/assignments/{aid}/exam/state`. If active attempt found, resumes timer, draft answers, strike count, and skips biometrics. |
| `_restoreAnswers(String)` | `void` | `_checkInitialState()`, `_startExam()` | Parses server JSON/text draft and populates `_codeCtrl`, `_textCtrl`, `_mcqAnswers`, or `_selectedFileName`. |
| `_getCurrentAnswersDraft()` | `String?` | `_sendHeartbeat()` | Serializes current student input into draft string according to `widget.assignmentType`. |
| `_enterFullscreen()` | `Future<bool>` | "Start Exam" button, Fullscreen icon, "Return to Exam" button | Sets system UI to immersive and requests HTML5 document fullscreen via JS interop. |
| `_exitFullscreen()` | `void` | `dispose()`, `_sendHeartbeat()`, `_reportViolation()`, "Back to Assignment" button, `PopScope` dialog | Restores system UI to edge-to-edge and exits HTML5 document fullscreen. |
| `_runBiometricAuth()` | `Future<void>` | `initState()`, "Verify Identity" button | Queries `local_auth`. Handles hardware absence, authentication success, and surfaces 3-strike bypass dialog. |
| `_startExam()` | `Future<void>` | "Start Exam" / "Resume Proctored Exam" button | Calls `POST .../exam/start`, initializes `_attemptId`, starts 1-second countdown timer, starts 10-second heartbeat, checks multi-monitor setup. |
| `_startTimer()` | `void` | `_startExam()` | Allocates 1s periodic timer. When `_remainingSeconds <= 1`, cancels timer and calls `_autoSubmit()`. |
| `_startHeartbeat()` | `void` | `_startExam()` | Allocates 10s periodic timer invoking `_sendHeartbeat()`. |
| `_sendHeartbeat()` | `Future<void>` | `_startHeartbeat()` | Sends draft answers to `POST /attempts/{id}/heartbeat`. Handles offline recovery, drains violation queue, and processes server `auto_closed`. |
| `_checkScreens()` | `Future<void>` | `_startExam()` | Queries Chrome Screen Management API. If `screens > 1`, reports `multi_monitor` violation. |
| `_autoSubmit()` | `Future<void>` | `_startTimer()`, `_startExam()` (if time already expired) | Submits exam with `autoSubmitted: true`. |
| `didChangeAppLifecycleState(AppLifecycleState)` | `void` | Flutter engine | Listens for native OS app minimize/backgrounding (`paused`, `hidden`, `inactive`) and triggers `window_blur` violation. |
| `_reportViolation(String, {String?})` | `Future<void>` | `_handleViolation()`, `_checkScreens()` | Posts violation to server. If offline or no attempt ID, buffers to `_violationQueue`. Updates strikes and auto-close status. |
| `_drainQueuedViolations()` | `Future<void>` | `_sendHeartbeat()` | Drains offline violation queue sequentially to server upon reconnection. |
| `_handleViolation(String, {String?})` | `void` | Web listener callbacks, `didChangeAppLifecycleState` | Queries `ProctorDetector.shouldRecordViolation()`. If accepted, increments local strike count and invokes `_reportViolation`. |
| `_handleFullscreenExit()` | `void` | Web `fullscreenchange` callback | Records `fullscreen_exit` violation and activates `_fullscreenExitActive = true` overlay. |
| `_handleCopyPasteViolation(String)` | `void` | Web clipboard callbacks (`copy`, `cut`, `paste`, `context_menu`) | Records `copy_paste` violation and shows red SnackBar notification. |
| `_submitExam({bool autoSubmitted})` | `Future<void>` | `_autoSubmit()`, `_confirmSubmit()` | Uploads file or posts text/programming/MCQ submission to `submissions` endpoint, then calls `.../exam/submit` to close attempt. |
| `_confirmSubmit()` | `Future<void>` | "Submit Exam" button | Displays modal confirmation dialog ("Submit Exam?" / "Review Answers") before initiating submission. |
| `_serializeMcqAnswers()` | `String?` | `_submitExam()` | Converts `_mcqAnswers` map into formatted human-readable string ("Option A" or "Question 1: Option A..."). |
| `_optionLetter(int)` | `String` | `_serializeMcqAnswers()` | Maps integer `1..5` to letters `'A'..'E'`. |
| `_buildAnswerSection()` | `Widget` | `build()` | Returns `_buildFileSection()`, `_buildCodeSection()`, `_buildMcqSection()`, or `_buildTextSection()`. |
| `_buildTextSection()` | `Widget` | `_buildAnswerSection()`, `_buildMcqSection()` (fallback) | Renders multiline TextField for plain text answers with copy/paste locked. |
| `_buildCodeSection()` | `Widget` | `_buildAnswerSection()` | Renders dark-themed JetBrains Mono code editor TextField. |
| `_buildMcqSection()` | `Widget` | `_buildAnswerSection()` | Renders radio button list from JSON description or regex-parsed A) B) C) text. |
| `_mcqOptions(...)` | `Widget` | `_buildMcqSection()` | Renders group of `RadioListTile` widgets for a single question. |
| `_buildFileSection()` | `Widget` | `_buildAnswerSection()` | Renders file drag/drop upload target utilizing `FilePicker` with proctor grace latch. |

---

## 2. Exam Start Flow & Fullscreen Invocation

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:783-803`)

### 2.1 The `onPressed` Handler
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:783-803
ElevatedButton(
  onPressed: () async {
    setState(() => _error = null);
    // Check browser fullscreen capability
    final supported = isBrowserFullscreenSupported();
    if (!supported && widget.unsupportedBrowserPolicy == 'block') {
      setState(() => _error =
          'Fullscreen is required. Please open this exam in Chrome, Edge, or Firefox on desktop.');
      return;
    }

    // Synchronously invoke fullscreen BEFORE any async network await
    final fsEntered = await _enterFullscreen();
    if (widget.fullscreenRequired && supported && !fsEntered) {
      setState(() => _error =
          'Fullscreen is required. Please allow fullscreen permission and try again.');
      return;
    }

    await _startExam();
  },
  ...
```

### 2.2 Is `requestFullscreen` Really Before Any Await?
[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:255-258`, `web_window_listener_web.dart:29-48`)

1. Inside `onPressed`, the synchronous statements are `setState(...)` and `isBrowserFullscreenSupported()` (which synchronously queries `document.fullscreenEnabled`).
2. The code then executes `await _enterFullscreen()`.
3. `_enterFullscreen()` executes:
   ```dart
   SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
   return requestBrowserFullscreen();
   ```
4. `requestBrowserFullscreen()` in `web_window_listener_web.dart` immediately grabs `html.document.documentElement` and executes `await docEl.requestFullscreen()`.
5. **Verdict:** Yes. `docEl.requestFullscreen()` is invoked **prior to any asynchronous HTTP network call or timer suspension**. In modern web browsers, calling `requestFullscreen()` after an `await http.post()` would throw `TypeError: Permissions check failed` or `NotAllowedError` because the browser's transient user activation expires across microtask boundaries. The code preserves transient activation by requesting fullscreen first.

---

## 3. Fullscreen Exit Flow, Overlay, and Restoring Latch

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:509-517, 1163-1257`)

### 3.1 Exit Detection & Overlay Presentation
When the student presses Escape, F11, or switches windows:
1. The browser fires the native `fullscreenchange` event.
2. `web_window_listener_web.dart:117-119` detects `html.document.fullscreenElement == null` and invokes `onFullscreenExit()`.
3. `_handleFullscreenExit()` executes:
   ```dart
   // frontend/lib/features/courses/presentation/exam_screen.dart:509-517
   void _handleFullscreenExit() {
     if (!_examStarted || _submitted || _submitting || _detector.isRestoringExam) {
       return;
     }
     _handleViolation('fullscreen_exit', details: 'Exited fullscreen mode');
     if (mounted) {
       setState(() => _fullscreenExitActive = true);
     }
   }
   ```
4. Setting `_fullscreenExitActive = true` renders a modal `Positioned.fill` overlay (`AppColors.bgSurface.withOpacity(0.98)`), completely concealing exam questions and answer fields.

### 3.2 Return to Exam Flow & `_restoringExam` Latch
[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:1226-1248`, `proctor_detector.dart:49-63`)

When the student clicks "Return to Exam" on the overlay:
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:1226-1248
onPressed: () async {
  _detector.startRestoring();
  try {
    final restored = await _enterFullscreen();
    if (restored || !isBrowserFullscreenSupported()) {
      if (mounted) {
        setState(() => _fullscreenExitActive = false);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fullscreen could not be restored. Please allow fullscreen permission.'),
        ));
      }
    }
  } finally {
    _detector.endRestoring();
  }
}
```

- `_detector.startRestoring()` sets `_restoringExam = true` and arms a 3-second safety timer (`maxRestoringTimeout`).
- While `_restoringExam == true`, `ProctorDetector.shouldRecordViolation()` returns `false` (lines 69-71), suppressing secondary violations generated while the browser transitions back into fullscreen.
- In `finally`, `_detector.endRestoring()` cancels the safety timer and resets `_restoringExam = false`.

### 3.3 File Picker Grace Flag
[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:1532-1559`, `proctor_detector.dart:29-47`)

Opening an OS file picker forces the browser window to lose focus (`window_blur` or `visibilitychange`).
- Before opening `FilePicker.platform.pickFiles`, `_detector.startFilePicker()` sets `_filePickerOpen = true` with a 60-second safety timeout.
- In `finally`, `_detector.endFilePicker()` arms a 1.5-second grace timer (`filePickerGrace`), keeping `_filePickerOpen = true` until after the window re-focuses.
- `ProctorDetector.shouldRecordViolation()` explicitly ignores `tab_switch` and `window_blur` while `_filePickerOpen == true` (`proctor_detector.dart:72-74`).

---

## 4. Heartbeat Architecture & Draft Synchronization

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:381-410`)

### 4.1 Periodic Execution
- **Interval:** Exactly **10 seconds** (`Timer.periodic(const Duration(seconds: 10), ...)`).
- **Endpoint:** `POST /attempts/{attempt_id}/heartbeat` (`ApiConstants.attemptHeartbeat`).
- **Payload:**
  ```json
  {
    "answers": "<serialized_draft_string>"
  }
  ```

### 4.2 Error Handling & Offline State Transition
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:388-410
Future<void> _sendHeartbeat() async {
  if (!_examStarted || _submitted || _submitting || _attemptId == null) return;
  try {
    final draft = _getCurrentAnswersDraft();
    final res = await _repo.sendHeartbeat(_attemptId!, answers: draft);
    if (mounted && _isOffline) {
      setState(() => _isOffline = false);
    }
    await _drainQueuedViolations();
    if (res['auto_closed'] == true && mounted) {
      _timer?.cancel();
      _exitFullscreen();
      setState(() {
        _submitted = true;
        _isFlagged = res['is_flagged'] == true;
      });
    }
  } catch (e) {
    if (mounted && !_isOffline) {
      setState(() => _isOffline = true);
    }
  }
}
```

- If Dio throws any network error (timeout, socket error), the catch block toggles `_isOffline = true`, displaying the yellow banner: *"Connection lost. Reconnecting... (Your answers and activity are queued locally)"*.
- When connectivity resumes and the heartbeat responds with HTTP 200, it clears `_isOffline = false` and calls `_drainQueuedViolations()`.
- If the backend monitor has auto-closed the exam (e.g., strike limit reached or deadline passed), `res['auto_closed'] == true` triggers immediate teardown: cancels timer, exits fullscreen, and transitions to submitted screen.

---

## 5. Draft Formats & Answer Restoration

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:210-252`)

### 5.1 Serialization: `_getCurrentAnswersDraft()`
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:240-253
String? _getCurrentAnswersDraft() {
  switch (widget.assignmentType) {
    case 'programming':
      return _codeCtrl.text;
    case 'text':
      return _textCtrl.text;
    case 'mcq':
      return jsonEncode(_mcqAnswers.map((k, v) => MapEntry(k.toString(), v)));
    case 'file':
      return _selectedFileName;
    default:
      return null;
  }
}
```

### 5.2 Deserialization: `_restoreAnswers(String raw)`
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:210-238
void _restoreAnswers(String raw) {
  try {
    switch (widget.assignmentType) {
      case 'programming':
        _codeCtrl.text = raw;
        break;
      case 'text':
        _textCtrl.text = raw;
        break;
      case 'mcq':
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              final key = int.tryParse(k.toString());
              final val = int.tryParse(v.toString());
              if (key != null && val != null) {
                _mcqAnswers[key] = val;
              }
            });
          }
        } catch (_) {}
        break;
      case 'file':
        _selectedFileName = raw.isNotEmpty ? raw : null;
        break;
    }
  } catch (_) {}
}
```

---

## 6. Submit Flow & The MCQ Text Drop Flaw

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:533-628`)

### 6.1 The Full `_submitExam` Method
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:533-628
Future<void> _submitExam({bool autoSubmitted = false}) async {
  if (_submitted || _submitting) return;
  setState(() => _submitting = true);
  _timer?.cancel();
  _heartbeatTimer?.cancel();

  try {
    switch (widget.assignmentType) {
      case 'file':
        if (_selectedFileBytes != null && _selectedFileName != null) {
          await _repo.submitFile(
            widget.courseId,
            widget.assignmentId,
            _selectedFileBytes!,
            _selectedFileName!,
            autoSubmitted: autoSubmitted,
          );
        } else {
          final fallback = emptyExamSubmission(
            'file',
            autoSubmitted: autoSubmitted,
          );
          await _repo.submitAssignment(
            widget.courseId,
            widget.assignmentId,
            fallback,
          );
        }
        break;
      case 'programming':
        final rawCode = _codeCtrl.text;
        final code = rawCode.trim().isEmpty
            ? (autoSubmitted
                ? '// [Time Expired - Auto-Submitted by System]'
                : '// [Submitted with empty response]')
            : rawCode;
        await _repo.submitAssignment(
          widget.courseId,
          widget.assignmentId,
          {
            'submission_type': 'programming',
            'content': code,
          },
        );
        break;
      case 'mcq':
        final content = _serializeMcqAnswers();
        final mcqPayload = content ??
            (autoSubmitted
                ? '[Time Expired - No answers selected]'
                : '[No answers selected]');
        await _repo.submitAssignment(
          widget.courseId,
          widget.assignmentId,
          {
            'submission_type': 'mcq',
            'content': mcqPayload,
          },
        );
        break;
      default: // text
        final rawText = _textCtrl.text;
        final text = rawText.trim().isEmpty
            ? (autoSubmitted
                ? '[Time Expired - Auto-Submitted by System]'
                : '[Submitted with empty response]')
            : rawText;
        await _repo.submitAssignment(
          widget.courseId,
          widget.assignmentId,
          {
            'submission_type': 'text',
            'content': text,
          },
        );
    }

    // Mark exam attempt as submitted
    await _repo.submitExam(widget.courseId, widget.assignmentId);

    if (mounted) {
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ErrorParser.parse(e)),
        backgroundColor: Colors.red,
      ));
    }
  }
}
```

### 6.2 Exact Root Cause: Why Students Received "[No answers selected]" When Typing in the Text Box

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:1451-1463, 1277-1289, 578-592`)

1. **Rendering Fallback:** When an assignment has `type == 'mcq'`, `_buildMcqSection()` attempts to parse questions or regex match `A) B) C)` lines. If the description contains plain text questions without explicit `A) B) C)` options (e.g. "Explain virtual memory paging"):
   ```dart
   // frontend/lib/features/courses/presentation/exam_screen.dart:1451-1463
   if (optionLines.isEmpty) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         if (questionLines.isNotEmpty)
           Text(questionLines.join('\n'), ...),
         const SizedBox(height: 12),
         _buildTextSection(), // <--- RENDERS A TEXT BOX BOUND TO _textCtrl!
       ],
     );
   }
   ```
2. **Student Types Answer:** The student sees a text box and enters their comprehensive answer into `_textCtrl`.
3. **Heartbeat Discards It:** Every 10 seconds, `_sendHeartbeat()` calls `_getCurrentAnswersDraft()`. Because `widget.assignmentType == 'mcq'`, it calls:
   ```dart
   return jsonEncode(_mcqAnswers.map((k, v) => MapEntry(k.toString(), v)));
   ```
   Because no radio buttons exist, `_mcqAnswers` is `{}`. The heartbeat persistently transmits `{}` to the backend, completely ignoring `_textCtrl.text`.
4. **Submit Discards It:** When the student clicks "Submit Exam":
   ```dart
   // frontend/lib/features/courses/presentation/exam_screen.dart:578-583
   case 'mcq':
     final content = _serializeMcqAnswers();
     final mcqPayload = content ??
         (autoSubmitted
             ? '[Time Expired - No answers selected]'
             : '[No answers selected]');
   ```
   `_serializeMcqAnswers()` executes:
   ```dart
   // frontend/lib/features/courses/presentation/exam_screen.dart:1277-1278
   String? _serializeMcqAnswers() {
     if (_mcqAnswers.isEmpty) return null;
     ...
   }
   ```
   Because `_mcqAnswers.isEmpty` is true, it returns `null`!
   `mcqPayload` evaluates to `'[No answers selected]'`.
5. **The Fatal Result:** The client sends `content: "[No answers selected]"` to the backend. The student's typed text is permanently discarded on the frontend before transmission.

---

## 7. Offline Violation Queue & The Truncation Bug

[CODE] (`frontend/lib/features/courses/utils/offline_violation_queue.dart:1-35`, `exam_screen.dart:475-494`)

### 7.1 Queue Implementation
`OfflineViolationQueue` stores maps with keys `type`, `details`, and `timestamp` (ISO-8601).

### 7.2 The Draining Implementation
```dart
// frontend/lib/features/courses/presentation/exam_screen.dart:475-494
Future<void> _drainQueuedViolations() async {
  if (_violationQueue.pendingCount == 0 || _attemptId == null) return;
  final items = _violationQueue.drainQueue();
  for (final item in items) {
    try {
      await _repo.reportAttemptViolation(
        _attemptId!,
        type: item['type'] as String,
        details: item['details'] as String?,
      );
    } catch (_) {
      _violationQueue.enqueue(
        type: item['type'] as String,
        details: item['details'] as String?,
        timestamp: DateTime.now(),
      );
      break;
    }
  }
}
```

### 7.3 Critical Bug: Queue Truncation Data Loss
Look closely at line 477:
```dart
final items = _violationQueue.drainQueue();
```
`drainQueue()` clears the internal `_queue` completely and returns the snapshot `items`.
Suppose the student was offline and accumulated 4 violations:
`items = [V1, V2, V3, V4]`.
- Loop iteration 0: `V1` is sent. It succeeds.
- Loop iteration 1: `V2` is sent. An intermittent network error throws an exception.
- Catch block: Only `V2` is re-enqueued (`_violationQueue.enqueue(...)`).
- The loop executes `break;`.
- **What happens to `V3` and `V4`?** They were removed from `_violationQueue` by `drainQueue()`, were never sent, and are never re-enqueued!
- **Verdict:** Severe data loss bug. Any partial network failure during drain permanently drops all remaining queued violation events from the queue.

---

## 8. Anti-Cheat Security, OS Interop, and Biometrics

### 8.1 Copy / Paste & Context Menu Blocking
[CODE] (`web_window_listener_web.dart:126-149`, `exam_screen.dart:1336, 1391`)
- In `web_window_listener_web.dart`, listeners call `event.preventDefault()` on `contextmenu`, `copy`, `cut`, and `paste` events across the entire DOM `html.document`.
- In `exam_screen.dart`, both the text answer `TextField` (line 1336) and code editor `TextField` (line 1391) set `enableInteractiveSelection: false`, preventing native selection handles, magnifier, and context bubble from opening.
- Attempting to copy/cut/paste triggers `_handleCopyPasteViolation(action)`, which increments strikes and displays a red SnackBar: *"Action blocked: [action] is disabled for academic integrity."*

### 8.2 Multi-Monitor Detection
[CODE] (`frontend/lib/features/courses/utils/web_window_listener_web.dart:80-95`, `exam_screen.dart:412-420`)
```dart
// frontend/lib/features/courses/utils/web_window_listener_web.dart:80-95
Future<int> checkConnectedScreensCount() async {
  try {
    if (js_util.hasProperty(html.window, 'getScreenDetails')) {
      final promise = js_util.callMethod(html.window, 'getScreenDetails', []);
      final screenDetails = await js_util.promiseToFuture(promise);
      if (screenDetails != null && js_util.hasProperty(screenDetails, 'screens')) {
        final screens = js_util.getProperty(screenDetails, 'screens');
        final length = js_util.getProperty(screens, 'length') as int? ?? 1;
        return length;
      }
    }
  } catch (e) {
    developer.log('ScreenDetails API unavailable or permission denied: $e', name: 'ProctoringWeb');
  }
  return 1;
}
```
- Invokes experimental Window Management API (`window.getScreenDetails()`, Chrome 100+).
- If `screens.length > 1`, `_checkScreens()` reports `multi_monitor` violation to the backend.
- On Firefox, Safari, Edge without permission, or mobile, the property does not exist or throws; the exception is caught and it returns `1` (safe fallback).

### 8.3 Unsupported Browser Policy
[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:787-792`)
- Controlled by `widget.unsupportedBrowserPolicy` (`'warn_allow'` vs `'block'`).
- If `isBrowserFullscreenSupported()` returns `false` (e.g. mobile Safari / iOS browsers where `document.fullscreenEnabled` is false):
  - If `'block'`: Clicking "Start Exam" aborts immediately and sets error: *"Fullscreen is required. Please open this exam in Chrome, Edge, or Firefox on desktop."*
  - If `'warn_allow'`: Displays an orange warning box on the pre-exam screen: *"Notice: Fullscreen is unsupported on this mobile/browser platform. Tab and focus tracking remain active."* and allows the exam to proceed.

### 8.4 Biometric Gate & 3-Strike Fallback
[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:266-322`)
- Uses `LocalAuthentication` (`local_auth`).
- **Web Execution:** On Flutter Web, `canCheckBiometrics` or `isDeviceSupported()` throws or returns `false`. The catch block (lines 318-321) catches the exception and immediately sets `_biometricPassed = true`.
- **Mobile / Desktop Execution:** If hardware biometrics are available, prompts identity verification.
- **Failures & Emergency Bypass:** If biometric authentication fails 3 times (`_biometricFailures >= 3`), an `AlertDialog` appears: *"Biometric verification failed several times. You can continue, but your attempt will be marked as unverified and may be reviewed by your instructor."* Clicking "Continue Anyway" sets `_biometricPassed = true`, allowing the student into the exam.

---

## 9. Test-Only Parameters & Release Mode Guards

[CODE] (`frontend/lib/features/courses/presentation/exam_screen.dart:37-71, 140-151`)

### 9.1 Parameter Inventory
The `ExamScreen` widget exposes five optional constructor arguments for integration/widget tests:
1. `initialBiometricPassed` (`bool?`)
2. `skipInitialStateCheck` (`bool`)
3. `initialFullscreenExitActive` (`bool?`)
4. `initialIsOffline` (`bool?`)
5. `initialExamStarted` (`bool?`)

### 9.2 Two-Layer Production Protection
The codebase employs two independent security mechanisms to guarantee these testing hooks cannot be exploited in production builds:

1. **Constructor Assertion (Debug/Profile Mode Guard):**
   ```dart
   // frontend/lib/features/courses/presentation/exam_screen.dart:58-66
   ) : assert(
         !kReleaseMode ||
             (initialBiometricPassed == null &&
                 !skipInitialStateCheck &&
                 initialFullscreenExitActive == null &&
                 initialIsOffline == null &&
                 initialExamStarted == null),
         'Test bypass flags are strictly forbidden in production release builds.',
       );
   ```
2. **Runtime Ternary Clamp (Release Mode Hardening):**
   Even if Flutter release compilation strips assertions (`dart --no-asserts`), `initState` ignores the parameters if `kReleaseMode` is true:
   ```dart
   // frontend/lib/features/courses/presentation/exam_screen.dart:141-145
   final effectiveBiometricPassed = kReleaseMode ? false : (widget.initialBiometricPassed ?? false);
   final effectiveSkipStateCheck = kReleaseMode ? false : widget.skipInitialStateCheck;
   final effectiveExamStarted = kReleaseMode ? false : (widget.initialExamStarted ?? false);
   final effectiveFullscreenExit = kReleaseMode ? false : (widget.initialFullscreenExitActive ?? false);
   final effectiveOffline = kReleaseMode ? false : (widget.initialIsOffline ?? false);
   ```

---

## 10. Web Platform Bridge & JS Interop

[CODE] (`frontend/lib/features/courses/utils/web_window_listener_web.dart:1-201`, `web_window_listener_stub.dart:1-31`)

### 10.1 Platform Abstraction Architecture
`web_window_listener.dart` uses Dart conditional exports:
```dart
export 'web_window_listener_stub.dart'
    if (dart.library.html) 'web_window_listener_web.dart';
```
On native platforms (Android, iOS, Windows, macOS, Linux), the stub provides safe no-op functions returning `true` or empty callbacks. On Flutter Web, `web_window_listener_web.dart` compiles against `dart:html` and `dart:js_util`.

### 10.2 JS Interop Bindings & Error Logging

| Feature | Browser API | DOM Event | Error Handling / Swallowing |
| :--- | :--- | :--- | :--- |
| Fullscreen Support Check | `document.fullscreenEnabled` | None | Caught; logs via `developer.log` to `'ProctoringWeb'`; returns `false`. |
| Request Fullscreen | `docEl.requestFullscreen()` | None | Caught; logs to `'ProctoringWeb'`; returns `false`. |
| Exit Fullscreen | `document.exitFullscreen()` | None | Caught; logs error to `'ProctoringWeb'`. |
| Escape Key Lock | `navigator.keyboard.lock(['Escape'])` | None | Feature-checked with `js_util.hasProperty`; logs success or logs warning on rejection. |
| Multi-Display Check | `window.getScreenDetails()` | None | Feature-checked with `js_util.hasProperty`; catches rejection; logs warning and returns `1`. |
| Tab Switch Detection | `document.hidden` | `visibilitychange` | Fires `onViolation('tab_switch')` if `document.hidden == true`. |
| Window Focus Loss | `window.onBlur` | `blur` | Fires `onViolation('window_blur')` unconditionally. |
| Fullscreen Exit Detection | `document.fullscreenElement` | `fullscreenchange` | Fires `onFullscreenExit()` if `fullscreenElement == null`. |
| Clipboard Suppression | `event.preventDefault()` | `contextmenu`, `copy`, `cut`, `paste` | Calls `preventDefault()`; fires `onCopyPasteViolation(action)`. |

---

## 11. Discrepancies, Bugs, & Security Vulnerabilities Summary

1. **MCQ Text Answer Dropped (Critical Data Loss Bug):**
   - **File & Lines:** `frontend/lib/features/courses/presentation/exam_screen.dart:1451-1463, 1277-1289, 578-592`
   - **Impact:** If an MCQ assignment has no `A) B) C)` options, it renders a text box. But `_getCurrentAnswersDraft` and `_submitExam` ignore `_textCtrl` and evaluate `_mcqAnswers`. The student's entire typed answer is dropped, sending `content: "[No answers selected]"` to the backend.
2. **Offline Queue Truncation on Partial Drain (Data Loss Bug):**
   - **File & Lines:** `frontend/lib/features/courses/presentation/exam_screen.dart:475-494`
   - **Impact:** `_violationQueue.drainQueue()` clears all queued violations. If the network drops while sending item 2 of 5, only item 2 is re-enqueued before breaking. Items 3, 4, and 5 are permanently lost.
3. **Alt-Tab Double-Strike (Client-Side Race Vulnerability):**
   - **File & Lines:** `frontend/lib/features/courses/utils/web_window_listener_web.dart:106-114`, `proctor_detector.dart:76-82`
   - **Impact:** An Alt-Tab triggers both `visibilitychange` (`tab_switch`) and `blur` (`window_blur`) ~30ms apart. `ProctorDetector` only debounces identical violation types (`_lastViolationByType[type]`). Because `window_blur` and `tab_switch` are distinct strings, both pass the client debounce, resulting in two recorded strikes for a single Alt-Tab action.
4. **Biometric Bypass Dialogue (Security Weakness):**
   - **File & Lines:** `frontend/lib/features/courses/presentation/exam_screen.dart:282-313`
   - **Impact:** On mobile/desktop devices where biometrics fail 3 times, an emergency popup offers "Continue Anyway", setting `_biometricPassed = true`. While the dialog text states *"your attempt will be marked as unverified"*, the frontend **never sets any unverified flag on the attempt or server payload**. The bypass is completely silent to the backend.
