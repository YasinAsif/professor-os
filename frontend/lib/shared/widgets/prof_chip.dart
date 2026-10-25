import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final String? count;
  final Color? activeColor;

  const ProfChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onSelected,
    this.icon,
    this.count,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = activeColor ?? const Color(0xFF4F46E5);

    final bgColor = isSelected
        ? primary.withOpacity(isDark ? 0.2 : 0.12)
        : (isDark ? AppColors.surface : AppColorsLight.surface);
    final borderColor = isSelected
        ? primary
        : (isDark ? AppColors.rule : AppColorsLight.rule);
    final textColor = isSelected
        ? primary
        : (isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary);

    return InkWell(
      onTap: onSelected != null ? () => onSelected!(!isSelected) : null,
      borderRadius: BorderRadius.circular(AppRadius.r6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.r6),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (count != null && count!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withOpacity(0.2)
                      : (isDark ? AppColors.surfaceMid : AppColorsLight.surfaceMid),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count!,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
