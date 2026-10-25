import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProfLoadingSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const ProfLoadingSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  const ProfLoadingSkeleton.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  const ProfLoadingSkeleton.line({
    super.key,
    this.width = double.infinity,
    this.height = 14,
  })  : borderRadius = null,
        shape = BoxShape.rectangle;

  @override
  State<ProfLoadingSkeleton> createState() => _ProfLoadingSkeletonState();
}

class _ProfLoadingSkeletonState extends State<ProfLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.surfaceMid : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor.withOpacity(_animation.value),
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : (widget.borderRadius ?? BorderRadius.circular(AppRadius.r4)),
          ),
        );
      },
    );
  }
}
