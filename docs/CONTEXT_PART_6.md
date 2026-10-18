# ProfessorOS Architectural Context – Part 6: Frontend Professor Side & Other Screens

**Generated:** 2026-10-17  
**Scope:** `frontend/lib/features/courses/presentation/assignment_detail_screen.dart`, live console, audit timelines, instructor decisions, proctor settings modal, CSV export, routing guards (`app_router.dart`), and API mapping (`course_repository.dart` vs backend).  
**Rules Applied:** Read-only inspection of source code files, exact line numbers, raw code snippets, blunt documentation of bugs and discrepancies, and strict `[CODE]`, `[RAN]`, `[ASSUMED]`, `[NOT DONE]` tagging.

---

## 1. `assignment_detail_screen.dart` Architecture & Overview

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1-4607`)  
[RAN] `Get-Item 'frontend/lib/features/courses/presentation/assignment_detail_screen.dart' | Select-Object Length, LastWriteTime` $\to$ **207,090 bytes, 4,606 lines**.

### 1.1 Structural Hierarchy
`AssignmentDetailScreen` is a massive monolithic screen handling instructor assignment management, student submission workflows, TA allocations, AI rubric evaluations, manual grading overrides, and the real-time **Live Proctoring Console**.

```
AssignmentDetailScreen (ConsumerStatefulWidget)
 └── _AssignmentDetailScreenState (ConsumerState<AssignmentDetailScreen>)
      ├── Top App Bar: Title, Rubric actions, TA allocations, Close Submissions toggle
      ├── Main Workspace:
      │    ├── Assignment Header & Metadata (Description, Max Marks, Deadline, OBE CLO maps)
      │    ├── Instructor Proctoring Toolbar:
      │    │    ├── "Proctor Settings" button (opens _showExamSettingsDialog)
      │    │    ├── "Export CSV Audit" button (opens _exportExamCsv)
      │    │    └── "Refresh Feed" button (triggers _loadSubmissions)
      │    ├── Live Proctoring Console (lines 2225-2560):
      │    │    ├── Summary Metrics Strip: Total, Active (Live), Offline, Finished, Auto-Submitted, Flagged
      │    │    ├── Filter Chips: all, flagged, auto_submitted, has_violations, active, offline
      │    │    └── Student Attempt Cards Wrap: Live status badge, strikes counter, click opens Audit Dialog
      │    ├── Submissions List / Student Submission Status
      │    └── Grading / Student Feedback Card
```

### 1.2 Exam-Related State Variables Catalog
[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:40-150`)

| Variable Name | Type | Initial Value | Purpose / Description |
| :--- | :--- | :--- | :--- |
| `_assignment` | `Map<String, dynamic>?` | `null` | Assignment record containing proctoring configuration (`time_limit_minutes`, `strike_limit_flag`, `fullscreen_required`, etc.). |
| `_examAttempts` | `List<Map<String, dynamic>>` | `[]` | List of normalized proctoring sessions returned from `GET .../exam/attempts`. |
| `_proctorRefreshTimer` | `Timer?` | `null` | 10-second periodic polling timer refreshing live proctoring telemetry for instructors. |
| `_proctorError` | `String?` | `null` | Captures error strings if `listExamAttempts` network call fails during polling. |
| `_examAttemptFilter` | `String` | `'all'` | Active filter string for the Live Console (`all`, `flagged`, `auto_submitted`, `has_violations`, `active`, `offline`). |
| `_mySubmission` | `Map<String, dynamic>?` | `null` | Student's own submission record fetched on load. Dictates whether student sees "Start Exam" vs "My Submission". |

### 1.3 Exam-Related Methods Catalog
[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:705-1540, 2219-2560`)

| Method Name | Return Type | Caller(s) | Functionality |
| :--- | :--- | :--- | :--- |
| `initState()` | `void` | Flutter runtime | Checks release mode; loads assignment and initial submissions. |
| `_load()` | `Future<void>` | `initState()`, refresh | Fetches assignment details, calls `_loadSubmissions()`, and starts 10s auto-refresh timer if timed exam. |
| `_loadSubmissions()` | `Future<void>` | `_load()`, timer, manual refresh | If instructor/TA, fetches submissions and attempts (`listExamAttempts`), normalizing with `normalizeProctorAttempts`. |
| `_startProctorRefresh()` | `void` | `_load()` | Allocates 10-second periodic timer invoking `_loadSubmissions()`. |
| `_isTimedExam` | `bool` (getter) | `_load()`, `build()` | Returns `true` if `time_limit_minutes > 0` or type is `'quiz'`, `'exam'`, or `'mcq'`. |
| `_buildLiveProctorConsole()` | `Widget` | `build()` | Renders summary metric strip, filter chips, and student attempt cards. |
| `_exportExamCsv()` | `Future<void>` | "Export CSV Audit" button | Calls `GET .../exam/export-csv`, rendering a modal dialog containing selectable CSV text with a "Copy to Clipboard" button. |
| `_showExamSettingsDialog()` | `Future<void>` | "Proctor Settings" button | Renders proctoring settings dialog; disables editing if `_examAttempts.isNotEmpty` ("Settings Locked"). |
| `_manageExamAttemptDialog(...)` | `Future<void>` | Student attempt card tap | Renders student proctor audit modal: strike details, live/offline status, event timeline, and decision actions. |
| `_recordAttemptDecisionDialog(...)`| `Future<void>` | Decision buttons in audit modal | Displays mandatory instructor rationale text prompt before submitting decision (`accept`, `invalidate`, `allow_retake`, `clear`). |

---

## 2. Live Proctoring Console Architecture

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:2225-2560`, `backend/app/api/v1/exams.py:726-836`)

### 2.1 Polling & Live Feed Lifecycle
- **Polling Interval:** Exactly **10 seconds** (`Timer.periodic(const Duration(seconds: 10), ...)`, lines 796-801).
- **Trigger Condition:** Auto-refresh runs only if the user has role `professor`, `admin`, or `ta`, and `_isTimedExam` is true (lines 729-734).
- **Manual Refresh:** The refresh icon button (line 2301) triggers `_loadSubmissions()` immediately.

### 2.2 Where "Live / Offline" Originates: Server Clock vs Client Clock
[CODE] (`backend/app/api/v1/exams.py:753-773`, `frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1209-1233`)
"Live" and "Offline" status is **strictly calculated on the server using the server's UTC clock**:
```python
# backend/app/api/v1/exams.py:753-773
now = datetime.now(timezone.utc)
...
elapsed_hb = int((now - last_hb).total_seconds()) if last_hb else None
is_live = (not is_submitted) and (elapsed_hb is not None) and (elapsed_hb <= HEARTBEAT_TIMEOUT_SECONDS)

if auto_sub:
    st = "auto_submitted"
elif is_submitted:
    st = "submitted"
elif is_live:
    st = "active"
else:
    st = "offline"
```
The frontend does **no** local time-differential math. It renders the exact `is_live`, `status`, and `seconds_since_heartbeat` integers supplied in the backend JSON payload.

### 2.3 Attempt Sorting
[CODE] (`backend/app/api/v1/exams.py:829-835`)
Attempts returned by `GET .../exam/attempts` are sorted on the backend before transmission:
```python
# backend/app/api/v1/exams.py:829-835
items.sort(
    key=lambda it: (
        0 if (it["is_flagged"] or it["status"] == "offline") else 1,
        it["started_at"] or "",
    ),
    reverse=False,
)
```
**Prioritization Rule:** Flagged students (`is_flagged == True`) and disconnected students (`status == 'offline'`) float to the very top of the feed (`key = 0`), followed by normal active/submitted students (`key = 1`), sorted ascending by session start time.

### 2.4 Summary Counts & Filter Chips
[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:2226-2250, 2311-2360`)

The top strip computes 6 real-time metrics:
1. **Total Sessions:** `_examAttempts.length`
2. **Active (Live):** `_examAttempts.where((a) => a['status'] == 'active').length`
3. **Offline:** `_examAttempts.where((a) => a['status'] == 'offline').length`
4. **Finished:** `_examAttempts.where((a) => a['status'] == 'submitted').length`
5. **Auto-Submitted:** `_examAttempts.where((a) => a['auto_submitted'] == true || a['status'] == 'auto_submitted').length`
6. **Flagged:** `_examAttempts.where((a) => a['is_flagged'] == true).length`

Interactive filter chips allow filtering the student card list below:
`all` | `flagged` | `auto_submitted` | `has_violations` | `active` | `offline`.

### 2.5 Fields Shown Per Student Card
[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:2397-2545`)
Each card displays:
- Student full name and avatar initial.
- Attempt number badge (`Attempt #1` or `Attempt #2`).
- Status Badge:
  - `LIVE (Xs ago)`: green badge with animated dot when heartbeat $\le 30$s.
  - `OFFLINE`: orange badge when heartbeat $> 30$s.
  - `AUTO-SUBMITTED`: deep orange badge.
  - `SUBMITTED`: blue badge with total time spent in minutes.
- Strike Count Indicator: `$strikes Strikes` (red text if flagged, gray if normal).
- Time Spent: `${att['time_spent_minutes']} min`.
- Decision Tag: If instructor previously recorded a decision, displays chip: `ACCEPTED`, `INVALIDATED`, `ALLOWED RETAKE`, or `FLAGS CLEARED`.

---

## 3. Proctor Audit Dialog & Event Timeline

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1199-1540`)

Tapping any student card opens `_manageExamAttemptDialog(sub, attempt)`.

### 3.1 Content Displayed
1. Header: `Proctor Audit: [Student Name] (Attempt #[N])`
2. Student Email and Session Status (`ACTIVE`, `OFFLINE`, `SUBMITTED`, `AUTO-SUBMITTED`).
3. Flag Status Banner: `FLAGGED: [flag_reason]` (red box) or `Clean / In Good Standing` (green box).
4. Review History: Displays previously recorded decision, reason text, reviewer name, and reviewed timestamp.
5. Violation Event Timeline: Scrollable list of every violation event attached to the attempt.

### 3.2 Timeline Rendering & Plain Text Implementation
[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1427-1468`)
```dart
// frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1456-1463
if (details.isNotEmpty)
  Text(
    details,
    style: GoogleFonts.inter(
      fontSize: 11,
      color: AppColors.textSecondary,
    ),
  ),
```
- **How details text is rendered:** As a standard Flutter `Text` widget with `GoogleFonts.inter` font styling.
- **Security Check:** It does **NOT** use `flutter_html`, `flutter_markdown`, or raw webview components. Plain text rendering completely neutralizes HTML injection and XSS risks in telemetry strings.

---

## 4. Instructor Decision Actions (`accept`, `invalidate`, `allow_retake`, `clear`)

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1112-1197, 1493-1538`)

### 4.1 UI Flow & Mandatory Reason Validation
Clicking any action button in the audit dialog opens `_recordAttemptDecisionDialog`:
```dart
// frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1132-1140
TextFormField(
  controller: reasonCtrl,
  maxLines: 3,
  validator: (val) {
    if (val == null || val.trim().length < 3) {
      return 'A mandatory reason of at least 3 characters is required.';
    }
    return null;
  },
  decoration: const InputDecoration(
    hintText: 'e.g. Technical glitch verified / Disqualification confirmed / Retake authorized due to outage...',
    border: OutlineInputBorder(),
  ),
),
```
- **Mandatory Reason Requirement:** Enforced by Flutter form validation. If input is empty or $< 3$ characters, the form validation fails and submission is blocked.

### 4.2 Actions & API Mapping

| Action | Button Label | Color | Endpoint Called | Body Payload | Backend Effect |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `accept` | "Accept Attempt" | Green (`AppColors.successGreen`) | `POST .../attempts/{id}/decision` | `{"action": "accept", "reason": "..."}` | Verifies attempt; sets `decision='accept'`. |
| `invalidate` | "Invalidate Attempt" | Red (`AppColors.dangerRose`) | `POST .../attempts/{id}/decision` | `{"action": "invalidate", "reason": "..."}` | Sets `decision='invalidate'`, flags attempt. |
| `allow_retake`| "Allow Retake (Attempt 2)" | Deep Orange (`Colors.orange.shade800`) | `POST .../attempts/{id}/decision` | `{"action": "allow_retake", "reason": "..."}` | Sets `decision='allow_retake'`, authorizes Attempt #2. |
| `clear` | "Clear Flags" | Outlined / Indigo | `POST .../attempts/{id}/decision` | `{"action": "clear", "reason": "..."}` | Resets `tab_switch_count = 0`, `is_flagged = False`. |

### 4.3 Error Handling
If `recordExamDecision` fails (e.g. 403 Forbidden, 404 Attempt Not Found, or 500 DB error):
```dart
// frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1183-1190
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Failed to record decision: $e'),
      backgroundColor: AppColors.dangerRose,
    ));
  }
}
```
Displays a red SnackBar with the error string; does not crash the console feed.

---

## 5. Exam Settings Panel & The 409 Lock

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:928-1110`)

### 5.1 Settings Fields

| Field Name | Input Widget | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `time_limit_minutes` | `TextField` (number) | `60` | Exam duration in minutes. |
| `strike_limit_flag` | `TextField` (number) | `3` | Strike count triggering review flag. |
| `strike_limit_autosubmit` | `TextField` (number) | `5` | Strike count triggering auto-submission. |
| `fullscreen_required` | `SwitchListTile` | `true` | Enforces HTML5 fullscreen requirement. |
| `block_copy_paste` | `SwitchListTile` | `true` | Suppresses copy/cut/paste and context menus. |
| `unsupported_browser_policy` | `DropdownButtonFormField` | `'warn_allow'` | `'warn_allow'` vs `'block'`. |

### 5.2 Client-Side Lock Banner
If any student has started an exam (`hasAttempts == _examAttempts.isNotEmpty`):
- All input fields and toggles are set to `enabled: false` / `onChanged: null` (lines 991, 1001, 1011, 1022, 1029, 1050).
- An amber warning banner appears:
  > *"Settings Locked: Student exam attempts have already started. Proctoring parameters cannot be altered mid-exam to ensure test integrity."*
- The "Save Settings" button is disabled (`onPressed: hasAttempts ? null : ...`, line 1066).

### 5.3 Backend 409 Response Handling
If an instructor opens the dialog before attempts start, but another student starts an attempt before the instructor clicks save, the backend raises `HTTPException(409, "Exam settings cannot be altered after attempts have started.")`.
The catch block catches the 409 exception and displays:
```dart
// frontend/lib/features/courses/presentation/assignment_detail_screen.dart:1095-1100
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  content: Text('Failed to save settings: $e'),
  backgroundColor: AppColors.dangerRose,
));
```

---

## 6. CSV Export Implementation

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:873-926`, `course_repository.dart:377-386`)

### 6.1 How CSV Is Handled on Web
In `CourseRepository`:
```dart
// frontend/lib/features/courses/data/course_repository.dart:377-386
Future<String> exportExamCsv({required int courseId, required int aid}) async {
  final response = await _dio.get(
    ApiConstants.examExportCsv(courseId, aid),
    options: Options(responseType: ResponseType.plain),
  );
  return response.data.toString();
}
```
In `AssignmentDetailScreen`:
```dart
// frontend/lib/features/courses/presentation/assignment_detail_screen.dart:880-915
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Row(children: [Icon(Icons.table_chart_outlined), SizedBox(width: 8), Text('Exam Proctoring Audit CSV')]),
    content: SizedBox(
      width: 600,
      height: 350,
      child: SelectableText(csvData, style: GoogleFonts.jetBrainsMono(fontSize: 12)),
    ),
    actions: [
      TextButton.icon(
        icon: const Icon(Icons.copy_rounded, size: 16),
        label: const Text('Copy CSV to Clipboard'),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: csvData));
          ScaffoldMessenger.of(context).showSnackBar(...);
        },
      ),
      ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
    ],
  ),
);
```
- **Finding:** It does **NOT** trigger a browser file download anchor (`<a download="audit.csv">`). Instead, it loads the raw CSV string into an in-app modal with a `SelectableText` box and a button to copy the CSV text to the system clipboard.

---

## 7. Post-Submission UI & The Resubmit Loophole

[CODE] (`frontend/lib/features/courses/presentation/assignment_detail_screen.dart:2921-2999`, `backend/app/services/submission_service.py:64-78`)

### 7.1 Is "Resubmit" Hidden for Exams?
**NO.** The UI condition for displaying "Resubmit Assignment" is:
```dart
// frontend/lib/features/courses/presentation/assignment_detail_screen.dart:2921-2947, 2986-2999
if (isGraded)
  // Grades finalized: "Grades have been finalized by your instructor. Submissions are closed."
else if (isSubmissionClosed)
  // Submissions closed
else ...[
  OutlinedButton.icon(
    onPressed: () {
      setState(() => _mySubmission = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Re-opened submission form. Upload your updated work below.'),
      ));
    },
    icon: const Icon(Icons.refresh, size: 16),
    label: const Text('Resubmit Assignment'),
  ),
]
```
- **UI Flaw:** The button only checks `!isGraded && !isSubmissionClosed`. It **does not check `_isTimedExam`**.
- When a student completes an exam, if the instructor has not finalized grades yet, the student sees the "Resubmit Assignment" button.
- Clicking "Resubmit Assignment" locally wipes `_mySubmission = null`, which causes the "Start Exam" card to reappear.

### 7.2 Is Double-Submission Blocked by the Backend?
**YES, but via different mechanisms depending on endpoint:**
1. If the student clicks "Start Exam" again: `POST .../exam/start` raises `HTTPException(400, "Maximum exam attempts reached. Contact your instructor for a retake permission.")` (`backend/app/api/v1/exams.py:425`).
2. If the student attempts to bypass `ExamScreen` and post directly to `POST /courses/{id}/assignments/{aid}/submissions`:
   `submission_service.py:75` checks if a submission already exists:
   ```python
   # backend/app/services/submission_service.py:75-76
   if existing_submission and assignment.time_limit_minutes:
       raise ValueError("This timed assignment has already been submitted and cannot be resubmitted.")
   ```
   The backend strictly blocks resubmission, returning HTTP 400.
- **Verdict:** The block is enforced by the backend, but the frontend UI has a state inconsistency bug that misleads the student into thinking they can resubmit.

---

## 8. How Students See "Take Exam" vs "Resume" vs "Submitted"

[CODE] (`assignment_detail_screen.dart:2658-2736, 2748-2755`, `exam_screen.dart:811-815, 826-890`)

The student experience traverses three states across two screens:

```
[Assignment Detail Screen]
   ├── Case A: Student has NOT submitted (_mySubmission == null)
   │     └── Shows "Timed Examination" card with "Start Exam (60 min)" button.
   │
   └── Case B: Student HAS submitted (_mySubmission != null)
         └── Shows "My Submission" card with grade, submitted content, and submission timestamp.

[When Student clicks "Start Exam" -> Enters ExamScreen]
   ├── Case 1: First time starting (_attemptResumed == false)
   │     └── Button displays: "Start Exam"
   │
   ├── Case 2: In-flight active attempt discovered by _checkInitialState() (_attemptResumed == true)
   │     └── Button displays: "Resume Proctored Exam"
   │
   └── Case 3: Student already submitted attempt on server (isSubmitted == true)
         └── Screen immediately bypasses exam view and shows: "Exam Submitted!" result screen.
```

---

## 9. Routing Architecture & Route Guards (`app_router.dart`)

[CODE] (`frontend/lib/core/router/app_router.dart:40-68, 175-194`)

### 9.1 Route Definition
```dart
// frontend/lib/core/router/app_router.dart:175-194
GoRoute(
  path: '/courses/:id/assignments/:aid/exam',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return ExamScreen(
      courseId: int.parse(state.pathParameters['id']!),
      assignmentId: int.parse(state.pathParameters['aid']!),
      assignmentTitle: extra?['title'] ?? 'Exam',
      assignmentType: extra?['type'] ?? 'text',
      description: extra?['description'],
      maxMarks: (extra?['max_marks'] as num?)?.toDouble() ?? 100.0,
      timeLimitMinutes: extra?['time_limit_minutes'] as int?,
      randomizeQuestions: extra?['randomize_questions'] as bool? ?? false,
      showResultsAfter: extra?['show_results_after'] as bool? ?? true,
    );
  },
),
```

### 9.2 Guards and Vulnerabilities
1. **Isolation Outside Shell:** The route is registered outside `ShellRoute`, ensuring clean full-screen isolation without sidebar or navigation bars.
2. **Missing Role Guards:** `app_router.dart:40-68` only checks authentication (`!isAuth -> /auth/login`) and restricts `/courses/new` to admin/professor. It has **no role restriction on `/courses/:id/assignments/:aid/exam`**. Any role (professor, TA, admin) can mount the exam screen.
3. **The `state.extra` Browser Refresh Bug:**
   The route extracts `title`, `type`, `description`, `max_marks`, and `time_limit_minutes` strictly from `state.extra`.
   If a student presses **Browser Refresh (F5)** or opens a bookmarked exam URL, `state.extra` is `null`!
   `ExamScreen` falls back to `type = 'text'` and `timeLimitMinutes = null`, breaking MCQ parsing and timer configurations unless resumed via `_checkInitialState()`.

---

## 10. API Audit: Frontend Calls vs Backend Endpoints

[CODE] (`frontend/lib/core/network/api_constants.dart:100-125`, `frontend/lib/features/courses/data/course_repository.dart:271-387`, `backend/app/api/v1/exams.py`)

### 10.1 Mapping Table

| Frontend Method (`CourseRepository`) | Method & Path Called | Backend Route in `exams.py` | Status / Notes |
| :--- | :--- | :--- | :--- |
| `startExam` | `POST /courses/{id}/assignments/{aid}/exam/start` | `POST .../exam/start` (line 384) | **ACTIVE** – Starts or resumes session. |
| `reportAttemptViolation` | `POST /attempts/{attemptId}/violations` | `POST /attempts/{attempt_id}/violations` (line 434) | **ACTIVE** – Universal telemetry endpoint. |
| `sendHeartbeat` | `POST /attempts/{attemptId}/heartbeat` | `POST /attempts/{attempt_id}/heartbeat` (line 477) | **ACTIVE** – 10s ping & draft sync. |
| `getExamState` | `GET /courses/{id}/assignments/{aid}/exam/state`| `GET .../exam/state` (line 700) | **ACTIVE** – Resume check on load. |
| `submitExam` | `POST /courses/{id}/assignments/{aid}/exam/submit` | `POST .../exam/submit` (line 661) | **ACTIVE** – Marks attempt submitted. |
| `listExamAttempts` | `GET /courses/{id}/assignments/{aid}/exam/attempts` | `GET .../exam/attempts` (line 726) | **ACTIVE** – Powers Live Console feed. |
| `recordExamDecision` | `POST .../attempts/{attemptId}/decision` | `POST .../attempts/{attempt_id}/decision` (line 893) | **ACTIVE** – Instructor review actions. |
| `updateExamSettings` | `PUT .../exam/settings` | `PUT .../exam/settings` (line 981) | **ACTIVE** – Updates proctor parameters. |
| `exportExamCsv` | `GET .../exam/export-csv` | `GET .../exam/export-csv` (line 941) | **ACTIVE** – Returns CSV text stream. |
| `flagExamSwitch` | `POST /courses/{id}/assignments/{aid}/exam/flag` | `POST .../exam/flag` (line 527) | **DEAD FRONTEND CALL** – Zero callers in frontend. |
| `getAttemptState` | `GET /attempts/{attemptId}/state` | `GET /attempts/{attempt_id}/state` (line 551) | **DEAD FRONTEND CALL** – Zero callers in frontend. |
| `updateExamAttemptStatus`| `POST .../attempts/{attemptId}/status` | `POST .../attempts/{attempt_id}/status` (line 847) | **DEAD FRONTEND CALL** – Replaced by `recordExamDecision`. |
| *(None)* | *(None)* | `POST /attempts/{id}/switch-tab` (line 465) | **DEAD BACKEND ROUTE** – Legacy; frontend uses `violations`. |
| *(None)* | *(None)* | `GET .../exam/settings` (line 967) | **DEAD BACKEND ROUTE** – Frontend reads settings via `getAssignment`. |

### 10.2 Other Areas Touching Exam Data
- **Dashboards (`student_dashboard_screen.dart`, `ta_dashboard_screen.dart`):** Contain **zero** references to exams or proctoring; all coursework is rendered as generic assignments.
- **Analytics (`analytics_dashboard_screen.dart`):** Exam data is **not** integrated into student at-risk prediction models or analytics summaries (only reads `final_weight` assignment weight).
- **Course Chat RAG:** Exam attempt data and violation timelines are completely excluded from the course chat ingestion vector space.
