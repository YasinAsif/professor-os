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

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});
  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  String _filter = 'all';
  String _search = '';
  final _filters = ['all', 'professor', 'student', 'ta', 'admin'];

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
        ref.invalidate(adminUsersProvider);
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

  @override
  Widget build(BuildContext context) {
    final query = AdminUserQuery(role: _filter, search: _search);
    final usersAsync = ref.watch(adminUsersProvider(query));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('User Management',
            style:
                GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            LayoutBuilder(
              builder: (context, constraints) => Flex(
                direction: constraints.maxWidth < 560
                    ? Axis.vertical
                    : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.maxWidth < 560)
                    ProfSearchBar(
                      onChanged: (v) => setState(() => _search = v),
                      hintText: 'Search users by name or email...',
                    )
                  else
                    Expanded(
                      child: ProfSearchBar(
                        onChanged: (v) => setState(() => _search = v),
                        hintText: 'Search users by name or email...',
                      ),
                    ),
                  SizedBox(
                      width: 12, height: constraints.maxWidth < 560 ? 10 : 0),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file,
                        color: AppColors.primaryTeal),
                    label: Text('Import CSV',
                        style: GoogleFonts.inter(color: AppColors.primaryTeal)),
                    onPressed: _importCsv,
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryTeal)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Filter chips
            Wrap(
              spacing: 8,
              children: _filters
                  .map((f) => ChoiceChip(
                        label: Text(f == 'all'
                            ? 'All'
                            : f[0].toUpperCase() + f.substring(1)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                        selectedColor: AppColors.primaryTeal,
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
            // User list
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
                  if (users.isEmpty) {
                    return Center(
                      child: Text('No users found.',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final u = users[index] as Map<String, dynamic>;
                      return _buildUserCard(
                        id: u['id'] as int,
                        name: u['full_name'] as String? ?? 'User',
                        email: u['email'] as String? ?? '',
                        role: u['role'] as String? ?? 'student',
                        isActive: u['is_active'] as bool? ?? true,
                        query: query,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required int id,
    required String name,
    required String email,
    required String role,
    required bool isActive,
    required AdminUserQuery query,
  }) {
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
            if (v == 'toggle_status') {
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
                  ref.invalidate(adminUsersProvider(query));
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
                  ref.invalidate(adminUsersProvider(query));
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
            PopupMenuItem(
              value: 'toggle_status',
              child: Text(isActive ? 'Deactivate Account' : 'Activate Account'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete Account',
                  style: TextStyle(color: AppColors.dangerRose)),
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
            if (compact)
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
              )
            else
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? AppColors.successGreen
                          : AppColors.textSecondary)),
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
