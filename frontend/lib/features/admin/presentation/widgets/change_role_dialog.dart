import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/admin_repository.dart';

class ChangeRoleDialog extends StatefulWidget {
  final int userId;
  final String userName;
  final String currentRole;

  const ChangeRoleDialog({
    super.key,
    required this.userId,
    required this.userName,
    required this.currentRole,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int userId,
    required String userName,
    required String currentRole,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ChangeRoleDialog(
        userId: userId,
        userName: userName,
        currentRole: currentRole,
      ),
    );
  }

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  late String _selectedRole;
  bool _isSubmitting = false;

  final _roles = [
    {'value': 'student', 'label': 'Student'},
    {'value': 'professor', 'label': 'Professor'},
    {'value': 'ta', 'label': 'Teaching Assistant (TA)'},
    {'value': 'admin', 'label': 'Administrator'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.currentRole.toLowerCase();
  }

  Future<void> _submit() async {
    if (_selectedRole == widget.currentRole.toLowerCase()) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await AdminRepository().updateUserRole(widget.userId, _selectedRole);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.dangerRose,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.manage_accounts_outlined, color: AppColors.inkPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Change User Role',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select new role for ${widget.userName}:',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ..._roles.map((r) {
              final val = r['value']!;
              final label = r['label']!;
              final isSelected = _selectedRole == val;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.inkPrimary : AppColors.marginRule,
                    width: isSelected ? 1.5 : 1,
                  ),
                  color: isSelected ? AppColors.inkPrimary.withAlpha(12) : Colors.transparent,
                ),
                child: RadioListTile<String>(
                  value: val,
                  groupValue: _selectedRole,
                  title: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppColors.inkPrimary : AppColors.textPrimary,
                    ),
                  ),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedRole = v);
                  },
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.inkPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text('Save Role', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
