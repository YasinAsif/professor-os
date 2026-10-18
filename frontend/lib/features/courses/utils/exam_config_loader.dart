import '../data/course_repository.dart';

/// Full authoritative server configuration and attempt state for an exam (Items 1.3 & 1.4).
class LoadedExamConfig {
  final int courseId;
  final int assignmentId;
  final String title;
  final String assignmentType;
  final String? description;
  final double maxMarks;
  final int? timeLimitMinutes;
  final bool fullscreenRequired;
  final bool blockClipboard;
  final String unsupportedBrowserPolicy;
  final int strikeLimitFlag;
  final int strikeLimitAutosubmit;
  final bool isProctored;

  // Active attempt state
  final bool isActiveAttempt;
  final int? attemptId;
  final int remainingSeconds;
  final int tabSwitchCount;
  final bool isFlagged;
  final String? currentAnswers;
  final bool isSubmitted;

  LoadedExamConfig({
    required this.courseId,
    required this.assignmentId,
    required this.title,
    required this.assignmentType,
    this.description,
    required this.maxMarks,
    this.timeLimitMinutes,
    required this.fullscreenRequired,
    required this.blockClipboard,
    required this.unsupportedBrowserPolicy,
    required this.strikeLimitFlag,
    required this.strikeLimitAutosubmit,
    required this.isProctored,
    required this.isActiveAttempt,
    this.attemptId,
    required this.remainingSeconds,
    required this.tabSwitchCount,
    required this.isFlagged,
    this.currentAnswers,
    required this.isSubmitted,
  });

  factory LoadedExamConfig.fromServer({
    required int courseId,
    required int assignmentId,
    required Map<String, dynamic> assignmentData,
    required Map<String, dynamic> stateData,
  }) {
    final title = assignmentData['title']?.toString() ?? 'Exam';
    final type = assignmentData['type']?.toString() ?? 'text';
    final desc = assignmentData['description']?.toString();
    final maxMarks = (assignmentData['max_marks'] as num?)?.toDouble() ?? 100.0;
    final timeLimit = assignmentData['time_limit_minutes'] as int?;
    final fsRequired = assignmentData['fullscreen_required'] != false;
    final blockClip = assignmentData['block_copy_paste'] != false;
    final policy = assignmentData['unsupported_browser_policy']?.toString() ?? 'warn_allow';
    final strikeFlag = assignmentData['strike_limit_flag'] as int? ?? 3;
    final strikeAuto = assignmentData['strike_limit_autosubmit'] as int? ?? 5;
    final isProc = assignmentData['is_proctored'] == true || (timeLimit != null && timeLimit > 0);

    final attemptId = stateData['attempt_id'] as int? ?? stateData['id'] as int?;
    final isSub = stateData['submitted_at'] != null || stateData['is_active'] == false;
    final isActive = stateData['is_active'] == true && attemptId != null && !isSub;
    final remaining = (stateData['remaining_seconds'] as num?)?.toInt() ?? (timeLimit != null ? timeLimit * 60 : 0);
    final tabSwitches = (stateData['tab_switch_count'] as num?)?.toInt() ?? 0;
    final isFlagged = stateData['is_flagged'] == true;
    final draft = stateData['current_answers']?.toString();

    return LoadedExamConfig(
      courseId: courseId,
      assignmentId: assignmentId,
      title: title,
      assignmentType: type,
      description: desc,
      maxMarks: maxMarks,
      timeLimitMinutes: timeLimit,
      fullscreenRequired: fsRequired,
      blockClipboard: blockClip,
      unsupportedBrowserPolicy: policy,
      strikeLimitFlag: strikeFlag,
      strikeLimitAutosubmit: strikeAuto,
      isProctored: isProc,
      isActiveAttempt: isActive,
      attemptId: attemptId,
      remainingSeconds: remaining,
      tabSwitchCount: tabSwitches,
      isFlagged: isFlagged,
      currentAnswers: draft,
      isSubmitted: isSub,
    );
  }
}

/// Helper to load authoritative exam config on load / F5 reload without router extras.
class ExamConfigLoader {
  static Future<LoadedExamConfig> load({
    required int courseId,
    required int assignmentId,
    required CourseRepository repo,
  }) async {
    final assignmentData = await repo.getAssignment(courseId, assignmentId);
    Map<String, dynamic> stateData = {};
    try {
      stateData = await repo.getExamState(courseId, assignmentId);
    } catch (_) {
      // If state fetch returns 404 or empty, student has not started
    }

    return LoadedExamConfig.fromServer(
      courseId: courseId,
      assignmentId: assignmentId,
      assignmentData: assignmentData,
      stateData: stateData,
    );
  }
}
