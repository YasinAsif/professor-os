import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/avatar_helper.dart';
import '../../../../shared/widgets/prof_badge.dart';

class UserDetailDialog extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserDetailDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, Map<String, dynamic> user) {
    return showDialog(
      context: context,
      builder: (context) => UserDetailDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = user['id'] as int? ?? 0;
    final name = user['full_name'] as String? ?? 'User';
    final email = user['email'] as String? ?? '';
    final role = user['role'] as String? ?? 'student';
    final isActive = user['is_active'] as bool? ?? true;
    final isVerified = user['is_verified'] as bool? ?? false;
    final createdAtStr = user['created_at'] as String? ?? '';

    String formattedDate = 'N/A';
    if (createdAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAtStr);
        formattedDate = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {
        formattedDate = createdAtStr;
      }
    }

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AvatarHelper.colorFor(name),
            child: Text(
              AvatarHelper.initialsFor(name),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'User ID: #$id',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildDetailRow('Email', email, icon: Icons.email_outlined),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.security_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Text('Role: ', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ProfBadge(
                  label: role[0].toUpperCase() + role.substring(1),
                  color: AppColors.badgeColor(role),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Account Status',
              isActive ? 'Active' : 'Deactivated / Suspended',
              icon: isActive ? Icons.check_circle_outline : Icons.block,
              valueColor: isActive ? AppColors.successGreen : AppColors.dangerRose,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Email Verification',
              isVerified ? 'Verified' : 'Pending Verification',
              icon: isVerified ? Icons.verified_outlined : Icons.pending_outlined,
              valueColor: isVerified ? AppColors.successGreen : AppColors.accentAmber,
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Member Since', formattedDate, icon: Icons.calendar_today_outlined),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.inter(color: AppColors.inkPrimary)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text('$label: ', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
