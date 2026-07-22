/// ProfessorOS – Analytics provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_repository.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository());

final analyticsDashboardProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, courseId) async {
  final repo = ref.read(analyticsRepositoryProvider);
  return await repo.getDashboard(courseId);
});
