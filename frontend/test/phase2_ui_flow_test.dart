import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/shared/widgets/hec_weightage_widget.dart';

void main() {
  group('Phase 2 UI Flow & SpeedGrader Tests', () {
    testWidgets('HECWeightageWidget renders standard 30/20/50 breakdown by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HECWeightageWidget(),
          ),
        ),
      );

      expect(find.text('Quizzes'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('Midterm'), findsOneWidget);
      expect(find.text('Final Exam'), findsOneWidget);
      expect(find.text('15%'), findsNWidgets(2));
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('Total Assessment Weight: 100%'), findsOneWidget);
    });

    test('Rubric scaling calculation caps accurately to max_marks', () {
      const maxMarks = 20.0;
      // 2 criteria, each 50%
      const crit1Weight = 50;
      const crit2Weight = 50;

      // Student gets 'good' (0.75) on crit1 and 'good' (0.75) on crit2
      // raw rubric total = 50 * 0.75 + 50 * 0.75 = 75.0%
      const calculatedTotal = (crit1Weight * 0.75) + (crit2Weight * 0.75);
      final scaledTotal = (calculatedTotal * (maxMarks / 100.0)).clamp(0.0, maxMarks);

      expect(scaledTotal, 15.0);
      expect(scaledTotal <= maxMarks, isTrue);
    });

    test('Structured multi-question regex parser correctly splits questions', () {
      const content = 'Question 1: Define Polymorphism\nPolymorphism allows OOP objects to take many forms.\nQuestion 2: Explain Encapsulation\nEncapsulation hides internal state.';
      final pattern = RegExp(
          r'(?:(?:^|\n)\s*(?:Question\s+(\d+)[:\.]?|Q(\d+)[:\.]?)\s*([^\n]*))',
          caseSensitive: false);
      final matches = pattern.allMatches(content).toList();

      expect(matches.length, 2);
      expect(matches[0].group(1), '1');
      expect(matches[0].group(3)?.trim(), 'Define Polymorphism');
      expect(matches[1].group(1), '2');
      expect(matches[1].group(3)?.trim(), 'Explain Encapsulation');
    });
  });
}
