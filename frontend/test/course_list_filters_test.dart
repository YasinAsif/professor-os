import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/presentation/course_list_screen.dart';
import 'package:professor_os/features/courses/providers/course_providers.dart';

Widget _courseList(List<Map<String, dynamic>> courses) {
  return ProviderScope(
    overrides: [
      courseListProvider.overrideWith((ref) async => {'courses': courses}),
    ],
    child: const MaterialApp(home: CourseListScreen()),
  );
}

void main() {
  final courses = [
    {
      'id': 1,
      'title': 'Secure Systems',
      'code': 'CS401',
      'semester': 'Fall 2026',
      'is_archived': false,
    },
    {
      'id': 2,
      'title': 'Legacy Databases',
      'code': 'CS201',
      'semester': 'Spring 2025',
      'is_archived': true,
    },
  ];

  testWidgets('search and active/archive filters compose', (tester) async {
    await tester.pumpWidget(_courseList(courses));
    await tester.pumpAndSettle();

    expect(find.text('Secure Systems'), findsOneWidget);
    expect(find.text('Legacy Databases'), findsNothing);
    await tester.tap(find.text('Archived'));
    await tester.pumpAndSettle();
    expect(find.text('Legacy Databases'), findsOneWidget);
    expect(find.text('Secure Systems'), findsNothing);

    await tester.enterText(find.byType(TextField), 'database');
    await tester.pumpAndSettle();
    expect(find.text('Legacy Databases'), findsOneWidget);
  });

  testWidgets('no-match search shows an actionable empty state',
      (tester) async {
    await tester.pumpWidget(_courseList(courses));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('No matching courses'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);
  });
}
