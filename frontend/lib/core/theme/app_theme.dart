/// ProfessorOS – "Electric Chalk" Design System
/// Light mode, vibrant indigo/violet accents, Gen-Z energy.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Backgrounds ───────────────────────────────────
  static const Color bgPage     = Color(0xFFF8FAFF); // barely-lavender white
  static const Color bgCard     = Color(0xFFFFFFFF);
  static const Color bgSurface  = Color(0xFFFFFFFF); // Alias for card background surface
  static const Color bgElevated = Color(0xFFF1F5F9);
  static const Color bgInput    = Color(0xFFF8FAFC);

  // ── Primary (electric indigo → violet) ───────────
  static const Color primaryIndigo = Color(0xFF4F46E5);
  static const Color primaryTeal   = Color(0xFF4F46E5); // Alias for backward compatibility
  static const Color primaryCyan   = Color(0xFF06B6D4); // Alias for cyan accent
  static const Color primaryViolet = Color(0xFF7C3AED);
  static const Color primarySoft   = Color(0xFFEEF2FF);
  static const Color primaryMid    = Color(0xFF6366F1);

  // ── Supporting accents ───────────────────────────
  static const Color accentCyan    = Color(0xFF06B6D4);
  static const Color accentPink    = Color(0xFFEC4899);
  static const Color accentAmber   = Color(0xFFD97706);
  static const Color successGreen  = Color(0xFF059669);
  static const Color dangerRose    = Color(0xFFE11D48);

  // ── Text ─────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted     = Color(0xFF94A3B8);

  // ── Borders ──────────────────────────────────────
  static const Color border        = Color(0xFFE2E8F0);
  static const Color borderFocus   = Color(0xFF4F46E5);

  // ── Auth hero panel (dark left side) ─────────────
  static const Color heroBg        = Color(0xFF0D0817);
  static const Color heroBg2       = Color(0xFF130B2B);

  static Color badgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'professor': return primaryIndigo;
      case 'student':   return successGreen;
      case 'ta':        return accentAmber;
      case 'admin':     return dangerRose;
      default:          return textSecondary;
    }
  }

  static Color hecGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'W': return successGreen;
      case 'X': return primaryIndigo;
      case 'Y': return accentAmber;
      case 'Z': return dangerRose;
      default:  return textSecondary;
    }
  }
}

class AppGradients {
  AppGradients._();

  static const LinearGradient primaryButton = LinearGradient(
    colors: [AppColors.primaryIndigo, AppColors.primaryViolet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient aurora = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroPanel = LinearGradient(
    colors: [AppColors.heroBg, AppColors.heroBg2],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardSheen = LinearGradient(
    colors: [Color(0x08FFFFFF), Color(0x02FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
    const BoxShadow(color: Color(0x0D000000), blurRadius: 24, offset: Offset(0, 4)),
    const BoxShadow(color: Color(0x074F46E5), blurRadius: 40, offset: Offset(0, 8)),
  ];

  static List<BoxShadow> get elevated => [
    const BoxShadow(color: Color(0x14000000), blurRadius: 48, offset: Offset(0, 12)),
    const BoxShadow(color: Color(0x0A4F46E5), blurRadius: 60, offset: Offset(0, 16)),
  ];

  static List<BoxShadow> get buttonGlow => [
    const BoxShadow(color: Color(0x604F46E5), blurRadius: 24, offset: Offset(0, 6)),
  ];

  static List<BoxShadow> get sidebar => [
    const BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(4, 0)),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final outfitTT = GoogleFonts.outfitTextTheme();
    final interTT  = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryIndigo,
        primary: AppColors.primaryIndigo,
        secondary: AppColors.primaryViolet,
        surface: AppColors.bgCard,
        error: AppColors.dangerRose,
      ),
      textTheme: TextTheme(
        displayLarge:  outfitTT.displayLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
        displayMedium: outfitTT.displayMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        displaySmall:  outfitTT.displaySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: outfitTT.headlineLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium:outfitTT.headlineMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: outfitTT.headlineSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge:    outfitTT.titleLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium:   outfitTT.titleMedium?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        titleSmall:    outfitTT.titleSmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge:     interTT.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium:    interTT.bodyMedium?.copyWith(color: AppColors.textPrimary),
        bodySmall:     interTT.bodySmall?.copyWith(color: AppColors.textSecondary),
        labelLarge:    interTT.labelLarge?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        labelMedium:   interTT.labelMedium?.copyWith(color: AppColors.textSecondary),
        labelSmall:    interTT.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryIndigo, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.dangerRose)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.dangerRose, width: 2)),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        hintStyle:  GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
        errorStyle: GoogleFonts.inter(color: AppColors.dangerRose, fontSize: 12),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgElevated,
        selectedColor: AppColors.primarySoft,
        labelStyle: GoogleFonts.inter(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll(AppColors.bgCard),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          )),
          elevation: const WidgetStatePropertyAll(8),
        ),
      ),
    );
  }
}
