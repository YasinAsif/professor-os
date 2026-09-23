/// ProfessorOS – Academic Quiz Attempt Screen (Mobile & Web).
///
/// Features:
///   - Dispatches start request to /api/v1/quizzes/{quiz_id}/attempts/start.
///   - One-question-at-a-time navigation with progress tracker and countdown timer.
///   - Interactive MCQ radio options and text field answer inputs.
///   - Real-time timer with auto-submission upon expiry.
///   - Automatic grading submission to /api/v1/attempts/{attempt_id}/submit.
///   - Post-attempt result breakdown and feedback screen.

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_theme.dart';

class QuizAttemptScreen extends ConsumerStatefulWidget {
  final String quizId;
  final String quizTitle;
  final String? proctorSessionId;

  const QuizAttemptScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
    this.proctorSessionId,
  });

  @override
  ConsumerState<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends ConsumerState<QuizAttemptScreen> {
  final Dio _dio = DioClient.instance;

  // ── State ────────────────────────────────────────────────────────────
  bool _loading = true;
  String? _errorMessage;
  String? _attemptId;
  int? _timeLimitMinutes;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;

  // Answers map: question_id -> selected_option or text_answer
  final Map<String, String> _userAnswers = {};

  // Timer
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _submitting = false;

  // Results state
  bool _showResult = false;
  Map<String, dynamic>? _resultData;

  @override
  void initState() {
    super.initState();
    _startOrResumeAttempt();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── 1. Start or Resume Attempt ───────────────────────────────────────
  Future<void> _startOrResumeAttempt() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await _dio.post(
        ApiConstants.startQuizAttempt(widget.quizId),
        data: {
          if (widget.proctorSessionId != null)
            'proctor_session_id': widget.proctorSessionId,
        },
      );

      final data = response.data as Map<String, dynamic>;
      _attemptId = data['attempt_id'] as String;
      _timeLimitMinutes = data['time_limit_minutes'] as int?;

      final rawQuestions = (data['questions'] as List<dynamic>?) ?? [];
      _questions = rawQuestions.map((q) => Map<String, dynamic>.from(q as Map)).toList();

      if (_timeLimitMinutes != null && _timeLimitMinutes! > 0) {
        _secondsRemaining = _timeLimitMinutes! * 60;
        _startTimer();
      }

      setState(() {
        _loading = false;
      });
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? e.message ?? 'Failed to load quiz.';
      setState(() {
        _loading = false;
        _errorMessage = detail.toString();
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _submitAttempt(autoSubmit: true);
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── 2. Submit Answers ────────────────────────────────────────────────
  Future<void> _submitAttempt({bool autoSubmit = false}) async {
    if (_attemptId == null || _submitting) return;

    if (!autoSubmit) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Submit Assessment?', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Text(
            'You have answered ${_userAnswers.length} of ${_questions.length} questions. '
            'Are you sure you want to finalize your submission?',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Review Answers'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    try {
      final answersList = _questions.map((q) {
        final qid = q['question_id'] as String;
        final ans = _userAnswers[qid];
        final type = q['question_type'] as String? ?? 'MCQ';

        if (type == 'MCQ') {
          return {'question_id': qid, 'selected_option': ans};
        } else {
          return {'question_id': qid, 'text_answer': ans};
        }
      }).toList();

      await _dio.post(
        ApiConstants.submitQuizAttempt(_attemptId!),
        data: {'answers': answersList},
      );

      // Fetch final detailed result
      await _fetchResult();
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] ?? 'Submission failed.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail.toString()), backgroundColor: Colors.red),
      );
      setState(() => _submitting = false);
    }
  }

  // ── 3. Fetch Result ──────────────────────────────────────────────────
  Future<void> _fetchResult() async {
    try {
      final res = await _dio.get(ApiConstants.quizAttemptResult(_attemptId!));
      setState(() {
        _submitting = false;
        _showResult = true;
        _resultData = res.data as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _showResult = true;
      });
    }
  }

  // ── 4. UI Builders ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text('Notice', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.grey.shade700)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Course'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showResult) {
      return _buildResultScreen();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizTitle)),
        body: const Center(child: Text('No questions available in this assessment.')),
      );
    }

    final currentQ = _questions[_currentIndex];
    final qId = currentQ['question_id'] as String;
    final qText = currentQ['question_text'] as String? ?? '';
    final qType = currentQ['question_type'] as String? ?? 'MCQ';
    final rawOptions = currentQ['options'];
    final options = (rawOptions is List) ? rawOptions.map((o) => o.toString()).toList() : <String>[];
    final bloom = currentQ['bloom_level'] as String? ?? 'C2';

    return WillPopScope(
      onWillPop: () async {
        final exit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave Assessment?'),
            content: const Text('Your timer will continue running in the background. Are you sure you want to leave?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        return exit == true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quizTitle, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
          actions: [
            if (_timeLimitMinutes != null)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _secondsRemaining < 120 ? Colors.red.shade100 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _secondsRemaining < 120 ? Colors.red : Colors.blue),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: _secondsRemaining < 120 ? Colors.red : Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimer(_secondsRemaining),
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        color: _secondsRemaining < 120 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        body: _submitting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Auto-scoring your assessment...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress & Bloom Badge Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Question ${_currentIndex + 1} of ${_questions.length}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Text(
                            'Taxonomy: $bloom',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo.shade800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_currentIndex + 1) / _questions.length,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                    const SizedBox(height: 24),

                    // Question Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          qText,
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Options / Input
                    if (qType == 'MCQ') ...[
                      Text('Select your answer:', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                      const SizedBox(height: 10),
                      ...options.map((opt) {
                        final isSelected = _userAnswers[qId] == opt;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade50 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: RadioListTile<String>(
                            value: opt,
                            groupValue: _userAnswers[qId],
                            activeColor: AppColors.primary,
                            title: Text(opt, style: GoogleFonts.inter(fontSize: 14)),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _userAnswers[qId] = val;
                                });
                              }
                            },
                          ),
                        );
                      }),
                    ] else ...[
                      Text('Your Answer:', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                      const SizedBox(height: 10),
                      TextField(
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter your response...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        onChanged: (val) {
                          _userAnswers[qId] = val;
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Bottom Navigation Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _currentIndex > 0
                              ? () => setState(() => _currentIndex--)
                              : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous'),
                        ),
                        if (_currentIndex < _questions.length - 1)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => setState(() => _currentIndex++),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next'),
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            onPressed: () => _submitAttempt(),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Submit Quiz'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ── 5. Results Screen ────────────────────────────────────────────────
  Widget _buildResultScreen() {
    final score = _resultData?['score'] ?? 0.0;
    final total = _resultData?['total_possible'] ?? 1.0;
    final pct = _resultData?['percentage'] ?? 0.0;
    final breakdown = (_resultData?['breakdown'] as List<dynamic>?) ?? [];
    final isPass = pct >= 50.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.quizTitle} – Result'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isPass ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isPass ? Colors.green : Colors.red),
              ),
              child: Column(
                children: [
                  Icon(isPass ? Icons.celebration : Icons.sentiment_dissatisfied,
                      size: 54, color: isPass ? Colors.green : Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    isPass ? 'Assessment Completed!' : 'Assessment Finished',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Score: $score / $total ($pct%)',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isPass ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Question Breakdown
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Question Breakdown',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            ...breakdown.map((b) {
              final bMap = Map<String, dynamic>.from(b as Map);
              final isCorrect = bMap['is_correct'] == true;
              final qText = bMap['question_text'] ?? '';
              final studentAns = bMap['student_answer'] ?? '(No answer)';
              final correctAns = bMap['correct_answer'];
              final rationale = bMap['distractor_rationale'];

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isCorrect ? Colors.green.shade200 : Colors.red.shade200),
                ),
                color: isCorrect ? Colors.green.shade50.withOpacity(0.3) : Colors.red.shade50.withOpacity(0.3),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.green : Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(qText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Your Answer: $studentAns', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade800)),
                      if (correctAns != null) ...[
                        const SizedBox(height: 4),
                        Text('Correct Answer: $correctAns', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                      ],
                      if (rationale != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text('Rationale: $rationale', style: GoogleFonts.inter(fontSize: 11, color: Colors.amber.shade900)),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Course', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
