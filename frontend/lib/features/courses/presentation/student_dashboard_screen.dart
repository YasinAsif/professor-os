/// ProfessorOS – Student Dashboard Screen.
/// Shows enrolled courses, upcoming deadlines, and recent grades.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/course_providers.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseListProvider);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student Dashboard',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            Text('Your enrolled courses and progress',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: coursesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(24),
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProfShimmer.card(height: 160),
          )),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.dangerRose),
                const SizedBox(height: 12),
                Text('Failed to load courses', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(err.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.dangerRose)),
              ],
            ),
          ),
        ),
        data: (data) {
          final allCourses = (data['courses'] as List<dynamic>).cast<Map<String, dynamic>>();
          
          if (allCourses.isEmpty) {
            return ProfEmptyState(
              icon: Icons.school_rounded,
              title: 'Not enrolled in any courses',
              subtitle: 'Your professor will enroll you shortly. Contact them if you believe this is an error.',
              actionLabel: null,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [const BoxShadow(color: Color(0x304F46E5), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,',
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 4),
                          Text(user?['full_name'] ?? 'Student',
                              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                          const SizedBox(height: 6),
                          Text('${allCourses.length} active enrollment(s)',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                        ],
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats
              Row(
                children: [
                  _quickStatCard('Enrolled', '${allCourses.length}', Icons.menu_book_rounded, AppColors.primaryIndigo),
                  const SizedBox(width: 12),
                  _quickStatCard('Pending', '--', Icons.pending_actions_rounded, AppColors.accentAmber),
                  const SizedBox(width: 12),
                  _quickStatCard('Graded', '--', Icons.grading_rounded, AppColors.successGreen),
                ],
              ),
              const SizedBox(height: 24),

              // My Courses Section
              Text('My Courses',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),

              ...allCourses.map((course) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go('/courses/${course['id']}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryIndigo.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.menu_book_rounded, color: AppColors.primaryIndigo, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(course['title'],
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text('${course['code']} • ${course['semester']}',
                                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('${course['assignment_count'] ?? 0} asg',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _quickStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
