import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

enum ProfToastType { success, error, info, warning }

class ProfToast {
  ProfToast._();

  static void show(
    BuildContext context,
    String message, {
    ProfToastType type = ProfToastType.info,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    Color bg;
    Color border;
    Color fg;
    IconData icon;

    switch (type) {
      case ProfToastType.success:
        bg = AppColors.statusPassBg;
        border = AppColors.statusPassBorder;
        fg = AppColors.statusPassInk;
        icon = Icons.check_circle_outline_rounded;
        break;
      case ProfToastType.error:
        bg = AppColors.statusCriticalBg;
        border = AppColors.statusCriticalBorder;
        fg = AppColors.statusCriticalInk;
        icon = Icons.error_outline_rounded;
        break;
      case ProfToastType.warning:
        bg = AppColors.statusPendingBg;
        border = AppColors.statusPendingBorder;
        fg = AppColors.statusPendingInk;
        icon = Icons.warning_amber_rounded;
        break;
      case ProfToastType.info:
      default:
        bg = AppColors.statusInfoBg;
        border = AppColors.statusInfoBorder;
        fg = AppColors.statusInfoInk;
        icon = Icons.info_outline_rounded;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.r6),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
        action: action,
      ),
    );
  }
}
