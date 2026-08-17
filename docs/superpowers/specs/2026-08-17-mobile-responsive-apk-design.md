# ProfessorOS Mobile Responsive and APK Design

## Goal

Make the existing Flutter application usable on phone-sized screens and produce an Android APK while preserving the current desktop web experience and backend behavior.

## Chosen approach

Use one responsive Flutter codebase. Keep the existing sidebar at widths of 800px and above. At narrower widths, replace it with a compact top bar and a slide-out drawer that reuses the same role-aware destinations. This keeps all navigation available without crowding a bottom navigation bar or maintaining separate mobile screens.

## Responsive behavior

- The shell selects its navigation treatment from layout constraints, not from a separate platform-specific route tree.
- Course lists become single-column phone layouts; course tabs scroll horizontally when needed.
- Course creation and assignment wizard actions wrap or stack, and long forms remain vertically scrollable.
- Analytics panels stack on narrow screens.
- Dense admin tables/rows become readable cards with wrapped actions.
- Profile controls use the full available width.
- The existing wide layouts remain the default and are not rewritten for mobile.

## Connectivity and packaging

- Preserve the existing API repositories, authentication, providers, and role routing.
- Support `--dart-define=API_BASE_URL=...` for Android builds while retaining the local development fallback.
- Keep Android internet permission and the current application identity.
- Produce a debug APK using the deployed Railway API URL; production signing remains out of scope unless credentials are supplied.

## Validation

- Add narrow-width widget coverage for the shell and representative course, assignment, analytics, admin, and profile states.
- Run the Flutter test suite and analyzer.
- Build the web release bundle and verify the existing web route remains available.
- Build the Android debug APK and verify it is non-empty.
- Check the Railway health endpoint and API URL configuration.

## Out of scope

- A separate native Android UI codebase.
- Backend/API changes unrelated to connectivity configuration.
- New product features beyond responsive layout and Android packaging.
