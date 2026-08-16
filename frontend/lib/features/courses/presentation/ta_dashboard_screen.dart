/// ProfessorOS – TA Dashboard Screen (Marginalia Design System).
/// Shows enrolled courses that the TA is assigned to grade, pending workload, and quick launch to SpeedGrader.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class TADashboardScreen extends ConsumerStatefulWidget {
  const TADashboardScreen({super.key});

  @override
  ConsumerState<TADashboardScreen> createState() => _TADashboardScreenState();
}

class _TADashboardScreenState extends ConsumerState<TADashboardScreen> {
  // Live workload items: {courseId, courseCode, assignmentId, assignmentTitle, pendingCount, dueDate}
  List<Map<String, dynamic>> _gradingTasks = [];
  int _totalPending = 0;
  int _totalGraded = 0;
  bool _loadingWorkload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWorkload());
  }

  Future<void> _loadWorkload() async {
    setState(() => _loadingWorkload = true);
    try {
      final repo = CourseRepository();
      final coursesRes = await repo.listCourses();
      final courses = (coursesRes['courses'] as List<dynamic>).cast<Map<String, dynamic>>();

      final tasks = <Map<String, dynamic>>[];
      int pending = 0;
      int graded = 0;

      for (final course in courses) {
        final courseId = course['id'] as int;
        final assignmentsRes = await repo.listAssignments(courseId, status: 'published');
        final assignments = (assignmentsRes['assignments'] as List<dynamic>).cast<Map<String, dynamic>>();

        for (final a in assignments) {
          final aid = a['id'] as int;
          try {
            final subsRes = await repo.listSubmissions(courseId, aid);
            final p = subsRes['pending_count'] as int? ?? 0;
            final g = subsRes['graded_count'] as int? ?? 0;
            pending += p;
            graded += g;
            if (p > 0) {
              tasks.add({
                'course_id': courseId,
                'course_name': '${course['code']} – ${course['title']}',
                'assignment_id': aid,
                'assignment_title': a['title'],
                'pending_count': p,
                'deadline': a['deadline'],
              });
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _gradingTasks = tasks;
          _totalPending = pending;
          _totalGraded = graded;
          _loadingWorkload = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingWorkload = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.inkSecondary),
            tooltip: 'Refresh Workload',
            onPressed: _loadWorkload,
          ),
        ],
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
                Text(ErrorParser.parse(err), textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.feedbackRed)),
              ],
            ),
          ),
        ),
        data: (data) {
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

              // Live KPI Metrics
              Text('Your Workload',
                  style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
              const SizedBox(height: 16),
              _loadingWorkload
                  ? ProfShimmer.card(height: 80)
                  : Row(
                      children: [
                        _kpiMetric('Pending', _totalPending.toString(), Icons.inbox_rounded, AppColors.pending),
                        const SizedBox(width: 12),
                        _kpiMetric('Graded', _totalGraded.toString(), Icons.task_alt_rounded, AppColors.verified),
                        const SizedBox(width: 12),
                        _kpiMetric('Assignments', _gradingTasks.length.toString(), Icons.assignment_rounded, AppColors.signal),
                      ],
                    ),
              const SizedBox(height: 32),

              // Needs Grading Queue
              Text('Needs Grading',
                  style: GoogleFonts.fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
              const SizedBox(height: 8),

              if (_loadingWorkload)
                ProfShimmer.lines(count: 3)
              else if (_gradingTasks.isEmpty)
                const ProfEmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'All caught up!',
                  subtitle: 'No pending submissions to grade right now.',
                  actionLabel: null,
                )
              else
                ..._gradingTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildGradingTask(
                    context: context,
                    courseId: task['course_id'] as int,
                    assignmentId: task['assignment_id'] as int,
                    courseName: task['course_name'] as String,
                    assignmentName: task['assignment_title'] as String,
                    pendingCount: task['pending_count'] as int,
                  ),
                )),
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
    required int courseId,
    required int assignmentId,
    required String courseName,
    required String assignmentName,
    required int pendingCount,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/courses/$courseId/assignments/$assignmentId'),
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
                  Text('SpeedGrader →', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.signal)),
                  const SizedBox(height: 4),
                  Text('$pendingCount pending', style: GoogleFonts.inter(fontSize: 11, color: AppColors.pending)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


