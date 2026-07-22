/// ProfessorOS – ProfCard: White card with soft shadow and 20px radius.

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool leadingStripe;

  const ProfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.leadingStripe = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            if (leadingStripe)
              Container(width: 4, color: AppColors.primaryTeal),
            Expanded(child: Padding(padding: padding, child: child)),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
      );
    }
    return card;
  }
}
