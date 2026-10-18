import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/exam_submission.dart';

void main() {
  test('creates a visible placeholder for an empty file exam submission', () {
    expect(
      emptyExamSubmission('file', autoSubmitted: false),
      {'submission_type': 'file', 'content': '[No File Attached]'},
    );
  });

  test('creates an auto-submit placeholder for an empty text response', () {
    expect(
      emptyExamSubmission('text', autoSubmitted: true),
      {
        'submission_type': 'text',
        'content': '[Time Expired - Auto-Submitted by System]',
      },
    );
  });
}
