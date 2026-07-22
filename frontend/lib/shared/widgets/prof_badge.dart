/// ProfessorOS – ProfBadge: Coloured pill badge.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool small;

  const ProfBadge({
    super.key,
    required this.label,
    this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? AppColors.primaryIndigo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.w600,
          color: bgColor,
        ),
      ),
    );
  }
}
