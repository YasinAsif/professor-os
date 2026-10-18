# CONTEXT PART 14: FRONTEND (WHOLE APP ARCHITECTURE & STATE MANAGEMENT)

> **Forensic Audit Standard:** Strictly read-only analysis of `backend/` and `frontend/`. Every claim is verified with exact file paths and line ranges (`file:line`). All statements are tagged `[CODE]`, `[RAN]`, `[ASSUMED]`, or `[NOT DONE]`.

---

## 1. Frontend Architecture & Technology Stack

### 1.1 Core Framework & Project Structure
`[CODE]` The ProfessorOS frontend is a unified multi-platform application built in Flutter 3 / Dart 3, compiled for Web, Android, iOS, and Desktop.
- Directory Structure:
  - `frontend/lib/core/`: Centralized infrastructure (`network/`, `router/`, `theme/`, `utils/`).
  - `frontend/lib/features/`: Feature-first modular encapsulation:
    - `auth/`: Authentication, biometric login, password reset, email verification.
    - `courses/`: Course rosters, materials, assignments, proctored exams, quizzes.
    - `admin/`: User management, registration approvals, platform configuration.
    - `analytics/`: Cohort performance charts, grade distribution, at-risk rosters.
    - `profile/`: Account credentials, active sessions, dark mode settings.
  - `frontend/lib/shared/`: Reusable design system widgets (`prof_button.dart`, `prof_card.dart`, `journal_ui/`).

### 1.2 State Management: Flutter Riverpod
`[CODE]` State management is standardized on `flutter_riverpod` (v2.x) across all features:
- Core authentication state is driven by `authProvider` (`AsyncNotifier<Map<String, dynamic>?>`) in [frontend/lib/features/auth/providers/auth_provider.dart](file:///e:/FYP_YASIN/frontend/lib/features/auth/providers/auth_provider.dart).
- Feature providers use `FutureProvider` and `FutureProvider.family` with explicit invalidation (`ref.invalidate(...)`) to synchronize UI states with backend updates.
- Theme switching is managed by `themeStateProvider` in [frontend/lib/core/theme/theme_provider.dart](file:///e:/FYP_YASIN/frontend/lib/core/theme/theme_provider.dart).

---

## 2. Routing & Role-Based Navigation Guards

### 2.1 Declarative Routing with GoRouter
`[CODE]` Implemented in [frontend/lib/core/router/app_router.dart:32-91](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L32-L91):
- Uses `GoRouter` with `_RouterNotifier(ref)` listening to `authProvider` for reactive redirects ([app_router.dart:35](file:///e:/FYP_YASIN/frontend/lib/core/router/app_router.dart#L35)).
- **Authentication & Role Redirect Rules**:
  ```dart
  // frontend/lib/core/router/app_router.dart:43-65
  if (!isAuth && !isAuthRoute) return '/auth/login';

  if (state.uri.path == '/') {
    if (!isAuth) return '/auth/login';
    if (authState.valueOrNull?['role'] == 'admin') return '/admin';
    return '/courses';
  }

  // Restrict /courses/new to admin and professor
  if (isAuth && state.uri.path == '/courses/new') {
    final role = authState.valueOrNull?['role'] as String?;
    if (role != 'admin' && role != 'professor') return '/courses';
  }
  ```

### 2.2 Responsive Navigation Shell
`[CODE]` Handled by `ResponsiveNavigation` in [frontend/lib/core/router/responsive_navigation.dart](file:///e:/FYP_YASIN/frontend/lib/core/router/responsive_navigation.dart):
- Breakpoint threshold: `mobileNavigationBreakpoint = 800.0` pixels ([responsive_navigation.dart:8](file:///e:/FYP_YASIN/frontend/lib/core/router/responsive_navigation.dart#L8)).
- **Width < 800px**: Renders `MobileNavigationShell` with a top AppBar and sliding hamburger `Drawer` ([responsive_navigation.dart:27-40](file:///e:/FYP_YASIN/frontend/lib/core/router/responsive_navigation.dart#L27-L40)).
- **Width >= 800px**: Renders `DesktopNavigationShell` with a persistent vertical `NavigationRail` and workspace container.

---

## 3. Network Architecture, Auth Interceptor & Token Refresh

### 3.1 Dio Client Configuration
`[CODE]` Implemented in [frontend/lib/core/network/dio_client.dart](file:///e:/FYP_YASIN/frontend/lib/core/network/dio_client.dart):
- Base URL resolution: Handled dynamically via `ApiConstants.baseUrl` ([dio_client.dart:18](file:///e:/FYP_YASIN/frontend/lib/core/network/dio_client.dart#L18)).
- In Web environments, it resolves `Uri.base.origin + '/api/v1'`. On desktop/mobile, it defaults to `http://localhost:8000/api/v1` or reads `--dart-define=API_BASE_URL` ([api_constants.dart:16-26](file:///e:/FYP_YASIN/frontend/lib/core/network/api_constants.dart#L16-L26)).
- Connect and receive timeouts are set to 30 seconds ([dio_client.dart:19-20](file:///e:/FYP_YASIN/frontend/lib/core/network/dio_client.dart#L19-L20)).

### 3.2 Secure Token Storage & Automatic 401 Refresh
`[CODE]` In [dio_client.dart:6-32, 78-100](file:///e:/FYP_YASIN/frontend/lib/core/network/dio_client.dart#L6-L32):
- Uses `FlutterSecureStorage` to persist `access_token` and `refresh_token` in the platform keychain/keystore.
- `_AuthInterceptor` intercepts HTTP 401 unauthorized errors:
  1. Queues the failing request.
  2. Issues a refresh request to `POST /auth/refresh` using the stored refresh token.
  3. If successful: updates `access_token` in secure storage and retries the original request.
  4. If refresh fails: calls `clearTokens()` and invalidates authentication state.

### 3.3 Security Vulnerability: Plaintext Biometric Credential Storage
`[CODE]` In [dio_client.dart:42-59](file:///e:/FYP_YASIN/frontend/lib/core/network/dio_client.dart#L42-L59):
```dart
// frontend/lib/core/network/dio_client.dart:42-46
static Future<void> saveBiometricCreds(String email, String password) async {
  await _storage.write(key: 'biometric_email', value: email);
  await _storage.write(key: 'biometric_password', value: password);
}
```
As audited in Part 9, biometric authentication is an app-level shim. It stores the user's raw password in `FlutterSecureStorage` and replays it to `/auth/login` after local fingerprint verification.

---

## 4. Screen Audit & Client-Server Fidelity

### 4.1 Student Experience
`[CODE]`
- **Dashboard (`student_dashboard_screen.dart`)**: Consumes live endpoint `GET /users/me/student-dashboard`. Displays active courses, upcoming deadlines, and recent graded submissions with triage badges.
- **Proctored Exam (`exam_screen.dart`)**:
  - Enforces fullscreen overlay, tab-switch event monitoring, 15-second heartbeat loop (`/heartbeat`), and violation reporting (`/switch-tab`).
  - **Fidelity Bugs**: Local strike limits are hardcoded (`kFlagThreshold = 3`, `kAutoSubmitThreshold = 5`) because assignment proctoring settings are never forwarded via GoRouter `extra`.
- **Unproctored Quiz (`quiz_attempt_screen.dart`)**: Provides standard interactive MCQ test-taking without proctoring guards.

### 4.2 Professor Experience
`[CODE]`
- **Course & Roster Management (`course_detail_screen.dart`)**:
  - 5 primary tabs: Syllabus, Lecture Materials, Assignments, Student Roster, Analytics.
  - Lecture materials upload tab dispatches files to `POST /courses/{course_id}/materials/ingest`.
- **Assignment Wizard (`assignment_creation_wizard.dart`)**:
  - Multi-step modal for title, instructions, deadlines, max marks, and rubric criteria definition. Enforces that rubric weights total 100%.
- **Grading & SpeedGrader (`assignment_detail_screen.dart`)**:
  - Lists student submissions with status filters.
  - Allows single-click triggering of AI rubric evaluation (`POST /submissions/{sid}/ai-grade`).
  - Supports manual grade entry and feedback editing (`PUT /submissions/{sid}/grade`).

### 4.3 Administrator Experience & In-Memory Mocks
`[CODE]` Implemented in [frontend/lib/features/admin/presentation/admin_dashboard_screen.dart](file:///e:/FYP_YASIN/frontend/lib/features/admin/presentation/admin_dashboard_screen.dart):
- **User Management Tab (`UserManagementTab`)**: Real backend integration with `GET /admin/users`, `PUT /admin/users/{id}/status`, `DELETE /admin/users/{id}`.
- **Pending Approvals Tab (`PendingApprovalsTab`)**: Real backend integration with `GET /admin/users/pending`, `POST /admin/users/{id}/approve`, `POST /admin/users/{id}/reject`.
- **Semesters Tab (`AdminSemestersTab`)**: **`[NOT DONE / MOCK]`**
  In lines 104-114 of [admin_dashboard_screen.dart](file:///e:/FYP_YASIN/frontend/lib/features/admin/presentation/admin_dashboard_screen.dart#L104-L114), "Add Semester" merely mutates a local in-memory Dart list `_semesters`. There is **no backend endpoint** or database model for semesters.
- **HEC Guidelines Tab (`AdminHECTab`)**: **`[NOT DONE / MOCK]`**
  In lines 174-220 of [admin_dashboard_screen.dart](file:///e:/FYP_YASIN/frontend/lib/features/admin/presentation/admin_dashboard_screen.dart#L174-L220), the "Maximum Credit Hours" slider updates local state `_creditLimit` via `setState`. No HTTP call is made to save or enforce credit limits.

---

PART 14 DONE
