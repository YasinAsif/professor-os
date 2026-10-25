/// ProfessorOS – Student Dashboard Screen.
/// Shows enrolled courses, live upcoming deadlines, recent feedback, and real metrics.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/course_providers.dart';
import '../data/course_repository.dart';
import '../../../core/utils/error_parser.dart';
import 'widgets/upcoming_deadlines_widget.dart';
import 'widgets/recent_feedback_widget.dart';
import 'course_detail_screen.dart';

final studentActionFilterProvider = StateProvider<String>((ref) => 'all');

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final coursesAsync = ref.watch(studentDashboardProvider);
    final user = ref.watch(authProvider).valueOrNull;

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: const ProfBreadcrumbs(
          items: [
            BreadcrumbItem(label: 'Home', path: '/dashboard'),
            BreadcrumbItem(label: 'Student Terminal'),
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showJoinDialog(context, ref),
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: Text(
                'Join Course',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.r6)),
              ),
            ),
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
                    child: ProfShimmer.card(height: 160),
                  )),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: AppColors.statusCritical),
                const SizedBox(height: 12),
                Text('Failed to load courses',
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(ErrorParser.parse(err),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.statusCriticalInk)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(studentDashboardProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final allCourses =
              (data['courses'] as List<dynamic>).cast<Map<String, dynamic>>();
          final stats = (data['stats'] as Map<String, dynamic>?) ?? {};
          final upcoming = ((data['upcoming'] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>()
              .map((item) {
            final deadline =
                DateTime.tryParse(item['deadline']?.toString() ?? '');
            final hours = deadline == null
                ? 9999
                : deadline.difference(DateTime.now()).inHours;
            return <String, dynamic>{
              ...item,
              'due_date_label':
                  deadline == null ? 'Due soon' : _formatDeadline(deadline),
              'is_urgent': hours <= 48,
            };
          }).toList();
          final feedback = ((data['feedback'] as List<dynamic>?) ?? [])
              .cast<Map<String, dynamic>>()
              .map((item) => <String, dynamic>{
                    ...item,
                    'comment': item['feedback'] ?? '',
                    'date_label': _formatDate(item['graded_at']),
                  })
              .toList();
          final actionFilter = ref.watch(studentActionFilterProvider);
          final actionItems = upcoming.where((item) {
            final needsSubmission = item['submitted'] != true;
            final flagged = item['needs_review'] == true;
            final dueSoon =
                (DateTime.tryParse(item['deadline']?.toString() ?? '')
                            ?.difference(DateTime.now())
                            .inDays ??
                        99) <=
                    7;
            switch (actionFilter) {
              case 'due_soon':
                return dueSoon;
              case 'needs_submission':
                return needsSubmission;
              case 'feedback_ready':
                return false;
              case 'flagged':
                return flagged;
              default:
                return true;
            }
          }).toList();

          if (allCourses.isEmpty) {
            return ProfEmptyState(
              icon: Icons.school_rounded,
              title: 'Not enrolled in any courses',
              subtitle:
                  'Your professor will enroll you shortly. Contact them if you believe this is an error.',
              actionLabel: null,
            );
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Editorial Masthead Welcome Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                  border: Border.all(
                      color: isDark ? AppColorsDark.ruleStrong : const Color(0xFFE2E8F0),
                      width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STUDENT DOSSIER',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: isDark ? AppColorsDark.inkSecondary : const Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?['full_name'] ?? 'Student',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColorsDark.canvas : const Color(0xFFF1F5F9),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.r4),
                                  border: Border.all(
                                      color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0), width: 1),
                                ),
                                child: Text(
                                  '${allCourses.length} ACTIVE ENROLLMENTS',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isDark ? AppColorsDark.canvas : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppRadius.r6),
                        border:
                            Border.all(color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Icon(Icons.school_outlined,
                          color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A), size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats (Live calculations)
              Row(
                children: [
                  _quickStatCard('Enrolled', '${allCourses.length}',
                      Icons.menu_book_rounded, AppColors.primary, surfaceColor, isDark),
                  const SizedBox(width: 12),
                  _quickStatCard('Pending', '${stats['pending'] ?? 0}',
                      Icons.pending_actions_rounded, AppColors.accentAmber, surfaceColor, isDark),
                  const SizedBox(width: 12),
                  _quickStatCard('Graded', '${stats['graded'] ?? 0}',
                      Icons.grading_rounded, AppColors.statusPass, surfaceColor, isDark),
                ],
              ),
              const SizedBox(height: 24),

              // Upcoming Deadlines Section
              UpcomingDeadlinesWidget(items: upcoming),
              const SizedBox(height: 24),

              Text('Action Queue',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkPrimary)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in const [
                      ('all', 'All'),
                      ('due_soon', 'Due Soon'),
                      ('needs_submission', 'Needs Submission'),
                      ('feedback_ready', 'Graded / Feedback Ready'),
                      ('flagged', 'Flagged / Needs Resubmission'),
                    ]) ...[
                      ChoiceChip(
                        label: Text(filter.$2),
                        selected: actionFilter == filter.$1,
                        onSelected: (_) => ref
                            .read(studentActionFilterProvider.notifier)
                            .state = filter.$1,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (actionFilter == 'feedback_ready')
                Text('${feedback.length} feedback item(s) ready to review.',
                    style: GoogleFonts.inter(color: AppColors.inkSecondary))
              else if (actionItems.isEmpty)
                Text('Nothing needs your attention in this view.',
                    style: GoogleFonts.inter(color: AppColors.inkSecondary))
              else
                ...actionItems.take(5).map((item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item['needs_review'] == true
                            ? Icons.warning_amber_rounded
                            : Icons.assignment_outlined,
                        color: item['needs_review'] == true
                            ? AppColors.accentAmber
                            : AppColors.signal,
                      ),
                      title: Text(item['title']?.toString() ?? 'Assignment'),
                      subtitle: Text(item['needs_review'] == true
                          ? 'Flagged for review: ${((item['triage_reasons'] as List?) ?? []).join(', ')}'
                          : item['submitted'] == true
                              ? 'Submitted • ${item['due_date_label']}'
                              : 'Needs submission • ${item['due_date_label']}'),
                    )),
              const SizedBox(height: 24),

              // Recent Feedback Section
              RecentFeedbackWidget(feedbackItems: feedback),
              const SizedBox(height: 24),

              // My Courses Section
              Text(
                'Enrolled Courses',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.inkPrimary,
                ),
              ),
              const SizedBox(height: 12),

              ...allCourses.map((course) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.go('/courses/${course['id']}'),
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                            border: Border.all(
                                color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColorsDark.canvas : const Color(0xFFF1F5F9),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.r6),
                                  border: Border.all(
                                      color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0), width: 1),
                                ),
                                child: Icon(Icons.menu_book_outlined,
                                    color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A), size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course['title'],
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${course['code']} • ${course['semester']}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: isDark ? AppColorsDark.inkSecondary : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColorsDark.canvas : const Color(0xFFF1F5F9),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.r4),
                                  border: Border.all(
                                      color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0), width: 1),
                                ),
                                child: Text(
                                  '${course['assignment_count'] ?? 0} ASG',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Ask Course AI Assistant',
                                icon: const Icon(Icons.auto_awesome, color: AppColors.signal, size: 20),
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    barrierDismissible: true,
                                    builder: (dialogContext) => CourseAiChatDialog(
                                      courseId: course['id'] as int,
                                      courseTitle: course['title'] as String? ?? 'Course',
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded,
                                  color: isDark ? AppColorsDark.inkGhost : const Color(0xFF64748B)),
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

  Future<void> _showJoinDialog(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Join Course',
            style:
                GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the 6-character course code provided by your instructor.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w600, letterSpacing: 2),
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g. A9B8C7',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(color: AppColors.inkSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.inkPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.r6)),
              ),
              onPressed: loading
                  ? null
                  : () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (code.isEmpty) return;
                      setState(() => loading = true);
                      try {
                        await CourseRepository().joinCourse(code);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ref.invalidate(courseListProvider);
                          ref.invalidate(studentDashboardProvider);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('Successfully enrolled into course!'),
                            backgroundColor: AppColors.statusPass,
                          ));
                        }
                      } catch (e) {
                        setState(() => loading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ErrorParser.parse(e)),
                          backgroundColor: AppColors.statusCritical,
                        ));
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('Join',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime date) {
    final difference = date.difference(DateTime.now());
    if (difference.inHours < 24) return 'Due today';
    if (difference.inDays == 1) return 'Due tomorrow';
    return 'Due in ${difference.inDays} days';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Recently';
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  Widget _quickStatCard(
      String label, String value, IconData icon, Color color, Color surfaceColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.r6),
          border: Border.all(
              color: isDark ? AppColorsDark.rule : const Color(0xFFE2E8F0),
              width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 2,
              width: 24,
              color: color,
              margin: const EdgeInsets.only(bottom: 12),
            ),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: isDark ? AppColorsDark.inkSecondary : const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColorsDark.inkPrimary : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
