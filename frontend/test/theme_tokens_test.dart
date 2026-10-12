import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:professor_os/core/theme/app_theme.dart';
import 'package:professor_os/shared/widgets/submission_triage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Design System & UI/UX Tokens Verification', () {
    test('journalLight theme satisfies Senior SaaS contrast and font contracts', () {
      final theme = AppTheme.journalLight;

      // 1. Transparent surfaceTintColor on all surface themes
      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      expect(theme.navigationBarTheme.surfaceTintColor, Colors.transparent);

      // 2. Inter font family and Urdu fallback list
      expect(AppText.fontFallbacks, contains('Noto Sans Arabic'));
      expect(AppText.fontFallbacks, contains('Noto Nastaliq Urdu'));
      expect(theme.textTheme.bodyMedium?.fontFamily, contains('Inter'));

      // 3. Page Background and Surface Contrast
      expect(AppColorsLight.canvas, const Color(0xFFF8FAFC));
      expect(AppColorsLight.surface, const Color(0xFFFFFFFF));
      expect(AppColorsLight.surfaceMid, const Color(0xFFF1F5F9));
      expect(AppColorsLight.primaryAction, const Color(0xFF4F46E5));

      // 4. Input decoration filled with pure white and 8px radius
      expect(theme.inputDecorationTheme.filled, isTrue);
      expect(theme.inputDecorationTheme.fillColor, Colors.white);
      expect(theme.inputDecorationTheme.border?.isOutline, isTrue);
    });

    test('journalDark theme eliminates purple surface tint and configures Inter + fallback', () {
      final theme = AppTheme.journalDark;

      expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(AppText.fontFallbacks, contains('Noto Sans Arabic'));
      expect(AppText.fontFallbacks, contains('Noto Nastaliq Urdu'));
      expect(theme.textTheme.bodyMedium?.fontFamily, contains('Inter'));
    });

    test('Submission triage badges map to high-contrast semantic tokens', () {
      // Danger: Injection detected -> Text #B91C1C, Bg #FEE2E2, Border #FCA5A5
      final dangerColors =
          SubmissionTriageBadges.badgeThemeFor('injection_detected');
      expect(dangerColors.$1, const Color(0xFFB91C1C));
      expect(dangerColors.$2, const Color(0xFFFEE2E2));
      expect(dangerColors.$3, const Color(0xFFFCA5A5));

      // Warning: Needs review -> Text #B45309, Bg #FEF3C7, Border #FCD34D
      final warnColors =
          SubmissionTriageBadges.badgeThemeFor('blank_or_unreadable');
      expect(warnColors.$1, const Color(0xFFB45309));
      expect(warnColors.$2, const Color(0xFFFEF3C7));
      expect(warnColors.$3, const Color(0xFFFCD34D));

      // Neutral -> Text #334155, Bg #F1F5F9, Border #CBD5E1
      final neutralColors =
          SubmissionTriageBadges.badgeThemeFor('unknown_reason');
      expect(neutralColors.$1, const Color(0xFF334155));
      expect(neutralColors.$2, const Color(0xFFF1F5F9));
      expect(neutralColors.$3, const Color(0xFFCBD5E1));
    });

    test('Success and Info semantic tokens conform to WCAG AA >= 4.5:1', () {
      // Success: Text #15803D, Bg #DCFCE7, Border #86EFAC
      expect(AppColorsLight.statusPassInk, const Color(0xFF15803D));
      expect(AppColorsLight.statusPassBg, const Color(0xFFDCFCE7));
      expect(AppColorsLight.statusPassBorder, const Color(0xFF86EFAC));

      // Info: Text #1D4ED8, Bg #DBEAFE, Border #93C5FD
      expect(AppColorsLight.statusInfoInk, const Color(0xFF1D4ED8));
      expect(AppColorsLight.statusInfoBg, const Color(0xFFDBEAFE));
      expect(AppColorsLight.statusInfoBorder, const Color(0xFF93C5FD));
    });
  });
}
