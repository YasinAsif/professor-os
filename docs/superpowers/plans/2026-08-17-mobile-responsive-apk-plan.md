# ProfessorOS Mobile Responsive APK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing Flutter app usable on phone widths, preserve the desktop web shell, and produce a Railway-connected Android APK.

**Architecture:** Keep one Flutter codebase and shared routes/providers. The existing 800px-and-above rail remains unchanged; below 800px the shell uses a top-bar drawer. Dense screens use constraint-aware wrapping/stacking instead of duplicated mobile screens. API connectivity remains compile-time configurable.

**Tech Stack:** Flutter/Dart, Riverpod, GoRouter, Dio, fl_chart, Android Gradle plugin.

---

### Task 1: Add responsive shell coverage

**Files:**
- Create: `frontend/lib/core/router/responsive_navigation.dart`
- Modify: `frontend/lib/core/router/app_router.dart`
- Modify: `frontend/test/widget_test.dart`

- [ ] **Step 1: Add a failing pure layout test**

Add a test for `shouldUseMobileNavigation(width)` that expects `true` at 390px and `false` at 800px.

- [ ] **Step 2: Run the focused test and verify the missing helper failure**

Run `flutter test test/widget_test.dart`; expect an undefined-symbol failure for the new helper.

- [ ] **Step 3: Implement the helper and drawer navigation**

Extract the width decision and role-aware destinations into `responsive_navigation.dart`. Render a compact `AppBar` with a menu button and `Drawer` below 800px. Reuse the same paths as the desktop rail and keep the existing rail at 800px and above.

- [ ] **Step 4: Run the focused test and analyzer**

Run `flutter test test/widget_test.dart` and `flutter analyze lib/core/router/app_router.dart lib/core/router/responsive_navigation.dart`.

### Task 2: Make dense course workflows phone-safe

**Files:**
- Modify: `frontend/lib/features/courses/presentation/course_list_screen.dart`
- Modify: `frontend/lib/features/courses/presentation/course_detail_screen.dart`
- Modify: `frontend/lib/features/courses/presentation/create_course_screen.dart`
- Modify: `frontend/lib/features/courses/presentation/assignment_creation_wizard.dart`
- Modify: `frontend/lib/features/courses/presentation/assignment_detail_screen.dart`
- Create: `frontend/test/course_mobile_test.dart`

- [ ] **Step 1: Add narrow-width widget coverage for stable layout helpers and labels**

Pump representative course screens at 390px where their existing constructors permit it, assert the key title/action labels render, and fail on Flutter overflow errors.

- [ ] **Step 2: Run the test to record the current mobile failure**

Run `flutter test test/course_mobile_test.dart`; capture any overflow or constructor issue before production changes.

- [ ] **Step 3: Apply constraint-aware layouts**

Use `LayoutBuilder`/`Wrap` for action rows, `SingleChildScrollView` for long wizard content, horizontally scrollable tab rows, and full-width mobile controls. Leave wide branches unchanged.

- [ ] **Step 4: Run focused tests and analyzer**

Run `flutter test test/course_mobile_test.dart` and analyze the five modified screens.

### Task 3: Make analytics, admin, and profile phone-safe

**Files:**
- Modify: `frontend/lib/features/analytics/presentation/analytics_dashboard_screen.dart`
- Modify: `frontend/lib/features/admin/presentation/user_management_screen.dart`
- Modify: `frontend/lib/features/profile/presentation/profile_screen.dart`
- Create: `frontend/test/role_mobile_test.dart`

- [ ] **Step 1: Add narrow-width coverage**

Pump representative loading/empty states at 390px and assert analytics, user-management, and profile labels are present without overflow errors.

- [ ] **Step 2: Run the test before implementation**

Run `flutter test test/role_mobile_test.dart` and record the baseline failure.

- [ ] **Step 3: Stack panels, wrap actions, and use full-width controls**

Use constraints to stack analytics cards, convert dense admin rows to vertical cards, and make profile fields/actions fill the phone width.

- [ ] **Step 4: Run focused tests and analyzer**

Run `flutter test test/role_mobile_test.dart` and `flutter analyze --no-pub`.

### Task 4: Verify Android connectivity and package output

**Files:**
- Modify: `frontend/lib/core/network/api_constants.dart` only if the existing define needs correction.
- Modify: `frontend/.env.example` if present; otherwise document the define in `README.md`.
- Generate: `frontend/build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 1: Verify the current API define and Android permission**

Confirm `API_BASE_URL` defaults to Railway and the manifest includes `android.permission.INTERNET`; change only if verification finds a gap.

- [ ] **Step 2: Run the complete Flutter test suite and web build**

Run `flutter test --no-pub` and `flutter build web --release --no-pub`.

- [ ] **Step 3: Build the Android debug APK against Railway**

Run `flutter build apk --debug --dart-define=API_BASE_URL=https://professor-os-production.up.railway.app/api/v1` and verify the APK exists with non-zero size.

- [ ] **Step 4: Verify deployment health and workspace cleanliness**

Check Railway `/health`, run `git diff --check`, and report any Android SDK limitation honestly.
