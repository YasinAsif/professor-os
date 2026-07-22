/// ProfessorOS – ProfStatCard: Large number with label and optional delta.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfStatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final bool deltaPositive;
  final IconData? icon;

  const ProfStatCard({
    super.key,
    required this.value,
    required this.label,
    this.delta,
    this.deltaPositive = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryTeal, size: 20),
            ),
          if (icon != null) const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: deltaPositive ? AppColors.successGreen : AppColors.dangerRose,
                ),
                const SizedBox(width: 4),
                Text(
                  delta!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: deltaPositive ? AppColors.successGreen : AppColors.dangerRose,
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
