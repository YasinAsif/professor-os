import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:professor_os/features/auth/providers/auth_provider.dart';
import 'package:professor_os/features/courses/presentation/course_list_screen.dart';
import 'package:professor_os/features/courses/presentation/course_detail_screen.dart';
import 'package:professor_os/features/courses/providers/course_providers.dart';

class _ProfessorAuthNotifier extends AuthNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {'role': 'professor'};
}

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

  testWidgets('professor course actions stay accessible on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_ProfessorAuthNotifier.new),
          courseDetailProvider(1).overrideWith((ref) async => {
                'id': 1,
                'title': 'Mobile QA Course',
                'code': 'MOB101',
              }),
          assignmentListProvider(1).overrideWith((ref) async => {
                'assignments': <dynamic>[],
                'total': 0,
              }),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(courseId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Course actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Course actions'));
    await tester.pumpAndSettle();
    expect(find.text('Ask Course AI'), findsOneWidget);
    expect(find.text('Gradebook CSV'), findsOneWidget);
    expect(find.text('Cohort Analytics'), findsOneWidget);
  });
}
