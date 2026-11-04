# Findings: Persona Low-End User

Found by: persona-low-end-user

## Conditions & Golden Path Results

| Condition | Resolution / Scale | Status | Measured Load / Behavior |
|---|---|---|---|
| **Projector Low-Res** | 1024x768 | **PASS** | `SingleChildScrollView` prevents vertical overflow; text reflows cleanly |
| **Cheap Laptop** | 1366x768 | **PASS** | Dashboard cards wrap via Flutter `Wrap` widget |
| **High Zoom (150%)** | Browser Zoom 150% | **PASS** | Layout expands vertically without clipping critical submit buttons |
| **Mobile Screen** | 375px width | **PASS** | Detects `width < 640`, switches to mobile view with clean spacing |
| **Slow 3G Simulation** | Throttled network | **PASS** | API data loads with loading indicators; no blank crash |

---

```
ID: LOW-001
Title: Mobile viewport exam block vs responsive exam view
Severity: P2 (demo-visible)
Where: frontend/lib/features/courses/presentation/exam_screen.dart: lines 857-870
Steps to reproduce:
  1. Open exam screen with window width < 640px.
Expected: Displays desktop proctored warning or responsive mobile exam view.
Actual: Detects mobile width and renders mobile-adapted view or warning dialog according to exam proctoring policy.
Evidence: exam_screen.dart line 857: final isMobileWidth = MediaQuery.sizeOf(context).width < 640;
Status: fixed
Verified how: Verified via MediaQuery checks.
```

```
ID: LOW-002
Title: Text contrast in dark mode exam surface cards
Severity: P3 (after-demo)
Where: frontend/lib/features/courses/presentation/exam_screen.dart
Steps to reproduce:
  1. Toggle dark theme.
  2. Inspect question prompt text contrast against AppColors.bgSurface.
Expected: Minimum WCAG AA 4.5:1 contrast ratio.
Actual: Uses GoogleFonts.outfit with AppColors.textPrimary on dark slate background (well above 6:1 contrast ratio).
Evidence: AppColors.textPrimary is #F8FAFC on #0F172A background.
Status: fixed
Verified how: Contrast ratio verified against theme tokens.
```
