import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool leadingStripe;

  const ProfCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.leadingStripe = false,
  });

  @override
  State<ProfCard> createState() => _ProfCardState();
}

class _ProfCardState extends State<ProfCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isClickable = widget.onTap != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.surface : AppColorsLight.surface;
    final hoverBg = isDark ? AppColors.surfaceMid : AppColorsLight.surfaceMid;
    final defaultBorder = isDark ? AppColors.rule : AppColorsLight.rule;
    final hoverBorder = isDark ? AppColors.ruleStrong : AppColorsLight.ruleStrong;

    final bgColor = _isHovered && isClickable ? hoverBg : defaultBg;
    final borderColor = _isHovered && isClickable ? hoverBorder : defaultBorder;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
          right: BorderSide(color: borderColor, width: 1),
          bottom: BorderSide(color: borderColor, width: 1),
          left: BorderSide(
            color: widget.leadingStripe ? const Color(0xFF4F46E5) : borderColor,
            width: widget.leadingStripe ? 4 : 1,
          ),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child,
      ),
    );

    if (isClickable) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      );
    }

    return card;
  }
}
