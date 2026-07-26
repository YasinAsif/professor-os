import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/prof_badge.dart';
import '../../../../shared/widgets/prof_card.dart';

class UpcomingDeadlinesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const UpcomingDeadlinesWidget({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ProfCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.task_alt_outlined, color: AppColors.successGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Upcoming Deadlines',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'You are all caught up on your course assignments!',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Upcoming Deadlines',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            ProfBadge(
              label: '${items.length} Due Soon',
              color: AppColors.accentAmber,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final courseId = item['course_id'] as int? ?? 1;
          final assignmentId = item['assignment_id'] as int? ?? 1;
          final title = item['title'] as String? ?? 'Assignment';
          final courseCode = item['course_code'] as String? ?? 'CS-101';
          final dueDateStr = item['due_date_label'] as String? ?? 'Due Soon';
          final isUrgent = item['is_urgent'] as bool? ?? false;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go('/courses/$courseId/assignments/$assignmentId'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUrgent ? AppColors.feedbackRed.withAlpha(80) : AppColors.border,
                      width: isUrgent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isUrgent ? AppColors.feedbackRed : AppColors.signal).withAlpha(18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isUrgent ? Icons.error_outline : Icons.alarm,
                          color: isUrgent ? AppColors.feedbackRed : AppColors.signal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              courseCode,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ProfBadge(
                        label: dueDateStr,
                        color: isUrgent ? AppColors.feedbackRed : AppColors.pending,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
