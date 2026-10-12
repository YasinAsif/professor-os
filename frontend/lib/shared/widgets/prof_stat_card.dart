import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfStatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final bool deltaPositive;
  final Color? accentColor;

  const ProfStatCard({
    super.key,
    required this.value,
    required this.label,
    this.delta,
    this.deltaPositive = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topBorderColor = accentColor ?? (isDark ? AppColors.ruleStrong : AppColorsLight.ruleStrong);
    final bgColor = isDark ? AppColors.surface : AppColorsLight.surface;
    final borderColor = isDark ? AppColors.rule : AppColorsLight.rule;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Semantic top border
          Container(
            height: 2,
            width: 32,
            color: topBorderColor,
            margin: const EdgeInsets.only(bottom: 16),
          ),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: deltaPositive
                      ? AppColors.verified
                      : AppColors.feedbackRed,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
