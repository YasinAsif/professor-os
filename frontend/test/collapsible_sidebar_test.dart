import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/core/theme/theme_provider.dart';
import 'package:professor_os/shared/journal_ui/journal_scaffold.dart';

void main() {
  group('Collapsible Sidebar & Hamburger Menu Tests', () {
    testWidgets('desktop journal scaffold renders hamburger button and toggles collapse state',
        (WidgetTester tester) async {
      // Set desktop window size
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                capturedRef = ref;
                return const JournalScaffold(
                  currentPath: '/courses',
                  workspace: Center(child: Text('Workspace Area')),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state: expanded (not collapsed)
      expect(capturedRef.read(sidebarCollapsedProvider), isFalse);
      expect(find.byTooltip('Collapse Sidebar (Ctrl+B)'), findsOneWidget);

      // Tap hamburger button to collapse
      await tester.tap(find.byTooltip('Collapse Sidebar (Ctrl+B)'));
      await tester.pumpAndSettle();

      // State is now collapsed
      expect(capturedRef.read(sidebarCollapsedProvider), isTrue);
      expect(find.byTooltip('Expand Sidebar (Ctrl+B)'), findsOneWidget);

      // Tap hamburger button to expand back
      await tester.tap(find.byTooltip('Expand Sidebar (Ctrl+B)'));
      await tester.pumpAndSettle();

      expect(capturedRef.read(sidebarCollapsedProvider), isFalse);
      expect(find.byTooltip('Collapse Sidebar (Ctrl+B)'), findsOneWidget);
    });
  });
}
