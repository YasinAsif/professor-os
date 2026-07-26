/// ProfessorOS – Admin User Management Screen.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../../shared/widgets/prof_search_bar.dart';
import '../../../shared/widgets/prof_shimmer.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';
import 'widgets/add_user_dialog.dart';
import 'widgets/change_role_dialog.dart';
import 'widgets/reset_password_dialog.dart';
import 'widgets/user_detail_dialog.dart';

class UserManagementTab extends ConsumerStatefulWidget {
  const UserManagementTab({super.key});

  @override
  ConsumerState<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends ConsumerState<UserManagementTab> {
  String _filter = 'all';
  String _search = '';
  int _page = 1;
  int _pageSize = 20;

  final _filters = ['all', 'professor', 'student', 'ta', 'admin'];

  void _refresh() {
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminUserStatsProvider);
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      try {
        final bytes = result.files.single.bytes!;
        final name = result.files.single.name;
        final res = await AdminRepository().importUsersCsv(bytes, name);
        _refresh();
        if (mounted) {
          final created = res['created'] ?? 0;
          final errors = (res['errors'] as List? ?? []);
          final msg = errors.isEmpty
              ? '$created users imported successfully.'
              : '$created imported, ${errors.length} errors (check CSV format).';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor:
                errors.isEmpty ? AppColors.successGreen : AppColors.accentAmber,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.dangerRose,
          ));
        }
      }
    }
  }

  Future<void> _exportCsv() async {
    try {
      final bytes = await AdminRepository().exportUsersCsv(role: _filter, search: _search);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Exported ${bytes.length} bytes CSV.'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = AdminUserQuery(
      role: _filter,
      search: _search,
      page: _page,
      pageSize: _pageSize,
    );
    final usersAsync = ref.watch(adminUsersProvider(query));
    final statsAsync = ref.watch(adminUserStatsProvider);

    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Metrics Header ──────────────────────────────────
          statsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => _buildMetricsHeader(stats, isCompact),
          ),
          const SizedBox(height: 16),

          // ── Top Bar ──────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ProfSearchBar(
                          onChanged: (v) => setState(() {
                            _search = v;
                            _page = 1;
                          }),
                          hintText: 'Search users by name or email...',
                        ),
                      ),
                      if (!narrow) ...[
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add, size: 18),
                          label: const Text('Add User'),
                          onPressed: () async {
                            final res = await AddUserDialog.show(context);
                            if (res == true) _refresh();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.inkPrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, color: AppColors.inkPrimary, size: 18),
                          label: Text('Import CSV', style: GoogleFonts.inter(color: AppColors.inkPrimary)),
                          onPressed: _importCsv,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.inkPrimary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, color: AppColors.inkPrimary, size: 18),
                          label: Text('Export', style: GoogleFonts.inter(color: AppColors.inkPrimary)),
                          onPressed: _exportCsv,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.inkPrimary),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (narrow) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add, size: 18),
                            label: const Text('Add User'),
                            onPressed: () async {
                              final res = await AddUserDialog.show(context);
                              if (res == true) _refresh();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.inkPrimary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Import'),
                          onPressed: _importCsv,
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Export'),
                          onPressed: _exportCsv,
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Filter Chips ──────────────────────────────────────
          Wrap(
            spacing: 8,
            children: _filters
                .map((f) => ChoiceChip(
                      label: Text(f == 'all'
                          ? 'All'
                          : f[0].toUpperCase() + f.substring(1)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() {
                        _filter = f;
                        _page = 1;
                      }),
                      selectedColor: AppColors.inkPrimary,
                      labelStyle: GoogleFonts.inter(
                        color: _filter == f
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),

          // ── User List ──────────────────────────────────────────
          Expanded(
            child: usersAsync.when(
              loading: () => ListView.separated(
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => ProfShimmer.card(height: 72),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.admin_panel_settings_outlined,
                          size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Admin Access Required or Session Error',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            color: AppColors.dangerRose, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) {
                final users = (data['users'] as List<dynamic>?) ?? [];
                final total = data['total'] as int? ?? users.length;
                final totalPages = (total / _pageSize).ceil();

                if (users.isEmpty) {
                  return Center(
                    child: Text('No users found.',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary)),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final u = users[index] as Map<String, dynamic>;
                          return _buildUserCard(
                            userMap: u,
                            query: query,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Pagination Controls ──────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Showing ${users.length} of $total users',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _page > 1
                                  ? () => setState(() => _page--)
                                  : null,
                            ),
                            Text(
                              'Page $_page of ${totalPages < 1 ? 1 : totalPages}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: (_page < totalPages)
                                  ? () => setState(() => _page++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsHeader(Map<String, dynamic> stats, bool isCompact) {
    final total = stats['total_users'] ?? 0;
    final active = stats['active_users'] ?? 0;
    final inactive = stats['inactive_users'] ?? 0;
    final roles = (stats['role_counts'] as Map<String, dynamic>?) ?? {};

    final cards = [
      _buildStatCard('Total Users', '$total', Icons.people_alt_outlined, AppColors.inkPrimary),
      _buildStatCard('Active', '$active', Icons.check_circle_outline, AppColors.successGreen),
      _buildStatCard('Inactive', '$inactive', Icons.pause_circle_outline, AppColors.accentAmber),
      _buildStatCard('Professors', '${roles['professor'] ?? 0}', Icons.school_outlined, AppColors.accentCyan),
      _buildStatCard('Students', '${roles['student'] ?? 0}', Icons.person_outline, AppColors.badgeColor('student')),
    ];

    if (isCompact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: cards
              .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(width: 140, child: c),
                  ))
              .toList(),
        ),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return ProfCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard({
    required Map<String, dynamic> userMap,
    required AdminUserQuery query,
  }) {
    final id = userMap['id'] as int;
    final name = userMap['full_name'] as String? ?? 'User';
    final email = userMap['email'] as String? ?? '';
    final role = userMap['role'] as String? ?? 'student';
    final isActive = userMap['is_active'] as bool? ?? true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final identity = Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AvatarHelper.colorFor(name),
              child: Text(
                AvatarHelper.initialsFor(name),
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(email,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        );

        final menu = PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
          onSelected: (v) async {
            if (v == 'view') {
              UserDetailDialog.show(context, userMap);
            } else if (v == 'change_role') {
              final updated = await ChangeRoleDialog.show(
                context,
                userId: id,
                userName: name,
                currentRole: role,
              );
              if (updated == true) _refresh();
            } else if (v == 'reset_password') {
              final reset = await ResetPasswordDialog.show(
                context,
                userId: id,
                userName: name,
              );
              if (reset == true && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Password reset for $name.'),
                  backgroundColor: AppColors.successGreen,
                ));
              }
            } else if (v == 'toggle_status') {
              final confirmed = await ProfConfirmSheet.show(
                context,
                title: isActive ? 'Deactivate User' : 'Activate User',
                body:
                    'Are you sure you want to ${isActive ? "deactivate" : "activate"} $name?',
                confirmLabel: isActive ? 'Deactivate' : 'Activate',
              );
              if (confirmed == true) {
                try {
                  await AdminRepository().updateUserStatus(id, !isActive);
                  _refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('User status updated for $name.'),
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.dangerRose,
                    ));
                  }
                }
              }
            } else if (v == 'delete') {
              final confirmed = await ProfConfirmSheet.show(
                context,
                title: 'Delete User Account',
                body:
                    'Are you sure you want to permanently delete $name? This action cannot be undone.',
                confirmLabel: 'Delete',
              );
              if (confirmed == true) {
                try {
                  await AdminRepository().deleteUser(id);
                  _refresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('User $name deleted.'),
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.dangerRose,
                    ));
                  }
                }
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'change_role',
              child: Row(
                children: [
                  Icon(Icons.manage_accounts_outlined, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('Change Role'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'reset_password',
              child: Row(
                children: [
                  Icon(Icons.lock_reset_outlined, size: 18, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('Reset Password'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggle_status',
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(isActive ? 'Deactivate Account' : 'Activate Account'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18, color: AppColors.dangerRose),
                  SizedBox(width: 8),
                  Text('Delete Account', style: TextStyle(color: AppColors.dangerRose)),
                ],
              ),
            ),
          ],
        );

        final status = Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ProfBadge(
                label: role[0].toUpperCase() + role.substring(1),
                color: AppColors.badgeColor(role)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? AppColors.successGreen
                            : AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ],
        );

        return ProfCard(
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Row(children: [Expanded(child: identity), menu]),
                      const SizedBox(height: 12),
                      status
                    ])
              : Row(children: [
                  Expanded(child: identity),
                  status,
                  const SizedBox(width: 8),
                  menu
                ]),
        );
      },
    );
  }
}
