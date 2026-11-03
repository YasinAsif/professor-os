import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/auth/presentation/login_screen.dart';
import 'package:professor_os/features/auth/providers/auth_provider.dart';
import 'package:professor_os/features/courses/presentation/assignment_creation_wizard.dart';
import 'package:professor_os/features/courses/presentation/create_course_screen.dart';

class _AdminAuthNotifier extends AuthNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {
        'id': 1,
        'email': 'admin@professoros.edu.pk',
        'role': 'admin',
        'full_name': 'Admin User',
      };
}

class _ProfAuthNotifier extends AuthNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {
        'id': 2,
        'email': 'prof@university.edu',
        'role': 'professor',
        'full_name': 'Professor Test',
      };
}

void main() {
  testWidgets('LoginScreen enables browser autofill and email autofillHints',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify AutofillGroup is present in widget tree
    expect(find.byType(AutofillGroup), findsWidgets);

    // 2. Find TextField widgets and verify email hints
    final textFields = tester.widgetList<TextField>(find.byType(TextField));
    expect(textFields.length, greaterThanOrEqualTo(2));

    final emailField = textFields.first;
    expect(emailField.autofillHints, contains(AutofillHints.email));
    expect(emailField.autofillHints, contains(AutofillHints.username));

    // 3. Verify password hints
    final passField = textFields.elementAt(1);
    expect(passField.autofillHints, contains(AutofillHints.password));
  });

  testWidgets('CreateCourseScreen locks semesters to Fall 2026 and Spring 2027',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _AdminAuthNotifier()),
        ],
        child: const MaterialApp(
          home: CreateCourseScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Dropdown exists and defaults to Fall 2026
    expect(find.text('Semester *'), findsOneWidget);
    expect(find.text('Fall 2026'), findsWidgets);

    // Tap the dropdown to open popup
    await tester.tap(find.text('Fall 2026').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // In popup menu:
    expect(find.text('Spring 2027'), findsWidgets);
    expect(find.text('Spring 2026'), findsNothing);
    expect(find.text('Summer 2026'), findsNothing);
    expect(find.text('+ Custom Semester...'), findsNothing);
  });

  testWidgets('AssignmentCreationWizard displays categories in order: Internal, Midterm, Final',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _ProfAuthNotifier()),
        ],
        child: const MaterialApp(
          home: AssignmentCreationWizard(courseId: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Check categories exist
    expect(find.text('Internal Assessment'), findsOneWidget);
    expect(find.text('Midterm'), findsOneWidget);
    expect(find.text('Final Exam'), findsOneWidget);

    // Verify relative positions (Internal Assessment is leftmost, then Midterm, then Final)
    final internalOffset = tester.getTopLeft(find.text('Internal Assessment'));
    final midtermOffset = tester.getTopLeft(find.text('Midterm'));
    final finalOffset = tester.getTopLeft(find.text('Final Exam'));

    expect(internalOffset.dx, lessThan(midtermOffset.dx));
    expect(midtermOffset.dx, lessThan(finalOffset.dx));
  });

  testWidgets('AssignmentCreationWizard hides Rubric Builder when MCQ is selected',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _ProfAuthNotifier()),
        ],
        child: const MaterialApp(
          home: AssignmentCreationWizard(courseId: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // By default, Internal Assessment is selected with quiz -> mcq
    // Step 3: Rubric Builder should be hidden for MCQ
    expect(find.text('Step 3: Rubric Builder'), findsNothing);
  });
}
