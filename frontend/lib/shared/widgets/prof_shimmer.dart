/// ProfessorOS – ProfShimmer: Skeleton loader with teal tint.

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class ProfShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ProfShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.bgElevated,
      highlightColor: AppColors.primarySoft.withOpacity(0.5),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Convenience: card-shaped shimmer.
  static Widget card({double height = 120}) {
    return ProfShimmer(height: height, borderRadius: 20);
  }

  /// Convenience: multiple lines shimmer.
  static Widget lines({int count = 3}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ProfShimmer(
            width: i == count - 1 ? 200 : double.infinity,
            height: 14,
          ),
        ),
      ),
    );
  }
}
