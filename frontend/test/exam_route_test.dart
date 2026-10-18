import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/exam_route.dart';

void main() {
  test('builds the isolated exam route for an assignment', () {
    expect(examRoutePath(4, 9), '/courses/4/assignments/9/exam');
  });

  test('preserves assignment data in the exam route payload', () {
    final payload = examRouteExtra(
      title: 'Midterm',
      type: 'programming',
      description: 'Solve it',
      maxMarks: 50,
      timeLimitMinutes: 30,
      randomizeQuestions: true,
      showResultsAfter: false,
    );

    expect(payload['title'], 'Midterm');
    expect(payload['type'], 'programming');
    expect(payload['time_limit_minutes'], 30);
    expect(payload['randomize_questions'], isTrue);
    expect(payload['show_results_after'], isFalse);
  });
}
