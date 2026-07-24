/// ProfessorOS – TA Dashboard Screen (Marginalia Design System).
/// Shows enrolled courses that the TA is assigned to grade, pending workload, and quick launch to SpeedGrader.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/course_providers.dart';

class TADashboardScreen extends ConsumerWidget {
  const TADashboardScreen({super.key});

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
            Text('TA Dashboard',
                style: GoogleFonts.fraunces(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.01, color: AppColors.inkPrimary)),
            Text('Manage your grading workload',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkSecondary, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: coursesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(24),
          children: List.generate(3, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ProfShimmer.card(height: 120),
          )),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.feedbackRed),
                const SizedBox(height: 12),
                Text('Failed to load workload', style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
                const SizedBox(height: 6),
                Text(err.toString(), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.feedbackRed)),
              ],
            ),
          ),
        ),
        data: (data) {
          final allCourses = (data['courses'] as List<dynamic>).cast<Map<String, dynamic>>();
          
          if (allCourses.isEmpty) {
            return const ProfEmptyState(
              icon: Icons.grading_rounded,
              title: 'No grading assigned',
              subtitle: 'You are not assigned to any courses as a Teaching Assistant yet.',
              actionLabel: null,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Welcome header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.marginRule),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome back,',
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.inkSecondary)),
                          const SizedBox(height: 4),
                          Text(user?['full_name'] ?? 'Assistant',
                              style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.pending.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TEACHING ASSISTANT',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.pending, letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.bgMargin,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.marginRule),
                      ),
                      child: const Icon(Icons.grading_rounded, color: AppColors.signal, size: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // KPI Metrics
              Text('Your Workload',
                  style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _kpiMetric('Pending', '24', Icons.inbox_rounded, AppColors.pending),
                  const SizedBox(width: 12),
                  _kpiMetric('Graded', '142', Icons.task_alt_rounded, AppColors.verified),
                  const SizedBox(width: 12),
                  _kpiMetric('Turnaround', '1.2d', Icons.timer_rounded, AppColors.signal),
                ],
              ),
              const SizedBox(height: 32),

              // Needs Grading Queue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Needs Grading',
                      style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Mocked pending assignments for grading
              _buildGradingTask(
                context: context,
                courseName: 'CS301 - Data Structures',
                assignmentName: 'Midterm Project: B-Trees',
                pendingCount: 14,
                dueDate: 'Due 2 days ago',
                isOverdue: true,
              ),
              const SizedBox(height: 12),
              _buildGradingTask(
                context: context,
                courseName: 'SE402 - Software Architecture',
                assignmentName: 'Microservices Architecture Doc',
                pendingCount: 10,
                dueDate: 'Due yesterday',
                isOverdue: true,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiMetric(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.marginRule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildGradingTask({
    required BuildContext context,
    required String courseName,
    required String assignmentName,
    required int pendingCount,
    required String dueDate,
    required bool isOverdue,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('SpeedGrader will launch here in a future update.'),
          ));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.marginRule),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.pending.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    pendingCount.toString(),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.pending),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assignmentName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
                    const SizedBox(height: 4),
                    Text(courseName, style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('SpeedGrader', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.signal)),
                  const SizedBox(height: 4),
                  Text(dueDate, style: GoogleFonts.inter(fontSize: 11, color: isOverdue ? AppColors.feedbackRed : AppColors.inkSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
