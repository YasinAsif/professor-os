import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/theme_provider.dart';

/// Single node in the navigation breadcrumb trail.
class BreadcrumbItem {
  final String label;
  final String? path;
  final IconData? icon;

  const BreadcrumbItem({
    required this.label,
    this.path,
    this.icon,
  });
}

/// Dynamic, interactive breadcrumbs component for ProfessorOS.
/// Renders hierarchical route trails with chevron separators, hover effects,
/// and smooth GoRouter navigation.
class ProfBreadcrumbs extends ConsumerWidget {
  final List<BreadcrumbItem> items;
  final double fontSize;
  final bool showHomeIcon;

  const ProfBreadcrumbs({
    super.key,
    required this.items,
    this.fontSize = 13.5,
    this.showHomeIcon = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return const SizedBox.shrink();

    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;

    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inkGhost = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: fontSize + 2,
                  color: inkGhost,
                ),
              ),
            _BreadcrumbNode(
              item: items[i],
              isLast: i == items.length - 1,
              isFirst: i == 0,
              showHomeIcon: showHomeIcon && i == 0,
              fontSize: fontSize,
              inkPrimary: inkPrimary,
              inkSecondary: inkSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

class _BreadcrumbNode extends StatefulWidget {
  final BreadcrumbItem item;
  final bool isLast;
  final bool isFirst;
  final bool showHomeIcon;
  final double fontSize;
  final Color inkPrimary;
  final Color inkSecondary;

  const _BreadcrumbNode({
    required this.item,
    required this.isLast,
    required this.isFirst,
    required this.showHomeIcon,
    required this.fontSize,
    required this.inkPrimary,
    required this.inkSecondary,
  });

  @override
  State<_BreadcrumbNode> createState() => _BreadcrumbNodeState();
}

class _BreadcrumbNodeState extends State<_BreadcrumbNode> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isClickable = widget.item.path != null && !widget.isLast;

    final textWidget = Text(
      widget.item.label,
      style: GoogleFonts.inter(
        fontSize: widget.fontSize,
        fontWeight: widget.isLast ? FontWeight.w600 : FontWeight.w500,
        color: widget.isLast
            ? widget.inkPrimary
            : (_isHovered ? const Color(0xFF4F46E5) : widget.inkSecondary),
        decoration: (_isHovered && isClickable) ? TextDecoration.underline : TextDecoration.none,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (!isClickable) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.item.icon != null) ...[
            Icon(
              widget.item.icon,
              size: widget.fontSize + 1,
              color: widget.isLast ? widget.inkPrimary : widget.inkSecondary,
            ),
            const SizedBox(width: 5),
          ],
          textWidget,
        ],
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          if (widget.item.path != null) {
            context.go(widget.item.path!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFF4F46E5).withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showHomeIcon && widget.isFirst) ...[
                Icon(
                  widget.item.icon ?? Icons.home_outlined,
                  size: widget.fontSize + 1,
                  color: _isHovered ? const Color(0xFF4F46E5) : widget.inkSecondary,
                ),
                const SizedBox(width: 5),
              ] else if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: widget.fontSize + 1,
                  color: _isHovered ? const Color(0xFF4F46E5) : widget.inkSecondary,
                ),
                const SizedBox(width: 5),
              ],
              textWidget,
            ],
          ),
        ),
      ),
    );
  }
}
