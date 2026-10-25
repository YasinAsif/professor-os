import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/presentation/widgets/exam_mobile_block_view.dart';

void main() {
  group('ExamMobileBlockView Widget Tests', () {
    testWidgets('renders lock icon and security block messaging', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ExamMobileBlockView(),
        ),
      );

      // Verify lock icon is rendered
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      // Verify headings and policy text
      expect(find.text('Secure App Required'), findsOneWidget);
      expect(find.text('Mobile Web Browser Detected'), findsOneWidget);
      expect(
        find.textContaining('exams cannot be taken on mobile web browsers'),
        findsOneWidget,
      );

      // Verify buttons
      expect(find.text('Download Android App (APK)'), findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);
    });

    testWidgets('calls onBackToDashboard callback when Return to Dashboard is pressed',
        (WidgetTester tester) async {
      bool backCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ExamMobileBlockView(
            onBackToDashboard: () {
              backCalled = true;
            },
          ),
        ),
      );

      await tester.ensureVisible(find.text('Return to Dashboard'));
      await tester.tap(find.text('Return to Dashboard'));
      await tester.pumpAndSettle();

      expect(backCalled, isTrue);
    });
  });
}
