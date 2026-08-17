/// ProfessorOS – Pending Signup Approvals Tab.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_empty_state.dart';
import '../data/admin_repository.dart';
import '../providers/admin_providers.dart';

class PendingApprovalsTab extends ConsumerStatefulWidget {
  const PendingApprovalsTab({super.key});

  @override
  ConsumerState<PendingApprovalsTab> createState() =>
      _PendingApprovalsTabState();
}

class _PendingApprovalsTabState extends ConsumerState<PendingApprovalsTab> {
  void _refresh() {
    ref.invalidate(pendingUsersProvider);
    ref.invalidate(adminUserStatsProvider);
    ref.invalidate(adminUsersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingUsersProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pending_actions_rounded,
                    color: AppColors.accentAmber, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pending Signup Approvals',
                        style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(
                        'Professor and TA signups require your approval before they can access the system.',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textSecondary),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // List
          Expanded(
            child: pendingAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.signal)),
              error: (err, _) => Center(
                child: Text('Error: $err',
                    style: GoogleFonts.inter(color: AppColors.dangerRose)),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return const ProfEmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No pending approvals',
                    subtitle:
                        'All signup requests have been processed. New student, professor, and TA registrations will appear here.',
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final u = users[index] as Map<String, dynamic>;
                    return _PendingUserCard(
                      userMap: u,
                      onApprove: () => _handleApprove(u),
                      onReject: () => _handleReject(u),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove(Map<String, dynamic> user) async {
    final id = user['id'] as int;
    final name = user['full_name'] as String? ?? 'User';
    try {
      await AdminRepository().approveUser(id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name has been approved and can now log in.'),
          backgroundColor: AppColors.successGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to approve: $e'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }

  Future<void> _handleReject(Map<String, dynamic> user) async {
    final id = user['id'] as int;
    final name = user['full_name'] as String? ?? 'User';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject $name?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(
            'This will permanently remove their registration. They will need to sign up again.',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject & Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AdminRepository().rejectUser(id);
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name\'s signup has been rejected.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to reject: $e'),
          backgroundColor: AppColors.dangerRose,
        ));
      }
    }
  }
}

class _PendingUserCard extends StatelessWidget {
  final Map<String, dynamic> userMap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingUserCard({
    required this.userMap,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final name = userMap['full_name'] as String? ?? 'User';
    final email = userMap['email'] as String? ?? '';
    final role = userMap['role'] as String? ?? 'student';
    final createdAt = userMap['created_at'] as String? ?? '';

    // Parse and format the date
    String formattedDate = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      formattedDate =
          '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return ProfCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                            style: GoogleFonts.inter(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(email,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  ProfBadge(
                    label: role[0].toUpperCase() + role.substring(1),
                    color: AppColors.badgeColor(role),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Registered: $formattedDate',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted)),
                  const Spacer(),
                  if (!compact) ...[
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.dangerRose),
                      label: Text('Reject',
                          style:
                              GoogleFonts.inter(color: AppColors.dangerRose)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.dangerRose),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
              if (compact) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.dangerRose),
                        label: Text('Reject',
                            style:
                                GoogleFonts.inter(color: AppColors.dangerRose)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.dangerRose),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
