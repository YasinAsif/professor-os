# ProfessorOS Mobile Responsive and APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Flutter screens usable on phone widths without changing the desktop web experience, then build and verify an Android APK.

**Architecture:** Keep one Flutter codebase and shared providers/routes. Add a responsive shell in `app_router.dart`, use `LayoutBuilder`/`MediaQuery` in dense screens, and keep the current API base URL configurable for Android. No backend duplication or native Android screens.

**Tech Stack:** Flutter 3.24.3, Dart 3.5.3, Riverpod, GoRouter, Dio, fl_chart, Android Gradle plugin.

---

### Task 1: Add responsive application shell

**Files:**
- Modify: `frontend/lib/core/router/app_router.dart`
- Test: `frontend/test/widget_test.dart`

- [ ] **Step 1: Add a narrow-width shell test**

Extend the existing smoke test to pump the app at a 390px-wide surface and assert that the shell renders without a 260px desktop sidebar overflow.

- [ ] **Step 2: Run the focused test and confirm the current desktop-only shell is the baseline**

Run: `flutter test test/widget_test.dart`

- [ ] **Step 3: Implement the responsive shell**

Use `LayoutBuilder` in the `ShellRoute` builder. Keep the current sidebar when `maxWidth >= 800`; for narrower widths render the child full-width and expose the same destinations through a `Drawer` or compact navigation menu. Reuse `_buildSidebar` content so role-based links remain identical.

- [ ] **Step 4: Run the focused test again**

Run: `flutter test test/widget_test.dart`

Expected: all tests pass.

### Task 2: Make course and assignment workflows phone-safe

**Files:**
- Modify: `frontend/lib/features/courses/presentation/course_list_screen.dart`
- Modify: `frontend/lib/features/courses/presentation/course_detail_screen.dart`
- Modify: `frontend/lib/features/courses/presentation/create_course_screen.dart`
- Modify: `frontend/lib/features/courses/presentation/assignment_creation_wizard.dart`
- Modify: `frontend/lib/features/courses/presentation/assignment_detail_screen.dart`

- [ ] **Step 1: Add narrow-width widget coverage for course cards and wizard content**

Pump the course list and assignment wizard at 390px width with mocked providers, and assert that key labels render without overflow exceptions.

- [ ] **Step 2: Run the new focused tests and record any overflow failure**

Run: `flutter test test/course_mobile_test.dart`

- [ ] **Step 3: Apply responsive layout changes**

Use `LayoutBuilder` to switch course cards from grid to one-column list, replace wide action rows with wrapping/stacked buttons, make course tabs scrollable, constrain dialogs to available width, and use `SingleChildScrollView` for wizard steps. Keep the existing desktop branches unchanged.

- [ ] **Step 4: Run the focused tests and Flutter test suite**

Run: `flutter test test/course_mobile_test.dart`

Run: `flutter test --no-pub`

Expected: all tests pass and no overflow exceptions are reported.

### Task 3: Make analytics and admin screens phone-safe

**Files:**
- Modify: `frontend/lib/features/analytics/presentation/analytics_dashboard_screen.dart`
- Modify: `frontend/lib/features/admin/presentation/user_management_screen.dart`
- Modify: `frontend/lib/features/profile/presentation/profile_screen.dart`

- [ ] **Step 1: Add narrow-width widget coverage for analytics/admin/profile**

Pump representative states at 390px width and assert that dashboard panels, user cards, and profile actions render.

- [ ] **Step 2: Run the focused test and confirm any current overflow**

Run: `flutter test test/role_mobile_test.dart`

- [ ] **Step 3: Apply responsive branches**

Keep analytics charts stacked on narrow screens, wrap action buttons, replace wide admin rows with cards, and ensure profile form controls use full available width. Preserve existing desktop layouts at wide constraints.

- [ ] **Step 4: Run the focused tests and analyzer**

Run: `flutter test test/role_mobile_test.dart`

Run: `flutter analyze --no-pub`

### Task 4: Configure Android API connectivity and build metadata

**Files:**
- Modify: `frontend/lib/core/network/api_constants.dart`
- Modify: `frontend/android/app/src/main/AndroidManifest.xml`
- Modify: `frontend/android/app/build.gradle`
- Modify: `frontend/.env.example`

- [ ] **Step 1: Add a configurable API base URL**

Use a compile-time Dart value such as `--dart-define=API_BASE_URL=https://api.example.com/api/v1`, while retaining localhost as the development fallback. Do not hard-code a production URL.

- [ ] **Step 2: Add Android internet permission and verify app metadata**

Ensure the main Android manifest contains `android.permission.INTERNET`; keep the existing application ID and version unless a release identity is supplied.

- [ ] **Step 3: Run Android configuration checks**

Run: `flutter pub get`

Run: `flutter doctor -v`

Expected: Android SDK is detected before APK build begins.

### Task 5: Verify web, mobile, and APK output

**Files:**
- Create: `frontend/build/app/outputs/flutter-apk/app-debug.apk` (generated artifact)

- [ ] **Step 1: Run Flutter tests and web build**

Run: `flutter test --no-pub`

Run: `flutter build web --no-pub`

- [ ] **Step 2: Build the debug APK**

Run: `flutter build apk --debug --dart-define=API_BASE_URL=<configured-backend-url>`

Expected: `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 3: Inspect the APK artifact and restart the development servers**

Verify the APK file exists and has non-zero size. Restart FastAPI on port 8000 and Flutter Web on port 8080, then check `/health`, `/auth/login`, and the generated web build.

- [ ] **Step 4: Report remaining environment limitations honestly**

If the Android SDK is still unavailable, report that responsive code and web verification completed but APK generation remains blocked by the machine toolchain.
