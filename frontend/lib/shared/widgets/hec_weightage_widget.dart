/// ProfessorOS – HECWeightageWidget: 20/20/20/40 progress bars.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

class HECWeightageWidget extends StatelessWidget {
  final int quiz;
  final int assignment;
  final int midterm;
  final int finalExam;
  final Map<String, int>? customCategories;

  const HECWeightageWidget({
    super.key,
    this.quiz = 20,
    this.assignment = 20,
    this.midterm = 20,
    this.finalExam = 40,
    this.customCategories,
  });

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> items = customCategories != null
        ? customCategories!.entries.toList()
        : [
            MapEntry('Quizzes', quiz),
            MapEntry('Assignments', assignment),
            MapEntry('Midterm', midterm),
            MapEntry('Final Exam', finalExam),
          ];

    final colors = [
      AppColors.primaryIndigo,
      const Color(0xFF8B5CF6),
      AppColors.accentAmber,
      AppColors.successGreen,
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];

    final total = items.fold<int>(0, (sum, e) => sum + e.value);
    final isValid = total == 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final color = colors[idx % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _bar(item.key, item.value, color),
          );
        }),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isValid ? AppColors.successGreen.withOpacity(0.08) : AppColors.dangerRose.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isValid ? AppColors.successGreen.withOpacity(0.3) : AppColors.dangerRose.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 16,
                color: isValid ? AppColors.successGreen : AppColors.dangerRose,
              ),
              const SizedBox(width: 8),
              Text(
                'Total Assessment Weight: $total%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isValid ? AppColors.successGreen : AppColors.dangerRose,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (value.clamp(0, 100)) / 100,
              backgroundColor: AppColors.bgSurface,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '$value%',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
