import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/shared/widgets/submission_triage.dart';
import 'package:professor_os/shared/widgets/prof_badge.dart';

void main() {
  testWidgets('renders every required triage reason', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SubmissionTriageBadges(
        submission: const {
          'needs_review': true,
          'triage_reasons': [
            'injection_detected',
            'blank_or_unreadable',
            'scanned_or_image_only',
            'truncated_oversized_file',
          ],
        },
      ),
    ));

    expect(
        find.text('Adversarial Prompt / Injection Detected'), findsOneWidget);
    expect(find.text('Unreadable / Blank Document'), findsOneWidget);
    expect(find.text('Scanned / Image-Only PDF'), findsOneWidget);
    expect(find.text('Truncated Oversized File'), findsOneWidget);
  });

  testWidgets('triage filter chips report the selected filter', (tester) async {
    var selected = 'all';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SubmissionTriageFilterChips(
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Prompt Injection'));
    await tester.pump();
    expect(selected, 'prompt_injection');
    expect(
      tester
          .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Prompt Injection'))
          .selected,
      isTrue,
    );
  });

  testWidgets('clean submissions render no triage badge', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SubmissionTriageBadges(submission: {'status': 'graded'}),
    ));
    expect(find.byType(ProfBadge), findsNothing);
  });
}
