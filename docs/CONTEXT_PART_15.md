# CONTEXT PART 15: CATCH-ALL, DISCREPANCY RECONCILIATION & FINAL AUDIT

> **Forensic Audit Standard:** Strictly read-only analysis of `backend/` and `frontend/`. Every claim is verified with exact file paths and line ranges (`file:line`). All statements are tagged `[CODE]`, `[RAN]`, `[ASSUMED]`, or `[NOT DONE]`.

---

## 1. Complete System Capability Matrix (Claim vs. Reality)

This matrix reconciles every advertised feature in the ProfessorOS design documents (SRS, SDS, Scope Document) against actual lines of code in the repository:

| Feature / Domain | Claimed Capability | Actual Code Status | Exact File & Line Evidence |
| :--- | :--- | :--- | :--- |
| **Authentication** | Argon2id password hashing, Dual-JWT with refresh rotation, account lockout | **`[CODE]` FULLY IMPLEMENTED** | `hash_password` in [auth_service.py:31](file:///e:/FYP_YASIN/backend/app/services/auth_service.py#L31), lockout in [auth_service.py:91-105](file:///e:/FYP_YASIN/backend/app/services/auth_service.py#L91-L105). |
| **Biometric Auth** | Native FIDO2 / WebAuthn passwordless biometrics | **`[CODE]` APP-LEVEL SHIM** | Stores plaintext password in `FlutterSecureStorage` and replays to `/auth/login` ([dio_client.dart:42-59](file:///e:/FYP_YASIN/backend/app/core/network/dio_client.dart#L42-L59)). |
| **User Signout** | Immediate session revocation across devices | **`[CODE]` PARTIAL / SHIM** | `/auth/logout` blacklists access token in Redis for only 3600s; does not revoke refresh token ([auth.py:80-87](file:///e:/FYP_YASIN/backend/app/api/v1/auth.py#L80-L87)). `/users/me/sessions` is required to revoke all refresh tokens ([users.py:166](file:///e:/FYP_YASIN/backend/app/api/v1/users.py#L166)). |
| **Course Lifecycle** | Creation, updating, archiving, HEC weight validation | **`[CODE]` FULLY IMPLEMENTED** | HEC weights sum to 100 ([course_service.py:57-59](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L57-L59)). Join code generation ([course.py:16](file:///e:/FYP_YASIN/backend/app/models/course.py#L16)). |
| **TA Delegation** | TAs assist in course management, grading, and proctoring | **`[CODE]` BROKEN / LOCKED OUT** | TAs enrolled with `role="ta"` are blocked with 403 on assignment CRUD and exam decisions due to `verify_course_management_access` ([course_service.py:114](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L114)). |
| **Course Materials** | Upload PDF/PPTX/DOCX, Docling markdown extraction, FAISS vector indexing | **`[CODE]` FULLY IMPLEMENTED** | Misplaced in [quizzes.py:220-307](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L220-L307). Fallback to PyMuPDF, python-docx, and NumPy vector store ([document_ingestion.py:175-325](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L175-L325)). |
| **Course Chat (RAG)** | Grounded Q&A over lecture slides with zero cross-course leakage | **`[CODE]` FULLY IMPLEMENTED** | Hard file isolation per course ([document_ingestion.py:110](file:///e:/FYP_YASIN/backend/app/services/document_ingestion.py#L110)). Fallback keyword mocks in [courses.py:424-453](file:///e:/FYP_YASIN/backend/app/api/v1/courses.py#L424-L453). |
| **Proctored Exams** | Fullscreen enforcement, tab switch detection, auto-submit on strikes | **`[CODE]` FULLY IMPLEMENTED** | Strike tracking ([exams.py:450-465](file:///e:/FYP_YASIN/backend/app/api/v1/exams.py#L450-L465)), periodic heartbeat loop ([exam_screen.dart:477-505](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L477-L505)). |
| **Proctor Settings Sync** | Assignment strike limits and browser policies passed to ExamScreen | **`[CODE]` BROKEN / DISCONNECTED** | ExamScreen hardcodes `kFlagThreshold = 3` and `kAutoSubmitThreshold = 5` because `app_router.dart` never extracts or passes settings from assignment ([app_router.dart:182-192](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L182-L192)). |
| **AI Rubric Grading** | DeepSeek-R1-Distill-70B on Groq with rationale-before-score | **`[CODE]` FULLY IMPLEMENTED** | Enforced via Pydantic schema in [grading_pipeline.py:61-105](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L61-L105). Borderline pass/fail (48-52%) flags `needs_review` ([grading_pipeline.py:193](file:///e:/FYP_YASIN/backend/app/services/grading_pipeline.py#L193)). |
| **OBE & CLO Attainment** | Washington Accord / HEC CLO cohort attainment calculation | **`[CODE]` FULLY IMPLEMENTED** | Misplaced route in [quizzes.py:638](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L638). Calculates attainment against 60% KPI and generates CQI plans ([clo_attainment.py:68-100](file:///e:/FYP_YASIN/backend/app/services/clo_attainment.py#L68-L100)). |
| **HEC Accreditation Dossier** | Formal PDF accreditation dossier generation for university audit | **`[CODE]` FULLY IMPLEMENTED** | Route `GET .../hec-dossier` in [quizzes.py:1218](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L1218). Background Celery generation via PyMuPDF/WeasyPrint ([hec_dossier.py:336-570](file:///e:/FYP_YASIN/backend/app/services/hec_dossier.py#L336-L570)). |
| **Cohort Analytics** | Mean, median, std dev, mark distribution, at-risk detection | **`[CODE]` FULLY IMPLEMENTED** | Handled in [analytics.py:23-119](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L23-L119) with Redis caching. WeasyPrint PDF export in [analytics.py:170-433](file:///e:/FYP_YASIN/backend/app/api/v1/analytics.py#L170-L433). |
| **Announcements** | Course-wide announcements and alerts | **`[NOT DONE]` ZERO CODE** | No database tables, no models, no routes. |
| **In-App Notification Hub** | Real-time student notification badge & bell | **`[NOT DONE]` ZERO CODE** | No database models or WebSocket notification endpoints. |
| **Admin System Analytics** | Platform-wide system usage metrics (`/analytics/system`) | **`[NOT DONE]` MISSING ROUTE** | Advertised in frontend UI concepts, but route does not exist in FastAPI backend. |
| **Admin Semester Management** | Global semester configuration and date limits | **`[CODE]` IN-MEMORY MOCK** | Frontend tab operates on a local in-memory list without backend persistence ([admin_dashboard_screen.dart:104-114](file:///e:/FYP_YASIN/frontend/lib/features/admin/presentation/admin_dashboard_screen.dart#L104-L114)). |
| **Admin HEC Credit Controls** | Maximum credit hour limiter | **`[CODE]` IN-MEMORY MOCK** | Frontend slider updates local `_creditLimit` state only ([admin_dashboard_screen.dart:208-215](file:///e:/FYP_YASIN/frontend/lib/features/admin/presentation/admin_dashboard_screen.dart#L208-L215)). |

---

## 2. Definitive Vulnerability & Defect Ranking

The following issues are ranked in order of actual operational and security severity:

### 1. Plaintext Password Storage for Biometric Login (Critical Security Vulnerability)
- **Files**: [frontend/lib/core/network/dio_client.dart:42-59](file:///e:/FYP_YASIN/frontend/lib/core/network/dio_client.dart#L42-L59) and [frontend/lib/features/auth/presentation/login_screen.dart:363-412](file:///e:/FYP_YASIN/frontend/lib/features/auth/presentation/login_screen.dart#L363-L412).
- **Impact**: The user's plaintext password is stored in `FlutterSecureStorage` under key `biometric_password`. If an attacker gains device root/keychain access or inspects application memory, the raw user credentials can be dumped.
- **Remediation**: Migrate to public-key cryptography (WebAuthn / FIDO2). The server should store a public key, and the device should sign a cryptographic nonce using a Secure Enclave hardware key upon biometric authorization.

### 2. TA Access Lockout Architecture Defect (High Operational Severity)
- **Files**: [backend/app/services/course_service.py:106-117](file:///e:/FYP_YASIN/backend/app/services/course_service.py#L106-L117) and [backend/app/api/v1/assignments.py:64-70](file:///e:/FYP_YASIN/backend/app/api/v1/assignments.py#L64-L70).
- **Impact**: While the schema supports delegating TAs to courses (`role="ta"` in `enrollments`), all core management handlers call `verify_course_management_access`, which strictly asserts `user.role == "professor" and course.professor_id == user.id`. This renders delegated TAs unable to create assignments, edit assignments, or record proctoring decisions.
- **Remediation**: Update `verify_course_management_access` to query `Enrollment.role == 'ta'` for the course and allow authorized TAs to perform permitted actions.

### 3. Exam Proctoring Settings Disconnect (Medium Usability Severity)
- **Files**: [frontend/lib/core/router/app_router.dart:182-192](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L182-L192) and [frontend/lib/features/courses/presentation/exam_screen.dart:39-44](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L39-L44).
- **Impact**: Custom proctoring settings configured by professors in the backend (`strike_limit_flag`, `strike_limit_autosubmit`, `fullscreen_required`, `block_copy_paste`, `unsupported_browser_policy`) are never passed to the student's `ExamScreen`. The screen falls back to hardcoded defaults (`kFlagThreshold = 3`, `kAutoSubmitThreshold = 5`).
- **Remediation**: In `app_router.dart`, fetch or pass assignment proctoring settings via `examRouteExtra` into `ExamScreen`.

### 4. Alt-Tab Double Strike Spike in Proctoring (Medium Telemetry Severity)
- **Files**: [frontend/lib/features/courses/presentation/exam_screen.dart:425-450](file:///e:/FYP_YASIN/frontend/lib/features/courses/presentation/exam_screen.dart#L425-L450).
- **Impact**: Switching away from the exam tab fires both `AppLifecycleState.paused`/`inactive` and `window.onBlur`, causing two separate violation reports for a single user action.
- **Remediation**: Add a 500ms debounce window on client-side proctoring violation dispatchers.

### 5. Timed Attempt Never-Heartbeat Blind Spot (Low/Medium Telemetry Severity)
- **Files**: [backend/app/services/exam_monitor.py:70-85](file:///e:/FYP_YASIN/backend/app/services/exam_monitor.py#L70-L85).
- **Impact**: If a student starts an exam attempt but crashes before the first heartbeat arrives (`last_heartbeat_at is None`), the monitor skips the missing-heartbeat check.
- **Remediation**: Update `start_exam` to initialize `last_heartbeat_at = started_at`.

---

## 3. Misplaced Routers & Dead Configuration Index

### 3.1 Misplaced Route Mounting
The following endpoints are mounted in unexpected router files, contrary to REST domain conventions:
- **Course Material Upload & List**: Mounted in [backend/app/api/v1/quizzes.py:220-440](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L220-L440) instead of `courses.py`.
- **CLO Attainment Report (`/courses/{id}/clo-attainment`)**: Mounted in [backend/app/api/v1/quizzes.py:638](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L638) instead of `analytics.py` or `courses.py`.
- **HEC Course Accreditation Dossier (`/courses/{id}/hec-dossier`)**: Mounted in [backend/app/api/v1/quizzes.py:1218](file:///e:/FYP_YASIN/backend/app/api/v1/quizzes.py#L1218) instead of `reports.py` or `courses.py`.

### 3.2 Dead / Unused Configuration
- `Assignment.late_penalty_per_day` ([assignment.py:68](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L68)): Stored in DB, never read by submission service.
- `Assignment.max_penalty_cap` ([assignment.py:69](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L69)): Stored in DB, never read.
- `Assignment.randomize_questions` ([assignment.py:74](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L74)): Stored in DB, never read by quiz engine.
- `Assignment.show_results_after` ([assignment.py:75](file:///e:/FYP_YASIN/backend/app/models/assignment.py#L75)): Stored in DB, never read by results handler.

---

## 4. Final Verdict & Demonstration Viability

### 4.1 Production Readiness Assessment
- **Core Academic Assessment**: **READY** (Course management, assignments, submissions, PDF ingestion, and rubric-anchored AI grading function solidly with strong test coverage).
- **Proctored Examination**: **READY FOR CONTROLLED DEMO** (Heartbeat tracking, strikes, tab switches, and auto-submit function properly, subject to the documented hardcoded threshold caveat).
- **HEC / Washington Accord Compliance**: **READY FOR DEMO** (CLO attainment calculation and HEC accreditation dossier generation produce high-fidelity reports).
- **Multi-Tenant Enterprise Security**: **REQUIRES REMEDIATION** (TA access lockout and plaintext biometric password storage must be fixed prior to commercial institutional deployment).

---

PART 15 DONE - COMPLETE 15-PART FORENSIC AUDIT DELIVERED
