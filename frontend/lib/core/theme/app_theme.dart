/// ProfessorOS – "Marginalia" Design System
/// Light mode ("Paper"): Warm canvas, ink-navy text, strict semantic colors.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Backgrounds ───────────────────────────────────
  static const Color bgPage     = Color(0xFFF6F5F0); // Paper canvas
  static const Color bgCard     = Color(0xFFFFFFFF); // Content surfaces
  static const Color bgSurface  = Color(0xFFFFFFFF); // Alias
  static const Color bgMargin   = Color(0xFFF6F5F0); // Margin rail / sidebar
  static const Color bgHover    = Color(0xFFFBF1EE); // Faint ink-wash tint
  static const Color bgActive   = Color(0xFFEFEAE0); // Selected nav item / tab
  static const Color bgElevated = Color(0xFFFFFFFF); // Alias for legacy code
  static const Color bgInput    = Color(0xFFFFFFFF); // Inputs use card background with borders

  // ── Text / Ink ───────────────────────────────────
  static const Color inkPrimary   = Color(0xFF1E2A38); // Fountain-pen navy
  static const Color inkSecondary = Color(0xFF5B6470); // Secondary metadata
  static const Color inkFaint     = Color(0xFF9CA0A6); // Placeholders, muted text
  
  // Legacy aliases to prevent build errors before full refactor
  static const Color textPrimary   = inkPrimary;
  static const Color textSecondary = inkSecondary;
  static const Color textMuted     = inkFaint;

  // ── Borders ──────────────────────────────────────
  static const Color marginRule   = Color(0xFFE4E1D8); // Hairline borders
  static const Color borderStrong = Color(0xFFD4CFC2); // Emphasized dividers / focus
  static const Color border       = marginRule; // Legacy alias
  static const Color borderFocus  = signal;

  // ── Semantic & Accents ───────────────────────────
  static const Color feedbackRed  = Color(0xFFB4432E); // RESERVED: grading marks only
  static const Color verified     = Color(0xFF3F6B4F); // Success / fully graded
  static const Color pending      = Color(0xFFB5872A); // Awaiting grading
  static const Color signal       = Color(0xFF2F5D8A); // Interactivity, links, primary buttons

  // Legacy aliases
  static const Color primaryIndigo = signal;
  static const Color primaryCyan   = signal;
  static const Color primaryViolet = signal;
  static const Color primaryMid    = signal;
  static const Color primarySoft   = bgActive;
  static const Color successGreen  = verified;
  static const Color dangerRose    = feedbackRed;
  static const Color accentAmber   = pending;
  static const Color accentCyan    = signal;
  static const Color accentPink    = signal;

  // ── Auth hero panel (Legacy, to be removed) ────────
  static const Color heroBg        = bgPage;
  static const Color heroBg2       = bgPage;

  static Color badgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'professor': return signal;
      case 'student':   return verified;
      case 'ta':        return pending;
      case 'admin':     return inkPrimary;
      default:          return inkSecondary;
    }
  }

  static Color hecGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'W': return verified;
      case 'X': return signal;
      case 'Y': return pending;
      case 'Z': return feedbackRed;
      default:  return inkSecondary;
    }
  }
}

class AppGradients {
  AppGradients._();

  // Marginalia uses flat solid fills. Returning flat gradients to prevent build errors.
  static const LinearGradient primaryButton = LinearGradient(
    colors: [AppColors.signal, AppColors.signal],
  );

  static const LinearGradient aurora = LinearGradient(
    colors: [AppColors.bgPage, AppColors.bgPage],
  );

  static const LinearGradient heroPanel = LinearGradient(
    colors: [AppColors.bgPage, AppColors.bgPage],
  );

  static const LinearGradient cardSheen = LinearGradient(
    colors: [Colors.transparent, Colors.transparent],
  );
}

class AppShadows {
  AppShadows._();

  // Marginalia shadows are near-invisible
  static List<BoxShadow> get card => [
    const BoxShadow(color: Color(0x051E2A38), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> get elevated => [
    const BoxShadow(color: Color(0x121E2A38), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static List<BoxShadow> get buttonGlow => []; // No glows

  static List<BoxShadow> get sidebar => [
    const BoxShadow(color: Color(0x021E2A38), blurRadius: 4, offset: Offset(2, 0)),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final frauncesTT = GoogleFonts.frauncesTextTheme();
    final interTT  = GoogleFonts.interTextTheme();
    // For mono, we'll manually apply JetBrains Mono to specific styles later, 
    // but the default body remains Inter.

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.signal,
        primary: AppColors.signal,
        secondary: AppColors.inkSecondary,
        surface: AppColors.bgCard,
        error: AppColors.feedbackRed,
      ),
      textTheme: TextTheme(
        // Headings & Titles: Fraunces
        displayLarge:  frauncesTT.displayLarge?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.01),
        displayMedium: frauncesTT.displayMedium?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.01),
        displaySmall:  frauncesTT.displaySmall?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.01),
        headlineLarge: frauncesTT.headlineLarge?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.01),
        headlineMedium:frauncesTT.headlineMedium?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600, fontSize: 28),
        headlineSmall: frauncesTT.headlineSmall?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge:    frauncesTT.titleLarge?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w600),
        titleMedium:   frauncesTT.titleMedium?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w500),
        titleSmall:    frauncesTT.titleSmall?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w500),
        
        // Body & UI: Inter
        bodyLarge:     interTT.bodyLarge?.copyWith(color: AppColors.inkPrimary, fontSize: 16),
        bodyMedium:    interTT.bodyMedium?.copyWith(color: AppColors.inkPrimary, fontSize: 14),
        bodySmall:     interTT.bodySmall?.copyWith(color: AppColors.inkSecondary, fontSize: 13),
        
        // Labels & Captions: Inter
        labelLarge:    interTT.labelLarge?.copyWith(color: AppColors.inkPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium:   interTT.labelMedium?.copyWith(color: AppColors.inkSecondary, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall:    interTT.labelSmall?.copyWith(color: AppColors.inkSecondary, fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.05),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.marginRule)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.marginRule)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.signal, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.feedbackRed)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.feedbackRed, width: 2)),
        labelStyle: GoogleFonts.inter(color: AppColors.inkSecondary, fontSize: 14),
        hintStyle:  GoogleFonts.inter(color: AppColors.inkFaint, fontSize: 14),
        errorStyle: GoogleFonts.inter(color: AppColors.feedbackRed, fontSize: 12),
        prefixIconColor: AppColors.inkSecondary,
        suffixIconColor: AppColors.inkSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.signal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.signal,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.bgCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.marginRule),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgMargin,
        selectedColor: AppColors.bgActive,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.inkPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: AppColors.marginRule),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.marginRule, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.inkPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
        iconTheme: const IconThemeData(color: AppColors.inkPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkPrimary,
        contentTextStyle: GoogleFonts.inter(color: AppColors.bgPage, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.bgCard),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.marginRule),
          )),
          elevation: const WidgetStatePropertyAll(4),
        ),
      ),
    );
  }
}
