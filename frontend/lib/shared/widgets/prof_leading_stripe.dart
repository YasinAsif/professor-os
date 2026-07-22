/// ProfessorOS – ProfLeadingStripe: 4px teal vertical bar.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfLeadingStripe extends StatelessWidget {
  final double height;
  final Color color;

  const ProfLeadingStripe({
    super.key,
    this.height = double.infinity,
    this.color = AppColors.primaryTeal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
