enum ExamState {
  initial,
  identityVerification,
  active,
  fullscreenExitOverlay,
  submitting,
  submitted,
}

/// Pure Dart state machine for exam session transitions.
class ExamStateMachine {
  ExamStateMachine({ExamState initialState = ExamState.initial})
      : _state = initialState;

  ExamState _state;
  ExamState get state => _state;

  bool get isActive => _state == ExamState.active;
  bool get isBlockingOverlay => _state == ExamState.fullscreenExitOverlay;
  bool get isFinished => _state == ExamState.submitted;

  bool transitionTo(ExamState next) {
    switch (_state) {
      case ExamState.initial:
        if (next == ExamState.identityVerification || next == ExamState.active) {
          _state = next;
          return true;
        }
        return false;

      case ExamState.identityVerification:
        if (next == ExamState.active || next == ExamState.initial) {
          _state = next;
          return true;
        }
        return false;

      case ExamState.active:
        if (next == ExamState.fullscreenExitOverlay || next == ExamState.submitting) {
          _state = next;
          return true;
        }
        return false;

      case ExamState.fullscreenExitOverlay:
        if (next == ExamState.active || next == ExamState.submitting) {
          _state = next;
          return true;
        }
        return false;

      case ExamState.submitting:
        if (next == ExamState.submitted || next == ExamState.active) {
          _state = next;
          return true;
        }
        return false;

      case ExamState.submitted:
        return false;
    }
  }
}
