import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/proctor_attempts.dart';

void main() {
  final attempts = [
    {'id': 1, 'student_id': 7, 'submitted_at': null, 'is_flagged': false},
    {'id': 2, 'student_id': 7, 'submitted_at': '2026-10-14T12:00:00Z', 'is_flagged': true},
  ];

  test('preserves every attempt, including repeated attempts by one student', () {
    expect(normalizeProctorAttempts(attempts), hasLength(2));
  });

  test('counts active and flagged attempts independently', () {
    final counts = summarizeProctorAttempts(attempts);
    expect(counts.active, 1);
    expect(counts.flagged, 1);
  });
}
