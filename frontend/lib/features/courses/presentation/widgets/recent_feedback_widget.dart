import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/prof_badge.dart';
import '../../../../shared/widgets/prof_card.dart';

class RecentFeedbackWidget extends StatelessWidget {
  final List<Map<String, dynamic>> feedbackItems;

  const RecentFeedbackWidget({super.key, required this.feedbackItems});

  @override
  Widget build(BuildContext context) {
    if (feedbackItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Instructor Feedback',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...feedbackItems.map((fb) {
          final courseId = fb['course_id'] as int? ?? 1;
          final assignmentId = fb['assignment_id'] as int? ?? 1;
          final title = fb['assignment_title'] as String? ?? 'Assignment';
          final courseCode = fb['course_code'] as String? ?? 'CS-101';
          final score = fb['score']?.toString() ?? '100';
          final comment = fb['comment'] as String? ?? 'Good job!';
          final dateStr = fb['date_label'] as String? ?? 'Recently';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ProfCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.verified.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rate_review_outlined, color: AppColors.verified, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$courseCode • Graded $dateStr',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ProfBadge(
                        label: '$score pts',
                        color: AppColors.signal,
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bgMargin,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.marginRule),
                      ),
                      child: Text(
                        '"$comment"',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: AppColors.inkPrimary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => context.go('/courses/$courseId/assignments/$assignmentId'),
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: Text('View Details', style: GoogleFonts.inter(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
