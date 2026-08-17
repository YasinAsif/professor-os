/// ProfessorOS – Admin Providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';

final adminRepositoryProvider = Provider((ref) => AdminRepository());

class AdminUserQuery {
  final String role;
  final String search;
  final int page;
  final int pageSize;
  const AdminUserQuery({
    this.role = 'all',
    this.search = '',
    this.page = 1,
    this.pageSize = 20,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminUserQuery &&
          runtimeType == other.runtimeType &&
          role == other.role &&
          search == other.search &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode =>
      role.hashCode ^ search.hashCode ^ page.hashCode ^ pageSize.hashCode;
}

final adminUsersProvider =
    FutureProvider.family<Map<String, dynamic>, AdminUserQuery>((ref, query) async {
  final repo = ref.read(adminRepositoryProvider);
  return await repo.listUsers(
    role: query.role,
    search: query.search,
    page: query.page,
    pageSize: query.pageSize,
  );
});

final adminUserStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return await repo.getUserStats();
});

final pendingUsersProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return await repo.listPendingUsers();
});

final professorsListProvider = FutureProvider<List<dynamic>>((ref) async {
  final repo = ref.read(adminRepositoryProvider);
  return await repo.listProfessors();
});
