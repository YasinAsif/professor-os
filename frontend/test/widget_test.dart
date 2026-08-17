// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:professor_os/app.dart';
import 'package:professor_os/core/router/responsive_navigation.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ProfessorOSApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('uses mobile navigation below the responsive breakpoint', () {
    expect(shouldUseMobileNavigation(390), isTrue);
    expect(shouldUseMobileNavigation(799.9), isTrue);
    expect(shouldUseMobileNavigation(800), isFalse);
  });
}
