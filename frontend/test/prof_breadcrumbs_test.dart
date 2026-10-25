import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/shared/widgets/prof_breadcrumbs.dart';

void main() {
  group('ProfBreadcrumbs Widget Tests', () {
    testWidgets('renders all breadcrumb items and chevron dividers', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfBreadcrumbs(
                items: [
                  BreadcrumbItem(label: 'Courses', path: '/courses'),
                  BreadcrumbItem(label: 'CS-101', path: '/courses/1'),
                  BreadcrumbItem(label: 'Midterm Exam'),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify item labels are present
      expect(find.text('Courses'), findsOneWidget);
      expect(find.text('CS-101'), findsOneWidget);
      expect(find.text('Midterm Exam'), findsOneWidget);

      // Verify chevron dividers (2 dividers for 3 items)
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    });

    testWidgets('renders empty when items list is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProfBreadcrumbs(items: []),
            ),
          ),
        ),
      );

      expect(find.byType(ProfBreadcrumbs), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });
}
