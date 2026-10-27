/// ProfessorOS – Assignment Detail Screen.

import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/utils/error_parser.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../../../shared/widgets/prof_stat_card.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
import '../../../shared/widgets/marginalia_strip.dart';
import '../../../shared/widgets/submission_triage.dart';
import '../data/course_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../utils/mcq_parser.dart';
import '../utils/exam_route.dart';
import '../utils/proctor_attempts.dart';
import '../utils/web_window_listener.dart';

final rubricProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, aid) async {
  return await CourseRepository().getRubric(aid);
});

class AssignmentDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int assignmentId;
  final Map<String, dynamic>? initialAssignment;
  final List<Map<String, dynamic>>? initialExamAttempts;

  const AssignmentDetailScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    this.initialAssignment,
    this.initialExamAttempts,
  }) : assert(
          !kReleaseMode ||
              (initialAssignment == null && initialExamAttempts == null),
          'Test data cannot be passed in release builds.',
        );

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _assignment;
  bool _loading = true;
  String? _error;

  // ── Submission state ──────────────────────────────────
  // For student view: their own submission (null = not submitted)
  Map<String, dynamic>? _mySubmission;
  bool _submissionLoading = false;

  // For prof/TA view: full list of all submissions
  List<Map<String, dynamic>> _submissions = [];
  bool _submissionsLoading = false;
  int _pendingCount = 0;
  int _gradedCount = 0;
  bool _batchGrading = false;
  Map<String, dynamic>? _studentAppeal;
  List<Map<String, dynamic>> _assignmentAppeals = [];
  String _submissionFilter = 'all';
  final Set<int> _gradingSubmissionIds = {};
  List<Map<String, dynamic>> _examAttempts = [];
  String _examAttemptFilter = 'all'; // 'all', 'flagged', 'auto_submitted', 'has_violations', 'active', 'offline'
  final TextEditingController _examAttemptSearchCtrl = TextEditingController();
  int _examAttemptPage = 1;
  static const int _examAttemptPageSize = 25;
  Timer? _proctorRefreshTimer;
  String? _proctorError;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final role =
          ref.read(authProvider).valueOrNull?['role'] as String? ?? 'student';
      if ((role == 'professor' || role == 'admin' || role == 'ta') &&
          (_isTimedExam || _examAttempts.isNotEmpty)) {
        _startProctorRefresh();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _proctorRefreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proctorRefreshTimer?.cancel();
    _examAttemptSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _exportGradesCsv() async {
    try {
      final token = await DioClient.getAccessToken();
      final url = Uri.parse(
          '${ApiConstants.baseUrl}${ApiConstants.assignmentExportCsv(widget.courseId, widget.assignmentId)}?token=$token');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not trigger CSV download.'),
            backgroundColor: AppColors.dangerRose,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export error: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  // Submission form state
  String? _selectedFileName;
  List<int>? _selectedFileBytes;
  final _textSubmissionCtrl = TextEditingController();
  final _codeSubmissionCtrl = TextEditingController();
  int? _mcqSelectedValue;
  final Map<int, int> _mcqAnswers = {};

  Future<void> _downloadSubmissionFile(
      int submissionId, String filename) async {
    try {
      final token = await DioClient.getAccessToken();
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/submissions/$submissionId/file?token=$token');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not trigger download for $filename'),
            backgroundColor: AppColors.dangerRose,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  String _formatSubmissionDate(dynamic raw) {
    if (raw == null) return 'Not submitted';
    final str = raw.toString().trim();
    if (str.isEmpty) return 'Not submitted';
    try {
      final dt = DateTime.parse(str).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour:$minute $ampm';
    } catch (_) {
      return str.length > 16 ? str.substring(0, 16) : str;
    }
  }

  List<String> _triageReasons(Map<String, dynamic> submission) {
    final reasons = submission['triage_reasons'];
    if (reasons is List) return reasons.map((item) => item.toString()).toList();
    return const [];
  }

  Future<void> _runBatchAiGrading() async {
    final pending = _submissions.where((s) => s['status'] == 'pending').length;
    if (pending == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.auto_awesome, color: AppColors.signal),
            SizedBox(width: 8),
            Text('Batch AI Grading'),
          ],
        ),
        content: Text(
          'AI evaluation engine will evaluate all $pending pending submissions against the course rubric and compute grades with diagnostic feedback.\n\nProceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.signal),
            icon: const Icon(Icons.bolt, size: 16),
            label: const Text('Start AI Batch'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _batchGrading = true);
    try {
      final res = await CourseRepository()
          .batchAiGrade(widget.courseId, widget.assignmentId);
      final count = res['graded_count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✓ Successfully AI-graded $count submissions against rubric.'),
          backgroundColor: AppColors.successGreen,
        ));
        await _loadSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Batch AI grading failed: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    } finally {
      if (mounted) setState(() => _batchGrading = false);
    }
  }

  Future<void> _aiGradeSingleSubmission(Map<String, dynamic> sub) async {
    final sid = sub['id'] as int;
    setState(() => _gradingSubmissionIds.add(sid));
    try {
      final result =
          await CourseRepository().aiGradeSubmission(sid, sync: true);
      if (!mounted) return;
      final score = result['score'];
      // Instant local state update for zero lag
      setState(() {
        final idx = _submissions.indexWhere((s) => s['id'] == sid);
        if (idx != -1) {
          final updated = Map<String, dynamic>.from(_submissions[idx]);
          if (score != null) updated['score'] = score;
          if (result['status'] != null) updated['status'] = result['status'];
          if (result['feedback'] != null) updated['feedback'] = result['feedback'];
          if (result['needs_review'] != null) updated['needs_review'] = result['needs_review'];
          _submissions[idx] = updated;
          if (updated['status'] == 'graded') {
            _gradedCount++;
            if (_pendingCount > 0) _pendingCount--;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✓ AI grading complete for ${sub['student_name']}: $score pts awarded.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      await _loadSubmissions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI grading error: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ),
      );
    } finally {
      if (mounted) setState(() => _gradingSubmissionIds.remove(sid));
    }
  }

  void _openGradingDialog(Map<String, dynamic> sub) {
    final scoreCtrl =
        TextEditingController(text: sub['score']?.toString() ?? '');
    final feedbackCtrl = TextEditingController(text: sub['feedback'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool aiGrading = false;
    String? aiStatusMessage;
    Map<String, dynamic>? aiEvaluation;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text('Grade: ${sub['student_name'] ?? 'Student'}',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
              ProfBadge(
                label: sub['needs_review'] == true
                    ? 'Needs Review'
                    : sub['status'] == 'graded'
                        ? 'Graded'
                        : 'Queued',
                color: sub['needs_review'] == true
                    ? AppColors.accentAmber
                    : sub['status'] == 'graded'
                        ? AppColors.successGreen
                        : AppColors.pending,
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubmissionTriageBadges(submission: sub),
                    if (sub['needs_review'] == true) const SizedBox(height: 10),
                    Text('Submitted Work:',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textMuted)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bgPage,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: sub['submission_type'] == 'programming'
                          ? Text(
                              sub['content'] ?? '',
                              style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12, color: AppColors.inkPrimary),
                            )
                          : sub['submission_type'] == 'file'
                              ? Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file,
                                        color: AppColors.signal, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                          sub['file_name'] ??
                                              sub['content'] ??
                                              'Uploaded file',
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                )
                              : Text(
                                  sub['content'] ?? '',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.4),
                                ),
                    ),
                    const SizedBox(height: 16),
                    // AI Evaluation Action Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.primaryIndigo.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome,
                                  color: AppColors.signal, size: 18),
                              const SizedBox(width: 8),
                              Text('AI Rubric Evaluation',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.inkPrimary)),
                              const Spacer(),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.signal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                                icon: aiGrading
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.bolt, size: 15),
                                label: Text(aiGrading
                                    ? 'Grading...'
                                    : 'Auto-Grade with AI'),
                                onPressed: (saving || aiGrading)
                                    ? null
                                    : () async {
                                        setDialogState(() {
                                          aiGrading = true;
                                          aiStatusMessage =
                                              'Analyzing submission with AI against rubric...';
                                        });
                                        try {
                                          final res = await CourseRepository()
                                              .aiGradeSubmission(
                                                  sub['id'] as int,
                                                  sync: true);
                                          final score = (res['score'] as num?)
                                              ?.toDouble();
                                          final feedback =
                                              res['feedback']?.toString() ??
                                                  res['diagnostic_reasoning']
                                                      ?.toString();
                                          setDialogState(() {
                                            if (score != null) {
                                              scoreCtrl.text =
                                                  score.toStringAsFixed(1);
                                              sub['score'] = score;
                                            }
                                            if (feedback != null &&
                                                feedback.isNotEmpty) {
                                              feedbackCtrl.text = feedback;
                                              sub['feedback'] = feedback;
                                            }
                                            if (res['status'] != null) {
                                              sub['status'] = res['status'];
                                            }
                                            if (res['needs_review'] != null) {
                                              sub['needs_review'] = res['needs_review'];
                                            }
                                            aiEvaluation = res;
                                            aiGrading = false;
                                            aiStatusMessage =
                                                '✓ AI evaluated: ${res['percentage']?.toStringAsFixed(1) ?? score}% score awarded.';
                                          });
                                          if (mounted) {
                                            setState(() {
                                              final idx = _submissions.indexWhere((s) => s['id'] == sub['id']);
                                              if (idx != -1) {
                                                _submissions[idx] = Map<String, dynamic>.from(sub);
                                              }
                                            });
                                          }
                                        } catch (e) {
                                          setDialogState(() {
                                            aiGrading = false;
                                            aiStatusMessage =
                                                'AI grading failed due to server error. Please try again or grade manually.';
                                          });
                                        }
                                      },
                              ),
                            ],
                          ),
                          if (aiStatusMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              aiStatusMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: aiStatusMessage!.startsWith('✓')
                                    ? AppColors.successGreen
                                    : aiStatusMessage!.contains('failed')
                                        ? AppColors.dangerRose
                                        : AppColors.signal,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (aiEvaluation != null &&
                              aiEvaluation!['criteria_evaluations']
                                  is List) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Text('Rubric Criteria Breakdown:',
                                style: GoogleFonts.inter(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            ...((aiEvaluation!['criteria_evaluations'] as List)
                                .map((crit) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.check_circle_outline,
                                              size: 14,
                                              color: AppColors.successGreen),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${crit['criterion_name']}: ${crit['score_awarded']}/${crit['max_score']} pts - ${crit['rationale'] ?? ''}',
                                              style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))),
                          ],
                        ],
                      ),
                    ),
                    if (aiEvaluation != null) ...[
                      const SizedBox(height: 12),
                      // XAI Summary Section
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primaryIndigo.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Percentage and needs review indicator
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Score: ${aiEvaluation!['percentage']?.toStringAsFixed(1) ?? 'N/A'}%',
                                    style: GoogleFonts.jetBrainsMono(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.inkPrimary),
                                  ),
                                ),
                                if (aiEvaluation!['needs_review'] == true) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentAmber
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppColors.accentAmber),
                                    ),
                                    child: Text(
                                      '📌 Needs Review',
                                      style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accentAmber),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Student-friendly rationale summary
                            Text(
                              _buildRationaleSummary(aiEvaluation!),
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.inkPrimary),
                            ),
                            const SizedBox(height: 8),
                            // Evaluator info
                            Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 14, color: AppColors.inkSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Evaluated by: ${aiEvaluation!['evaluator_model'] ?? 'AI Model'}',
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.inkSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: scoreCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            'Score / Points (max ${_assignment?['max_marks']?.toStringAsFixed(0) ?? '100'})',
                        hintText: 'e.g. 85.5',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Score is required';
                        final val = double.tryParse(v);
                        final max =
                            (_assignment?['max_marks'] as num?)?.toDouble() ??
                                100.0;
                        if (val == null || val < 0 || val > max) {
                          return 'Must be between 0 and $max';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: feedbackCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Qualitative Feedback',
                        hintText:
                            'Enter student-facing qualitative feedback...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final sid = sub['id'] as int;
                        final score = double.parse(scoreCtrl.text);
                        final feedback = feedbackCtrl.text.trim().isEmpty
                            ? null
                            : feedbackCtrl.text.trim();
                        await CourseRepository()
                            .gradeSubmission(sid, score, feedback);
                        if (mounted) {
                          Navigator.pop(ctx);
                          await _loadSubmissions();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                '✓ Grade and feedback saved successfully.'),
                            backgroundColor: AppColors.successGreen,
                          ));
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ErrorParser.parse(e)),
                            backgroundColor: AppColors.dangerRose,
                          ));
                        }
                      }
                    },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.signal),
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Grade'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final effectiveAssignment =
        kReleaseMode ? null : widget.initialAssignment;
    final effectiveAttempts =
        kReleaseMode ? null : widget.initialExamAttempts;
    if (effectiveAssignment != null) {
      _assignment = effectiveAssignment;
      _examAttempts = effectiveAttempts ?? [];
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _assignment = await CourseRepository()
          .getAssignment(widget.courseId, widget.assignmentId);
      await _loadSubmissions();
      final role =
          ref.read(authProvider).valueOrNull?['role'] as String? ?? 'student';
      if ((role == 'professor' || role == 'admin' || role == 'ta') &&
          (_isTimedExam || _examAttempts.isNotEmpty)) {
        _startProctorRefresh();
      }
    } catch (e) {
      _error = ErrorParser.parse(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSubmissions() async {
    final role =
        ref.read(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin' || role == 'ta';
    if (isProf && _submissionsLoading) return;
    try {
        if (isProf) {
          try {
            _assignmentAppeals = await CourseRepository().getAssignmentAppeals(widget.assignmentId);
          } catch (_) {}
        } else if (_mySubmission != null && _mySubmission!['id'] != null) {
          try {
            _studentAppeal = await CourseRepository().getSubmissionAppeal(_mySubmission!['id'] as int);
          } catch (_) {}
        }

      if (isProf) {
        if (mounted) {
          setState(() {
            _submissionsLoading = true;
            _proctorError = null;
          });
        }
        final res = await CourseRepository()
            .listSubmissions(widget.courseId, widget.assignmentId);
        var attempts = _examAttempts;
        String? proctorError;
        try {
          attempts = normalizeProctorAttempts(await CourseRepository()
              .listExamAttempts(widget.courseId, widget.assignmentId));
        } catch (e) {
          proctorError = ErrorParser.parse(e);
        }
        if (mounted) {
          setState(() {
            _examAttempts = attempts;
            _proctorError = proctorError;
            _submissions = (res['submissions'] as List<dynamic>)
                .cast<Map<String, dynamic>>();
            _pendingCount = res['pending_count'] as int? ?? 0;
            _gradedCount = res['graded_count'] as int? ?? 0;
            _submissionsLoading = false;
          });
        }
      } else {
        // Student: fetch own submission
        setState(() => _submissionLoading = true);
        final mySub = await CourseRepository()
            .getMySubmission(widget.courseId, widget.assignmentId);
        if (mounted)
          setState(() {
            _mySubmission = mySub;
            _submissionLoading = false;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _submissionsLoading = false;
          _submissionLoading = false;
        });
    }
  }

  void _startProctorRefresh() {
    _proctorRefreshTimer?.cancel();
    _proctorRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_submissionsLoading) _loadSubmissions();
    });
  }

  Map<String, dynamic>? _attemptForStudent(dynamic studentId) {
    for (final attempt in _examAttempts) {
      if (attempt['student_id'] == studentId) return attempt;
    }
    return null;
  }

  Widget _violationIcon(String type) {
    switch (type) {
      case 'fullscreen_exit':
        return const Icon(Icons.fullscreen_exit_rounded,
            size: 16, color: Colors.red);
      case 'tab_switch':
        return const Icon(Icons.tab_unselected_rounded,
            size: 16, color: Colors.orange);
      case 'window_blur':
        return const Icon(Icons.visibility_off_rounded,
            size: 16, color: Colors.orange);
      case 'copy_paste':
        return const Icon(Icons.content_paste_off_rounded,
            size: 16, color: Colors.deepOrange);
      case 'multi_monitor':
        return const Icon(Icons.desktop_windows_rounded,
            size: 16, color: Colors.purple);
      case 'heartbeat_missed':
        return const Icon(Icons.wifi_off_rounded,
            size: 16, color: Colors.redAccent);
      case 'auto_close':
        return const Icon(Icons.timer_off_rounded,
            size: 16, color: Colors.brown);
      default:
        return const Icon(Icons.warning_amber_rounded,
            size: 16, color: Colors.amber);
    }
  }

  String _violationLabel(String type) {
    switch (type) {
      case 'fullscreen_exit':
        return 'Fullscreen Exit';
      case 'tab_switch':
        return 'Tab Switch';
      case 'window_blur':
        return 'Window Blur';
      case 'copy_paste':
        return 'Copy/Paste Blocked';
      case 'multi_monitor':
        return 'Multi-Monitor Setup';
      case 'heartbeat_missed':
        return 'Heartbeat Missed (Offline)';
      case 'auto_close':
        return 'Auto-Closed by Server';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatAuditTime(String str) {
    try {
      final dt = DateTime.parse(str).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      final sec = dt.second.toString().padLeft(2, '0');
      return '$hour:$min:$sec $ampm';
    } catch (_) {
      return str.length > 19 ? str.substring(11, 19) : str;
    }
  }

  Future<void> _exportExamCsv() async {
    try {
      final csvData = await CourseRepository().exportExamCsv(
        courseId: widget.courseId,
        aid: widget.assignmentId,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.table_chart_outlined, color: AppColors.primaryIndigo),
                SizedBox(width: 8),
                Text('Exam Proctoring Audit CSV'),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: 350,
              child: SelectableText(
                csvData,
                style: GoogleFonts.jetBrainsMono(fontSize: 12),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download CSV File'),
                onPressed: () {
                  triggerBrowserDownload(
                    csvData,
                    'exam_proctor_audit_assignment_${widget.assignmentId}.csv',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Downloading CSV file...'),
                    backgroundColor: AppColors.successGreen,
                  ));
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy CSV'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: csvData));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('CSV copied to clipboard!'),
                    backgroundColor: AppColors.successGreen,
                  ));
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  Future<void> _showExamSettingsDialog() async {
    final hasAttempts = _examAttempts.isNotEmpty;
    final timeLimitCtrl = TextEditingController(
      text: (_assignment?['time_limit_minutes'] ?? 60).toString(),
    );
    final flagLimitCtrl = TextEditingController(
      text: (_assignment?['strike_limit_flag'] ?? 3).toString(),
    );
    final autoSubmitCtrl = TextEditingController(
      text: (_assignment?['strike_limit_autosubmit'] ?? 5).toString(),
    );
    bool fullscreenRequired = _assignment?['fullscreen_required'] ?? true;
    bool blockCopyPaste = _assignment?['block_copy_paste'] ?? true;
    String unsupportedPolicy =
        _assignment?['unsupported_browser_policy'] ?? 'warn_allow';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security_rounded, color: AppColors.primaryIndigo),
              SizedBox(width: 8),
              Text('Exam Proctoring Settings'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasAttempts) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_rounded, size: 20, color: Colors.amber.shade900),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Settings Locked: Student exam attempts have already started. Proctoring parameters cannot be altered mid-exam to ensure test integrity.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: timeLimitCtrl,
                    enabled: !hasAttempts,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Time Limit (minutes)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: flagLimitCtrl,
                    enabled: !hasAttempts,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Strikes Threshold to Flag (default: 3)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: autoSubmitCtrl,
                    enabled: !hasAttempts,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Strikes Threshold to Auto-Submit (default: 5)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Require Fullscreen Focus Mode'),
                    value: fullscreenRequired,
                    onChanged: hasAttempts
                        ? null
                        : (v) => setDialogState(() => fullscreenRequired = v),
                  ),
                  SwitchListTile(
                    title: const Text('Block Copy & Paste Events'),
                    value: blockCopyPaste,
                    onChanged: hasAttempts
                        ? null
                        : (v) => setDialogState(() => blockCopyPaste = v),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: unsupportedPolicy,
                    decoration: const InputDecoration(
                      labelText: 'Unsupported Browser Policy',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'warn_allow',
                        child: Text('Warn and Allow (Allow access with warning)'),
                      ),
                      DropdownMenuItem(
                        value: 'block',
                        child: Text('Strict Block (Require Chrome / Edge)'),
                      ),
                    ],
                    onChanged: hasAttempts
                        ? null
                        : (v) {
                            if (v != null) setDialogState(() => unsupportedPolicy = v);
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: hasAttempts
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      try {
                        await CourseRepository().updateExamSettings(
                          courseId: widget.courseId,
                          aid: widget.assignmentId,
                          settings: {
                            'time_limit_minutes':
                                int.tryParse(timeLimitCtrl.text) ?? 60,
                            'strike_limit_flag':
                                int.tryParse(flagLimitCtrl.text) ?? 3,
                            'strike_limit_autosubmit':
                                int.tryParse(autoSubmitCtrl.text) ?? 5,
                            'fullscreen_required': fullscreenRequired,
                            'block_copy_paste': blockCopyPaste,
                            'unsupported_browser_policy': unsupportedPolicy,
                          },
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Exam proctoring settings saved successfully.'),
                            backgroundColor: AppColors.successGreen,
                          ));
                          final updated = await CourseRepository()
                              .getAssignment(widget.courseId, widget.assignmentId);
                          if (mounted) setState(() => _assignment = updated);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Failed to save settings: $e'),
                            backgroundColor: AppColors.dangerRose,
                          ));
                        }
                      }
                    },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordAttemptDecisionDialog(
      int attemptId, String action, String actionTitle) async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm $actionTitle'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please provide a mandatory instructor rationale for "$actionTitle":',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'A mandatory reason of at least 3 characters is required.';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  hintText: 'e.g. Technical glitch verified / Disqualification confirmed / Retake authorized due to outage...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'invalidate'
                  ? AppColors.dangerRose
                  : (action == 'accept'
                      ? AppColors.successGreen
                      : (action == 'allow_retake'
                          ? Colors.orange.shade800
                          : AppColors.primaryIndigo)),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (formKey.currentState?.validate() != true) return;
              Navigator.pop(ctx);
              try {
                await CourseRepository().recordExamDecision(
                  courseId: widget.courseId,
                  aid: widget.assignmentId,
                  attemptId: attemptId,
                  action: action,
                  reason: reasonCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Decision "$actionTitle" recorded successfully.'),
                    backgroundColor: AppColors.successGreen,
                  ));
                  _loadSubmissions();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to record decision: $e'),
                    backgroundColor: AppColors.dangerRose,
                  ));
                }
              }
            },
            child: Text('Confirm $actionTitle'),
          ),
        ],
      ),
    );
  }

  Future<void> _manageExamAttemptDialog(
      Map<String, dynamic> sub, Map<String, dynamic> attempt) async {
    final studentName = sub['student_name'] ?? attempt['student_name'] ?? 'Student';
    final studentEmail = sub['student_email'] ?? attempt['student_email'] ?? '';
    final isFlagged = attempt['is_flagged'] == true;
    final switchCount = attempt['strike_count'] ?? attempt['tab_switch_count'] ?? 0;
    final attemptId = attempt['id'] as int;
    final attemptNumber = attempt['attempt_number'] ?? 1;
    final autoSubmitted = attempt['auto_submitted'] == true;
    final currentRole = ref.read(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final canAdjudicate = currentRole == 'professor' || currentRole == 'admin';
    final status = attempt['status'] ?? (attempt['submitted_at'] != null ? 'submitted' : 'active');
    final isLive = attempt['is_live'] == true;
    final secondsSinceHb = attempt['seconds_since_heartbeat'];
    final violations = (attempt['violations'] as List<dynamic>? ?? [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    final decision = attempt['decision'] as String?;
    final decisionReason = attempt['decision_reason'] as String?;
    final reviewerName = attempt['reviewed_by_name'] as String?;
    final reviewedAt = attempt['reviewed_at'] as String?;

    String statusLabel = 'ACTIVE';
    Color statusColor = AppColors.primaryIndigo;
    if (status == 'auto_submitted' || autoSubmitted) {
      statusLabel = 'AUTO-SUBMITTED';
      statusColor = Colors.orange.shade800;
    } else if (status == 'submitted') {
      statusLabel = 'SUBMITTED';
      statusColor = AppColors.successGreen;
    } else if (status == 'offline') {
      statusLabel = 'OFFLINE';
      statusColor = Colors.orange;
    } else if (isLive) {
      statusLabel = 'LIVE (${secondsSinceHb ?? 0}s)';
      statusColor = AppColors.successGreen;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.primaryIndigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Proctor Audit: $studentName (Attempt #$attemptNumber)',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (studentEmail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Student Email: $studentEmail',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkSecondary),
                    ),
                  ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFlagged
                            ? AppColors.dangerRose.withOpacity(0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$switchCount Strikes recorded',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isFlagged
                              ? AppColors.dangerRose
                              : AppColors.inkPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (decision != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: decision == 'accept'
                          ? AppColors.successGreen.withOpacity(0.08)
                          : (decision == 'invalidate'
                              ? AppColors.dangerRose.withOpacity(0.08)
                              : Colors.orange.withOpacity(0.08)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: decision == 'accept'
                            ? AppColors.successGreen.withOpacity(0.4)
                            : (decision == 'invalidate'
                                ? AppColors.dangerRose.withOpacity(0.4)
                                : Colors.orange.withOpacity(0.4)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recorded Decision: ${decision.toUpperCase()}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: decision == 'accept'
                                ? AppColors.successGreen
                                : (decision == 'invalidate'
                                    ? AppColors.dangerRose
                                    : Colors.orange.shade900),
                          ),
                        ),
                        if (decisionReason != null && decisionReason.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: $decisionReason',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkPrimary),
                          ),
                        ],
                        if (reviewerName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Reviewed by: $reviewerName (${reviewedAt ?? ''})',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      isFlagged
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                      color: isFlagged
                          ? AppColors.dangerRose
                          : AppColors.successGreen,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isFlagged
                            ? "FLAGGED: ${attempt['flag_reason'] ?? 'Exceeded strike threshold'}"
                            : "Clean / In Good Standing",
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isFlagged
                                ? AppColors.dangerRose
                                : AppColors.successGreen),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Violation Event Timeline (${violations.length})',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (violations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No violations recorded during this attempt. Fully clean session.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.inkGhost),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: violations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final v = violations[i];
                        final vType = v['violation_type'] ?? 'unknown';
                        final details = v['details'] ?? '';
                        final timeStr = v['occurred_at'] != null
                            ? _formatAuditTime(v['occurred_at'].toString())
                            : '';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppColors.border.withOpacity(0.6)),
                          ),
                          child: Row(
                            children: [
                              _violationIcon(vType),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _violationLabel(vType),
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.inkPrimary,
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (details.isNotEmpty)
                                      Text(
                                        details,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Instructor Review Actions:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '• Accept: Validates attempt and verifies student submission.\n'
                  '• Invalidate: Disqualifies attempt due to confirmed academic violations.\n'
                  '• Allow Retake: Grants an authorized fresh retake attempt (Attempt #2).\n'
                  '• Clear Flags: Clears strikes counter while preserving complete audit logs.',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.inkSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (canAdjudicate) ...[
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _recordAttemptDecisionDialog(attemptId, 'clear', 'Clear Flags');
              },
              child: const Text('Clear Flags'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _recordAttemptDecisionDialog(attemptId, 'allow_retake', 'Allow Retake (Attempt 2)');
              },
              child: const Text('Allow Retake'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerRose,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _recordAttemptDecisionDialog(attemptId, 'invalidate', 'Invalidate Attempt');
              },
              child: const Text('Invalidate Attempt'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _recordAttemptDecisionDialog(attemptId, 'accept', 'Accept Attempt');
              },
              child: const Text('Accept Attempt'),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'View-only (Instructor Adjudication Required)',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null)
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    if (_assignment == null) return const SizedBox.shrink();

    final a = _assignment!;
    final role =
        ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final isProf = role == 'professor' || role == 'admin' || role == 'ta';
    final canManageAssignment = role == 'professor' || role == 'admin';

    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final bgPage = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        title: ProfBreadcrumbs(
          items: [
            const BreadcrumbItem(label: 'Courses', path: '/courses'),
            BreadcrumbItem(
              label: 'Course',
              path: '/courses/${widget.courseId}',
            ),
            BreadcrumbItem(label: a['title'] ?? 'Assignment'),
          ],
        ),
        actions: [
          if (canManageAssignment && a['status'] == 'draft')
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
                if (a['time_limit_minutes'] != null &&
                    (a['time_limit_minutes'] as num) > 0) ...[
                  ProfBadge(
                    icon: Icons.timer_outlined,
                    label: '${a['time_limit_minutes']} MINS (PROCTORED)',
                    color: AppColors.primaryIndigo,
                  ),
                ],
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
                  final pendingCount = _pendingCount > 0
                      ? _pendingCount
                      : _submissions
                          .where((s) => s['status'] == 'pending')
                          .length;
                  final gradedCount = _gradedCount > 0
                      ? _gradedCount
                      : _submissions
                          .where((s) => s['status'] == 'graded')
                          .length;
                  final gradedScores = _submissions
                      .where(
                          (s) => s['status'] == 'graded' && s['score'] != null)
                      .map((s) => s['score'] as double)
                      .toList();
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
                              value: '$totalCount', label: 'Submissions')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$pendingCount', label: 'Pending Review')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: '$gradedCount', label: 'Graded')),
                      SizedBox(
                          width: 200,
                          child: ProfStatCard(
                              value: avgScoreStr, label: 'Average Score')),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (isProf && (_isTimedExam || _examAttempts.isNotEmpty)) ...[
                _buildLiveProctorConsole(),
                const SizedBox(height: 24),
              ],
            ],

            // Submissions & Rubric (Side by Side on desktop)
            LayoutBuilder(
              builder: (ctx, constraints) {
                final studentEmail =
                    ref.watch(authProvider).valueOrNull?['email'] ?? '';
                final submissionWidget = isProf
                    ? _buildSubmissionsList()
                    : _buildStudentSubmissionView(studentEmail);

                if (constraints.maxWidth > 920) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: submissionWidget),
                      const SizedBox(width: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 360),
                        child: SizedBox(
                          width: constraints.maxWidth * 0.38,
                          child: _buildRubric(a['has_rubric'] == true),
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRubric(a['has_rubric'] == true),
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
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkPrimary)),
          const SizedBox(height: 16),
          rubricAsync.when(
            loading: () => ProfShimmer.lines(count: 3),
            error: (e, _) => Text(ErrorParser.parse(e)),
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
                  return Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      iconColor: AppColors.inkPrimary,
                      collapsedIconColor: AppColors.inkSecondary,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Row(
                        children: [
                          Expanded(
                              child: Text(c['name'],
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkPrimary))),
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
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.inkPrimary))),
                                Expanded(
                                    child: Text(l['description'] ?? '',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppColors.textSecondary))),
                              ],
                            ),
                          ))),
                    ],
                    ),
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
    final pendingCount =
        _submissions.where((s) => s['status'] == 'pending').length;
    final filteredSubmissions = _submissions.where((submission) {
      final needsReview = submission['needs_review'] == true ||
          _triageReasons(submission).isNotEmpty;
      switch (_submissionFilter) {
        case 'flagged_anticheat':
          final att = _attemptForStudent(submission['student_id']);
          return att?['is_flagged'] == true || (att?['tab_switch_count'] ?? 0) > 0;
        case 'needs_review':
          return needsReview;
        case 'prompt_injection':
          return _triageReasons(submission).contains('injection_detected');
        case 'unreadable':
          return _triageReasons(submission).any((reason) =>
              reason == 'blank_or_unreadable' ||
              reason == 'scanned_or_image_only');
        case 'ungraded':
          return submission['status'] != 'graded';
        case 'graded':
          return submission['status'] == 'graded';
        default:
          return true;
      }
    }).toList();
    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Submissions (${_submissions.length})',
                      style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: AppColorsLight.inkTitle)),
                  if (_submissionsLoading) ...[
                    const SizedBox(width: 10),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SubmissionTriageFilterChips(
                    selected: _submissionFilter,
                    onSelected: (filter) =>
                        setState(() => _submissionFilter = filter),
                  ),
                  IconButton(
                    tooltip: 'Refresh Submissions & Proctor Flags',
                    icon: _submissionsLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: _submissionsLoading ? null : _loadSubmissions,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      foregroundColor: AppColors.primaryIndigo,
                    ),
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: Text(
                      'Appeals (${_assignmentAppeals.length})',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _openAppealsManagementDialog,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(
                      'Export CSV',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _exportGradesCsv,
                  ),
                  if (pendingCount > 0)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: _batchGrading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome,
                              size: 16, color: Colors.white),
                      label: Text(
                        _batchGrading
                            ? 'AI Batch Grading...'
                            : 'Batch AI Grade ($pendingCount Pending)',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      onPressed: _batchGrading ? null : _runBatchAiGrading,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredSubmissions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _submissions.isEmpty
                      ? 'No submissions yet for this assignment.'
                      : 'No submissions match this filter.',
                  style: GoogleFonts.inter(color: AppColors.textMuted),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSubmissions.length,
              itemBuilder: (context, index) {
                final sub = filteredSubmissions[index];
                final originalIndex = _submissions.indexOf(sub);
                final isGraded = sub['status'] == 'graded';
                final sid = sub['id'] as int;
                final isAiGrading = _gradingSubmissionIds.contains(sid);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => SpeedGraderScreen(
                          submissions: _submissions,
                          initialIndex: originalIndex,
                          assignmentId: widget.assignmentId,
                          onSave: (idx, updatedSub) {
                            setState(() {
                              _submissions[idx] = updatedSub;
                            });
                          },
                        ),
                      ));
                      await _loadSubmissions();
                    },
                    child: IntrinsicHeight(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: index == 0
                                ? const BorderSide(
                                    color: AppColors.marginRule, width: 1)
                                : BorderSide.none,
                            bottom: const BorderSide(
                                color: AppColors.marginRule, width: 1),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.surfaceHigh,
                                      child: Text(
                                        (sub['student_name'] ?? 'S')
                                            .toString()
                                            .trim()
                                            .split(' ')
                                            .map(
                                                (n) => n.isNotEmpty ? n[0] : '')
                                            .take(2)
                                            .join()
                                            .toUpperCase(),
                                        style: GoogleFonts.dmSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.inkPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(sub['student_name'] ?? 'Student',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.inkPrimary)),
                                          const SizedBox(height: 2),
                                          Text(sub['student_email'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.dmSans(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.inkSecondary)),
                                          if (sub['needs_review'] == true) ...[
                                            const SizedBox(height: 5),
                                            SubmissionTriageBadges(
                                                submission: sub),
                                          ],
                                          if (_attemptForStudent(
                                                  sub['student_id']) !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            Builder(builder: (ctx) {
                                              final att = _attemptForStudent(
                                                  sub['student_id']);
                                              final isFlagged =
                                                  att?['is_flagged'] == true;
                                              final switches =
                                                  att?['tab_switch_count'] ?? 0;
                                              return InkWell(
                                                borderRadius: BorderRadius.circular(4),
                                                onTap: () => _manageExamAttemptDialog(sub, att!),
                                                child: Tooltip(
                                                  message: 'Click to audit or manage attempt',
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isFlagged
                                                          ? AppColorsLight.statusCriticalBg
                                                          : AppColorsLight.statusPassBg,
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(
                                                        color: isFlagged
                                                            ? AppColorsLight.statusCriticalBorder
                                                            : AppColorsLight.statusPassBorder,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          isFlagged
                                                              ? 'Flagged: $switches switches'
                                                              : 'Clean ($switches switches)',
                                                          style: GoogleFonts.dmSans(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: isFlagged
                                                                ? AppColors.dangerRose
                                                                : AppColors.successGreen,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Icon(
                                                          Icons.tune_rounded,
                                                          size: 11,
                                                          color: isFlagged
                                                              ? AppColors.dangerRose
                                                              : AppColors.successGreen,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius:
                                            BorderRadius.circular(AppRadius.r4),
                                        border: Border.all(
                                            color: AppColors.rule, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.schedule_rounded,
                                              size: 13,
                                              color: AppColors.inkGhost),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatSubmissionDate(
                                                sub['submitted_at']),
                                            style: GoogleFonts.dmSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.inkSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      onPressed: () => _openGradingDialog(sub),
                                      icon: const Icon(
                                          Icons.rate_review_outlined,
                                          size: 15,
                                          color: AppColors.inkPrimary),
                                      label: Text(
                                        'Grade',
                                        style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.inkPrimary),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: AppColors.rule, width: 0.8),
                                        backgroundColor: AppColors.surface,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        minimumSize: const Size(0, 32),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(6)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      tooltip:
                                          'Auto-grade with AI',
                                      icon: isAiGrading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.signal))
                                          : const Icon(Icons.auto_awesome,
                                              color: AppColors.signal,
                                              size: 18),
                                      onPressed: isAiGrading
                                          ? null
                                          : () => _aiGradeSingleSubmission(sub),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            MarginaliaStrip(
                              statusLabel: sub['needs_review'] == true
                                  ? 'Needs Review'
                                  : isGraded
                                      ? 'Graded'
                                      : 'Queued',
                              statusColor: sub['needs_review'] == true
                                  ? AppColors.accentAmber
                                  : isGraded
                                      ? AppColors.feedbackRed
                                      : AppColors.pending,
                              score: sub['score'] != null
                                  ? '${sub['score']}'
                                  : '--',
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

  bool get _isTimedExam {
    final type = _assignment?['type']?.toString().toLowerCase() ?? '';
    final limit = _assignment?['time_limit_minutes'] as int?;
    return (limit != null && limit > 0) || type == 'quiz' || type == 'exam' || type == 'mcq';
  }

  Widget _buildLiveProctorConsole() {
    final currentRole = ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    final canManageSettings = currentRole == 'professor' || currentRole == 'admin';

    final hasAttempts = _examAttempts.isNotEmpty;
    final totalCount = _examAttempts.length;
    final activeCount = _examAttempts.where((a) => a['status'] == 'active').length;
    final offlineCount = _examAttempts.where((a) => a['status'] == 'offline').length;
    final submittedCount = _examAttempts.where((a) => a['status'] == 'submitted').length;
    final autoSubmittedCount = _examAttempts.where((a) => a['auto_submitted'] == true || a['status'] == 'auto_submitted').length;
    final flaggedCount = _examAttempts.where((a) => a['is_flagged'] == true).length;

    final filteredAttempts = _examAttempts.where((att) {
      switch (_examAttemptFilter) {
        case 'flagged':
          return att['is_flagged'] == true;
        case 'auto_submitted':
          return att['auto_submitted'] == true || att['status'] == 'auto_submitted';
        case 'has_violations':
          final strikes = att['strike_count'] ?? att['tab_switch_count'] ?? 0;
          return strikes > 0;
        case 'active':
          return att['status'] == 'active';
        case 'offline':
          return att['status'] == 'offline';
        case 'all':
        default:
          return true;
      }
    }).toList();

    final searchQuery = _examAttemptSearchCtrl.text.trim().toLowerCase();
    final searchFilteredAttempts = filteredAttempts.where((att) {
      if (searchQuery.isEmpty) return true;
      final name = (att['student_name'] ?? '').toString().toLowerCase();
      final email = (att['student_email'] ?? '').toString().toLowerCase();
      final sid = (att['student_id'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery) ||
          email.contains(searchQuery) ||
          sid.contains(searchQuery);
    }).toList();

    final totalPages =
        (searchFilteredAttempts.length / _examAttemptPageSize).ceil().clamp(1, 99999);
    final currentPage = _examAttemptPage.clamp(1, totalPages);
    final paginatedAttempts = searchFilteredAttempts
        .skip((currentPage - 1) * _examAttemptPageSize)
        .take(_examAttemptPageSize)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: AppColors.rule, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 20, color: AppColors.primaryIndigo),
                    const SizedBox(width: 10),
                    Text(
                      'Live Proctoring Console',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    if (canManageSettings) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: const Text('Proctor Settings', style: TextStyle(fontSize: 12)),
                        onPressed: _showExamSettingsDialog,
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('Export CSV Audit', style: TextStyle(fontSize: 12)),
                      onPressed: _exportExamCsv,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Refresh Proctoring Feed',
                      onPressed: _loadSubmissions,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Summary Metrics Strip
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildProctorMetricChip('Total Sessions', '$totalCount', AppColors.inkPrimary, AppColors.surface),
                const SizedBox(width: 8),
                _buildProctorMetricChip('Active (Live)', '$activeCount', AppColors.successGreen, AppColors.successGreen.withOpacity(0.08)),
                const SizedBox(width: 8),
                _buildProctorMetricChip('Offline', '$offlineCount', Colors.orange.shade800, Colors.orange.shade50),
                const SizedBox(width: 8),
                _buildProctorMetricChip('Finished', '$submittedCount', AppColors.primaryIndigo, AppColors.primaryIndigo.withOpacity(0.08)),
                const SizedBox(width: 8),
                _buildProctorMetricChip('Auto-Submitted', '$autoSubmittedCount', Colors.deepOrange, Colors.deepOrange.withOpacity(0.08)),
                const SizedBox(width: 8),
                _buildProctorMetricChip('Flagged', '$flaggedCount', AppColors.dangerRose, AppColors.dangerRose.withOpacity(0.1)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Post-Exam Filter Selector
          Row(
            children: [
              Text(
                'Filter: ',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSecondary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildExamFilterChip('all', 'All ($totalCount)'),
                      const SizedBox(width: 6),
                      _buildExamFilterChip('flagged', 'Flagged ($flaggedCount)'),
                      const SizedBox(width: 6),
                      _buildExamFilterChip('auto_submitted', 'Auto-Submitted ($autoSubmittedCount)'),
                      const SizedBox(width: 6),
                      _buildExamFilterChip('has_violations', 'Has Violations'),
                      const SizedBox(width: 6),
                      _buildExamFilterChip('active', 'Active ($activeCount)'),
                      const SizedBox(width: 6),
                      _buildExamFilterChip('offline', 'Offline ($offlineCount)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _examAttemptSearchCtrl,
                    onChanged: (_) => setState(() => _examAttemptPage = 1),
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search attempts by student name or ID...',
                      hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.inkGhost),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16),
                      suffixIcon: _examAttemptSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 14),
                              onPressed: () {
                                _examAttemptSearchCtrl.clear();
                                setState(() => _examAttemptPage = 1);
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      fillColor: AppColors.canvas,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.rule, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppColors.rule, width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Showing ${paginatedAttempts.length} of ${searchFilteredAttempts.length}',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.inkSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_proctorError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Live tracking unavailable: $_proctorError',
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.dangerRose),
              ),
            ),
          if (!hasAttempts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty_rounded, size: 16, color: AppColors.inkGhost),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No student sessions initiated yet. As students start, their live focus status and tab switches appear here.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary),
                    ),
                  ),
                ],
              ),
            )
          else if (searchFilteredAttempts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No exam attempts match the active filter or search query.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: paginatedAttempts.map((att) {
                final isFlagged = att['is_flagged'] == true;
                final strikes = att['strike_count'] ?? att['tab_switch_count'] ?? 0;
                final baseline = att['reviewed_strike_baseline'] ?? 0;
                final activeStrikes = strikes > baseline ? strikes - baseline : 0;
                final biometric = att['biometric_status'] as String?;
                final flagReason = att['flag_reason'] as String? ?? '';
                final isOfflineOnly = flagReason.contains('[OFFLINE]');
                final autoSubmitted = att['auto_submitted'] == true;
                final status = att['status'] ?? (att['submitted_at'] != null ? 'submitted' : 'active');
                final isLive = att['is_live'] == true;
                final secondsSinceHb = att['seconds_since_heartbeat'];
                final sName = att['student_name'] ?? 'Student #${att['student_id']}';
                final attemptNumber = att['attempt_number'] ?? 1;
                final decision = att['decision'] as String?;

                String statusBadgeText;
                Color statusColor;
                IconData statusIcon;

                if (autoSubmitted || status == 'auto_submitted') {
                  statusBadgeText = 'Auto-Submitted';
                  statusColor = Colors.orange.shade800;
                  statusIcon = Icons.timer_off_rounded;
                } else if (status == 'submitted') {
                  statusBadgeText = 'Finished';
                  statusColor = AppColors.successGreen;
                  statusIcon = Icons.check_circle_outline_rounded;
                } else if (isLive || status == 'active') {
                  statusBadgeText = secondsSinceHb != null ? 'Live (${secondsSinceHb}s)' : 'Live';
                  statusColor = AppColors.successGreen;
                  statusIcon = Icons.play_circle_outline_rounded;
                } else {
                  statusBadgeText = secondsSinceHb != null ? 'Offline (${secondsSinceHb}s)' : 'Offline';
                  statusColor = Colors.orange;
                  statusIcon = Icons.wifi_off_rounded;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFlagged
                        ? (isOfflineOnly ? Colors.orange.shade50 : AppColorsLight.statusCriticalBg)
                        : AppColors.canvas,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFlagged
                          ? (isOfflineOnly ? Colors.orange.shade300 : AppColorsLight.statusCriticalBorder)
                          : AppColors.rule,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFlagged
                            ? (isOfflineOnly ? Icons.wifi_off_rounded : Icons.warning_amber_rounded)
                            : statusIcon,
                        size: 16,
                        color: isFlagged
                            ? (isOfflineOnly ? Colors.orange.shade800 : AppColors.dangerRose)
                            : statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$sName (#$attemptNumber)',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isFlagged
                              ? (isOfflineOnly ? Colors.orange.shade900 : AppColors.dangerRose)
                              : AppColors.inkPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFlagged
                              ? (isOfflineOnly ? Colors.orange.withOpacity(0.12) : AppColors.dangerRose.withOpacity(0.12))
                              : statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$statusBadgeText • $activeStrikes strikes${baseline > 0 ? ' (+$baseline base)' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isFlagged
                                ? (isOfflineOnly ? Colors.orange.shade900 : AppColors.dangerRose)
                                : statusColor,
                          ),
                        ),
                      ),
                      if (biometric != null && biometric.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: biometric == 'passed'
                                ? AppColors.successGreen.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'BIO: ${biometric.toUpperCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: biometric == 'passed' ? AppColors.successGreen : AppColors.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                      if (decision != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryIndigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.3)),
                          ),
                          child: Text(
                            decision.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryIndigo,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          final matchedSub = _submissions.firstWhere(
                            (s) => s['student_id'] == att['student_id'],
                            orElse: () => {
                              'id': 0,
                              'student_id': att['student_id'],
                              'student_name': sName,
                              'student_email': att['student_email'] ?? '',
                              'status': status,
                            },
                          );
                          _manageExamAttemptDialog(matchedSub, att);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.rule, width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_rounded, size: 12, color: AppColors.inkPrimary),
                              const SizedBox(width: 4),
                              Text(
                                'Audit & Decision',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (totalPages > 1) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  onPressed: currentPage > 1
                      ? () => setState(() => _examAttemptPage = currentPage - 1)
                      : null,
                ),
                Text(
                  'Page $currentPage of $totalPages',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  onPressed: currentPage < totalPages
                      ? () => setState(() => _examAttemptPage = currentPage + 1)
                      : null,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProctorMetricChip(String label, String value, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.inkSecondary),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildExamFilterChip(String key, String label) {
    final isSelected = _examAttemptFilter == key;
    return InkWell(
      onTap: () => setState(() => _examAttemptFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryIndigo : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryIndigo : AppColors.rule,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.inkSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildStudentSubmissionView(String studentEmail) {
    final sub = _mySubmission ?? <String, dynamic>{};

    final hasSubmitted = sub.isNotEmpty;
    final isGraded = hasSubmitted && sub['status'] == 'graded';
    final assignmentType =
        _assignment?['type']?.toString().toLowerCase() ?? 'text';
    final timeLimitMinutes = _assignment?['time_limit_minutes'] as int?;
    final isQuizOrExam = assignmentType == 'quiz' ||
        assignmentType == 'exam' ||
        assignmentType == 'mcq' ||
        (timeLimitMinutes != null && timeLimitMinutes > 0);

    final deadlineRaw = _assignment?['deadline'];
    DateTime? deadline;
    if (deadlineRaw != null) {
      deadline = DateTime.tryParse(deadlineRaw.toString());
    }
    final now = DateTime.now();
    final isPastDeadline = deadline != null && now.isAfter(deadline);
    final allowLate = _assignment?['allow_late'] == true;
    final isAssignmentClosed =
        _assignment?['status']?.toString().toLowerCase() == 'closed';
    final isSubmissionClosed =
        isAssignmentClosed || (isPastDeadline && !allowLate);

    if (!hasSubmitted && isSubmissionClosed) {
      return ProfCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              const Icon(Icons.event_busy_rounded,
                  size: 48, color: AppColors.dangerRose),
              const SizedBox(height: 12),
              Text(
                'Submissions Closed',
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                isAssignmentClosed
                    ? 'This assignment has been closed for submissions by the instructor.'
                    : 'The submission deadline (${_formatSubmissionDate(deadlineRaw)}) has passed, and late submissions are not permitted.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.inkSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasSubmitted && isQuizOrExam) {
      final isQuiz = assignmentType == 'quiz' || assignmentType == 'mcq';
      return ProfCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPastDeadline && allowLate) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.accentAmber.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 20, color: AppColors.accentAmber),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notice: Late submission policy is active (${_assignment?['late_penalty_per_day'] ?? 0}% penalty/day).',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Text(isQuiz ? 'Quiz Assessment' : 'Timed Examination',
                style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkPrimary)),
            const SizedBox(height: 8),
            Text(
              isQuiz
                  ? 'This is an academic quiz assessment with structured questions. Click below to begin your attempt in focused assessment mode.'
                  : 'This is a timed examination (${timeLimitMinutes ?? 60} minutes). Once you start, the assessment begins and fullscreen focus mode is active.',
              style: GoogleFonts.dmSans(
                  color: AppColors.inkSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: isQuiz
                  ? (timeLimitMinutes != null && timeLimitMinutes > 0
                      ? 'Start Quiz Assessment ($timeLimitMinutes min)'
                      : 'Start Quiz Assessment')
                  : 'Start Exam (${timeLimitMinutes ?? 60} min)',
              onPressed: () {
                final targetType = (assignmentType == 'mcq' || isQuiz)
                    ? 'mcq'
                    : (_assignment!['type'] ?? 'text');
                context.push(
                  examRoutePath(widget.courseId, widget.assignmentId),
                  extra: examRouteExtra(
                    title: _assignment!['title'] ?? 'Assessment',
                    type: targetType,
                    description: _assignment!['description'] as String?,
                    maxMarks:
                        (_assignment!['max_marks'] as num?)?.toDouble() ?? 100.0,
                    timeLimitMinutes: timeLimitMinutes ?? (isQuiz ? 30 : 60),
                    randomizeQuestions:
                        _assignment!['randomize_questions'] as bool? ?? false,
                    showResultsAfter:
                        _assignment!['show_results_after'] as bool? ?? true,
                  ),
                ).then((_) => _loadSubmissions());
              },
            ),
          ],
        ),
      );
    }

    return ProfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My Submission',
              style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
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
                            color: isGraded
                                ? AppColors.successGreen
                                : AppColors.accentAmber,
                          ),
                          if (sub['retake_granted'] == true || sub['can_retake'] == true)
                            const ProfBadge(
                              label: 'Retake available',
                              color: AppColors.successGreen,
                            ),
                          if (sub['score'] != null)
                            ProfBadge(
                              label: '${sub['score']} pts',
                              color: AppColors.primaryIndigo,
                            ),
                        ],
                      ),
                      Text(
                        'Submitted ${_formatSubmissionDate(sub['submitted_at'])}',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (sub['retake_granted'] == true || sub['can_retake'] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.refresh_rounded, size: 16, color: AppColors.successGreen),
                              const SizedBox(width: 8),
                              Text(
                                'Retake available: Your instructor has authorized a retake attempt.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.successGreen,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () {
                              final targetType = (assignmentType == 'mcq' || isQuizOrExam)
                                  ? 'mcq'
                                  : (_assignment!['type'] ?? 'text');
                              context.push(
                                examRoutePath(widget.courseId, widget.assignmentId),
                                extra: examRouteExtra(
                                  title: _assignment!['title'] ?? 'Assessment',
                                  type: targetType,
                                  description: _assignment!['description'] as String?,
                                  maxMarks: (_assignment!['max_marks'] as num?)?.toDouble() ?? 100.0,
                                  timeLimitMinutes: timeLimitMinutes ?? 60,
                                  randomizeQuestions: _assignment!['randomize_questions'] as bool? ?? false,
                                  showResultsAfter: _assignment!['show_results_after'] as bool? ?? true,
                                ),
                              ).then((_) => _loadSubmissions());
                            },
                            child: const Text('Start Retake Attempt', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Submitted Content:',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.inkSecondary)),
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
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      color: AppColors.primaryIndigo, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                        sub['file_name'] ??
                                            sub['content'] ??
                                            '',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _downloadSubmissionFile(
                                  sub['id'] as int,
                                  sub['file_name'] ??
                                      sub['content'] ??
                                      'submission_file',
                                ),
                                icon: const Icon(Icons.download_rounded,
                                    size: 16),
                                label: const Text('Download Submitted File'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  textStyle: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          )
                        : sub['submission_type'] == 'programming'
                            ? Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.canvas,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.rule),
                                ),
                                child: Text(
                                  sub['content'] ?? '',
                                  style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      color: AppColors.inkPrimary),
                                ),
                              )
                            : SelectableText(
                                sub['content'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: AppColors.inkPrimary,
                                  height: 1.5,
                                ),
                              ),
                  ),
                  if (isGraded &&
                      sub['feedback'] != null &&
                      sub['feedback'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'Instructor Feedback',
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
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
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                  // AI Evaluation / Rubric Breakdown
                  Builder(builder: (context) {
                    Map<String, dynamic>? metadata;
                    if (sub['evaluation_metadata'] is Map<String, dynamic>) {
                      metadata = sub['evaluation_metadata'];
                    } else if (sub['evaluation_metadata'] is String &&
                        sub['evaluation_metadata'].toString().isNotEmpty) {
                      try {
                        metadata = jsonDecode(sub['evaluation_metadata'])
                            as Map<String, dynamic>;
                      } catch (_) {}
                    }
                    if (metadata != null &&
                        (metadata['criteria_evaluations'] is List ||
                            metadata['diagnostic_reasoning'] != null)) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildStudentDiagnosticCard(metadata, sub),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 16),
                  if (isGraded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 18, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Grades have been finalized by your instructor. Submissions are closed.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isGraded) ...[
                      const SizedBox(height: 14),
                      _buildStudentAppealSection(sub),
                    ]
                  else if (isSubmissionClosed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRose.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.dangerRose.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.alarm_off_rounded,
                              size: 18, color: AppColors.dangerRose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The deadline for this assignment has passed and submissions are closed.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.dangerRose,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (isPastDeadline && allowLate)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Late resubmission active: ${_assignment?['late_penalty_per_day'] ?? 0}% penalty per day applies.',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.accentAmber,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (_assignment?['is_proctored'] != true &&
                        (_assignment?['time_limit_minutes'] == null ||
                            (_assignment?['time_limit_minutes'] as num) == 0))
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _mySubmission = null;
                          });
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'Re-opened submission form. Upload your updated work below.'),
                          ));
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Resubmit Assignment'),
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
                  if (isPastDeadline && allowLate)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.accentAmber.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 20, color: AppColors.accentAmber),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Notice: Late submission policy is active. Submissions after ${_formatSubmissionDate(deadlineRaw)} will incur a ${_assignment?['late_penalty_per_day'] ?? 0}% penalty per day up to ${_assignment?['max_penalty_cap'] ?? 100}%.',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.inkPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (assignmentType == 'file') ...[
                    Text('Upload PDF/ZIP Submission File',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'pdf',
                            'zip',
                            'docx',
                            'doc',
                            'txt',
                            'png',
                            'jpg',
                            'jpeg'
                          ],
                          withData: true,
                        );
                        if (result != null &&
                            result.files.single.bytes != null) {
                          final file = result.files.single;
                          const maxBytes = 25 * 1024 * 1024; // 25 MB
                          if (file.size > maxBytes) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'File too large. Maximum allowed size is 25 MB.'),
                                  backgroundColor: Colors.red),
                            );
                            return;
                          }
                          setState(() {
                            _selectedFileName = file.name;
                            _selectedFileBytes = file.bytes!.toList();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.primaryIndigo.withOpacity(0.3),
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_upload_outlined,
                                size: 36, color: AppColors.primaryIndigo),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFileName ?? 'Click to choose file...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _selectedFileName != null
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _selectedFileName != null
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: (_selectedFileName == null ||
                              _selectedFileBytes == null ||
                              _submissionLoading)
                          ? null
                          : () async {
                              setState(() => _submissionLoading = true);
                              try {
                                await CourseRepository().submitFile(
                                  widget.courseId,
                                  widget.assignmentId,
                                  _selectedFileBytes!,
                                  _selectedFileName!,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('File submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  setState(() {
                                    _selectedFileName = null;
                                    _selectedFileBytes = null;
                                  });
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                                }
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Assignment'),
                    ),
                  ] else if (assignmentType == 'programming') ...[
                    Text('Paste Source Code Submission',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeSubmissionCtrl,
                      maxLines: 8,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'e.g. def my_solution():\n    return True',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submissionLoading
                          ? null
                          : () async {
                              final code = _codeSubmissionCtrl.text.trim();
                              if (code.isEmpty) return;
                              setState(() => _submissionLoading = true);
                              try {
                                await CourseRepository().submitAssignment(
                                  widget.courseId,
                                  widget.assignmentId,
                                  {
                                    'submission_type': 'programming',
                                    'content': code
                                  },
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('Code submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  _codeSubmissionCtrl.clear();
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Submit Code'),
                    ),
                  ] else if (assignmentType == 'mcq') ...[
                    Builder(builder: (context) {
                      final questions = parseMcqDescription(
                          _assignment?['description']?.toString());
                      if (questions.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'This quiz has no configured questions yet.',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      final answeredCount = _mcqAnswers.length;
                      final totalQuestions = questions.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Multiple Choice Assessment',
                                  style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                              ProfBadge(
                                label:
                                    '$answeredCount / $totalQuestions Answered',
                                color: answeredCount == totalQuestions
                                    ? AppColors.successGreen
                                    : AppColors.primaryIndigo,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select your answers for all questions below. You can also switch to fullscreen exam mode for a distraction-free experience.',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          ...List.generate(questions.length, (qIndex) {
                            final question = questions[qIndex];
                            final options = (question['options'] as List?)
                                    ?.map((option) => option.toString())
                                    .toList() ??
                                const <String>[];
                            final selectedVal = _mcqAnswers[qIndex];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selectedVal != null
                                      ? AppColors.primaryIndigo.withOpacity(0.5)
                                      : AppColors.border,
                                  width: selectedVal != null ? 1.5 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryIndigo
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Q${qIndex + 1}',
                                          style: GoogleFonts.jetBrainsMono(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12,
                                              color: AppColors.primaryIndigo),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          question['question']?.toString() ??
                                              '',
                                          style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...List.generate(
                                    options.length,
                                    (optIndex) => RadioListTile<int>(
                                      title: Text(options[optIndex],
                                          style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.textPrimary)),
                                      value: optIndex + 1,
                                      groupValue: selectedVal,
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _mcqAnswers[qIndex] = val;
                                            if (qIndex == 0)
                                              _mcqSelectedValue = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: (_mcqAnswers.isEmpty ||
                                          _submissionLoading)
                                      ? null
                                      : () async {
                                          setState(
                                              () => _submissionLoading = true);
                                          String content;
                                          if (questions.length == 1) {
                                            final val = _mcqAnswers[0] ??
                                                _mcqSelectedValue ??
                                                1;
                                            final letter = [
                                              'A',
                                              'B',
                                              'C',
                                              'D',
                                              'E'
                                            ][(val - 1).clamp(0, 4)];
                                            content = 'Option $letter';
                                          } else {
                                            final buffer = StringBuffer();
                                            for (var i = 0;
                                                i < questions.length;
                                                i++) {
                                              final val = _mcqAnswers[i];
                                              final letter = val != null
                                                  ? [
                                                      'A',
                                                      'B',
                                                      'C',
                                                      'D',
                                                      'E'
                                                    ][(val - 1).clamp(0, 4)]
                                                  : 'None';
                                              buffer.writeln(
                                                  'Question ${i + 1}: Option $letter');
                                            }
                                            content = buffer.toString().trim();
                                          }
                                          try {
                                            await CourseRepository()
                                                .submitAssignment(
                                              widget.courseId,
                                              widget.assignmentId,
                                              {
                                                'submission_type': 'mcq',
                                                'content': content
                                              },
                                            );
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Quiz answers submitted successfully!'),
                                                backgroundColor: Colors.green,
                                              ));
                                              setState(() {
                                                _mcqAnswers.clear();
                                                _mcqSelectedValue = null;
                                              });
                                              await _loadSubmissions();
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content:
                                                    Text(ErrorParser.parse(e)),
                                                backgroundColor: Colors.red,
                                              ));
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() =>
                                                  _submissionLoading = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    questions.length > 1
                                        ? 'Submit All ($answeredCount/$totalQuestions answered)'
                                        : 'Submit Quiz',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  context
                                      .push(
                                        examRoutePath(widget.courseId,
                                            widget.assignmentId),
                                        extra: examRouteExtra(
                                          title: _assignment!['title'] ??
                                              'Assessment',
                                          type: 'mcq',
                                          description:
                                              _assignment!['description']
                                                  as String?,
                                          maxMarks: (_assignment!['max_marks']
                                                      as num?)
                                                  ?.toDouble() ??
                                              100.0,
                                          timeLimitMinutes:
                                              _assignment!['time_limit_minutes']
                                                  as int?,
                                          randomizeQuestions: _assignment![
                                                      'randomize_questions']
                                                  as bool? ??
                                              false,
                                          showResultsAfter:
                                              _assignment!['show_results_after']
                                                      as bool? ??
                                                  true,
                                        ),
                                      )
                                      .then((_) => _loadSubmissions());
                                },
                                icon: const Icon(Icons.fullscreen_rounded,
                                    size: 18),
                                label: const Text('Exam Mode'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(130, 48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),
                  ] else ...[
                    Text('Write Q&A Response Submission',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
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
                      onPressed: _submissionLoading
                          ? null
                          : () async {
                              final text = _textSubmissionCtrl.text.trim();
                              if (text.isEmpty) return;
                              setState(() => _submissionLoading = true);
                              try {
                                await CourseRepository().submitAssignment(
                                  widget.courseId,
                                  widget.assignmentId,
                                  {'submission_type': 'text', 'content': text},
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content:
                                        Text('Answer submitted successfully!'),
                                    backgroundColor: Colors.green,
                                  ));
                                  _textSubmissionCtrl.clear();
                                  await _loadSubmissions();
                                }
                              } catch (e) {
                                if (mounted)
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(ErrorParser.parse(e)),
                                    backgroundColor: Colors.red,
                                  ));
                              } finally {
                                if (mounted)
                                  setState(() => _submissionLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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

  /// Builds a student-friendly summary of the AI grading rationale.
  String _buildRationaleSummary(Map<String, dynamic> aiEvaluation) {
    final criteria = aiEvaluation['criteria_evaluations'] as List?;
    final diagnostic = aiEvaluation['diagnostic_reasoning'] as String?;
    final percentage = aiEvaluation['percentage'] as num?;

    final positives = <String>[];
    final improvements = <String>[];

    // Simple heuristic to extract key points from diagnostic reasoning
    if (diagnostic != null && diagnostic.isNotEmpty) {
      final lines = diagnostic.split('.').where((l) => l.isNotEmpty).toList();
      for (final line in lines) {
        final lower = line.toLowerCase();
        // Sentences with positive words → positives
        if (lower.contains('correct') ||
            lower.contains('good') ||
            lower.contains('well') ||
            lower.contains('success')) {
          positives.add(line.trim());
        }
        // Sentences with improvement words → improvements
        else if (lower.contains('however') ||
            lower.contains('issue') ||
            lower.contains('problem') ||
            lower.contains('improve') ||
            lower.contains('missing') ||
            lower.contains('error')) {
          improvements.add(line.trim());
        }
      }
    }

    // Fallback: use first few criteria rationales if no diagnostic available
    if (positives.isEmpty && improvements.isEmpty && criteria != null) {
      for (final crit in criteria.take(3)) {
        final rationale = crit['rationale'] ?? '';
        if (rationale.isNotEmpty) {
          final rLower = rationale.toLowerCase();
          if (rLower.contains('correct') || rLower.contains('good')) {
            positives.add(rationale);
          } else if (rLower.contains('issue') || rLower.contains('problem')) {
            improvements.add(rationale);
          }
        }
      }
    }

    final result = <String>[];
    if (positives.isNotEmpty) {
      result.add('✅ **What was done well:**');
      result.addAll(positives.map((p) => '• $p').take(3));
    }
    if (improvements.isNotEmpty) {
      result.add('⚠️ **Area for improvement:**');
      result.addAll(improvements.map((i) => '• $i').take(3));
    }
    // Always show percentage
    if (percentage != null) {
      result.add('📊 **Score:** ${percentage.toStringAsFixed(1)}%');
    }

    return result.join('\n');
  }

  Widget _buildStudentDiagnosticCard(
      Map<String, dynamic> metadata, Map<String, dynamic> sub) {
    final criteria = (metadata['criteria_evaluations'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final reasoning = metadata['diagnostic_reasoning']?.toString();
    final modelName =
        metadata['evaluator_model']?.toString() ?? 'ProfessorOS AI';
    final needsReview = metadata['needs_review'] == true;
    final reviewReasons = (metadata['review_reasons'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  size: 18, color: AppColors.primaryIndigo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Evaluation & Rubric Breakdown',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkPrimary),
                ),
              ),
              ProfBadge(
                label: 'Powered by $modelName',
                color: AppColors.primaryIndigo,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (needsReview) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade700, width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This automated assessment is flagged for instructor review: ${reviewReasons.join(", ")}',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (reasoning != null && reasoning.isNotEmpty) ...[
            Text('Pedagogical Rationale:',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.inkSecondary)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                reasoning,
                style: GoogleFonts.inter(
                    fontSize: 13, height: 1.45, color: AppColors.inkPrimary),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (criteria.isNotEmpty) ...[
            Text('Rubric Criteria Performance:',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.inkSecondary)),
            const SizedBox(height: 8),
            ...criteria.map((c) {
              final cName = c['criterion_name'] ?? 'Criterion';
              final score =
                  (c['score_awarded'] ?? c['score'] as num?)?.toDouble() ?? 0.0;
              final max = (c['max_score'] as num?)?.toDouble() ?? 10.0;
              final level = (c['assigned_level'] ?? 'satisfactory')
                  .toString()
                  .toLowerCase();
              final rationale = c['rationale']?.toString() ?? '';
              final evidence = c['evidence_quote']?.toString() ?? '';

              Color levelColor;
              switch (level) {
                case 'excellent':
                  levelColor = AppColors.successGreen;
                  break;
                case 'satisfactory':
                  levelColor = AppColors.primaryIndigo;
                  break;
                case 'developing':
                  levelColor = Colors.orange;
                  break;
                default:
                  levelColor = AppColors.dangerRose;
              }

              final pct = max > 0 ? (score / max).clamp(0.0, 1.0) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            cName,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ProfBadge(
                          label: level.toUpperCase(),
                          color: levelColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${score.toStringAsFixed(1)} / ${max.toStringAsFixed(1)} pts',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                      ),
                    ),
                    if (rationale.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        rationale,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.inkSecondary),
                      ),
                    ],
                    if (evidence.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(4),
                          border: const Border(
                            left: BorderSide(
                                color: AppColors.primaryIndigo, width: 3),
                          ),
                        ),
                        child: Text(
                          '"$evidence"',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: AppColors.inkSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

// ── Student & Professor Grade Appeal Helpers ─────────────────────────

  Widget _buildStudentAppealSection(Map<String, dynamic> sub) {
    if (_studentAppeal == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryIndigo,
          side: const BorderSide(color: AppColors.primaryIndigo),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.rate_review_outlined, size: 18),
        label: Text('Submit Grade Dispute / Appeal',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
        onPressed: () => _openSubmitAppealDialog(sub),
      );
    }

    final status = _studentAppeal!['status']?.toString().toLowerCase() ?? 'pending';
    Color badgeColor;
    String statusTitle;
    IconData statusIcon;
    switch (status) {
      case 'accepted':
        badgeColor = const Color(0xFF10B981);
        statusTitle = 'Appeal Accepted (Score Adjusted)';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        badgeColor = const Color(0xFFEF4444);
        statusTitle = 'Appeal Declined';
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        badgeColor = const Color(0xFFF59E0B);
        statusTitle = 'Grade Dispute Pending Review';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: badgeColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusTitle,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: badgeColor,
                  ),
                ),
              ),
              if (_studentAppeal!['adjusted_score'] != null)
                ProfBadge(
                  label: 'Adjusted: ${_studentAppeal!['adjusted_score']} pts',
                  color: const Color(0xFF10B981),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_studentAppeal!['challenged_criterion'] != null) ...[
            Text('Challenged Criterion: ${_studentAppeal!['challenged_criterion']}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkPrimary)),
            const SizedBox(height: 4),
          ],
          Text('Your Justification:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
          const SizedBox(height: 2),
          Text(
            _studentAppeal!['justification'] ?? '',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkPrimary, height: 1.4),
          ),
          if (_studentAppeal!['professor_feedback'] != null &&
              _studentAppeal!['professor_feedback'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 6),
            Text('Instructor Feedback:',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
            const SizedBox(height: 2),
            Text(
              _studentAppeal!['professor_feedback'],
              style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.inkPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  void _openSubmitAppealDialog(Map<String, dynamic> sub) {
    final criterionCtrl = TextEditingController();
    final justCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: AppColors.primaryIndigo),
              const SizedBox(width: 10),
              Text('Submit Grade Dispute', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'If you believe the AI evaluation or assigned score was inconsistent with the rubric, submit your justification below for instructor review.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.inkSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: criterionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Challenged Criterion (Optional)',
                      hintText: 'e.g. Critical Analysis, Efficiency & Complexity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: justCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Student Justification *',
                      hintText: 'Explain why your submission satisfies the rubric criteria...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: const Text('Submit Dispute'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final reason = justCtrl.text.trim();
                      if (reason.length < 5) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please enter at least 5 characters for your justification.'),
                          backgroundColor: Colors.red,
                        ));
                        return;
                      }
                      setDlgState(() => isSubmitting = true);
                      try {
                        final res = await CourseRepository().submitGradeAppeal(
                          sub['id'] as int,
                          challengedCriterion: criterionCtrl.text.trim().isNotEmpty ? criterionCtrl.text.trim() : null,
                          justification: reason,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        setState(() => _studentAppeal = res);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('✓ Grade dispute submitted successfully for instructor review.'),
                          backgroundColor: Color(0xFF10B981),
                        ));
                      } catch (e) {
                        setDlgState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Submission failed: ${ErrorParser.parse(e)}'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _openAppealsManagementDialog() async {
    try {
      final list = await CourseRepository().getAssignmentAppeals(widget.assignmentId);
      if (!mounted) return;
      setState(() => _assignmentAppeals = list);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.gavel_rounded, color: AppColors.primaryIndigo),
              const SizedBox(width: 10),
              Text('Grade Appeals Management (${_assignmentAppeals.length})',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
            child: _assignmentAppeals.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                          const SizedBox(height: 12),
                          Text('No Grade Appeals', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('No students have submitted disputes for this assignment.',
                              style: GoogleFonts.inter(color: AppColors.inkSecondary)),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _assignmentAppeals.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, idx) {
                      final a = _assignmentAppeals[idx];
                      final status = a['status']?.toString().toLowerCase() ?? 'pending';
                      final isPending = status == 'pending';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isPending ? AppColors.accentAmber.withOpacity(0.4) : AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primaryIndigo.withOpacity(0.1),
                                      child: Text(
                                        (a['student_name']?.toString() ?? 'S').substring(0, 1).toUpperCase(),
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.primaryIndigo),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a['student_name'] ?? 'Student',
                                            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                                        Text(a['student_email'] ?? '',
                                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ],
                                ),
                                ProfBadge(
                                  label: status.toUpperCase(),
                                  color: isPending ? const Color(0xFFF59E0B) : (status == 'accepted' ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (a['challenged_criterion'] != null)
                              Text('Challenged: ${a['challenged_criterion']}',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primaryIndigo)),
                            const SizedBox(height: 4),
                            Text('Student Justification:',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSecondary)),
                            Text('"${a['justification'] ?? ''}"',
                                style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.inkPrimary)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Current Score: ${a['current_score'] ?? 'None'} pts',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                                if (a['adjusted_score'] != null) ...[
                                  const SizedBox(width: 12),
                                  Text('→ Adjusted Score: ${a['adjusted_score']} pts',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF10B981))),
                                ],
                              ],
                            ),
                            if (a['professor_feedback'] != null && a['professor_feedback'].toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Resolution Notes: ${a['professor_feedback']}',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.inkSecondary)),
                            ],
                            if (isPending) ...[
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                                    icon: const Icon(Icons.close_rounded, size: 16),
                                    label: const Text('Reject Appeal'),
                                    onPressed: () => _openResolveAppealDialog(a, accept: false, onDone: (updated) {
                                      setModalState(() => _assignmentAppeals[idx] = updated);
                                    }),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                    icon: const Icon(Icons.check_rounded, size: 16),
                                    label: const Text('Adjust Grade'),
                                    onPressed: () => _openResolveAppealDialog(a, accept: true, onDone: (updated) {
                                      setModalState(() => _assignmentAppeals[idx] = updated);
                                      _loadSubmissions();
                                    }),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _openResolveAppealDialog(Map<String, dynamic> appeal, {required bool accept, required Function(Map<String, dynamic>) onDone}) {
    final scoreCtrl = TextEditingController(text: appeal['current_score']?.toString() ?? '');
    final notesCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(accept ? 'Accept & Adjust Grade' : 'Reject Grade Appeal',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accept) ...[
                  TextField(
                    controller: scoreCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'New Final Score (Points)',
                      hintText: 'e.g. 85.0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: accept ? 'Instructor Resolution Notes' : 'Rejection Reason *',
                    hintText: accept ? 'e.g. Verified code memoization, awarded extra points.' : 'e.g. Solution does not address boundary conditions.',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: accept ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDlgState(() => isSaving = true);
                      try {
                        final double? newScore = accept ? double.tryParse(scoreCtrl.text.trim()) : null;
                        final res = await CourseRepository().resolveGradeAppeal(
                          appeal['id'] as int,
                          status: accept ? 'accepted' : 'rejected',
                          adjustedScore: newScore,
                          professorFeedback: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        final updated = Map<String, dynamic>.from(appeal);
                        updated['status'] = res['status'];
                        updated['adjusted_score'] = res['adjusted_score'];
                        updated['professor_feedback'] = res['professor_feedback'];
                        onDone(updated);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('✓ Appeal ${accept ? "accepted and grade updated" : "rejected"}.'),
                          backgroundColor: accept ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ));
                      } catch (e) {
                        setDlgState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Action failed: ${ErrorParser.parse(e)}'),
                          backgroundColor: Colors.red,
                        ));
                      }
                    },
              child: Text(accept ? 'Confirm New Grade' : 'Confirm Rejection'),
            ),
          ],
        ),
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
  double? _aiSuggestedScore;
  bool _isAiAccepted = false;
  String _manualScoreBeforeAi = '';
  String _initialScore = '';
  String _initialFeedback = '';
  bool _savingCurrent = false;

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
    _initialScore = _scoreCtrl.text;
    _initialFeedback = _feedbackCtrl.text;
    _selectedLevels.clear();
    _aiSuggestedScore = null;
    _isAiAccepted = false;
  }

  Future<bool> _checkUnsavedAndProceed() async {
    if (_scoreCtrl.text != _initialScore ||
        _feedbackCtrl.text != _initialFeedback) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have modified the grade or qualitative feedback. Would you like to save to the database before moving to the next student?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save & Continue'),
            ),
          ],
        ),
      );
      if (shouldSave == true) {
        await _onSaveCurrent();
        return true;
      } else if (shouldSave == false) {
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> _onSaveCurrent() async {
    final score = double.tryParse(_scoreCtrl.text);
    if (score == null && _scoreCtrl.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid numeric score.'),
        backgroundColor: AppColors.dangerRose,
      ));
      return;
    }
    final feedback = _feedbackCtrl.text.trim();
    final sub = widget.submissions[_currentIndex];
    final sid = sub['id'] as int;

    setState(() => _savingCurrent = true);
    try {
      if (score != null) {
        await CourseRepository().gradeSubmission(
          sid,
          score,
          feedback.isEmpty ? null : feedback,
        );
      }
      final updated = Map<String, dynamic>.from(sub);
      updated['score'] = score;
      updated['feedback'] = feedback;
      if (score != null) {
        updated['status'] = 'graded';
      }

      widget.onSave(_currentIndex, updated);
      _initialScore = _scoreCtrl.text;
      _initialFeedback = _feedbackCtrl.text;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Grade and feedback saved to database successfully!'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save grade: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _savingCurrent = false);
      }
    }
  }

  Future<void> _downloadSubmissionFile(
      int submissionId, String filename) async {
    try {
      final token = await DioClient.getAccessToken();
      final url = Uri.parse(
          '${ApiConstants.baseUrl}/submissions/$submissionId/file?token=$token');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not trigger download for $filename'),
            backgroundColor: AppColors.dangerRose,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: ${ErrorParser.parse(e)}'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  bool _aiGrading = false;

  Future<void> _runAiGrade() async {
    final sub = widget.submissions[_currentIndex];
    setState(() => _aiGrading = true);
    try {
      final res = await CourseRepository()
          .aiGradeSubmission(sub['id'] as int, sync: true);
      final score = (res['score'] as num?)?.toDouble();
      final feedback = res['feedback']?.toString() ??
          res['diagnostic_reasoning']?.toString();
      setState(() {
        _aiSuggestedScore = score;
        _isAiAccepted = false;
        if (feedback != null && feedback.isNotEmpty) {
          _feedbackCtrl.text = feedback;
        }
        _aiGrading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✓ AI evaluated: ${score?.toStringAsFixed(1) ?? ''} pts proposed. Review suggestion below.'),
          backgroundColor: AppColors.statusPassInk,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiGrading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('AI grading failed due to server error. Please try again or grade manually.'),
          backgroundColor: AppColors.statusCriticalInk,
        ));
      }
    }
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
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      lines[i],
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 12, color: AppColors.inkPrimary),
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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text('SpeedGrader',
            style:
                GoogleFonts.dmSans(fontWeight: FontWeight.w500, fontSize: 16)),
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
                      ? () async {
                          final canProceed = await _checkUnsavedAndProceed();
                          if (canProceed && mounted) {
                            setState(() {
                              _currentIndex--;
                              _loadSubmission();
                            });
                          }
                        }
                      : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${sub['roll_number'] ?? 'Student #${sub['student_id'] ?? (_currentIndex + 1)}'} • ${sub['student_name']}',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub['student_email'] ?? '',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.inkSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: _currentIndex < widget.submissions.length - 1
                      ? () async {
                          final canProceed = await _checkUnsavedAndProceed();
                          if (canProceed && mounted) {
                            setState(() {
                              _currentIndex++;
                              _loadSubmission();
                            });
                          }
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
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: AppColorsLight.inkTitle)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColorsLight.surface,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          border: Border.all(color: AppColorsLight.rule),
                        ),
                        child: sub['submission_type'] == 'file'
                            ? Column(
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      size: 56, color: Color(0xFF4F46E5)),
                                  const SizedBox(height: 12),
                                  Text(sub['content'] ?? '',
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColorsLight.inkPrimary)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _downloadSubmissionFile(
                                      sub['id'] as int,
                                      sub['file_name'] ??
                                          sub['content'] ??
                                          'submission_file',
                                    ),
                                    icon: const Icon(Icons.download),
                                    label:
                                        const Text('Download Submission File'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF4F46E5)),
                                  ),
                                ],
                              )
                            : sub['submission_type'] == 'programming'
                                ? _buildCodeViewer(sub['content'] ?? '')
                                : Text(
                                    sub['content'] ?? '',
                                    style: GoogleFonts.inter(
                                        fontSize: 15,
                                        color: AppColorsLight.inkPrimary,
                                        height: 1.5),
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
                          style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              color: AppColorsLight.inkTitle)),
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
                                  style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('$critName ($weight%)',
                                            style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: levels.map((l) {
                                            final levelName =
                                                l['level'] as String;
                                            final isSelected =
                                                _selectedLevels[critName] ==
                                                    levelName;
                                            return ChoiceChip(
                                              label: Text(
                                                  levelName.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 11)),
                                              selected: isSelected,
                                              onSelected: (selected) {
                                                setState(() {
                                                  _selectedLevels[critName] =
                                                      levelName;

                                                  // Auto calculate total score based on rubric clicks
                                                  double calculatedTotal = 0;
                                                  _selectedLevels
                                                      .forEach((key, val) {
                                                    final matchCrit = criteria
                                                        .firstWhere((element) =>
                                                            element['name'] ==
                                                            key);
                                                    final matchWeight =
                                                        matchCrit['weight']
                                                            as int;
                                                    double factor = 1.0;
                                                    if (val == 'good')
                                                      factor = 0.75;
                                                    if (val == 'poor')
                                                      factor = 0.40;
                                                    calculatedTotal +=
                                                        matchWeight * factor;
                                                  });
                                                  _scoreCtrl.text =
                                                      calculatedTotal
                                                          .toStringAsFixed(1);
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

                      // AI Draft Suggestion Pill or Undo Chip
                      if (_aiSuggestedScore != null) ...[
                        if (!_isAiAccepted)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isAiAccepted = true;
                                  _manualScoreBeforeAi = _scoreCtrl.text;
                                  _scoreCtrl.text =
                                      _aiSuggestedScore!.toStringAsFixed(1);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.statusPassBg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.r2),
                                  border: Border.all(
                                      color: AppColors.statusPassInk
                                          .withOpacity(0.4),
                                      width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'AI Suggestion: [ ${_aiSuggestedScore!.toStringAsFixed(1)} ]',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.statusPassInk,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '• Tap to apply',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 11,
                                        color: AppColors.statusPassInk
                                            .withOpacity(0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isAiAccepted = false;
                                  _scoreCtrl.text = _manualScoreBeforeAi;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMid,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.r2),
                                  border: Border.all(
                                      color: AppColors.ruleStrong, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('✨',
                                        style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI ${_aiSuggestedScore!.toStringAsFixed(1)} • Undo',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],

                      // Bounded 4-sided Surface Score Input Container
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMid,
                            borderRadius: BorderRadius.circular(AppRadius.r4),
                            border: Border.all(
                                color: AppColors.ruleStrong, width: 1),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'SCORE:',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _scoreCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.inkPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0.0',
                                    hintStyle: GoogleFonts.jetBrainsMono(
                                        color: AppColors.inkGhost),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                ),
                              ),
                              Text(
                                '/ 100',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  color: AppColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'QUALITATIVE FEEDBACK:',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppColors.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _feedbackCtrl,
                        maxLines: 4,
                        style: GoogleFonts.dmSans(
                            fontSize: 14, color: AppColors.inkPrimary),
                        decoration: InputDecoration(
                          hintText:
                              'Enter qualitative rubric feedback and diagnostics...',
                          hintStyle:
                              GoogleFonts.dmSans(color: AppColors.inkGhost),
                          filled: true,
                          fillColor: AppColors.surfaceMid,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.r4),
                            borderSide: const BorderSide(color: AppColors.rule),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.r4),
                            borderSide: const BorderSide(color: AppColors.rule),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      SecondaryButton(
                        label: _aiGrading
                            ? 'AI Evaluating...'
                            : 'Auto-Grade with AI',
                        isLoading: _aiGrading,
                        width: double.infinity,
                        onPressed: _aiGrading ? null : _runAiGrade,
                      ),
                      const SizedBox(height: 12),

                      PrimaryButton(
                        label: 'Save Grade & Comments',
                        isLoading: _savingCurrent,
                        width: double.infinity,
                        onPressed: _savingCurrent ? null : _onSaveCurrent,
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
