/// ProfessorOS – Course List Screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/course_providers.dart';

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
  String _filter = 'all'; // 'all', 'active', 'archived'

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    final role =
        ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin';
    final coursesAsync = ref.watch(courseListProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isProf ? 'Course Management' : 'My Enrollments',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3)),
            Text(
                isProf
                    ? 'Manage offerings, HEC rubrics & student cohorts'
                    : 'Your active academic courses',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (isProf)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    const BoxShadow(
                        color: Color(0x304F46E5),
                        blurRadius: 12,
                        offset: Offset(0, 4))
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: isNarrow
                      ? const SizedBox.shrink()
                      : const Text('Create Course'),
                  onPressed: () => context.go('/courses/new'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Pills Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterPill('all', 'All Courses'),
                _filterPill('active', 'Active'),
                _filterPill('archived', 'Archived'),
              ],
            ),
          ),
          Expanded(
            child: coursesAsync.when(
              loading: () => GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20),
                itemCount: 6,
                itemBuilder: (_, __) => ProfShimmer.card(),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Failed to load courses:\n$err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.dangerRose)),
                ),
              ),
              data: (data) {
                final allCourses = (data['courses'] as List<dynamic>)
                    .cast<Map<String, dynamic>>();

                final courses = allCourses.where((c) {
                  final isArchived = (c['is_archived'] as bool? ?? false);
                  if (_filter == 'active') return !isArchived;
                  if (_filter == 'archived') return isArchived;
                  return true;
                }).toList();

                if (courses.isEmpty) {
                  return ProfEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: isProf
                        ? 'No courses found.'
                        : 'Not enrolled in any courses.',
                    subtitle: isProf
                        ? 'Create your first course to get started with HEC compliance.'
                        : 'Your professor will enroll you shorty.',
                    actionLabel: isProf ? 'Create Course' : null,
                    onAction: isProf ? () => context.go('/courses/new') : null,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 420,
                      mainAxisExtent: 230,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20),
                  itemCount: courses.length,
                  itemBuilder: (context, index) {
                    final course = courses[index];
                    return _CourseCard(course: course, isProf: isProf);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String id, String label) {
    final selected = _filter == id;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryIndigo : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primaryIndigo : AppColors.border),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primaryIndigo.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends StatefulWidget {
  final Map<String, dynamic> course;
  final bool isProf;
  const _CourseCard({required this.course, required this.isProf});

  @override
  State<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends State<_CourseCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final isProf = widget.isProf;
    final isActive = !(course['is_archived'] as bool? ?? false);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..translate(0, _hovering ? -6.0 : 0.0),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _hovering ? AppColors.primaryIndigo : AppColors.border,
            width: _hovering ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _hovering 
                  ? AppColors.primaryIndigo.withOpacity(0.08) 
                  : Colors.black.withOpacity(0.02),
              blurRadius: _hovering ? 20 : 10,
              offset: Offset(0, _hovering ? 10 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.go('/courses/${course['id']}'),
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  left: 0, right: 0, top: 0,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive 
                            ? [AppColors.primaryIndigo, AppColors.accentCyan] 
                            : [AppColors.textMuted, AppColors.border],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ProfBadge(
                              label: course['code'],
                              color: AppColors.primaryIndigo),
                          const Spacer(),
                          ProfBadge(
                            label: isActive ? 'Active' : 'Archived',
                            color: isActive
                                ? AppColors.successGreen
                                : AppColors.textMuted,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        course['title'],
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isProf
                            ? 'Semester: ${course['semester']}'
                            : 'Prof: ${course['professor_name']} • ${course['semester']}',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(
                          height: 1,
                          color: AppColors.border.withOpacity(0.6)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text('${course['enrollment_count']} Enrolled',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.assignment_outlined,
                              size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                              '${course['assignment_count']} Assignments',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
