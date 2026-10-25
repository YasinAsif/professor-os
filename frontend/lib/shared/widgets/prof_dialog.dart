import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class ProfDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget content;
  final List<Widget>? actions;
  final double maxWidth;

  const ProfDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.content,
    this.actions,
    this.maxWidth = 520,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    required Widget content,
    List<Widget>? actions,
    double maxWidth = 520,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => ProfDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.surface : AppColorsLight.surface;
    final ruleColor = isDark ? AppColors.rule : AppColorsLight.rule;
    final titleColor = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final subtitleColor = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    return Dialog(
      backgroundColor: bgColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        side: BorderSide(color: ruleColor, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (iconColor ?? const Color(0xFF4F46E5)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: iconColor ?? const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: content)),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      actions![i],
                      if (i < actions!.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
