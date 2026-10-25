import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import 'prof_button.dart';

class ProfErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ProfErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusCriticalInk.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppColors.statusCriticalInk,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ProfButton(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                variant: ProfButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
