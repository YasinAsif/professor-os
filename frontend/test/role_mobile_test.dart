import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:professor_os/features/admin/presentation/user_management_screen.dart';
import 'package:professor_os/features/admin/providers/admin_providers.dart';
import 'package:professor_os/features/analytics/presentation/analytics_dashboard_screen.dart';
import 'package:professor_os/features/analytics/providers/analytics_provider.dart';
import 'package:professor_os/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('analytics screen fits a phone width while loading',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsDashboardProvider(1).overrideWith((ref) async {
            return <String, dynamic>{
              'total_students': 0,
              'distribution': <dynamic>[],
            };
          }),
        ],
        child: const MaterialApp(home: AnalyticsDashboardScreen(courseId: 1)),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Cohort Intelligence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin and profile surfaces render at a phone width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminUsersProvider(const AdminUserQuery())
              .overrideWith((ref) async => {'users': <dynamic>[], 'total': 0}),
          adminUserStatsProvider
              .overrideWith((ref) async => <String, dynamic>{}),
        ],
        child: const MaterialApp(
          home: Scaffold(body: UserManagementTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Account Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
