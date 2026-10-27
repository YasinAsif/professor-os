/// ProfessorOS – Anti-Cheat Exam Screen.
/// Supports all assignment types with fullscreen lock, tab-switch detection,
/// countdown timer, biometric verification, and auto-submission.

import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_parser.dart';
import '../../../core/device/device_inspector.dart';
import 'widgets/exam_mobile_block_view.dart';
import '../data/course_repository.dart';
import '../utils/mcq_parser.dart';
import '../utils/web_window_listener.dart';
import '../utils/proctor_detector.dart';
import '../utils/offline_violation_queue.dart';
import '../utils/exam_state_machine.dart';
import '../utils/exam_draft_serializer.dart';
import '../utils/exam_config_loader.dart';
import '../utils/mobile_proctor_service.dart';

class ExamScreen extends ConsumerStatefulWidget {
  final int courseId;
  final int assignmentId;
  final String assignmentTitle;
  final String assignmentType; // 'text', 'programming', 'file', 'mcq'
  final String? description;
  final double maxMarks;
  final int? timeLimitMinutes;
  final bool randomizeQuestions;
  final bool showResultsAfter;
  final bool fullscreenRequired;
  final bool blockClipboard;
  final String unsupportedBrowserPolicy; // 'warn_allow' | 'block'
  final bool? initialBiometricPassed;

  const ExamScreen({
    super.key,
    required this.courseId,
    required this.assignmentId,
    required this.assignmentTitle,
    required this.assignmentType,
    this.description,
    required this.maxMarks,
    this.timeLimitMinutes,
    this.randomizeQuestions = false,
    this.showResultsAfter = true,
    this.fullscreenRequired = true,
    this.blockClipboard = true,
    this.unsupportedBrowserPolicy = 'warn_allow',
    this.initialBiometricPassed,
    this.skipInitialStateCheck = false,
    this.initialFullscreenExitActive,
    this.initialIsOffline,
    this.initialExamStarted,
  }) : assert(
          !kReleaseMode ||
              (initialBiometricPassed == null &&
                  !skipInitialStateCheck &&
                  initialFullscreenExitActive == null &&
                  initialIsOffline == null &&
                  initialExamStarted == null),
          'Test bypass flags are strictly forbidden in production release builds.',
        );

  final bool skipInitialStateCheck;
  final bool? initialFullscreenExitActive;
  final bool? initialIsOffline;
  final bool? initialExamStarted;

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen>
    with WidgetsBindingObserver {
  // ── State ────────────────────────────────────────────────────────────
  bool _biometricPassed = false;
  bool _examStarted = false;
  bool _submitted = false;
  bool _submitting = false;
  String? _error;
  int? _attemptId;
  bool _attemptResumed = false;
  bool _isOffline = false;
  bool _fullscreenExitActive = false;
  Timer? _returnCountdownTimer;
  int _returnSecondsRemaining = 15;
  static const int _returnGraceDuration = 15;

  // Pure logic components
  final _detector = ProctorDetector();
  final _violationQueue = OfflineViolationQueue();
  final _stateMachine = ExamStateMachine();

  // Timer
  Timer? _timer;
  Timer? _heartbeatTimer;
  int _remainingSeconds = 0;

  // Anti-cheat
  int _tabSwitchCount = 0;
  bool _isFlagged = false;

  // Biometric fallback tracking
  int _biometricFailures = 0;

  // Submission content
  final _textCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final Map<int, int> _mcqAnswers = {};
  String? _selectedFileName;
  List<int>? _selectedFileBytes;

  final _localAuth = LocalAuthentication();
  final _repo = CourseRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    attachWebProctorListeners(
      onViolation: (type) {
        if (_examStarted && !_submitted) {
          _handleViolation(type);
        }
      },
      onFullscreenExit: () {
        if (_examStarted && !_submitted) {
          _handleFullscreenExit();
        }
      },
      onCopyPasteViolation: (action) {
        if (_examStarted && !_submitted) {
          _handleCopyPasteViolation(action);
        }
      },
      onRestrictedKey: (reason) {
        if (_examStarted && !_submitted) {
          _handleRestrictedKey(reason);
        }
      },
      blockClipboardAndContextMenu: widget.blockClipboard,
    );

    // Security Guard: In release mode (production), testing bypasses are completely disabled.
    final effectiveBiometricPassed = kReleaseMode ? false : (widget.initialBiometricPassed ?? false);
    final effectiveSkipStateCheck = kReleaseMode ? false : widget.skipInitialStateCheck;
    final effectiveExamStarted = kReleaseMode ? false : (widget.initialExamStarted ?? false);
    final effectiveFullscreenExit = kReleaseMode ? false : (widget.initialFullscreenExitActive ?? false);
    final effectiveOffline = kReleaseMode ? false : (widget.initialIsOffline ?? false);

    _biometricPassed = effectiveBiometricPassed;
    _examStarted = effectiveExamStarted;
    _fullscreenExitActive = effectiveFullscreenExit;
    _isOffline = effectiveOffline;

    if (!effectiveSkipStateCheck) {
      _checkInitialState();
    }
    if (!effectiveBiometricPassed) {
      _runBiometricAuth();
    }
  }

  @override
  void dispose() {
    detachWebProctorListeners();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _returnCountdownTimer?.cancel();
    _detector.dispose();
    _textCtrl.dispose();
    _codeCtrl.dispose();
    _exitFullscreen();
    MobileProctorService.releaseExamLock();
    super.dispose();
  }

  // Server-authoritative config (Items 1.3 & 1.4)
  String? _serverTitle;
  double? _serverMaxMarks;
  String? _serverType;
  String? _serverDescription;
  int? _serverTimeLimitMinutes;
  int _serverStrikeLimitFlag = 3;
  int _serverStrikeLimitAutosubmit = 5;
  bool _serverFullscreenRequired = true;
  bool _serverBlockClipboard = true;
  String _serverUnsupportedBrowserPolicy = 'warn_allow';

  String get _effectiveTitle => _serverTitle ?? widget.assignmentTitle;
  double get _effectiveMaxMarks => _serverMaxMarks ?? widget.maxMarks;
  String get _effectiveType => _serverType ?? widget.assignmentType;
  String? get _effectiveDescription => _serverDescription ?? widget.description;
  int? get _effectiveTimeLimitMinutes => _serverTimeLimitMinutes ?? widget.timeLimitMinutes;
  bool get _effectiveFullscreenRequired => _serverFullscreenRequired;
  bool get _effectiveBlockClipboard => _serverBlockClipboard;
  String get _effectiveUnsupportedBrowserPolicy => _serverUnsupportedBrowserPolicy;

  bool get _hasOptions {
    if (_effectiveType != 'mcq') return false;
    final desc = _effectiveDescription ?? '';
    final structured = parseMcqDescription(desc);
    if (structured.isNotEmpty) {
      return structured.any((q) {
        final opts = (q['options'] as List?)
                ?.where((o) => o.toString().trim().isNotEmpty)
                .toList() ??
            [];
        return opts.length >= 2;
      });
    }
    int optCount = 0;
    for (final line in desc.split('\n')) {
      if (RegExp(r'^[A-Ea-e][).]').hasMatch(line.trim())) {
        optCount++;
      }
    }
    return optCount >= 2;
  }

  Future<void> _checkInitialState() async {
    try {
      final config = await ExamConfigLoader.load(
        courseId: widget.courseId,
        assignmentId: widget.assignmentId,
        repo: _repo,
      );

      if (mounted) {
        setState(() {
          _serverTitle = config.title;
          _serverMaxMarks = config.maxMarks;
          _serverType = config.assignmentType;
          _serverDescription = config.description;
          _serverTimeLimitMinutes = config.timeLimitMinutes;
          _serverFullscreenRequired = config.fullscreenRequired;
          _serverBlockClipboard = config.blockClipboard;
          _serverUnsupportedBrowserPolicy = config.unsupportedBrowserPolicy;
          _serverStrikeLimitFlag = config.strikeLimitFlag;
          _serverStrikeLimitAutosubmit = config.strikeLimitAutosubmit;

          if (config.isSubmitted) {
            _submitted = true;
            _attemptId = config.attemptId;
            _tabSwitchCount = config.tabSwitchCount;
            _isFlagged = config.isFlagged;
          } else if (config.isActiveAttempt && config.attemptId != null) {
            // Item 1.3: Resume straight into exam view!
            _attemptId = config.attemptId;
            _attemptResumed = true;
            _examStarted = true;
            _biometricPassed = true;
            _stateMachine.transitionTo(ExamState.active);
            _remainingSeconds = config.remainingSeconds;
            _tabSwitchCount = config.tabSwitchCount;
            _isFlagged = config.isFlagged;

            if (config.currentAnswers != null && config.currentAnswers!.isNotEmpty) {
              _restoreAnswers(config.currentAnswers!);
            }
          }
        });

        if (config.isActiveAttempt && config.attemptId != null) {
          _startHeartbeat();
          if (_remainingSeconds > 0) {
            _startTimer();
          } else if (config.timeLimitMinutes != null && config.timeLimitMinutes! > 0) {
            _autoSubmit();
          }
        }
      }
    } catch (_) {
      // Offline fallback: fall back to widget extras
    }
  }

  void _restoreAnswers(String raw) {
    try {
      final result = ExamDraftSerializer.deserialize(
        raw,
        assignmentType: _effectiveType,
        hasOptions: _hasOptions,
      );
      if (result.text != null && result.text!.isNotEmpty) {
        _textCtrl.text = result.text!;
      }
      if (result.code != null && result.code!.isNotEmpty) {
        _codeCtrl.text = result.code!;
      }
      if (result.mcqAnswers.isNotEmpty) {
        _mcqAnswers.clear();
        _mcqAnswers.addAll(result.mcqAnswers);
      }
      if (result.fileName != null && result.fileName!.isNotEmpty) {
        _selectedFileName = result.fileName;
      }
    } catch (_) {}
  }

  String? _getCurrentAnswersDraft() {
    return ExamDraftSerializer.serialize(
      assignmentType: _effectiveType,
      hasOptions: _hasOptions,
      text: _textCtrl.text,
      code: _codeCtrl.text,
      mcqAnswers: _mcqAnswers,
      fileName: _selectedFileName,
    );
  }

  Future<bool> _enterFullscreen() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    return requestBrowserFullscreen();
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    exitBrowserFullscreen();
  }

  // ── Biometric ────────────────────────────────────────────────────────
  Future<void> _runBiometricAuth() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isDeviceSupported) {
        if (mounted) setState(() => _biometricPassed = true);
        return;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to start the exam',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (authenticated) {
        if (mounted) setState(() => _biometricPassed = true);
        return;
      }
      _biometricFailures++;
      if (_biometricFailures >= 3 && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppColors.bgSurface,
            title: Text('Cannot verify identity',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            content: const Text(
              'Biometric verification failed several times. You can continue, but your attempt will be marked as unverified and may be reviewed by your instructor.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Try Again'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryIndigo),
                child: const Text('Continue Anyway',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (proceed == true && mounted) {
          setState(() => _biometricPassed = true);
        }
        return;
      }
      if (mounted) {
        setState(
            () => _error = 'Identity verification failed. Please try again.');
      }
    } catch (_) {
      // local_auth not available (e.g., web) — skip
      if (mounted) setState(() => _biometricPassed = true);
    }
  }

  // ── Exam Start ──────────────────────────────────────────────────
  Future<void> _startExam() async {
    try {
      final bioStatus = _biometricPassed ? 'passed' : 'skipped';
      final result =
          await _repo.startExam(widget.courseId, widget.assignmentId, biometricStatus: bioStatus);
      final attemptId = result['attempt_id'] as int? ?? result['id'] as int?;
      final timeLimit = result['time_limit_minutes'] as int?;
      final remaining = result['remaining_seconds'] as int?;
      final serverSwitches = result['tab_switch_count'] as int?;
      final currentAnswers = result['current_answers'] as String?;

      setState(() {
        _attemptId = attemptId;
        _examStarted = true;
        _stateMachine.transitionTo(ExamState.active);
        _remainingSeconds = remaining ?? (timeLimit ?? 0) * 60;
        if (serverSwitches != null && serverSwitches > _tabSwitchCount) {
          _tabSwitchCount = serverSwitches;
        }
        if (result['is_flagged'] == true) _isFlagged = true;
        _serverStrikeLimitFlag = result['strike_limit_flag'] as int? ?? _serverStrikeLimitFlag;
        _serverStrikeLimitAutosubmit = result['strike_limit_autosubmit'] as int? ?? _serverStrikeLimitAutosubmit;
        if (result['fullscreen_required'] != null) {
          _serverFullscreenRequired = result['fullscreen_required'] == true;
        }
        if (result['block_copy_paste'] != null) {
          _serverBlockClipboard = result['block_copy_paste'] == true;
        }
        if (result['unsupported_browser_policy'] != null) {
          _serverUnsupportedBrowserPolicy = result['unsupported_browser_policy'].toString();
        }
        if (currentAnswers != null && currentAnswers.isNotEmpty) {
          _restoreAnswers(currentAnswers);
        }
      });

      // Check multi-monitor setup
      _checkScreens();

      // Start 10s heartbeat
      _startHeartbeat();

      // Mobile native lock (Kiosk & FLAG_SECURE)
      await MobileProctorService.startExamLock();

      if (_remainingSeconds > 0) {
        _startTimer();
      } else if (timeLimit != null && timeLimit > 0) {
        // Resumed a session whose time has already expired on the server
        _autoSubmit();
      }
    } catch (e) {
      if (mounted) setState(() => _error = ErrorParser.parse(e));
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        t.cancel();
        _autoSubmit();
      } else {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds == 0) {
          t.cancel();
          _autoSubmit();
        }
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    if (!_examStarted || _submitted || _submitting || _attemptId == null) return;
    try {
      final draft = _getCurrentAnswersDraft();
      final res = await _repo.sendHeartbeat(_attemptId!, answers: draft);
      if (mounted) {
        if (_isOffline) {
          setState(() => _isOffline = false);
        }
        final serverRemaining = res['remaining_seconds'] as int?;
        if (serverRemaining != null) {
          setState(() => _remainingSeconds = serverRemaining);
        }
      }
      await _drainQueuedViolations();
      if (res['auto_closed'] == true && mounted) {
        _timer?.cancel();
        _exitFullscreen();
        setState(() {
          _submitted = true;
          _isFlagged = res['is_flagged'] == true;
        });
      }
    } catch (e) {
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    }
  }

  Future<void> _checkScreens() async {
    try {
      final screens = await checkConnectedScreensCount();
      if (screens > 1 && mounted) {
        _reportViolation('multi_monitor',
            details: 'Detected $screens connected displays');
      }
    } catch (_) {}
  }

  Future<void> _autoSubmit() async {
    if (!_examStarted || _submitted || _submitting) return;
    await _submitExam(autoSubmitted: true);
  }

  // ── App lifecycle ── (Native / OS switch detection) ────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_examStarted || _submitted || _detector.isRestoringExam) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _handleViolation('window_blur', details: 'App lost focus or minimized');
    }
  }

  // ── Violation Reporting & Offline Queue ─────────────────────────────
  Future<void> _reportViolation(String type, {String? details}) async {
    if (_attemptId == null) {
      _violationQueue.enqueue(
          type: type, details: details, timestamp: DateTime.now());
      return;
    }
    try {
      final result = await _repo.reportAttemptViolation(
        _attemptId!,
        type: type,
        details: details,
      );
      final serverSwitches = result['tab_switch_count'] as int?;
      if (mounted) {
        setState(() {
          if (serverSwitches != null && serverSwitches >= _tabSwitchCount) {
            _tabSwitchCount = serverSwitches;
          }
          if (result['is_flagged'] == true) _isFlagged = true;
          if (_isOffline) _isOffline = false;
        });
        if (result['auto_closed'] == true) {
          _timer?.cancel();
          _exitFullscreen();
          setState(() => _submitted = true);
        }
      }
    } catch (e) {
      _violationQueue.enqueue(
          type: type, details: details, timestamp: DateTime.now());
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    }
  }

  Future<void> _drainQueuedViolations() async {
    if (_violationQueue.pendingCount == 0 || _attemptId == null) return;
    while (_violationQueue.pendingCount > 0) {
      final item = _violationQueue.peekFirst();
      if (item == null) break;
      try {
        await _repo.reportAttemptViolation(
          _attemptId!,
          type: item['type'] as String,
          details: item['details'] as String?,
        );
        _violationQueue.removeFirst();
      } catch (_) {
        // Network still unavailable or failed mid-stream: keep all remaining in queue
        break;
      }
    }
  }


  void _startReturnCountdown() {
    _returnCountdownTimer?.cancel();
    if (mounted) {
      setState(() => _returnSecondsRemaining = _returnGraceDuration);
    }
    _returnCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_fullscreenExitActive || _submitted || _submitting) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_returnSecondsRemaining > 0) {
          _returnSecondsRemaining--;
        }
      });
      if (_returnSecondsRemaining <= 0) {
        timer.cancel();
        _onReturnGraceTimeout();
      }
    });
  }

  void _cancelReturnCountdown() {
    _returnCountdownTimer?.cancel();
    _returnCountdownTimer = null;
    if (mounted) {
      setState(() => _returnSecondsRemaining = _returnGraceDuration);
    }
  }

  Future<void> _onReturnGraceTimeout() async {
    if (!_fullscreenExitActive || _submitted || _submitting) return;
    _handleViolation('fullscreen_exit_timeout',
        details: 'Student failed to return to exam within 15 seconds grace period.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Grace period expired: You failed to return to fullscreen. Auto-submitting exam.'),
        backgroundColor: Colors.red,
      ));
    }
    await _submitExam(autoSubmitted: true);
  }

  void _handleViolation(String type, {String? details}) {
    if (!_examStarted || _submitted || _submitting) return;
    final now = DateTime.now();
    if (!_detector.shouldRecordViolation(type, now)) return;

    setState(() {
      _tabSwitchCount++;
      if (_tabSwitchCount >= 3) _isFlagged = true;
      if (type == 'window_blur' || type == 'tab_switch' || type == 'fullscreen_exit') {
        _fullscreenExitActive = true;
        _startReturnCountdown();
      }
    });

    _reportViolation(type, details: details);
  }

  void _handleFullscreenExit() {
    if (!_examStarted || _submitted || _submitting || _detector.isRestoringExam) {
      return;
    }
    _handleViolation('fullscreen_exit', details: 'Exited fullscreen mode');
    if (mounted) {
      setState(() => _fullscreenExitActive = true);
      _startReturnCountdown();
    }
  }

  DateTime? _lastRestrictedKeyWarning;

  void _handleRestrictedKey(String reason) {
    if (!_examStarted || _submitted || _submitting) return;
    final now = DateTime.now();
    if (_lastRestrictedKeyWarning != null &&
        now.difference(_lastRestrictedKeyWarning!) < const Duration(seconds: 2)) {
      return;
    }
    _lastRestrictedKeyWarning = now;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Key restricted: $reason. Focus mode is strictly enforced.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCopyPasteViolation(String action) {
    if (!_examStarted || _submitted || _submitting) return;
    _handleViolation('copy_paste',
        details: 'Attempted $action on proctored exam area');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Action blocked: $action is disabled for academic integrity.'),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────
  Future<void> _submitExam({bool autoSubmitted = false}) async {
    if (_submitted || _submitting) return;
    setState(() => _submitting = true);

    try {
      if (_effectiveType == 'file' && _selectedFileBytes != null && _selectedFileName != null) {
        await _repo.submitFile(
          widget.courseId,
          widget.assignmentId,
          _selectedFileBytes!,
          _selectedFileName!,
          autoSubmitted: autoSubmitted,
        );
      }

      final draftPayload = _getCurrentAnswersDraft();
      await _repo.submitExam(
        widget.courseId,
        widget.assignmentId,
        data: {
          'submission_type': _effectiveType,
          'answers': draftPayload,
        },
      );

      _timer?.cancel();
      _heartbeatTimer?.cancel();
      _exitFullscreen();
      await MobileProctorService.releaseExamLock();

      if (mounted) {
        setState(() {
          _submitted = true;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Item 1.7: On failure keep timers and heartbeat running and let student retry
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Submission failed: ${ErrorParser.parse(e)}. Please retry.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── Timer display ─────────────────────────────────────────────────────
  String get _timerDisplay {
    if (_effectiveTimeLimitMinutes == null) return '';
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_remainingSeconds > 300) return AppColors.successGreen;
    if (_remainingSeconds > 60) return AppColors.accentAmber;
    return Colors.red;
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobileWidth = MediaQuery.sizeOf(context).width < 640;

    // ─ Mobile Web Gatekeeper ─
    if (kIsWeb && DeviceInspector.isMobileBrowser()) {
      return const ExamMobileBlockView();
    }

    // ─ Biometric gate ─
    if (!_biometricPassed) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint,
                    size: 72, color: AppColors.primaryIndigo),
                const SizedBox(height: 24),
                Text('Identity Verification Required',
                    style: GoogleFonts.outfit(
                        fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'Please verify your identity using biometrics or device PIN to start the exam.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _runBiometricAuth,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Verify Identity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ─ Pre-exam instructions ─
    if (!_examStarted && !_submitted) {
      final fsSupported = isBrowserFullscreenSupported();
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        appBar: AppBar(
          title: Text(_effectiveTitle,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Before You Start',
                      style: GoogleFonts.outfit(
                          fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _instructionItem(
                      Icons.timer_outlined,
                      _effectiveTimeLimitMinutes != null
                          ? 'Time limit: ${_effectiveTimeLimitMinutes} minutes. The server strictly enforces this limit and auto-submits when time expires.'
                          : 'No time limit for this exam.'),
                  _instructionItem(
                      _effectiveFullscreenRequired ? Icons.fullscreen : Icons.fullscreen_exit,
                      _effectiveFullscreenRequired
                          ? 'The exam runs in fullscreen focus mode. Exiting fullscreen locks the exam immediately.'
                          : 'Windowed Mode: Fullscreen enforcement is not required for this assessment.'),
                  _instructionItem(Icons.visibility,
                      'Leaving the app or switching tabs is recorded in an audit timeline and flagged for your instructor.'),
                  _instructionItem(Icons.warning_amber_rounded,
                      'After $_serverStrikeLimitFlag tab switches or violations, your attempt will be flagged for review (auto-submit at $_serverStrikeLimitAutosubmit strikes).'),
                  _instructionItem(
                      _effectiveBlockClipboard ? Icons.content_paste_off_rounded : Icons.content_paste_rounded,
                      _effectiveBlockClipboard
                          ? 'Clipboard Locked: Copying, cutting, pasting, and context menus are disabled.'
                          : 'Clipboard Permitted: Standard copy and paste actions are allowed for this assessment.'),
                  if (!fsSupported) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.unsupportedBrowserPolicy == 'block'
                                  ? 'Notice: Fullscreen is unsupported on this browser. Starting the exam will be blocked.'
                                  : 'Notice: Fullscreen is unsupported on this mobile/browser platform. Tab and focus tracking remain active.',
                              style: GoogleFonts.inter(
                                  color: Colors.orange.shade900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: GoogleFonts.inter(
                                    color: Colors.red, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() => _error = null);
                        // Check browser fullscreen capability
                        final supported = isBrowserFullscreenSupported();
                        if (!supported && widget.unsupportedBrowserPolicy == 'block') {
                          setState(() => _error =
                              'Fullscreen is required. Please open this exam in Chrome, Edge, or Firefox on desktop.');
                          return;
                        }

                        // Synchronously invoke fullscreen BEFORE any async network await
                        final fsEntered = await _enterFullscreen();
                        if (widget.fullscreenRequired && supported && !fsEntered) {
                          setState(() => _error =
                              'Fullscreen is required. Please allow fullscreen permission and try again.');
                          return;
                        }

                        await _startExam();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _attemptResumed ? 'Resume Proctored Exam' : 'Start Exam',
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ─ Submitted / Result screen ─
    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.bgPage,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 80, color: AppColors.successGreen),
                const SizedBox(height: 24),
                Text('Exam Submitted!',
                    style: GoogleFonts.outfit(
                        fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  'Your answers have been recorded successfully. Your instructor will grade them shortly.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, height: 1.5),
                ),
                if (_isFlagged) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Note: Your attempt was flagged due to $_tabSwitchCount proctoring events. Your instructor has been notified.',
                            style: GoogleFonts.inter(
                                color: Colors.orange.shade800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    _exitFullscreen();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Back to Assignment'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ─ Active exam ─
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Leave Exam?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            content: const Text(
                'Are you sure you want to leave? Your progress may be lost and this exit will be recorded in the audit log.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Stay')),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && mounted) {
          _exitFullscreen();
          Navigator.pop(context);
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (!_examStarted || _submitted) return KeyEventResult.ignored;

          final key = event.logicalKey;
          // 1. Intercept Windows / Meta / OS keys
          if (key == LogicalKeyboardKey.metaLeft ||
              key == LogicalKeyboardKey.metaRight ||
              key == LogicalKeyboardKey.meta ||
              key == LogicalKeyboardKey.contextMenu) {
            if (event is KeyDownEvent) {
              _handleRestrictedKey('Windows/System key');
            }
            return KeyEventResult.handled;
          }

          // 2. Intercept Alt combinations
          if (HardwareKeyboard.instance.isAltPressed &&
              (key == LogicalKeyboardKey.tab ||
               key == LogicalKeyboardKey.f4 ||
               key == LogicalKeyboardKey.escape ||
               key == LogicalKeyboardKey.arrowLeft ||
               key == LogicalKeyboardKey.arrowRight)) {
            if (event is KeyDownEvent) {
              _handleRestrictedKey('Alt combination');
            }
            return KeyEventResult.handled;
          }

          // 3. Intercept Function keys (F5, F11, F12, F1, F3)
          if (key == LogicalKeyboardKey.f5 ||
              key == LogicalKeyboardKey.f11 ||
              key == LogicalKeyboardKey.f12 ||
              key == LogicalKeyboardKey.f1 ||
              key == LogicalKeyboardKey.f3) {
            if (event is KeyDownEvent) {
              _handleRestrictedKey('${key.keyLabel} key');
            }
            return KeyEventResult.handled;
          }

          // 4. Intercept Escape key
          if (key == LogicalKeyboardKey.escape) {
            if (event is KeyDownEvent) {
              _handleRestrictedKey('Escape key');
            }
            return KeyEventResult.handled;
          }

          // 5. Intercept browser control shortcuts
          if (HardwareKeyboard.instance.isControlPressed) {
            if (key == LogicalKeyboardKey.keyW ||
                key == LogicalKeyboardKey.keyT ||
                key == LogicalKeyboardKey.keyN ||
                key == LogicalKeyboardKey.keyR ||
                key == LogicalKeyboardKey.keyU ||
                key == LogicalKeyboardKey.keyP ||
                key == LogicalKeyboardKey.keyH) {
              if (event is KeyDownEvent) {
                _handleRestrictedKey('Browser shortcut');
              }
              return KeyEventResult.handled;
            }
            if (HardwareKeyboard.instance.isShiftPressed &&
                (key == LogicalKeyboardKey.keyI ||
                 key == LogicalKeyboardKey.keyJ ||
                 key == LogicalKeyboardKey.keyC)) {
              if (event is KeyDownEvent) {
                _handleRestrictedKey('Developer tools');
              }
              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AppColors.bgPage,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(widget.assignmentTitle,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primaryIndigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.primaryIndigo.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 14, color: AppColors.primaryIndigo),
                        const SizedBox(width: 5),
                        Text(
                          'Proctored',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Fullscreen Focus Mode',
                  icon: const Icon(Icons.fullscreen_rounded, size: 20),
                  onPressed: () async {
                    await _enterFullscreen();
                  },
                ),
              ),
              if (!isMobileWidth && _effectiveTimeLimitMinutes != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _timerColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _timerColor.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 16, color: _timerColor),
                          const SizedBox(width: 6),
                          Text(
                            _timerDisplay,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _timerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isFlagged)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: 'Attempt flagged for review',
                    child: Icon(Icons.flag_rounded, color: Colors.orange),
                  ),
                ),
              if (!isMobileWidth)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ElevatedButton(
                    onPressed: _submitting ? null : () => _confirmSubmit(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Exam'),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: isMobileWidth
              ? Container(
                  decoration: const BoxDecoration(
                    color: AppColors.bgSurface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 10,
                    bottom: 10 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        if (_effectiveTimeLimitMinutes != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _timerColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: _timerColor.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 16, color: _timerColor),
                                const SizedBox(width: 6),
                                Text(
                                  _timerDisplay,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _timerColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _submitting ? null : () => _confirmSubmit(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Submit Exam'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        body: Stack(
          children: [
            Column(
              children: [
                if (_isOffline)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    color: AppColors.accentAmber,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 16, color: Colors.black87),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Connection lost. Reconnecting... (Your answers and activity are queued locally)',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                        ),
                        if (_violationQueue.pendingCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_violationQueue.pendingCount} buffered',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_tabSwitchCount > 0)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (_isFlagged ? Colors.red : Colors.orange)
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      (_isFlagged ? Colors.red : Colors.orange)
                                          .withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isFlagged
                                      ? Icons.flag_rounded
                                      : Icons.warning_amber_rounded,
                                  color: _isFlagged
                                      ? Colors.red
                                      : Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isFlagged
                                      ? 'Attempt flagged ($_tabSwitchCount strikes) — instructor notified'
                                      : 'Proctor strikes: $_tabSwitchCount / 3 before flagging',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _isFlagged
                                        ? Colors.red.shade700
                                        : Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Question / Prompt
                        if (widget.description != null &&
                            widget.description!.isNotEmpty)
                          Builder(
                            builder: (context) {
                              String promptText = widget.description!;
                              if (widget.assignmentType == 'mcq') {
                                try {
                                  final decoded = jsonDecode(promptText);
                                  if (decoded is Map<String, dynamic>) {
                                    promptText = (decoded['instructions'] ?? '')
                                        .toString();
                                  }
                                } catch (_) {}
                              }
                              if (promptText.trim().isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Question / Prompt',
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMuted,
                                            letterSpacing: 0.5)),
                                    const SizedBox(height: 10),
                                    Text(
                                      promptText,
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                          height: 1.6),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                        // Answer section
                        _buildAnswerSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Fullscreen Exit Blocking Overlay ───────────────────────
            if (_fullscreenExitActive)
              Positioned.fill(
                child: Container(
                  color: AppColors.bgSurface.withOpacity(0.98),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                            const Icon(Icons.fullscreen_exit_rounded,
                                size: 72, color: Colors.red),
                            const SizedBox(height: 20),
                            Text(
                              'Exam Locked: Fullscreen Focus Lost',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'You exited fullscreen mode. All exits are recorded as proctoring violations and reported to your instructor. Return immediately to continue.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.4),
                                    width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.timer_outlined,
                                          color: Colors.red, size: 28),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$_returnSecondsRemaining',
                                        style: GoogleFonts.outfit(
                                          fontSize: 38,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'sec',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Time Left to Return before Auto-Submission',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Failure to re-enter fullscreen within this window will terminate and auto-submit your attempt.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Recorded Strikes: $_tabSwitchCount',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red),
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryIndigo,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.fullscreen_rounded),
                                label: const Text('Return to Exam',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                                onPressed: () async {
                                  _cancelReturnCountdown();
                                  _detector.startRestoring();
                                  try {
                                    final restored = await _enterFullscreen();
                                    if (restored ||
                                        !isBrowserFullscreenSupported()) {
                                      if (mounted) {
                                        setState(() =>
                                            _fullscreenExitActive = false);
                                      }
                                    } else {
                                      _handleViolation('fullscreen_exit',
                                          details: 'Fullscreen refused on Return to Exam');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text(
                                              'Fullscreen could not be restored. Please allow fullscreen permission or submit your exam.'),
                                        ));
                                      }
                                    }
                                  } finally {
                                    _detector.endRestoring();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              key: const Key('overlay_submit_now_button'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Exam Submission'),
                                    content: const Text(
                                        'Are you sure you want to submit your exam now while outside fullscreen?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Submit Now'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await _submitExam();
                                }
                              },
                              child: const Text(
                                'Unable to restore fullscreen? Submit Exam Now',
                                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildAnswerSection() {
    switch (_effectiveType) {
      case 'file':
        return _buildFileSection();
      case 'programming':
        return _buildCodeSection();
      case 'mcq':
        return _buildMcqSection();
      default:
        return _buildTextSection();
    }
  }

  String? _serializeMcqAnswers() {
    if (_mcqAnswers.isEmpty) return null;
    if (_mcqAnswers.length == 1) {
      return 'Option ${_optionLetter(_mcqAnswers.values.first)}';
    }
    final buffer = StringBuffer();
    final keys = _mcqAnswers.keys.toList()..sort();
    for (final k in keys) {
      buffer.writeln(
          'Question ${k + 1}: Option ${_optionLetter(_mcqAnswers[k]!)}');
    }
    return buffer.toString().trim();
  }

  String _optionLetter(int optionValue) {
    const letters = ['A', 'B', 'C', 'D', 'E'];
    final idx = (optionValue - 1).clamp(0, letters.length - 1);
    return letters[idx];
  }

  Widget _buildTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Answer',
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.statusNeutralBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Paste disabled',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _textCtrl,
          maxLines: 12,
          enableInteractiveSelection: false,
          decoration: InputDecoration(
            hintText: 'Write your answer here...',
            filled: true,
            fillColor: AppColors.bgSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          style: GoogleFonts.inter(fontSize: 14, height: 1.6),
        ),
      ],
    );
  }

  Widget _buildCodeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Your Code',
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.statusNeutralBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Paste disabled',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _codeCtrl,
          maxLines: 16,
          enableInteractiveSelection: false,
          style: GoogleFonts.jetBrainsMono(
              fontSize: 13, color: AppColors.inkPrimary),
          decoration: InputDecoration(
            hintText: '// Write your code here...\n',
            hintStyle: GoogleFonts.jetBrainsMono(
                fontSize: 13, color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF0F1117),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMcqSection() {
    final desc = _effectiveDescription ?? '';
    final structuredQuestions = parseMcqDescription(desc);
    if (structuredQuestions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < structuredQuestions.length; i++) ...[
            Text(structuredQuestions[i]['question'].toString(),
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Builder(
              builder: (ctx) {
                final opts = (structuredQuestions[i]['options'] as List?)
                        ?.map((o) => o.toString().trim())
                        .where((s) => s.isNotEmpty)
                        .toList() ??
                    const <String>[];
                if (opts.length < 2) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Enter your answer...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                          borderSide: const BorderSide(color: AppColors.rule),
                        ),
                      ),
                    ),
                  );
                }
                return _mcqOptions(opts, i);
              },
            ),
            if (i < structuredQuestions.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: AppColors.border),
              ),
          ],
        ],
      );
    }

    final lines = desc.split('\n');
    final questionLines = <String>[];
    final optionLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (RegExp(r'^[A-Ea-e][).]').hasMatch(trimmed)) {
        optionLines.add(trimmed);
      } else if (trimmed.isNotEmpty) {
        questionLines.add(trimmed);
      }
    }

    if (optionLines.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (questionLines.isNotEmpty)
            Text(questionLines.join('\n'),
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildTextSection(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (questionLines.isNotEmpty)
          Text(questionLines.join('\n'),
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _mcqOptions(optionLines, 0),
      ],
    );
  }

  Widget _mcqOptions(List<String> optionLines, int questionIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Your Answer',
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: optionLines.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (_, i) {
              final optionText = optionLines[i];
              final optionValue = i + 1;
              return RadioListTile<int>(
                value: optionValue,
                groupValue: _mcqAnswers[questionIndex],
                onChanged: (v) =>
                    setState(() => _mcqAnswers[questionIndex] = v!),
                title: Text(optionText,
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary)),
                activeColor: AppColors.primaryIndigo,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Upload Your File',
            style:
                GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Allowed: PDF, ZIP, DOCX, TXT • Max: 25 MB',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            _detector.startFilePicker();
            try {
              const allowedExts = ['pdf', 'zip', 'docx', 'doc', 'txt'];
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: allowedExts,
                withData: true,
              );
              if (result != null && result.files.single.bytes != null) {
                final file = result.files.single;
                final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : '';
                if (!allowedExts.contains(ext)) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Invalid file format ".$ext". Allowed: ${allowedExts.map((e) => ".$e").join(", ")}'),
                      backgroundColor: Colors.red,
                    ));
                  }
                  return;
                }
                const maxBytes = 25 * 1024 * 1024;
                if (file.size > maxBytes) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('File too large. Max 25 MB allowed.'),
                      backgroundColor: Colors.red,
                    ));
                  }
                  return;
                }
                setState(() {
                  _selectedFileName = file.name;
                  _selectedFileBytes = file.bytes!.toList();
                });
              }
            } finally {
              _detector.endFilePicker();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryIndigo.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _selectedFileName != null
                      ? Icons.insert_drive_file_rounded
                      : Icons.cloud_upload_outlined,
                  size: 40,
                  color: AppColors.primaryIndigo,
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedFileName ?? 'Click to choose file',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: _selectedFileName != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: _selectedFileName != null
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _instructionItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryIndigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.inter(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Submit Exam?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: const Text(
            'Are you sure you want to submit? You cannot make changes after submission.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Review Answers')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successGreen,
                foregroundColor: Colors.white),
            child: const Text('Submit Now'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submitExam();
  }
}
