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
                              label: 'Submissions',
                              icon: Icons.inbox)),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$pendingCount',
                              label: 'Pending Review',
                              icon: Icons.pending_actions)),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$gradedCount',
                              label: 'Graded',
                              icon: Icons.done_all)),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: avgScoreStr,
                              label: 'Average Score',
                              icon: Icons.analytics)),
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
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _submissions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sub = _submissions[index];
              final isGraded = sub['status'] == 'graded';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryIndigo.withOpacity(0.08),
                      child: Text(
                        sub['student_name'].split(' ').map((n) => n[0]).join(),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryIndigo,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sub['student_name'],
                              style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text(sub['student_email'],
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            ProfBadge(
                              label: isGraded ? 'Graded' : 'Pending',
                              color: isGraded
                                  ? AppColors.successGreen
                                  : AppColors.accentAmber,
                              small: true,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              sub['score'] != null
                                  ? '${sub['score']} pts'
                                  : '-- pts',
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(sub['submitted_at'],
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.edit_note_rounded,
                                  size: 20, color: AppColors.primaryIndigo),
                              onPressed: () => _openGradingDialog(sub),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              tooltip: 'Grade & Feedback',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
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
                            label: isGraded ? 'Graded' : 'Pending Review',
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
