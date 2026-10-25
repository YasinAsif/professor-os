/// ProfessorOS – TA Dashboard Screen (Marginalia Design System).
/// Shows enrolled courses that the TA is assigned to grade, pending workload, and quick launch to SpeedGrader.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
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
  String _queueFilter = 'all';

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
      final courses =
          (coursesRes['courses'] as List<dynamic>).cast<Map<String, dynamic>>();

      final tasks = <Map<String, dynamic>>[];
      int pending = 0;
      int graded = 0;

      for (final course in courses) {
        final courseId = course['id'] as int;
        final assignmentsRes =
            await repo.listAssignments(courseId, status: 'published');
        final assignments = (assignmentsRes['assignments'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        for (final a in assignments) {
          final aid = a['id'] as int;
          try {
            final subsRes = await repo.listSubmissions(courseId, aid);
            final submissions = (subsRes['submissions'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
            final reviewCount = submissions
                .where((submission) => submission['needs_review'] == true)
                .length;
            final promptCount = submissions.where((submission) {
              final reasons = submission['triage_reasons'];
              return reasons is List && reasons.contains('injection_detected');
            }).length;
            final unreadableCount = submissions.where((submission) {
              final reasons = submission['triage_reasons'];
              return reasons is List &&
                  reasons.any((reason) =>
                      reason == 'blank_or_unreadable' ||
                      reason == 'scanned_or_image_only');
            }).length;
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
                'review_count': reviewCount,
                'prompt_count': promptCount,
                'unreadable_count': unreadableCount,
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
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final coursesAsync = ref.watch(courseListProvider);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: const ProfBreadcrumbs(
          items: [
            BreadcrumbItem(label: 'Home', path: '/ta-dashboard'),
            BreadcrumbItem(label: 'Grading Queue'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.inkSecondary),
            tooltip: 'Refresh Workload',
            onPressed: _loadWorkload,
          ),
        ],
      ),
      body: coursesAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(24),
          children: List.generate(
              3,
              (_) => Padding(
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
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.feedbackRed),
                const SizedBox(height: 12),
                Text('Failed to load workload',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkPrimary)),
                const SizedBox(height: 6),
                Text(ErrorParser.parse(err),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.feedbackRed)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadWorkload,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
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
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: AppColors.inkSecondary)),
                          const SizedBox(height: 4),
                          Text(user?['full_name'] ?? 'Assistant',
                              style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkPrimary)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.pending.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TEACHING ASSISTANT',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.pending,
                                  letterSpacing: 0.5),
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
                      child: const Icon(Icons.grading_rounded,
                          color: AppColors.signal, size: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final filter in const [
                    ('all', 'All'),
                    ('needs_review', 'Needs Review'),
                    ('prompt_injection', 'Prompt Injection'),
                    ('unreadable', 'Unreadable / Scanned'),
                    ('ungraded', 'Ungraded'),
                  ])
                    ChoiceChip(
                      label: Text(filter.$2),
                      selected: _queueFilter == filter.$1,
                      onSelected: (_) =>
                          setState(() => _queueFilter = filter.$1),
                    ),
                  OutlinedButton.icon(
                    onPressed: _filteredTasks.isEmpty
                        ? null
                        : () {
                            final task = _filteredTasks.first;
                            context.go(
                                '/courses/${task['course_id']}/assignments/${task['assignment_id']}');
                          },
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Next Matching'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Live KPI Metrics
              Text('Your Workload',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkPrimary)),
              const SizedBox(height: 16),
              _loadingWorkload
                  ? ProfShimmer.card(height: 80)
                  : Row(
                      children: [
                        _kpiMetric('Pending', _totalPending.toString(),
                            Icons.inbox_rounded, AppColors.pending),
                        const SizedBox(width: 12),
                        _kpiMetric('Graded', _totalGraded.toString(),
                            Icons.task_alt_rounded, AppColors.verified),
                        const SizedBox(width: 12),
                        _kpiMetric(
                            'Assignments',
                            _gradingTasks.length.toString(),
                            Icons.assignment_rounded,
                            AppColors.signal),
                      ],
                    ),
              const SizedBox(height: 32),

              // Needs Grading Queue
              Text('Needs Grading',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkPrimary)),
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
              else if (_filteredTasks.isEmpty)
                const ProfEmptyState(
                  icon: Icons.filter_alt_off_rounded,
                  title: 'No matching queue items',
                  subtitle: 'Try another triage filter.',
                  actionLabel: null,
                )
              else
                ..._filteredTasks.map((task) => Padding(
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

  List<Map<String, dynamic>> get _filteredTasks {
    return _gradingTasks.where((task) {
      switch (_queueFilter) {
        case 'needs_review':
          return (task['review_count'] as int? ?? 0) > 0;
        case 'prompt_injection':
          return (task['prompt_count'] as int? ?? 0) > 0;
        case 'unreadable':
          return (task['unreadable_count'] as int? ?? 0) > 0;
        case 'ungraded':
          return (task['pending_count'] as int? ?? 0) > 0;
        default:
          return true;
      }
    }).toList();
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
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkPrimary)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.inkSecondary)),
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
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.pending),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assignmentName,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkPrimary)),
                    const SizedBox(height: 4),
                    Text(courseName,
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.inkSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('SpeedGrader →',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.signal)),
                  const SizedBox(height: 4),
                  Text('$pendingCount pending',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.pending)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
