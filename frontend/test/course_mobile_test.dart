import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:professor_os/features/courses/presentation/course_list_screen.dart';
import 'package:professor_os/features/courses/providers/course_providers.dart';

void main() {
  testWidgets('course list renders its mobile content at phone width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          courseListProvider.overrideWith((ref) async => {
                'courses': [
                  {
                    'id': 1,
                    'title': 'Software Construction and Development',
                    'code': 'SE2112',
                    'semester': 'Spring 2024',
                    'enrollment_count': 42,
                  },
                ],
              }),
        ],
        child: const MaterialApp(home: CourseListScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('My Enrollments'), findsOneWidget);
    expect(find.text('Software Construction and Development'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
