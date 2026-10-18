import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/proctor_detector.dart';
import 'package:professor_os/features/courses/utils/offline_violation_queue.dart';
import 'package:professor_os/features/courses/utils/exam_state_machine.dart';

void main() {
  group('ProctorDetector Deduplication', () {
    test('ignores duplicate violations of same type within dedupe window', () {
      final detector = ProctorDetector(
        dedupeWindow: const Duration(milliseconds: 1500),
      );
      final t0 = DateTime(2026, 10, 17, 12, 0, 0);

      // First event allowed
      expect(detector.shouldRecordViolation('tab_switch', t0), isTrue);

      // Second event within 500ms ignored
      expect(
        detector.shouldRecordViolation(
          'tab_switch',
          t0.add(const Duration(milliseconds: 500)),
        ),
        isFalse,
      );

      // Second event within 1499ms ignored
      expect(
        detector.shouldRecordViolation(
          'tab_switch',
          t0.add(const Duration(milliseconds: 1499)),
        ),
        isFalse,
      );

      // Event at 1501ms allowed
      expect(
        detector.shouldRecordViolation(
          'tab_switch',
          t0.add(const Duration(milliseconds: 1501)),
        ),
        isTrue,
      );

      detector.dispose();
    });

    test('deduplicates independently per violation type', () {
      final detector = ProctorDetector();
      final t0 = DateTime(2026, 10, 17, 12, 0, 0);

      expect(detector.shouldRecordViolation('tab_switch', t0), isTrue);
      // Different violation type at same millisecond is allowed
      expect(detector.shouldRecordViolation('fullscreen_exit', t0), isTrue);

      // Within dedupe window, both are ignored
      expect(
        detector.shouldRecordViolation(
          'tab_switch',
          t0.add(const Duration(milliseconds: 300)),
        ),
        isFalse,
      );
      expect(
        detector.shouldRecordViolation(
          'fullscreen_exit',
          t0.add(const Duration(milliseconds: 300)),
        ),
        isFalse,
      );

      detector.dispose();
    });

    test('deduplicates tab_switch and window_blur together under focus_loss group', () {
      final detector = ProctorDetector();
      final t0 = DateTime(2026, 10, 17, 12, 0, 0);

      // 1. window_blur triggers at t0
      expect(detector.shouldRecordViolation('window_blur', t0), isTrue);

      // 2. tab_switch 30ms later must be ignored (focus_loss group)
      expect(
        detector.shouldRecordViolation(
          'tab_switch',
          t0.add(const Duration(milliseconds: 30)),
        ),
        isFalse,
      );

      // 3. window_blur 500ms later must also be ignored
      expect(
        detector.shouldRecordViolation(
          'window_blur',
          t0.add(const Duration(milliseconds: 500)),
        ),
        isFalse,
      );

      // 4. After dedupe window (1501ms), focus loss event is accepted again
      expect(
        detector.shouldRecordViolation(
          'tab_switch',
          t0.add(const Duration(milliseconds: 1501)),
        ),
        isTrue,
      );

      detector.dispose();
    });
  });

  group('ProctorDetector _restoringExam State', () {
    test('pauses violation recording while restoring, resumes after endRestoring()', () {
      final detector = ProctorDetector();
      final t0 = DateTime(2026, 10, 17, 12, 0, 0);

      detector.startRestoring();
      expect(detector.isRestoringExam, isTrue);
      expect(detector.shouldRecordViolation('window_blur', t0), isFalse);

      detector.endRestoring();
      expect(detector.isRestoringExam, isFalse);
      expect(detector.shouldRecordViolation('window_blur', t0), isTrue);

      detector.dispose();
    });

    test('safety timer resets restoring state automatically after timeout', () async {
      final detector = ProctorDetector(
        maxRestoringTimeout: const Duration(milliseconds: 50),
      );
      detector.startRestoring();
      expect(detector.isRestoringExam, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(detector.isRestoringExam, isFalse);

      detector.dispose();
    });
  });

  group('ProctorDetector File Picker False Strike Prevention', () {
    test('ignores blur/visibility events while file picker is open', () {
      final detector = ProctorDetector();
      final t0 = DateTime(2026, 10, 17, 12, 0, 0);

      detector.startFilePicker();
      expect(detector.isFilePickerOpen, isTrue);

      expect(detector.shouldRecordViolation('window_blur', t0), isFalse);
      expect(detector.shouldRecordViolation('tab_switch', t0), isFalse);

      detector.dispose();
    });

    test('retains grace period after file picker closes', () async {
      final detector = ProctorDetector(
        filePickerGrace: const Duration(milliseconds: 50),
      );
      final t0 = DateTime(2026, 10, 17, 12, 0, 0);

      detector.startFilePicker();
      detector.endFilePicker();

      // Grace period still active
      expect(detector.isFilePickerOpen, isTrue);
      expect(detector.shouldRecordViolation('window_blur', t0), isFalse);

      // Wait for grace period to expire
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(detector.isFilePickerOpen, isFalse);
      expect(detector.shouldRecordViolation('window_blur', t0), isTrue);

      detector.dispose();
    });
  });

  group('OfflineViolationQueue', () {
    test('enqueues and drains violation items', () {
      final queue = OfflineViolationQueue();
      final now = DateTime(2026, 10, 17, 12, 0, 0);

      expect(queue.pendingCount, 0);
      queue.enqueue(type: 'tab_switch', timestamp: now, details: 'Blurred');
      queue.enqueue(type: 'fullscreen_exit', timestamp: now);

      expect(queue.pendingCount, 2);

      final items = queue.drainQueue();
      expect(items.length, 2);
      expect(items.first['type'], 'tab_switch');
      expect(items.last['type'], 'fullscreen_exit');
      expect(queue.pendingCount, 0);
    });

    test('online status toggle', () {
      final queue = OfflineViolationQueue();
      expect(queue.isOnline, isTrue);

      queue.setOnline(false);
      expect(queue.isOnline, isFalse);

      queue.setOnline(true);
      expect(queue.isOnline, isTrue);
    });

    test('peekFirst and removeFirst retain remaining items in order if network fails', () {
      final queue = OfflineViolationQueue();
      final now = DateTime(2026, 10, 17, 12, 0, 0);

      queue.enqueue(type: 'tab_switch', timestamp: now);
      queue.enqueue(type: 'fullscreen_exit', timestamp: now);
      queue.enqueue(type: 'window_blur', timestamp: now);

      expect(queue.pendingCount, 3);
      expect(queue.peekFirst()!['type'], 'tab_switch');
      expect(queue.pendingCount, 3); // peeking does not drop items

      // Simulate success on first item
      final removed = queue.removeFirst();
      expect(removed!['type'], 'tab_switch');
      expect(queue.pendingCount, 2);

      // Next item is peeked
      expect(queue.peekFirst()!['type'], 'fullscreen_exit');
      // If error occurs here, remaining count is still 2 in exact order
      expect(queue.pendingCount, 2);
    });
  });

  group('ExamStateMachine', () {
    test('follows valid exam lifecycle transitions', () {
      final fsm = ExamStateMachine(initialState: ExamState.initial);
      expect(fsm.state, ExamState.initial);

      expect(fsm.transitionTo(ExamState.identityVerification), isTrue);
      expect(fsm.state, ExamState.identityVerification);

      expect(fsm.transitionTo(ExamState.active), isTrue);
      expect(fsm.isActive, isTrue);

      expect(fsm.transitionTo(ExamState.fullscreenExitOverlay), isTrue);
      expect(fsm.isBlockingOverlay, isTrue);

      expect(fsm.transitionTo(ExamState.active), isTrue);
      expect(fsm.isActive, isTrue);

      expect(fsm.transitionTo(ExamState.submitting), isTrue);
      expect(fsm.transitionTo(ExamState.submitted), isTrue);
      expect(fsm.isFinished, isTrue);

      // Cannot transition out of submitted state
      expect(fsm.transitionTo(ExamState.active), isFalse);
    });

    test('rejects illegal transitions', () {
      final fsm = ExamStateMachine(initialState: ExamState.initial);
      expect(fsm.transitionTo(ExamState.fullscreenExitOverlay), isFalse);
      expect(fsm.transitionTo(ExamState.submitted), isFalse);
    });
  });
}
