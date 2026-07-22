/// ProfessorOS – HECQualityBadge: W/X/Y/Z badge with appropriate colours.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class HECQualityBadge extends StatelessWidget {
  final String grade;
  final bool large;

  const HECQualityBadge({super.key, required this.grade, this.large = false});

  String get _label {
    switch (grade.toUpperCase()) {
      case 'W': return 'World Class';
      case 'X': return 'Acceptable';
      case 'Y': return 'Needs Improvement';
      case 'Z': return 'Below Standard';
      default: return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.hecGradeColor(grade);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 20 : 12,
        vertical: large ? 10 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: large ? 28 : 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: GoogleFonts.inter(
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
