import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/auth/providers/auth_provider.dart';
import 'package:professor_os/features/courses/presentation/assignment_detail_screen.dart';
import 'package:professor_os/features/courses/presentation/exam_screen.dart';

void main() {
  testWidgets('ExamScreen initially displays biometric verification gate when unverified',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExamScreen(
            courseId: 1,
            assignmentId: 10,
            assignmentTitle: 'Algorithms Midterm Examination',
            assignmentType: 'text',
            description: 'Solve the dynamic programming problem.',
            maxMarks: 100.0,
            timeLimitMinutes: 60,
            initialBiometricPassed: false,
            skipInitialStateCheck: true,
          ),
        ),
      ),
    );

    expect(find.text('Identity Verification Required'), findsOneWidget);
    expect(find.text('Verify Identity'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsWidgets);
  });

  testWidgets('ExamScreen renders instructions screen and Start Exam button when biometric passes',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExamScreen(
            courseId: 1,
            assignmentId: 10,
            assignmentTitle: 'Algorithms Midterm Examination',
            assignmentType: 'text',
            description: 'Solve the dynamic programming problem.',
            maxMarks: 100.0,
            timeLimitMinutes: 60,
            initialBiometricPassed: true,
            skipInitialStateCheck: true,
          ),
        ),
      ),
    );

    expect(find.text('Algorithms Midterm Examination'), findsWidgets);
    expect(find.text('Before You Start'), findsOneWidget);
    expect(find.textContaining('60 minutes'), findsOneWidget);
    expect(find.text('Start Exam'), findsOneWidget);
  });

  testWidgets('ExamScreen renders instructions for programming assessment type',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExamScreen(
            courseId: 2,
            assignmentId: 20,
            assignmentTitle: 'Operating Systems Final Exam',
            assignmentType: 'programming',
            description: 'Implement a thread pool in C.',
            maxMarks: 50.0,
            timeLimitMinutes: 90,
            initialBiometricPassed: true,
            skipInitialStateCheck: true,
          ),
        ),
      ),
    );

    expect(find.text('Operating Systems Final Exam'), findsWidgets);
    expect(find.text('Before You Start'), findsOneWidget);
    expect(find.textContaining('90 minutes'), findsOneWidget);
    expect(find.text('Start Exam'), findsOneWidget);
  });

  testWidgets('ExamScreen renders instructions for MCQ assessment type',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExamScreen(
            courseId: 3,
            assignmentId: 30,
            assignmentTitle: 'CS101 Quiz 1',
            assignmentType: 'mcq',
            description: 'What is the time complexity of binary search?',
            maxMarks: 20.0,
            timeLimitMinutes: 30,
            initialBiometricPassed: true,
            skipInitialStateCheck: true,
          ),
        ),
      ),
    );

    expect(find.text('CS101 Quiz 1'), findsWidgets);
    expect(find.text('Before You Start'), findsOneWidget);
    expect(find.textContaining('30 minutes'), findsOneWidget);
    expect(find.text('Start Exam'), findsOneWidget);
  });

  testWidgets('ExamScreen renders fullscreen exit overlay with Return to Exam button when fullscreen is lost',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExamScreen(
            courseId: 1,
            assignmentId: 10,
            assignmentTitle: 'Algorithms Midterm Examination',
            assignmentType: 'text',
            description: 'Solve the dynamic programming problem.',
            maxMarks: 100.0,
            timeLimitMinutes: 60,
            initialBiometricPassed: true,
            skipInitialStateCheck: true,
            initialExamStarted: true,
            initialFullscreenExitActive: true,
          ),
        ),
      ),
    );

    expect(find.text('Exam Locked: Fullscreen Focus Lost'), findsOneWidget);
    expect(find.textContaining('Recorded Strikes:'), findsOneWidget);
    expect(find.text('Return to Exam'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_exit_rounded), findsOneWidget);

    // Tap Return to Exam button
    await tester.tap(find.text('Return to Exam'));
    await tester.pump();
  });

  testWidgets('ExamScreen renders offline banner when network drops',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ExamScreen(
            courseId: 1,
            assignmentId: 10,
            assignmentTitle: 'Algorithms Midterm Examination',
            assignmentType: 'text',
            description: 'Solve the dynamic programming problem.',
            maxMarks: 100.0,
            timeLimitMinutes: 60,
            initialBiometricPassed: true,
            skipInitialStateCheck: true,
            initialExamStarted: true,
            initialIsOffline: true,
          ),
        ),
      ),
    );

    expect(
      find.text('Connection lost. Reconnecting... (Your answers and activity are queued locally)'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });

  testWidgets('AssignmentDetailScreen renders live proctor console and filter chips filter student attempts',
      (WidgetTester tester) async {
    final mockAssignment = {
      'id': 10,
      'course_id': 1,
      'title': 'Midterm Examination',
      'type': 'exam',
      'status': 'published',
      'time_limit_minutes': 60,
      'max_attempts': 1,
      'max_marks': 100.0,
      'has_rubric': false,
    };
    final mockAttempts = [
      {
        'id': 101,
        'student_id': 1,
        'student_name': 'Alice Flagged',
        'status': 'active',
        'is_flagged': true,
        'strike_count': 3,
        'tab_switch_count': 3,
        'auto_submitted': false,
        'attempt_number': 1,
      },
      {
        'id': 102,
        'student_id': 2,
        'student_name': 'Bob AutoSubmitted',
        'status': 'auto_submitted',
        'is_flagged': false,
        'strike_count': 0,
        'tab_switch_count': 0,
        'auto_submitted': true,
        'attempt_number': 1,
      },
      {
        'id': 103,
        'student_id': 3,
        'student_name': 'Charlie Offline',
        'status': 'offline',
        'is_flagged': false,
        'strike_count': 0,
        'tab_switch_count': 0,
        'auto_submitted': false,
        'attempt_number': 1,
      },
    ];

    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _ProfessorAuthNotifier()),
        ],
        child: MaterialApp(
          home: AssignmentDetailScreen(
            courseId: 1,
            assignmentId: 10,
            initialAssignment: mockAssignment,
            initialExamAttempts: mockAttempts,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Live Proctoring Console and all 3 students initially visible
    expect(find.text('Live Proctoring Console'), findsOneWidget);
    expect(find.textContaining('Alice Flagged'), findsOneWidget);
    expect(find.textContaining('Bob AutoSubmitted'), findsOneWidget);
    expect(find.textContaining('Charlie Offline'), findsOneWidget);

    // 2. Tap "Flagged (1)" filter chip -> only Alice visible
    await tester.tap(find.text('Flagged (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alice Flagged'), findsOneWidget);
    expect(find.textContaining('Bob AutoSubmitted'), findsNothing);
    expect(find.textContaining('Charlie Offline'), findsNothing);

    // 3. Tap "Auto-Submitted (1)" filter chip -> only Bob visible
    await tester.tap(find.text('Auto-Submitted (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alice Flagged'), findsNothing);
    expect(find.textContaining('Bob AutoSubmitted'), findsOneWidget);
    expect(find.textContaining('Charlie Offline'), findsNothing);

    // 4. Tap "Has Violations" filter chip -> only Alice visible (strike_count == 3 > 0)
    await tester.tap(find.text('Has Violations'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alice Flagged'), findsOneWidget);
    expect(find.textContaining('Bob AutoSubmitted'), findsNothing);
    expect(find.textContaining('Charlie Offline'), findsNothing);

    // 5. Tap "Offline (1)" filter chip -> only Charlie visible
    await tester.tap(find.text('Offline (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alice Flagged'), findsNothing);
    expect(find.textContaining('Bob AutoSubmitted'), findsNothing);
    expect(find.textContaining('Charlie Offline'), findsOneWidget);

    // 6. Tap "All (3)" filter chip -> all 3 students visible again
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alice Flagged'), findsOneWidget);
    expect(find.textContaining('Bob AutoSubmitted'), findsOneWidget);
    expect(find.textContaining('Charlie Offline'), findsOneWidget);
  });
}

class _ProfessorAuthNotifier extends AuthNotifier {
  @override
  Future<Map<String, dynamic>?> build() async => {
        'id': 1,
        'email': 'prof@university.edu',
        'role': 'professor',
        'full_name': 'Professor Test',
      };
}
