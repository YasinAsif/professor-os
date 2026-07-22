/// ProfessorOS – Assignment Detail Screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_stat_card.dart';
import '../data/course_repository.dart';
import '../../auth/providers/auth_provider.dart';

final rubricProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, aid) async {
  return await CourseRepository().getRubric(aid);
});

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int assignmentId;
  const AssignmentDetailScreen(
      {super.key, required this.courseId, required this.assignmentId});

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  Map<String, dynamic>? _assignment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _assignment = await CourseRepository()
          .getAssignment(widget.courseId, widget.assignmentId);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    if (_assignment == null) return const SizedBox.shrink();

    final a = _assignment!;
    final isProf =
        ref.watch(authProvider).valueOrNull?['role'] == 'professor' ||
            ref.watch(authProvider).valueOrNull?['role'] == 'admin';

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(a['title'],
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          if (isProf && a['status'] == 'draft')
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await CourseRepository().publishAssignment(
                        widget.courseId, widget.assignmentId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Assignment published successfully!'),
                        backgroundColor: AppColors.successGreen,
                      ));
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Publishing failed: ${e.toString()}'),
                        backgroundColor: AppColors.dangerRose,
                      ));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white),
                child: const Text('Publish'),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meta Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ProfBadge(
                    label: a['type'].toString().toUpperCase(),
                    color: AppColors.primaryTeal),
                ProfBadge(
                    label: a['status'].toString().toUpperCase(),
                    color: a['status'] == 'published'
                        ? AppColors.successGreen
                        : AppColors.accentAmber),
                Text('Max Marks: ${a['max_marks']}',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textSecondary)),
                if (a['clo_ids'] != null &&
                    (a['clo_ids'] as List).isNotEmpty) ...[
                  ProfBadge(
                      label: 'CLOs: ${(a['clo_ids'] as List).join(", ")}',
                      color: AppColors.primaryIndigo,
                      small: true),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Stats Row
            if (isProf) ...[
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: const [
                  SizedBox(
                      width: 200,
                      child: ProfStatCard(
                          value: '34/180',
                          label: 'Submissions',
                          icon: Icons.inbox)),
                  SizedBox(
                      width: 200,
                      child: ProfStatCard(
                          value: '12',
                          label: 'Pending Review',
                          icon: Icons.pending_actions)),
                  SizedBox(
                      width: 200,
                      child: ProfStatCard(
                          value: '22', label: 'Graded', icon: Icons.done_all)),
                  SizedBox(
                      width: 200,
                      child: ProfStatCard(
                          value: '76%',
                          label: 'Average Score',
                          icon: Icons.analytics)),
                ],
              ),
              const SizedBox(height: 32),
            ],

            // Submissions & Rubric (Side by Side on desktop)
            LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildSubmissionsList()),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _buildRubric(a['has_rubric'])),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRubric(a['has_rubric']),
                    const SizedBox(height: 24),
                    _buildSubmissionsList(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRubric(bool hasRubric) {
    if (!hasRubric) {
      return ProfCard(child: const Text('No rubric defined.'));
    }
    final rubricAsync = ref.watch(rubricProvider(widget.assignmentId));
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rubric Summary',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          rubricAsync.when(
            loading: () => ProfShimmer.lines(count: 3),
            error: (e, _) => Text(e.toString()),
            data: (r) {
              if (r == null) return const Text('No rubric found.');
              final criteria = r['criteria'] as List<dynamic>;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: criteria.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final c = criteria[i];
                  return ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                            child: Text(c['name'],
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600))),
                        ProfBadge(
                            label: '${c['weight']}%',
                            color: AppColors.primaryTeal,
                            small: true),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.all(16),
                    children: [
                      ...((c['levels'] as List<dynamic>).map((l) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                    width: 80,
                                    child: Text(
                                        l['level'].toString().toUpperCase(),
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600))),
                                Expanded(
                                    child: Text(l['description'] ?? '',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.textSecondary))),
                              ],
                            ),
                          ))),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildSubmissionsList() {
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submissions',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No submissions yet.'))),
        ],
      ),
    );
  }
}
