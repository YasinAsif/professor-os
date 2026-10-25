/// ProfessorOS – Design System v2 "The Journal"
/// Reference implementation for Dark Mode ("Pressroom Night"),
/// Light Mode ("Pressroom Day"), and v1 "Marginalia" backward compatibility.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme_provider.dart';

// ── The Journal v2 Colors (Light Mode / Academic SaaS / Default) ───────
class AppColors {
  AppColors._();

  // ── Surfaces ──────────────────────────────────────────────────
  static const Color canvas =
      Color(0xFFF8FAFC); // Slate 50 background (light mode)
  static const Color surface = Color(0xFFFFFFFF); // Pure white cards, containers
  static const Color surfaceMid = Color(0xFFF1F5F9); // Slate 100 hover, active rows
  static const Color surfaceHigh = Color(0xFFE2E8F0); // Slate 200 popovers, drawers

  // ── Borders (1px only) ─────────────────────────────────────────
  static const Color rule =
      Color(0xFFE2E8F0); // Slate 200 dividers
  static const Color ruleStrong =
      Color(0xFFCBD5E1); // Slate 300 section dividers

  // ── Ink ───────────────────────────────────────────────────────
  static const Color inkTitle =
      Color(0xFF0F172A); // Slate 900 title ink
  static const Color inkPrimary =
      Color(0xFF0F172A); // Slate 900 primary text (high contrast)
  static const Color inkSecondary =
      Color(0xFF475569); // Slate 600 metadata (> 4.5:1 WCAG AA)
  static const Color inkGhost =
      Color(0xFF64748B); // Slate 500 placeholders, muted hints
  static const Color inkLabel =
      Color(0xFF334155); // Slate 700 form labels
  static const Color inkAccent =
      Color(0xFF4F46E5); // Indigo 600 links, active nav item

  // ── Status pairs (ALWAYS use bg + ink together) ───────────────
  // High-contrast Semantic Status & Triage Badges:
  // Success: Text #15803D, Bg #DCFCE7, Border #86EFAC
  static const Color statusPassBg = Color(0xFFDCFCE7);
  static const Color statusPassInk = Color(0xFF15803D);
  static const Color statusPassBorder = Color(0xFF86EFAC);

  // Info / In Progress: Text #1D4ED8, Bg #DBEAFE, Border #93C5FD
  static const Color statusInfoBg = Color(0xFFDBEAFE);
  static const Color statusInfoInk = Color(0xFF1D4ED8);
  static const Color statusInfoBorder = Color(0xFF93C5FD);

  // Warning / Needs Review: Text #B45309, Bg #FEF3C7, Border #FCD34D
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingInk = Color(0xFFB45309);
  static const Color statusPendingBorder = Color(0xFFFCD34D);

  // Danger / Injection / Failed: Text #B91C1C, Bg #FEE2E2, Border #FCA5A5
  static const Color statusCriticalBg = Color(0xFFFEE2E2);
  static const Color statusCriticalInk = Color(0xFFB91C1C);
  static const Color statusCriticalBorder = Color(0xFFFCA5A5);

  // Neutral / Draft / Queued: Text #334155, Bg #F1F5F9, Border #CBD5E1
  static const Color statusNeutralBg = Color(0xFFF1F5F9);
  static const Color statusNeutralInk = Color(0xFF334155);
  static const Color statusNeutralBorder = Color(0xFFCBD5E1);

  // ── Backward-compatible semantic aliases for existing code ────
  static const Color bgPage = canvas;
  static const Color bgCard = surface;
  static const Color bgSurface = surface;
  static const Color bgMargin = surface;
  static const Color bgHover = surfaceMid;
  static const Color bgActive = surfaceMid;
  static const Color bgElevated = surfaceHigh;
  static const Color bgInput = surface;

  static const Color textPrimary = inkPrimary;
  static const Color textSecondary = inkSecondary;
  static const Color textMuted = inkGhost;
  static const Color inkFaint = inkGhost;

  static const Color marginRule = rule;
  static const Color borderStrong = ruleStrong;
  static const Color border = rule;
  static const Color borderFocus = Color(0xFF4F46E5);

  static const Color feedbackRed = statusCriticalInk;
  static const Color verified = statusPassInk;
  static const Color pending = statusPendingInk;
  static const Color signal = Color(0xFF4F46E5); // Indigo 600

  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color emerald = statusPassInk;
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primaryCyan = Color(0xFF0284C7);
  static const Color primaryViolet = Color(0xFF4F46E5);
  static const Color primaryMid = Color(0xFF4F46E5);
  static const Color primarySoft = Color(0xFFEEF2FF);
  static const Color successGreen = statusPassInk;
  static const Color dangerRose = statusCriticalInk;
  static const Color accentAmber = statusPendingInk;
  static const Color statusCritical = statusCriticalInk;
  static const Color statusPass = statusPassInk;
  static const Color statusPending = statusPendingInk;
  static const Color accentCyan = Color(0xFF0284C7);
  static const Color accentPink = Color(0xFF4F46E5);

  // Design System Reconciled Tokens
  static const Color cta = Color(0xFFD97706); // Amber 600
  static const Color ctaHover = Color(0xFFB45309); // Amber 700
  static const Color academicTeal = Color(0xFF0D9488); // Teal 600

  static const Color heroBg = canvas;
  static const Color heroBg2 = canvas;

  static Color badgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'professor':
        return primary;
      case 'student':
        return statusPassInk;
      case 'ta':
        return statusPendingInk;
      case 'admin':
        return primary;
      default:
        return inkSecondary;
    }
  }

  static Color hecGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'W':
        return statusPassInk;
      case 'X':
        return primary;
      case 'Y':
        return statusPendingInk;
      case 'Z':
        return statusCriticalInk;
      default:
        return inkSecondary;
    }
  }
}

// ── The Journal v2 Colors (Dark Mode / Pressroom Night) ───────────────
class AppColorsDark {
  AppColorsDark._();

  static const Color canvas = Color(0xFF0F172A); // Slate 900 background
  static const Color surface = Color(0xFF1E293B); // Slate 800 cards, containers
  static const Color surfaceMid = Color(0xFF334155); // Slate 700 hover, active rows
  static const Color surfaceHigh = Color(0xFF475569); // Slate 600 popovers, drawers

  static const Color rule = Color(0xFF334155); // Slate 700 dividers
  static const Color ruleStrong = Color(0xFF475569); // Slate 600 section dividers

  static const Color inkTitle = Color(0xFFF8FAFC);
  static const Color inkPrimary = Color(0xFFF8FAFC); // Slate 50 primary text
  static const Color inkSecondary = Color(0xFF94A3B8); // Slate 400 metadata on dark (> 4.5:1 WCAG AA)
  static const Color inkGhost = Color(0xFF64748B); // Slate 500 placeholders, muted hints
  static const Color inkLabel = Color(0xFFCBD5E1);
  static const Color inkAccent = Color(0xFF818CF8); // Indigo 400 links, active nav item

  static const Color statusPassBg = Color(0xFF14532D);
  static const Color statusPassInk = Color(0xFF86EFAC);
  static const Color statusPassBorder = Color(0xFF166534);

  static const Color statusInfoBg = Color(0xFF1E3A8A);
  static const Color statusInfoInk = Color(0xFF93C5FD);
  static const Color statusInfoBorder = Color(0xFF1D4ED8);

  static const Color statusPendingBg = Color(0xFF78350F);
  static const Color statusPendingInk = Color(0xFFFCD34D);
  static const Color statusPendingBorder = Color(0xFF92400E);

  static const Color statusCriticalBg = Color(0xFF7F1D1D);
  static const Color statusCriticalInk = Color(0xFFFCA5A5);
  static const Color statusCriticalBorder = Color(0xFF991B1B);

  static const Color statusNeutralBg = Color(0xFF1E293B);
  static const Color statusNeutralInk = Color(0xFF94A3B8);
  static const Color statusNeutralBorder = Color(0xFF334155);

  static const Color bgPage = canvas;
  static const Color bgCard = surface;
  static const Color bgSurface = surface;
  static const Color bgMargin = surface;
  static const Color bgHover = surfaceMid;
  static const Color bgActive = surfaceMid;
  static const Color bgElevated = surfaceHigh;
  static const Color bgInput = surface;

  static const Color textPrimary = inkPrimary;
  static const Color textSecondary = inkSecondary;
  static const Color textMuted = inkGhost;
  static const Color inkFaint = inkGhost;

  static const Color marginRule = rule;
  static const Color borderStrong = ruleStrong;
  static const Color border = rule;
  static const Color borderFocus = Color(0xFF818CF8);

  static const Color feedbackRed = statusCriticalInk;
  static const Color verified = statusPassInk;
  static const Color pending = statusPendingInk;
  static const Color signal = Color(0xFF818CF8);

  static const Color primary = Color(0xFF818CF8);
  static const Color emerald = statusPassInk;
  static const Color primaryIndigo = Color(0xFF818CF8);
  static const Color primaryCyan = Color(0xFF38BDF8);
  static const Color primaryViolet = Color(0xFF818CF8);
  static const Color primaryMid = Color(0xFF818CF8);
  static const Color primarySoft = Color(0xFF312E81);
  static const Color successGreen = statusPassInk;
  static const Color dangerRose = statusCriticalInk;
  static const Color accentAmber = statusPendingInk;
  static const Color statusCritical = statusCriticalInk;
  static const Color statusPass = statusPassInk;
  static const Color statusPending = statusPendingInk;
  static const Color accentCyan = Color(0xFF38BDF8);
  static const Color accentPink = Color(0xFF818CF8);

  static const Color cta = Color(0xFFF59E0B);
  static const Color ctaHover = Color(0xFFD97706);
  static const Color academicTeal = Color(0xFF14B8A6);

  static const Color heroBg = canvas;
  static const Color heroBg2 = canvas;

  static Color badgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'professor':
        return primary;
      case 'student':
        return statusPassInk;
      case 'ta':
        return statusPendingInk;
      case 'admin':
        return primary;
      default:
        return inkSecondary;
    }
  }

  static Color hecGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'W':
        return statusPassInk;
      case 'X':
        return primary;
      case 'Y':
        return statusPendingInk;
      case 'Z':
        return statusCriticalInk;
      default:
        return inkSecondary;
    }
  }
}

// ── Clean Academic SaaS Light Mode Palette (WCAG AA >= 4.5:1) ──────────
class AppColorsLight {
  AppColorsLight._();

  // Page Background: #F8FAFC (Slate 50)
  static const Color canvas = Color(0xFFF8FAFC);
  static const Color bgPage = canvas;
  // Primary Surface: #FFFFFF (Pure White)
  static const Color surface = Color(0xFFFFFFFF);
  // Secondary / Input / Hover Surface: #F1F5F9 (Slate 100)
  static const Color surfaceMid = Color(0xFFF1F5F9);
  static const Color surfaceHigh = Color(0xFFE2E8F0);

  // Borders: 1px #E2E8F0 (Slate 200) / Strong #CBD5E1 (Slate 300)
  static const Color rule = Color(0xFFE2E8F0);
  static const Color ruleStrong = Color(0xFFCBD5E1);

  // Ink Typography:
  // H1/H2 Title: #0F172A (Slate 900)
  static const Color inkTitle = Color(0xFF0F172A);
  // Body & Submission Text: #1E293B (Slate 800)
  static const Color inkPrimary = Color(0xFF1E293B);
  // Secondary Metadata / Subtitles: #475569 (Slate 600)
  static const Color inkSecondary = Color(0xFF475569);
  // Muted / Timestamps / Hints: #64748B (Slate 500 — WCAG AA compliant on white)
  static const Color inkGhost = Color(0xFF64748B);
  // Table Headers & Form Labels: #334155 (Slate 700)
  static const Color inkLabel = Color(0xFF334155);

  // Primary Brand Action: #4F46E5 (Indigo 600), Hover #4338CA, Light Chip #EEF2FF
  static const Color inkAccent = Color(0xFF4F46E5);
  static const Color primaryAction = Color(0xFF4F46E5);
  static const Color primaryHover = Color(0xFF4338CA);
  static const Color chipFill = Color(0xFFEEF2FF);
  static const Color chipText = Color(0xFF3730A3);

  // Design System Reconciled Tokens
  static const Color cta = Color(0xFFD97706); // Amber 600
  static const Color ctaHover = Color(0xFFB45309); // Amber 700
  static const Color academicTeal = Color(0xFF0D9488); // Teal 600

  // Status Badges (Text + Subtle Fill + 1px Border)
  // Success / Graded / Approved: Text #15803D, Bg #DCFCE7, Border #86EFAC
  static const Color statusPassBg = Color(0xFFDCFCE7);
  static const Color statusPassInk = Color(0xFF15803D);
  static const Color statusPassBorder = Color(0xFF86EFAC);

  // Info / Processing: Text #1D4ED8, Bg #DBEAFE, Border #93C5FD
  static const Color statusInfoBg = Color(0xFFDBEAFE);
  static const Color statusInfoInk = Color(0xFF1D4ED8);
  static const Color statusInfoBorder = Color(0xFF93C5FD);

  // Warning / Needs Review / Scanned: Text #B45309, Bg #FEF3C7, Border #FCD34D
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingInk = Color(0xFFB45309);
  static const Color statusPendingBorder = Color(0xFFFCD34D);

  // Danger / Injection / Failed: Text #B91C1C, Bg #FEE2E2, Border #FCA5A5
  static const Color statusCriticalBg = Color(0xFFFEE2E2);
  static const Color statusCriticalInk = Color(0xFFB91C1C);
  static const Color statusCriticalBorder = Color(0xFFFCA5A5);

  // Neutral / Draft / Queued: Text #334155, Bg #F1F5F9, Border #CBD5E1
  static const Color statusNeutralBg = Color(0xFFF1F5F9);
  static const Color statusNeutralInk = Color(0xFF334155);
  static const Color statusNeutralBorder = Color(0xFFCBD5E1);
}

// ── Marginalia v1 Palette (Paper Canvas Classic) ──────────────────────
class AppColorsMarginalia {
  AppColorsMarginalia._();

  static const Color bgPage = Color(0xFFF6F5F0);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgMargin = Color(0xFFF6F5F0);
  static const Color bgHover = Color(0xFFFBF1EE);
  static const Color bgActive = Color(0xFFEFEAE0);
  static const Color bgElevated = Color(0xFFFFFFFF);
  static const Color bgInput = Color(0xFFFFFFFF);
  static const Color inkPrimary = Color(0xFF1E2A38);
  static const Color inkSecondary = Color(0xFF5B6470);
  static const Color inkFaint = Color(0xFF9CA0A6);
  static const Color marginRule = Color(0xFFE4E1D8);
  static const Color borderStrong = Color(0xFFD4CFC2);
  static const Color feedbackRed = Color(0xFFB4432E);
  static const Color verified = Color(0xFF3F6B4F);
  static const Color pending = Color(0xFFB5872A);
  static const Color signal = Color(0xFF2F5D8A);
}

// ── Spacing Tokens ────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const s2 = 2.0; // icon-to-label gap
  static const s4 = 4.0; // between metadata items in same row
  static const s8 = 8.0; // compact component internal padding
  static const s12 = 12.0; // label to content gap
  static const s16 = 16.0; // standard card padding (all sides)
  static const s24 = 24.0; // between distinct sections
  static const s32 = 32.0; // between major layout zones
  static const s48 = 48.0; // page-level horizontal margin
}

// ── Border Radius Tokens ──────────────────────────────────────────────
class AppRadius {
  AppRadius._();
  static const r2 = 2.0; // stamp badges, toasts, code blocks
  static const r4 = 4.0; // buttons (more press-like, less pill)
  static const r6 = 6.0; // cards, surface containers
  static const r8 = 8.0; // input fields, drawers
}

// ── Typography Tokens ─────────────────────────────────────────────────
class AppText {
  AppText._();

  static const String fontInter = 'Inter';
  static const String fontMono = 'JetBrains Mono';

  static const List<String> fontFallbacks = [
    'Noto Sans Arabic',
    'Noto Nastaliq Urdu',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  // Course name header, HEC sections, wordmark
  static TextStyle get display => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.4,
        color: AppColors.inkPrimary,
      );

  // Section / Card Title (H3): 18px, FontWeight.w600, letter-spacing -0.2
  static TextStyle get title => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        letterSpacing: -0.2,
        color: AppColors.inkPrimary,
      );

  // Body & Submission Text: 15px–16px, FontWeight.w400, line-height 1.5
  static TextStyle get body => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.inkPrimary,
      );

  static TextStyle get bodyLong => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.inkPrimary,
      );

  static TextStyle get bodyDense => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.inkPrimary,
      );

  // Table Headers & Form Labels: 12px–13px, FontWeight.w600
  static TextStyle get sectionHeader => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
        color: AppColors.inkSecondary,
      );

  static TextStyle get label => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.1,
        color: AppColors.inkSecondary,
      );

  // Muted / Timestamps / Hints: 12px, FontWeight.w400, color Slate 500
  static TextStyle get caption => const TextStyle(
        fontFamily: fontInter,
        fontFamilyFallback: fontFallbacks,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.inkGhost,
      );

  // JetBrains Mono — course codes, numbers, code, IDs, score badges
  static TextStyle get mono => const TextStyle(
        fontFamily: fontMono,
        fontFamilyFallback: ['Courier New', 'monospace'],
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.inkPrimary,
      );
  static TextStyle get monoLarge => const TextStyle(
        fontFamily: fontMono,
        fontFamilyFallback: ['Courier New', 'monospace'],
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.inkPrimary,
      );
  static TextStyle get monoStat => const TextStyle(
        fontFamily: fontMono,
        fontFamilyFallback: ['Courier New', 'monospace'],
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.1,
        color: AppColors.inkPrimary,
      );
}

// ── Gradients & Shadows ───────────────────────────────────────────────
class AppGradients {
  AppGradients._();
  // Zero gradients in v2
  static const LinearGradient primaryButton =
      LinearGradient(colors: [AppColors.inkPrimary, AppColors.inkPrimary]);
  static const LinearGradient aurora =
      LinearGradient(colors: [AppColors.canvas, AppColors.canvas]);
  static const LinearGradient heroPanel =
      LinearGradient(colors: [AppColors.surface, AppColors.surface]);
  static const LinearGradient cardSheen =
      LinearGradient(colors: [Colors.transparent, Colors.transparent]);
}

class AppShadows {
  AppShadows._();
  // Zero shadows in v2
  static List<BoxShadow> get card => const [];
  static List<BoxShadow> get elevated => const [];
  static List<BoxShadow> get buttonGlow => const [];
  static List<BoxShadow> get sidebar => const [];
}

// ── AppTheme Factory ──────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => journalLight;

  static ThemeData themeFor(DesignSystem design, JournalThemeMode mode) {
    if (design == DesignSystem.marginalia) {
      return marginaliaLight;
    }
    return mode == JournalThemeMode.light ? journalLight : journalDark;
  }

  // ── The Journal v2 - Dark Mode (Default "Pressroom Night") ───────────
  static ThemeData get journalDark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppText.fontInter,
      fontFamilyFallback: AppText.fontFallbacks,
      scaffoldBackgroundColor: AppColorsDark.canvas,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF4F46E5),
        onPrimary: Colors.white,
        secondary: AppColorsDark.inkSecondary,
        onSecondary: AppColorsDark.inkPrimary,
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.inkPrimary,
        error: AppColorsDark.statusCriticalInk,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppText.display.copyWith(fontSize: 32, color: AppColorsDark.inkPrimary),
        displayMedium: AppText.display.copyWith(fontSize: 26, color: AppColorsDark.inkPrimary),
        displaySmall: AppText.display.copyWith(fontSize: 22, color: AppColorsDark.inkPrimary),
        headlineLarge: AppText.title.copyWith(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColorsDark.inkPrimary),
        headlineMedium: AppText.title.copyWith(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColorsDark.inkPrimary),
        headlineSmall: AppText.title.copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: AppColorsDark.inkPrimary),
        titleLarge: AppText.title.copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: AppColorsDark.inkPrimary),
        titleMedium: AppText.title.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: AppColorsDark.inkPrimary),
        titleSmall: AppText.title.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColorsDark.inkPrimary),
        bodyLarge: AppText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColorsDark.inkPrimary),
        bodyMedium: AppText.bodyDense.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: AppColorsDark.inkPrimary),
        bodySmall: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColorsDark.inkGhost),
        labelLarge: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColorsDark.inkPrimary),
        labelMedium: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColorsDark.inkSecondary),
        labelSmall: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColorsDark.inkGhost),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsDark.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: AppColorsDark.rule, width: 1)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: AppColorsDark.rule, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide:
                const BorderSide(color: Color(0xFF4F46E5), width: 2.0)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide:
                const BorderSide(color: AppColorsDark.statusCriticalInk, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(
                color: AppColorsDark.statusCriticalInk, width: 2.0)),
        labelStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsDark.inkSecondary,
            fontSize: 13),
        hintStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsDark.inkGhost,
            fontSize: 13),
        errorStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsDark.statusCriticalInk,
            fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.r4)),
          textStyle: const TextStyle(
              fontFamily: AppText.fontInter,
              fontFamilyFallback: AppText.fontFallbacks,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsDark.inkPrimary,
          side: const BorderSide(color: AppColorsDark.ruleStrong, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.r4)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(
              fontFamily: AppText.fontInter,
              fontFamilyFallback: AppText.fontFallbacks,
              fontWeight: FontWeight.w500,
              fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF818CF8),
          textStyle: const TextStyle(
              fontFamily: AppText.fontInter,
              fontFamilyFallback: AppText.fontFallbacks,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColorsDark.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          side: const BorderSide(color: AppColorsDark.rule, width: 1),
        ),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColorsDark.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: AppColorsDark.rule, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsDark.canvas,
        foregroundColor: AppColorsDark.inkPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.title.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: AppColorsDark.inkPrimary),
        iconTheme: const IconThemeData(color: AppColorsDark.inkPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsDark.surface,
        contentTextStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsDark.inkPrimary,
            fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r4),
          side: const BorderSide(color: AppColorsDark.rule, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: AppColorsDark.inkPrimary,
        iconColor: AppColorsDark.inkPrimary,
        collapsedTextColor: AppColorsDark.inkPrimary,
        collapsedIconColor: AppColorsDark.inkSecondary,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColorsDark.inkPrimary,
        iconColor: AppColorsDark.inkSecondary,
      ),
    );
  }

  // ── The Journal v2 - Light Mode ("Pressroom Day" / Clean Academic SaaS) ───────────────────
  static ThemeData get journalLight {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppText.fontInter,
      fontFamilyFallback: AppText.fontFallbacks,
      scaffoldBackgroundColor: AppColorsLight.canvas,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: Color(0xFF4F46E5), // Indigo 600
        onPrimary: Colors.white,
        secondary: AppColorsLight.inkSecondary,
        onSecondary: Colors.white,
        surface: AppColorsLight.surface,
        onSurface: AppColorsLight.inkPrimary,
        error: AppColorsLight.statusCriticalInk,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: AppText.display
            .copyWith(fontSize: 32, color: AppColorsLight.inkTitle),
        displayMedium: AppText.display
            .copyWith(fontSize: 26, color: AppColorsLight.inkTitle),
        displaySmall: AppText.display
            .copyWith(fontSize: 22, color: AppColorsLight.inkTitle),
        headlineLarge: AppText.title.copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColorsLight.inkTitle),
        headlineMedium: AppText.title.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppColorsLight.inkTitle),
        headlineSmall: AppText.title
            .copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: AppColorsLight.inkTitle),
        titleLarge: AppText.title.copyWith(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: AppColorsLight.inkTitle),
        titleMedium: AppText.title
            .copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: AppColorsLight.inkTitle),
        titleSmall: AppText.title
            .copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColorsLight.inkTitle),
        bodyLarge: AppText.body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: AppColorsLight.inkPrimary),
        bodyMedium:
            AppText.bodyDense.copyWith(fontSize: 15, fontWeight: FontWeight.w400, height: 1.5, color: AppColorsLight.inkPrimary),
        bodySmall: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColorsLight.inkGhost),
        labelLarge: AppText.label
            .copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColorsLight.inkLabel),
        labelMedium: AppText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColorsLight.inkLabel),
        labelSmall: AppText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: AppColorsLight.inkGhost),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: AppColorsLight.ruleStrong, width: 1)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(color: AppColorsLight.ruleStrong, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide:
                const BorderSide(color: Color(0xFF4F46E5), width: 2.0)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(
                color: AppColorsLight.statusCriticalInk, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            borderSide: const BorderSide(
                color: AppColorsLight.statusCriticalInk, width: 2.0)),
        labelStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsLight.inkLabel,
            fontSize: 13,
            fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsLight.inkGhost,
            fontSize: 13),
        errorStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsLight.statusCriticalInk,
            fontSize: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4F46E5),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.r4)),
          textStyle: const TextStyle(
              fontFamily: AppText.fontInter,
              fontFamilyFallback: AppText.fontFallbacks,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight.inkPrimary,
          side: const BorderSide(color: AppColorsLight.ruleStrong, width: 1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.r4)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          textStyle: const TextStyle(
              fontFamily: AppText.fontInter,
              fontFamilyFallback: AppText.fontFallbacks,
              fontWeight: FontWeight.w500,
              fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF4F46E5),
          textStyle: const TextStyle(
              fontFamily: AppText.fontInter,
              fontFamilyFallback: AppText.fontFallbacks,
              fontWeight: FontWeight.w600,
              fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColorsLight.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          side: const BorderSide(color: AppColorsLight.rule, width: 1),
        ),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: AppColorsLight.surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsLight.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColorsLight.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme:
          const DividerThemeData(color: AppColorsLight.rule, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorsLight.surface,
        foregroundColor: AppColorsLight.inkPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.title
            .copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: AppColorsLight.inkTitle),
        iconTheme: const IconThemeData(color: AppColorsLight.inkPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColorsLight.surface,
        contentTextStyle: const TextStyle(
            fontFamily: AppText.fontInter,
            fontFamilyFallback: AppText.fontFallbacks,
            color: AppColorsLight.inkPrimary,
            fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r4),
          side: const BorderSide(color: AppColorsLight.rule, width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        textColor: AppColorsLight.inkPrimary,
        iconColor: AppColorsLight.inkPrimary,
        collapsedTextColor: AppColorsLight.inkPrimary,
        collapsedIconColor: AppColorsLight.inkSecondary,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColorsLight.inkPrimary,
        iconColor: AppColorsLight.inkSecondary,
      ),
    );
  }

  // ── Marginalia v1 - Classic Light Mode ──────────────────────────────
  static ThemeData get marginaliaLight {
    final frauncesTT = GoogleFonts.frauncesTextTheme();
    final interTT = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsMarginalia.bgPage,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColorsMarginalia.signal,
        primary: AppColorsMarginalia.signal,
        secondary: AppColorsMarginalia.inkSecondary,
        surface: AppColorsMarginalia.bgCard,
        error: AppColorsMarginalia.feedbackRed,
      ),
      textTheme: TextTheme(
        displayLarge: frauncesTT.displayLarge?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        displayMedium: frauncesTT.displayMedium?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        displaySmall: frauncesTT.displaySmall?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        headlineLarge: frauncesTT.headlineLarge?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        headlineMedium: frauncesTT.headlineMedium?.copyWith(
            color: AppColorsMarginalia.inkPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 28),
        headlineSmall: frauncesTT.headlineSmall?.copyWith(
            color: AppColorsMarginalia.inkPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 20),
        titleLarge: frauncesTT.titleLarge?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w600),
        titleMedium: frauncesTT.titleMedium?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w500),
        titleSmall: frauncesTT.titleSmall?.copyWith(
            color: AppColorsMarginalia.inkPrimary, fontWeight: FontWeight.w500),
        bodyLarge: interTT.bodyLarge
            ?.copyWith(color: AppColorsMarginalia.inkPrimary, fontSize: 16),
        bodyMedium: interTT.bodyMedium
            ?.copyWith(color: AppColorsMarginalia.inkPrimary, fontSize: 14),
        bodySmall: interTT.bodySmall
            ?.copyWith(color: AppColorsMarginalia.inkSecondary, fontSize: 13),
        labelLarge: interTT.labelLarge?.copyWith(
            color: AppColorsMarginalia.inkPrimary,
            fontWeight: FontWeight.w500,
            fontSize: 14),
        labelMedium: interTT.labelMedium?.copyWith(
            color: AppColorsMarginalia.inkSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12),
        labelSmall: interTT.labelSmall?.copyWith(
            color: AppColorsMarginalia.inkSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorsMarginalia.bgInput,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColorsMarginalia.marginRule)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColorsMarginalia.marginRule)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColorsMarginalia.signal, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                const BorderSide(color: AppColorsMarginalia.feedbackRed)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: AppColorsMarginalia.feedbackRed, width: 2)),
        labelStyle: GoogleFonts.inter(
            color: AppColorsMarginalia.inkSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(
            color: AppColorsMarginalia.inkFaint, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsMarginalia.signal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColorsMarginalia.bgCard,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColorsMarginalia.marginRule),
        ),
      ),
      dialogTheme: const DialogTheme(
        backgroundColor: AppColorsMarginalia.bgCard,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsMarginalia.bgCard,
        surfaceTintColor: Colors.transparent,
      ),
      appBarTheme: const AppBarTheme(
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
