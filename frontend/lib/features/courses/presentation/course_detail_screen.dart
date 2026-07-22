import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../../shared/widgets/hec_weightage_widget.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final role =
        ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin';

    if (!isProf && _tabCtrl.length == 3) {
      _tabCtrl.dispose();
      _tabCtrl = TabController(length: 2, vsync: this);
    }

    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: courseAsync.when(
          data: (c) => Row(
            children: [
              ProfBadge(label: c['code'], color: AppColors.primaryIndigo),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(c['title'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700, fontSize: 18))),
            ],
          ),
          loading: () => const ProfShimmer(width: 120, height: 20),
          error: (_, __) => const Text('Course Details'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.insights_rounded, size: 16),
              label: isNarrow
                  ? const SizedBox.shrink()
                  : const Text('Cohort Analytics'),
              onPressed: () =>
                  context.go('/courses/${widget.courseId}/analytics'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                side: const BorderSide(color: AppColors.primaryIndigo),
              ),
            ),
          ),
          if (isProf)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Course Settings',
                onPressed: () => context.go('/courses/${widget.courseId}/edit'),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: AppColors.primaryIndigo,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primaryIndigo,
          indicatorWeight: 3,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            const Tab(text: 'Assignments'),
            const Tab(text: 'Students Roster'),
            if (isProf) const Tab(text: 'Course Settings'),
          ],
        ),
      ),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: AppColors.dangerRose))),
        data: (course) => TabBarView(
          controller: _tabCtrl,
          children: [
            _AssignmentsTab(courseId: widget.courseId, isProf: isProf),
            _StudentsTab(courseId: widget.courseId, isProf: isProf),
            if (isProf) _SettingsTab(course: course),
          ],
        ),
      ),
      floatingActionButton: isProf
          ? Container(
              decoration: BoxDecoration(
                gradient: AppGradients.primaryButton,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  const BoxShadow(
                      color: Color(0x404F46E5),
                      blurRadius: 16,
                      offset: Offset(0, 6))
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () =>
                    context.go('/courses/${widget.courseId}/assignments/new'),
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text('New Assignment',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            )
          : null,
    );
  }
}

class _AssignmentsTab extends ConsumerWidget {
  final int courseId;
  final bool isProf;
  const _AssignmentsTab({required this.courseId, required this.isProf});

  IconData _getAssignmentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'qna':
        return Icons.quiz_rounded;
      case 'file':
        return Icons.cloud_upload_rounded;
      case 'mcq':
        return Icons.check_circle_outline_rounded;
      case 'programming':
        return Icons.terminal_rounded;
      case 'hybrid':
        return Icons.hub_rounded;
      default:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(assignmentListProvider(courseId));
    return assignmentsAsync.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (_, __) => ProfShimmer.card(height: 100),
      ),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (data) {
        final assignments = data['assignments'] as List<dynamic>;
        if (assignments.isEmpty) {
          return ProfEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No assignments created yet.',
            subtitle: isProf
                ? 'Create an assignment with HEC rubric to start collecting submissions.'
                : 'Check back when your professor posts an assignment.',
            actionLabel: isProf ? 'Create First Assignment' : null,
            onAction: isProf
                ? () => context.go('/courses/$courseId/assignments/new')
                : null,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final a = assignments[index] as Map<String, dynamic>;
            final status = (a['status'] as String? ?? 'draft').toLowerCase();
            final statusColor = status == 'published'
                ? AppColors.successGreen
                : (status == 'closed'
                    ? AppColors.textMuted
                    : AppColors.accentAmber);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    context.go('/courses/$courseId/assignments/${a['id']}'),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(18),
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
                        child: Icon(_getAssignmentIcon(a['type'] ?? 'text'),
                            color: AppColors.primaryIndigo, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a['title'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text('Max Marks: ${a['max_marks']} pts',
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textMuted)),
                                const SizedBox(width: 8),
                                Text('•',
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
                                const SizedBox(width: 8),
                                Text(a['type'].toString().toUpperCase(),
                                    style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryIndigo)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ProfBadge(
                          label: status.toUpperCase(),
                          color: statusColor,
                          small: true),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StudentsTab extends ConsumerStatefulWidget {
  final int courseId;
  final bool isProf;
  const _StudentsTab({required this.courseId, required this.isProf});

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _enrollDialog() async {
    final uidCtrl = TextEditingController();
    String role = 'student';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enroll Student or TA',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: uidCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'User ID', hintText: 'e.g. 5'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(
                      value: 'ta', child: Text('Teaching Assistant (TA)')),
                ],
                onChanged: (val) => role = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final uid = int.tryParse(uidCtrl.text.trim());
              if (uid == null) return;
              try {
                await CourseRepository().enrollUser(widget.courseId, uid, role);
                if (mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(courseEnrollmentsProvider(widget.courseId));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('User enrolled successfully.')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.dangerRose));
                }
              }
            },
            child: const Text('Enroll'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      try {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;
        final res = await CourseRepository()
            .importEnrollmentsCsv(widget.courseId, bytes, name);
        ref.invalidate(courseEnrollmentsProvider(widget.courseId));
        if (mounted) {
          final created = res['created'] ?? 0;
          final errors = (res['errors'] as List? ?? []);
          final msg = errors.isEmpty
              ? '$created students enrolled successfully.'
              : '$created enrolled, ${errors.length} errors (check CSV format).';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor:
                errors.isEmpty ? AppColors.successGreen : AppColors.accentAmber,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.dangerRose,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrollmentsAsync =
        ref.watch(courseEnrollmentsProvider(widget.courseId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ProfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text('Enrolled Student Roster',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    if (widget.isProf)
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.person_add_rounded, size: 16),
                            label: const Text('Enroll Single'),
                            onPressed: _enrollDialog,
                          ),
                          OutlinedButton.icon(
                            icon:
                                const Icon(Icons.upload_file_rounded, size: 16),
                            label: const Text('Import CSV'),
                            onPressed: _uploadCsv,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _searchCtrl,
                  onChanged: (val) =>
                      setState(() => _query = val.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search by student name, email, or role...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),
                enrollmentsAsync.when(
                  loading: () => ProfShimmer.lines(count: 4),
                  error: (e, _) => Center(
                      child: Text(e.toString(),
                          style: const TextStyle(color: AppColors.dangerRose))),
                  data: (enrollments) {
                    final filtered = enrollments.where((e) {
                      final name =
                          (e['user_name'] ?? '').toString().toLowerCase();
                      final email =
                          (e['user_email'] ?? '').toString().toLowerCase();
                      final role = (e['role'] ?? '').toString().toLowerCase();
                      return name.contains(_query) ||
                          email.contains(_query) ||
                          role.contains(_query);
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                            child: Text('No enrolled students found.',
                                style: TextStyle(color: AppColors.textMuted))),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = filtered[index] as Map<String, dynamic>;
                        final name =
                            item['user_name'] ?? 'User #${item['user_id']}';
                        final email = item['user_email'] ?? '';
                        final role = (item['role'] ?? 'student')
                            .toString()
                            .toUpperCase();
                        final initials = name.isNotEmpty
                            ? name
                                .split(' ')
                                .map((e) => e.isNotEmpty ? e[0] : '')
                                .take(2)
                                .join()
                                .toUpperCase()
                            : 'U';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primaryIndigo.withOpacity(0.1),
                            child: Text(initials,
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryIndigo)),
                          ),
                          title: Text(name,
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              email.isNotEmpty
                                  ? '$email • Role: $role'
                                  : 'Role: $role',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textMuted)),
                          trailing: Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              ProfBadge(
                                  label: role,
                                  color: role == 'TA'
                                      ? AppColors.accentAmber
                                      : AppColors.primaryTeal,
                                  small: true),
                              if (widget.isProf) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      color: AppColors.dangerRose, size: 20),
                                  onPressed: () async {
                                    final confirm = await ProfConfirmSheet.show(
                                      context,
                                      title: 'Remove Student',
                                      body:
                                          'Are you sure you want to remove "$name" from this course?',
                                    );
                                    if (confirm == true) {
                                      await CourseRepository().removeEnrollment(
                                          widget.courseId, item['user_id']);
                                      ref.invalidate(courseEnrollmentsProvider(
                                          widget.courseId));
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  final Map<String, dynamic> course;
  const _SettingsTab({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Course Details',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Text('Title: ${course['title']}',
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Course Code: ${course['code']}',
                        style: GoogleFonts.inter(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Semester: ${course['semester']}',
                        style: GoogleFonts.inter(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ProfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HEC Assessment Weightage',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    HECWeightageWidget(
                      quiz: course['quiz_weight'] ?? 20,
                      assignment: course['assignment_weight'] ?? 20,
                      midterm: course['midterm_weight'] ?? 20,
                      finalExam: course['final_weight'] ?? 40,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ProfCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Danger Zone',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dangerRose)),
                    const SizedBox(height: 6),
                    Text(
                      'Archiving hides this course from active dashboards while preserving all historical assignments, rubrics, submissions, and CLO analytics intact for accreditation audits.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.archive_outlined,
                          color: AppColors.dangerRose),
                      label: const Text('Archive Course (Preserves Data)',
                          style: TextStyle(
                              color: AppColors.dangerRose,
                              fontWeight: FontWeight.w600)),
                      onPressed: () async {
                        final confirm = await ProfConfirmSheet.show(
                          context,
                          title: 'Archive Course',
                          body:
                              'Are you sure you want to archive "${course['title']}"? This will hide it from active lists while keeping all student grades and rubrics preserved.',
                        );
                        if (confirm == true) {
                          try {
                            final cid = course['id'] as int;
                            await CourseRepository().archiveCourse(cid);
                            ref.invalidate(courseListProvider);
                            ref.invalidate(courseDetailProvider(cid));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Course archived successfully.')));
                              context.go('/courses');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: AppColors.dangerRose));
                            }
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.dangerRose),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
