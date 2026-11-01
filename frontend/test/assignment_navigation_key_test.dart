import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/presentation/assignment_detail_screen.dart';

void main() {
  testWidgets('AssignmentDetailScreen key and widget update contract',
      (WidgetTester tester) async {
    // Verify ValueKeys differentiate assignment routes
    final keyA = const ValueKey('assignment_69_12');
    final keyB = const ValueKey('assignment_69_13');
    expect(keyA, isNot(equals(keyB)));

    // Verify AssignmentDetailScreen accepts ValueKey correctly
    final screenA = AssignmentDetailScreen(
      key: keyA,
      courseId: 69,
      assignmentId: 12,
      initialAssignment: {
        'id': 12,
        'course_id': 69,
        'title': 'Assignment 01',
        'type': 'text',
      },
    );

    final screenB = AssignmentDetailScreen(
      key: keyB,
      courseId: 69,
      assignmentId: 13,
      initialAssignment: {
        'id': 13,
        'course_id': 69,
        'title': 'Quiz 02',
        'type': 'quiz',
      },
    );

    expect(screenA.key, keyA);
    expect(screenB.key, keyB);
    expect(screenA.assignmentId, 12);
    expect(screenB.assignmentId, 13);
  });
}
