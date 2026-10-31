import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/course_repository.dart';
import '../providers/course_providers.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  String _filter = 'active'; // 'active', 'archived', 'all'
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showJoinCourseDialog(BuildContext context, bool isDark) async {
    final codeCtrl = TextEditingController();
    var loading = false;
    var error = '';

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ruleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: ruleColor),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.group_add_rounded, color: Color(0xFF4F46E5), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Join Course',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: inkPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter the 6-character invitation code provided by your instructor to enroll:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: inkSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: inkPrimary,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'A1B2C3',
                      hintStyle: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        letterSpacing: 2,
                        color: inkSecondary.withOpacity(0.4),
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: ruleColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                      ),
                    ),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: GoogleFonts.inter(
                        color: AppColors.feedbackRed,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: loading ? null : () => Navigator.pop(dialogCtx),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(color: inkSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: loading
                            ? null
                            : () async {
                                final code = codeCtrl.text.trim().toUpperCase();
                                if (code.length < 4) {
                                  setDialogState(() => error = 'Enter a valid join code');
                                  return;
                                }
                                setDialogState(() {
                                  loading = true;
                                  error = '';
                                });
                                try {
                                  await CourseRepository().joinCourse(code);
                                  if (context.mounted) {
                                    ref.invalidate(courseListProvider);
                                    Navigator.pop(dialogCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Successfully joined course!'),
                                        backgroundColor: AppColors.verified,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    error = ErrorParser.parse(e);
                                    loading = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Join Course'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    codeCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final role = ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isAdmin = role == 'admin';
    final isProf = role == 'professor' || role == 'admin';
    final coursesAsync = ref.watch(courseListProvider);

    final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final ruleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isNarrow = MediaQuery.sizeOf(context).width < 640;

    return Scaffold(
      backgroundColor: bgPage,
      body: CustomScrollView(
        slivers: [
          // Header banner
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 640;
                final heading = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProfBreadcrumbs(
                      items: [
                        BreadcrumbItem(label: 'Home', path: '/dashboard'),
                        BreadcrumbItem(label: 'Courses'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SPRING 2027',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                        Text(
                          '•  Shifa Tameer-e-Millat University',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: inkSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isProf ? 'Course Portfolio' : 'My Enrollments',
                      style: GoogleFonts.outfit(
                        fontSize: isNarrow ? 24 : 28,
                        fontWeight: FontWeight.w700,
                        color: inkPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isProf
                          ? 'Manage academic course offerings, OBE mappings, and student cohorts.'
                          : 'Your active enrolled academic courses and continuous assessments.',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        color: inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                );

                final actionButton = isAdmin
                    ? ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Create Course'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () => context.go('/courses/new'),
                      )
                    : (role == 'student'
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.group_add_rounded, size: 18),
                            label: const Text('Join Course'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () => _showJoinCourseDialog(context, isDark),
                          )
                        : const SizedBox.shrink());

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 20 : 36,
                    isNarrow ? 24 : 36,
                    isNarrow ? 20 : 36,
                    20,
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            heading,
                            const SizedBox(height: 16),
                            actionButton,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: heading),
                            actionButton,
                          ],
                        ),
                );
              },
            ),
          ),

          // Search and Filter Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 20 : 36),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value.trim().toLowerCase()),
                          style: GoogleFonts.inter(fontSize: 14, color: inkPrimary),
                          decoration: InputDecoration(
                            hintText: isProf
                                ? 'Search by course title, code, semester, or professor…'
                                : 'Search your enrolled courses…',
                            hintStyle: GoogleFonts.inter(fontSize: 13, color: inkSecondary.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.search_rounded, size: 18, color: inkSecondary),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: surfaceColor,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: ruleColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterTab(
                          label: 'Active',
                          active: _filter == 'active',
                          isDark: isDark,
                          onTap: () => setState(() => _filter = 'active'),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'Archived',
                          active: _filter == 'archived',
                          isDark: isDark,
                          onTap: () => setState(() => _filter = 'archived'),
                        ),
                        const SizedBox(width: 8),
                        _FilterTab(
                          label: 'All Courses',
                          active: _filter == 'all',
                          isDark: isDark,
                          onTap: () => setState(() => _filter = 'all'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: ruleColor, height: 1),
                ],
              ),
            ),
          ),

          // Course Grid / List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
            sliver: coursesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2.5),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: _CourseListError(
                  message: ErrorParser.parse(err),
                  onRetry: () => ref.invalidate(courseListProvider),
                  isDark: isDark,
                ),
              ),
              data: (data) {
                final allCourses =
                    (data['courses'] as List<dynamic>).cast<Map<String, dynamic>>();
                final courses = allCourses.where((c) {
                  final isArchived = (c['is_archived'] as bool? ?? false);
                  final matchesStatus = _filter == 'active'
                      ? !isArchived
                      : _filter == 'archived'
                          ? isArchived
                          : true;
                  if (!matchesStatus) return false;
                  if (_searchQuery.isEmpty) return true;
                  final searchable = [
                    c['title'],
                    c['code'],
                    c['semester'],
                    c['professor_name'],
                  ].whereType<String>().join(' ').toLowerCase();
                  return searchable.contains(_searchQuery);
                }).toList();

                if (courses.isEmpty) {
                  final hasSearch = _searchQuery.isNotEmpty;
                  final String emptyTitle = isAdmin
                      ? (hasSearch ? 'No matching courses' : 'No courses created')
                      : (isProf
                          ? (hasSearch ? 'No matching courses' : 'No courses assigned')
                          : (hasSearch ? 'No matching courses' : 'No courses found'));
                  final String emptySub = isAdmin
                      ? (hasSearch
                          ? 'Try a different title, course code, or semester.'
                          : 'Click Create Course to add a course and assign it to a professor.')
                      : (isProf
                          ? (hasSearch
                              ? 'Try a different title, course code, or semester.'
                              : 'You have not been assigned to any active courses yet. Contact an administrator.')
                          : (hasSearch
                              ? 'Try a different title, course code, or semester.'
                              : 'You are not enrolled in any courses. Click Join Course above.'));
                  return SliverToBoxAdapter(
                    child: ProfEmptyState(
                      icon: Icons.menu_book_rounded,
                      title: emptyTitle,
                      subtitle: emptySub,
                      actionLabel: hasSearch ? 'Clear search' : null,
                      onAction: hasSearch
                          ? () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            }
                          : null,
                    ),
                  );
                }

                return SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final crossAxisCount = width >= 1100 ? 3 : (width >= 720 ? 2 : 1);

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: crossAxisCount == 1 ? 1.85 : 1.35,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final course = courses[index];
                          return _CourseCard(
                            course: course,
                            isProf: isProf,
                            isDark: isDark,
                          );
                        },
                        childCount: courses.length,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF4F46E5).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatefulWidget {
  final Map<String, dynamic> course;
  final bool isProf;
  final bool isDark;

  const _CourseCard({
    required this.course,
    required this.isProf,
    required this.isDark,
  });

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isDark = widget.isDark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceHover = isDark ? const Color(0xFF243048) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final title = course['title'] ?? 'Untitled Course';
    final code = course['code'] ?? 'CODE';
    final semester = course['semester'] ?? 'Spring 2027';
    final profName = course['professor_name'] ?? 'Faculty Instructor';
    final count = course['enrollment_count'] ?? 0;
    final isArchived = course['is_archived'] as bool? ?? false;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: () => context.go('/courses/${course['id']}'),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? surfaceHover : surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? const Color(0xFF4F46E5).withOpacity(0.5) : border,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_hovered ? 0.08 : 0.02),
                blurRadius: _hovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top meta chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isArchived
                          ? const Color(0xFF64748B).withOpacity(0.12)
                          : const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isArchived ? 'Archived' : 'Active',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isArchived ? const Color(0xFF64748B) : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),

              // Title & Semester
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: inkPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    semester,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: inkSecondary,
                    ),
                  ),
                ],
              ),

              // Footer: Instructor & Enrollment count
              Column(
                children: [
                  Divider(color: border, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 15, color: inkSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.isProf ? 'Instructor' : profName,
                                style: GoogleFonts.inter(fontSize: 12, color: inkSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_alt_outlined, size: 15, color: const Color(0xFF4F46E5)),
                          const SizedBox(width: 4),
                          Text(
                            '$count students',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inkPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseListError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;

  const _CourseListError({
    required this.message,
    required this.onRetry,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.feedbackRed),
          const SizedBox(height: 12),
          Text(
            'Failed to load course list',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.inkPrimary : AppColorsLight.inkTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
