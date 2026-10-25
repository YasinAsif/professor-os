import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

enum ProfButtonVariant {
  primary,
  cta,
  secondary,
  outline,
  danger,
  ghost,
}

enum ProfButtonSize {
  sm,
  md,
  lg,
}

class ProfButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final ProfButtonVariant variant;
  final ProfButtonSize size;
  final bool isLoading;
  final bool isExpanded;
  final String? tooltip;
  final BorderRadius? borderRadius;

  const ProfButton({
    super.key,
    this.label,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.variant = ProfButtonVariant.primary,
    this.size = ProfButtonSize.md,
    this.isLoading = false,
    this.isExpanded = false,
    this.tooltip,
    this.borderRadius,
  });

  @override
  State<ProfButton> createState() => _ProfButtonState();
}

class _ProfButtonState extends State<ProfButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    // Size dimensions
    final double height;
    final double fontSize;
    final double iconSize;
    final EdgeInsets padding;

    switch (widget.size) {
      case ProfButtonSize.sm:
        height = 32.0;
        fontSize = 12.0;
        iconSize = 14.0;
        padding = const EdgeInsets.symmetric(horizontal: 10.0);
        break;
      case ProfButtonSize.lg:
        height = 48.0;
        fontSize = 15.0;
        iconSize = 18.0;
        padding = const EdgeInsets.symmetric(horizontal: 20.0);
        break;
      case ProfButtonSize.md:
      default:
        height = 40.0;
        fontSize = 13.0;
        iconSize = 16.0;
        padding = const EdgeInsets.symmetric(horizontal: 16.0);
        break;
    }

    // Color resolution
    Color bgColor;
    Color fgColor;
    Border? border;

    switch (widget.variant) {
      case ProfButtonVariant.cta:
        bgColor = _isHovered ? AppColors.ctaHover : AppColors.cta;
        fgColor = Colors.white;
        break;
      case ProfButtonVariant.secondary:
        bgColor = isDark
            ? (_isHovered ? AppColors.surfaceHigh : AppColors.surfaceMid)
            : (_isHovered ? AppColorsLight.surfaceHigh : AppColorsLight.surfaceMid);
        fgColor = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
        border = Border.all(
          color: isDark ? AppColors.rule : AppColorsLight.rule,
          width: 1,
        );
        break;
      case ProfButtonVariant.outline:
        bgColor = _isHovered
            ? (isDark ? AppColors.surfaceMid.withOpacity(0.5) : AppColorsLight.surfaceMid)
            : Colors.transparent;
        fgColor = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
        border = Border.all(
          color: isDark ? AppColors.ruleStrong : AppColorsLight.ruleStrong,
          width: 1,
        );
        break;
      case ProfButtonVariant.danger:
        bgColor = _isHovered ? const Color(0xFFB91C1C) : const Color(0xFFDC2626);
        fgColor = Colors.white;
        break;
      case ProfButtonVariant.ghost:
        bgColor = _isHovered
            ? (isDark ? AppColors.surfaceMid.withOpacity(0.4) : AppColorsLight.surfaceMid)
            : Colors.transparent;
        fgColor = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;
        break;
      case ProfButtonVariant.primary:
      default:
        bgColor = _isHovered ? const Color(0xFF4338CA) : const Color(0xFF4F46E5);
        fgColor = Colors.white;
        break;
    }

    if (!isEnabled) {
      bgColor = isDark ? AppColors.surfaceMid.withOpacity(0.4) : const Color(0xFFE2E8F0);
      fgColor = isDark ? AppColors.inkGhost : const Color(0xFF94A3B8);
      border = null;
    }

    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.r4);

    Widget content = Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fgColor),
            ),
          ),
          if (widget.label != null) const SizedBox(width: 8),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: iconSize, color: fgColor),
          if (widget.label != null) const SizedBox(width: 8),
        ],
        if (widget.label != null)
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fgColor,
              letterSpacing: 0.1,
            ),
          ),
        if (widget.trailingIcon != null && !widget.isLoading) ...[
          const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: iconSize, color: fgColor),
        ],
      ],
    );

    Widget button = MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isEnabled && mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: isEnabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: radius,
            border: border,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    if (widget.isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}
