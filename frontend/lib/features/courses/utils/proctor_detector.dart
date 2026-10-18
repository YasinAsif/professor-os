import 'dart:async';

/// Pure Dart anti-cheat proctoring detector.
/// Contains zero browser dependencies so it can be thoroughly unit-tested.
class ProctorDetector {
  ProctorDetector({
    this.dedupeWindow = const Duration(milliseconds: 1500),
    this.filePickerGrace = const Duration(milliseconds: 1500),
    this.maxRestoringTimeout = const Duration(seconds: 3),
    this.maxFilePickerTimeout = const Duration(seconds: 60),
  });

  final Duration dedupeWindow;
  final Duration filePickerGrace;
  final Duration maxRestoringTimeout;
  final Duration maxFilePickerTimeout;

  bool _filePickerOpen = false;
  bool _restoringExam = false;
  Timer? _restoringSafetyTimer;
  Timer? _filePickerSafetyTimer;
  Timer? _filePickerGraceTimer;

  final Map<String, DateTime> _lastViolationByType = {};

  bool get isFilePickerOpen => _filePickerOpen;
  bool get isRestoringExam => _restoringExam;

  /// Call immediately before opening the OS file picker.
  void startFilePicker() {
    _filePickerGraceTimer?.cancel();
    _filePickerOpen = true;
    _filePickerSafetyTimer?.cancel();
    _filePickerSafetyTimer = Timer(maxFilePickerTimeout, () {
      _filePickerOpen = false;
    });
  }

  /// Call immediately when the file picker dialog closes (picked or cancelled).
  void endFilePicker() {
    _filePickerSafetyTimer?.cancel();
    _filePickerGraceTimer?.cancel();
    // Keep flag true for grace period so window-focus events don't falsely strike
    _filePickerGraceTimer = Timer(filePickerGrace, () {
      _filePickerOpen = false;
    });
  }

  /// Pause detection while the warning dialog closes and fullscreen re-enters.
  void startRestoring() {
    _restoringExam = true;
    _restoringSafetyTimer?.cancel();
    // Safety timeout: can never stay restoring for more than 3 seconds
    _restoringSafetyTimer = Timer(maxRestoringTimeout, () {
      _restoringExam = false;
    });
  }

  /// Reset restoring state. Always called in a finally block.
  void endRestoring() {
    _restoringSafetyTimer?.cancel();
    _restoringExam = false;
  }

  /// Evaluates an event (e.g. 'tab_switch', 'window_blur', 'fullscreen_exit').
  /// Returns `true` if this violation should be recorded and reported to the server.
  /// Returns `false` if the event is ignored due to debounce, file picker, or restoring state.
  bool shouldRecordViolation(String type, DateTime now) {
    if (_restoringExam) {
      return false;
    }
    if (_filePickerOpen && (type == 'tab_switch' || type == 'window_blur')) {
      return false;
    }

    final groupKey = (type == 'tab_switch' || type == 'window_blur')
        ? 'focus_loss'
        : type;

    final last = _lastViolationByType[groupKey];
    if (last != null && now.difference(last) < dedupeWindow) {
      return false;
    }

    _lastViolationByType[groupKey] = now;
    return true;
  }

  void dispose() {
    _restoringSafetyTimer?.cancel();
    _filePickerSafetyTimer?.cancel();
    _filePickerGraceTimer?.cancel();
  }
}
