/// ProfessorOS – Assignment Detail Screen.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_stat_card.dart';
import '../../../shared/widgets/marginalia_strip.dart';
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

  // ── State variables for Student Submission ───────────
  String? _selectedFileName;
  final _textSubmissionCtrl = TextEditingController();
  final _codeSubmissionCtrl = TextEditingController();
  int? _mcqSelectedValue; // simple quiz question selection

  final List<Map<String, dynamic>> _submissions = [
    {
      'student_id': 1,
      'student_name': 'Sana Ahmed',
      'student_email': 'sana.a@univ.edu.pk',
      'score': 85.0,
      'submitted_at': '2 days ago',
      'status': 'graded',
      'feedback': 'Excellent analysis and structure.',
      'submission_type': 'file',
      'content': 'lab3_solution.zip',
    },
    {
      'student_id': 2,
      'student_name': 'Ali Khan',
      'student_email': 'ali.k@univ.edu.pk',
      'score': null,
      'submitted_at': '1 day ago',
      'status': 'pending',
      'feedback': '',
      'submission_type': 'text',
      'content': 'Here is my written response describing HEC weights. Standard midterms are 20%, finals 40%, and the remaining 40% are split.',
    },
    {
      'student_id': 3,
      'student_name': 'Yasif Asif',
      'student_email': 'yasif9155@gmail.com',
      'score': 92.0,
      'submitted_at': '3 days ago',
      'status': 'graded',
      'feedback': 'Exceptional implementation quality.',
      'submission_type': 'programming',
      'content': 'def calculate_hec_grade(scores):\n    # Calculate HEC compliant aggregate\n    mid = scores.get("midterm", 0) * 0.2\n    fin = scores.get("final", 0) * 0.4\n    return mid + fin',
    },
    {
      'student_id': 4,
      'student_name': 'Zainab Fatima',
      'student_email': 'zainab.f@univ.edu.pk',
      'score': null,
      'submitted_at': '12 hours ago',
      'status': 'pending',
      'feedback': '',
      'submission_type': 'mcq',
      'content': 'Selected Answer: Option B (40% Weightage for Finals)',
    },
  ];

  void _openGradingDialog(Map<String, dynamic> sub) {
    final scoreCtrl = TextEditingController(text: sub['score']?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: sub['feedback'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grade Submission: ${sub['student_name']}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display Student Submitted Work
                Text('Student Submitted Work:',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: sub['submission_type'] == 'file'
                      ? Row(
                          children: [
                            const Icon(Icons.insert_drive_file, color: AppColors.primaryIndigo, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(sub['content'] ?? '',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            ),
                            TextButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Download'),
                            ),
                          ],
                        )
                      : sub['submission_type'] == 'programming'
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sub['content'] ?? '',
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
                              ),
                            )
                          : Text(
                              sub['content'] ?? '',
                              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                TextFormField(
                  controller: scoreCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Score / Points',
                    hintText: 'e.g. 85.5',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Score is required';
                    final val = double.tryParse(v);
                    if (val == null || val < 0 || val > 100) {
                      return 'Must be between 0 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: feedbackCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Feedback Comments',
                    hintText: 'Enter qualitative feedback...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  sub['score'] = double.parse(scoreCtrl.text);
                  sub['feedback'] = feedbackCtrl.text;
                  sub['status'] = 'graded';
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Grade updated successfully!'),
                  backgroundColor: AppColors.successGreen,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryIndigo),
            child: const Text('Save Grade'),
          ),
        ],
      ),
    );
  }

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
                    color: AppColors.inkPrimary),
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
                      color: AppColors.primaryIndigo),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Stats Row
            if (isProf) ...[
              Builder(
                builder: (context) {
                  final totalCount = _submissions.length;
                  final pendingCount = _submissions.where((s) => s['status'] == 'pending').length;
                  final gradedCount = _submissions.where((s) => s['status'] == 'graded').length;
                  final gradedScores = _submissions.where((s) => s['status'] == 'graded' && s['score'] != null).map((s) => s['score'] as double).toList();
                  final avgScoreStr = gradedScores.isNotEmpty
                      ? '${(gradedScores.reduce((a, b) => a + b) / gradedScores.length).toStringAsFixed(1)}%'
                      : '0.0%';

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$totalCount/180',
                              label: 'Submissions')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$pendingCount',
                              label: 'Pending Review')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$gradedCount',
                              label: 'Graded')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: avgScoreStr,
                              label: 'Average Score')),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
            ],

            // Submissions & Rubric (Side by Side on desktop)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final studentEmail = ref.watch(authProvider).valueOrNull?['email'] ?? '';
                final submissionWidget = isProf
                    ? _buildSubmissionsList()
                    : _buildStudentSubmissionView(studentEmail);

                if (constraints.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: submissionWidget),
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
                    submissionWidget,
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
                            color: AppColors.inkPrimary),
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _submissions.length,
            itemBuilder: (context, index) {
              final sub = _submissions[index];
              final isGraded = sub['status'] == 'graded';

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => SpeedGraderScreen(
                        submissions: _submissions,
                        initialIndex: index,
                        assignmentId: widget.assignmentId,
                        onSave: (idx, updatedSub) {
                          setState(() {
                            _submissions[idx] = updatedSub;
                          });
                        },
                      ),
                    ));
                  },
                  child: IntrinsicHeight(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: index == 0 ? const BorderSide(color: AppColors.marginRule, width: 1) : BorderSide.none,
                          bottom: const BorderSide(color: AppColors.marginRule, width: 1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.bgSurface,
                                    child: Text(
                                      sub['student_name'].split(' ').map((n) => n[0]).join(),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.inkPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(sub['student_name'],
                                            style: GoogleFonts.inter(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.inkPrimary)),
                                        Text(sub['student_email'],
                                            style: GoogleFonts.inter(
                                                fontSize: 12, color: AppColors.inkSecondary)),
                                      ],
                                    ),
                                  ),
                                  Text(sub['submitted_at'],
                                      style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12,
                                          color: AppColors.inkSecondary)),
                                ],
                              ),
                            ),
                          ),
                          MarginaliaStrip(
                            statusLabel: isGraded ? 'Graded' : 'Pending',
                            statusColor: isGraded ? AppColors.feedbackRed : AppColors.pending,
                            score: sub['score'] != null ? '${sub['score']}' : '--',
                            grader: isGraded ? 'System' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSubmissionView(String studentEmail) {
    final sub = _submissions.firstWhere(
      (s) => s['student_email'] == studentEmail,
      orElse: () => <String, dynamic>{},
    );

    final hasSubmitted = sub.isNotEmpty;
    final isGraded = hasSubmitted && sub['status'] == 'graded';
    final assignmentType = _assignment?['type']?.toString().toLowerCase() ?? 'text';

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Submission',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          if (hasSubmitted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          ProfBadge(
                            label: isGraded ? 'Graded' : 'Submitted (Latest)',
                            color: isGraded ? AppColors.successGreen : AppColors.accentAmber,
                          ),
                          if (sub['score'] != null)
                            ProfBadge(
                              label: '${sub['score']} pts',
                              color: AppColors.primaryIndigo,
                            ),
                        ],
                      ),
                      Text(
                        'Submitted ${sub['submitted_at']}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Submitted Content:',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: sub['submission_type'] == 'file'
                        ? Row(
                            children: [
                              const Icon(Icons.insert_drive_file, color: AppColors.primaryIndigo, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(sub['content'] ?? '',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ),
                            ],
                          )
                        : sub['submission_type'] == 'programming'
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sub['content'] ?? '',
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black87),
                                ),
                              )
                            : Text(
                                sub['content'] ?? '',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                              ),
                  ),
                  if (isGraded && sub['feedback'] != null && sub['feedback'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Instructor Feedback',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        sub['feedback'],
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _submissions.removeWhere((s) => s['student_email'] == studentEmail);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Re-opened submission form. Upload your updated work below.'),
                      ));
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Resubmit Assignment'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (assignmentType == 'file') ...[
                    Text('Upload PDF/ZIP Submission File',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(type: FileType.any);
                        if (result != null) {
                          setState(() {
                            _selectedFileName = result.files.single.name;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.3), style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.primaryIndigo),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFileName ?? 'Click to choose file...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _selectedFileName != null ? FontWeight.w600 : FontWeight.w400,
                                color: _selectedFileName != null ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _selectedFileName == null
                          ? null
                          : () {
                              setState(() {
                                _submissions.add({
                                  'student_id': 99,
                                  'student_name': ref.read(authProvider).valueOrNull?['full_name'] ?? 'Student',
                                  'student_email': studentEmail,
                                  'score': null,
                                  'submitted_at': 'Just now',
                                  'status': 'pending',
                                  'feedback': '',
                                  'submission_type': 'file',
                                  'content': _selectedFileName,
                                });
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('File assignment submitted successfully!'),
                                backgroundColor: AppColors.successGreen,
                              ));
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Assignment'),
                    ),
                  ] else if (assignmentType == 'programming') ...[
                    Text('Paste Source Code Submission',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeSubmissionCtrl,
                      maxLines: 8,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'e.g. def my_solution():\n    return True',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final code = _codeSubmissionCtrl.text.trim();
                        if (code.isEmpty) return;
                        setState(() {
                          _submissions.add({
                            'student_id': 99,
                            'student_name': ref.read(authProvider).valueOrNull?['full_name'] ?? 'Student',
                            'student_email': studentEmail,
                            'score': null,
                            'submitted_at': 'Just now',
                            'status': 'pending',
                            'feedback': '',
                            'submission_type': 'programming',
                            'content': code,
                          });
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Code assignment submitted successfully!'),
                          backgroundColor: AppColors.successGreen,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Code'),
                    ),
                  ] else if (assignmentType == 'mcq') ...[
                    Text('Complete Multiple Choice Quiz',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question: What is the primary purpose of Course Learning Outcomes (CLOs) in HEC compliance?',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 12),
                          RadioListTile<int>(
                            title: const Text('A. To calculate student GPA automatically.', style: TextStyle(fontSize: 13)),
                            value: 1,
                            groupValue: _mcqSelectedValue,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _mcqSelectedValue = val),
                          ),
                          RadioListTile<int>(
                            title: const Text('B. To map assessment questions to educational standards.', style: TextStyle(fontSize: 13)),
                            value: 2,
                            groupValue: _mcqSelectedValue,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _mcqSelectedValue = val),
                          ),
                          RadioListTile<int>(
                            title: const Text('C. To restrict students from viewing class folders.', style: TextStyle(fontSize: 13)),
                            value: 3,
                            groupValue: _mcqSelectedValue,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) => setState(() => _mcqSelectedValue = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _mcqSelectedValue == null
                          ? null
                          : () {
                              final optionText = _mcqSelectedValue == 1
                                  ? 'Option A (GPA Calculation)'
                                  : _mcqSelectedValue == 2
                                      ? 'Option B (Mapping Questions to Standards - CORRECT)'
                                      : 'Option C (Folder Access)';
                              setState(() {
                                _submissions.add({
                                  'student_id': 99,
                                  'student_name': ref.read(authProvider).valueOrNull?['full_name'] ?? 'Student',
                                  'student_email': studentEmail,
                                  'score': _mcqSelectedValue == 2 ? 100.0 : 0.0,
                                  'submitted_at': 'Just now',
                                  'status': 'graded',
                                  'feedback': _mcqSelectedValue == 2 ? 'Auto-graded: 100% correct!' : 'Auto-graded: 0% incorrect. Correct answer was B.',
                                  'submission_type': 'mcq',
                                  'content': 'Selected Answer: $optionText',
                                });
                              });
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(_mcqSelectedValue == 2 ? 'Correct! 100% score auto-graded.' : 'Incorrect! Auto-graded.'),
                                backgroundColor: _mcqSelectedValue == 2 ? AppColors.successGreen : AppColors.dangerRose,
                              ));
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Quiz'),
                    ),
                  ] else ...[
                    Text('Write Q&A Response Submission',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _textSubmissionCtrl,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        hintText: 'Enter your written answer response here...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        final text = _textSubmissionCtrl.text.trim();
                        if (text.isEmpty) return;
                        setState(() {
                          _submissions.add({
                            'student_id': 99,
                            'student_name': ref.read(authProvider).valueOrNull?['full_name'] ?? 'Student',
                            'student_email': studentEmail,
                            'score': null,
                            'submitted_at': 'Just now',
                            'status': 'pending',
                            'feedback': '',
                            'submission_type': 'text',
                            'content': text,
                          });
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Written assignment submitted successfully!'),
                          backgroundColor: AppColors.successGreen,
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Answer'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SpeedGraderScreen extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> submissions;
  final int initialIndex;
  final int assignmentId;
  final Function(int index, Map<String, dynamic> updatedSub) onSave;

  const SpeedGraderScreen({
    super.key,
    required this.submissions,
    required this.initialIndex,
    required this.assignmentId,
    required this.onSave,
  });

  @override
  ConsumerState<SpeedGraderScreen> createState() => _SpeedGraderScreenState();
}

class _SpeedGraderScreenState extends ConsumerState<SpeedGraderScreen> {
  late int _currentIndex;
  final _scoreCtrl = TextEditingController();
  final _feedbackCtrl = TextEditingController();
  final Map<String, String> _selectedLevels = {}; // criteria_name -> level

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadSubmission();
  }

  void _loadSubmission() {
    final sub = widget.submissions[_currentIndex];
    _scoreCtrl.text = sub['score']?.toString() ?? '';
    _feedbackCtrl.text = sub['feedback'] ?? '';
    _selectedLevels.clear();
  }

  void _onSaveCurrent() {
    final score = double.tryParse(_scoreCtrl.text);
    final feedback = _feedbackCtrl.text;
    final updated = Map<String, dynamic>.from(widget.submissions[_currentIndex]);
    updated['score'] = score;
    updated['feedback'] = feedback;
    updated['status'] = 'graded';

    widget.onSave(_currentIndex, updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Grade and feedback saved successfully!'),
      backgroundColor: AppColors.successGreen,
    ));
  }

  Widget _buildCodeViewer(String code) {
    final lines = code.split('\n');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: lines.length,
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.sourceCodePro(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      lines[i],
                      style: GoogleFonts.sourceCodePro(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submissions[_currentIndex];
    final rubricAsync = ref.watch(rubricProvider(widget.assignmentId));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('SpeedGrader Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Carousel Nav Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bgSurface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _currentIndex > 0
                      ? () {
                          setState(() {
                            _currentIndex--;
                            _loadSubmission();
                          });
                        }
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(sub['student_name'],
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(sub['student_email'],
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: _currentIndex < widget.submissions.length - 1
                      ? () {
                          setState(() {
                            _currentIndex++;
                            _loadSubmission();
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
          
          // Split Pane Body
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useVertical = constraints.maxWidth < 900;
                
                final leftPane = SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Submitted Work Preview',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: sub['submission_type'] == 'file'
                            ? Column(
                                children: [
                                  const Icon(Icons.insert_drive_file, size: 64, color: AppColors.primaryIndigo),
                                  const SizedBox(height: 12),
                                  Text(sub['content'] ?? '',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.download),
                                    label: const Text('Download Submission File'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryIndigo),
                                  ),
                                ],
                              )
                            : sub['submission_type'] == 'programming'
                                ? _buildCodeViewer(sub['content'] ?? '')
                                : Text(
                                    sub['content'] ?? '',
                                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                                  ),
                      ),
                    ],
                  ),
                );

                final rightPane = SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Grade & Feedback Card',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 16),
                      
                      // Clickable Rubric Evaluator
                      rubricAsync.when(
                        data: (r) {
                          if (r == null) return const SizedBox.shrink();
                          final criteria = r['criteria'] as List<dynamic>;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rubric Grading Checklist',
                                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              const SizedBox(height: 10),
                              ...criteria.map((c) {
                                final critName = c['name'] as String;
                                final weight = c['weight'] as int;
                                final levels = c['levels'] as List<dynamic>;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$critName ($weight%)',
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: levels.map((l) {
                                            final levelName = l['level'] as String;
                                            final isSelected = _selectedLevels[critName] == levelName;
                                            return ChoiceChip(
                                              label: Text(levelName.toUpperCase(), style: const TextStyle(fontSize: 11)),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  _selectedLevels[critName] = levelName;
                                                  
                                                  // Auto calculate total score based on rubric clicks
                                                  double calculatedTotal = 0;
                                                  _selectedLevels.forEach((key, val) {
                                                    final matchCrit = criteria.firstWhere((element) => element['name'] == key);
                                                    final matchWeight = matchCrit['weight'] as int;
                                                    double factor = 1.0;
                                                    if (val == 'good') factor = 0.75;
                                                    if (val == 'poor') factor = 0.40;
                                                    calculatedTotal += matchWeight * factor;
                                                  });
                                                  _scoreCtrl.text = calculatedTotal.toStringAsFixed(1);
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const Divider(),
                              const SizedBox(height: 12),
                            ],
                          );
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      
                      TextField(
                        controller: _scoreCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Points / Score',
                          hintText: 'e.g. 85.5',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Qualitative Feedback',
                          hintText: 'Great work! Solid structure...',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _onSaveCurrent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Save Grade & Comments'),
                      ),
                    ],
                  ),
                );

                if (useVertical) {
                  return ListView(
                    children: [
                      leftPane,
                      rightPane,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: leftPane),
                    const VerticalDivider(width: 1),
                    Expanded(flex: 2, child: rightPane),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
