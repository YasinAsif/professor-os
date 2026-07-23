/// ProfessorOS – Profile / Account Settings Screen.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_card.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ── Name editing ─────────────────────────────────────
  bool _editingName = false;
  bool _savingName = false;
  final _nameCtrl = TextEditingController();

  // ── Password change ───────────────────────────────────
  final _pwFormKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _savingPw = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Update display name ───────────────────────────────
  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.length < 2) {
      _showSnack('Name must be at least 2 characters.', error: true);
      return;
    }
    setState(() => _savingName = true);
    try {
      await AuthRepository().updateProfile(newName);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        setState(() => _editingName = false);
        _showSnack('Name updated successfully.');
      }
    } catch (e) {
      if (mounted) _showSnack(_extractError(e), error: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ── Change password ───────────────────────────────────
  Future<void> _changePassword() async {
    if (!_pwFormKey.currentState!.validate()) return;
    if (_newPassCtrl.text != _confirmCtrl.text) {
      _showSnack('Passwords do not match.', error: true);
      return;
    }
    setState(() => _savingPw = true);
    try {
      await AuthRepository()
          .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
      if (mounted) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmCtrl.clear();
        _showSnack('Password changed successfully.');
      }
    } catch (e) {
      if (mounted) _showSnack(_extractError(e), error: true);
    } finally {
      if (mounted) setState(() => _savingPw = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────
  String _extractError(Object e) {
    if (e is DioException) {
      final detail = e.response?.data?['detail'];
      if (detail is String) return detail;
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.dangerRose : AppColors.successGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final name = user?['full_name'] as String? ?? 'Professor';
    final email = user?['email'] as String? ?? '';
    final role = user?['role'] as String? ?? 'professor';
    final verified = user?['is_verified'] as bool? ?? true;
    final isProf = role == 'professor' || role == 'admin';

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text('Professor Profile & Settings',
            style:
                GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // ── Avatar + Name Card ─────────────────
                ProfCard(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: AppColors.primaryIndigo,
                        child: Text(
                          AvatarHelper.initialsFor(name),
                          style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_editingName)
                        Row(children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameCtrl,
                              autofocus: true,
                              decoration:
                                  const InputDecoration(labelText: 'Full Name'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _savingName
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryIndigo))
                              : IconButton(
                                  icon: const Icon(Icons.check_rounded,
                                      color: AppColors.successGreen),
                                  onPressed: _saveName),
                          IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () =>
                                  setState(() => _editingName = false)),
                        ])
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(name,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.textMuted),
                              onPressed: () {
                                _nameCtrl.text = name;
                                setState(() => _editingName = true);
                              },
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(email,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  fontSize: 14, color: AppColors.textMuted)),
                          ProfBadge(
                            label:
                                verified ? 'Verified Academic' : 'Unverified',
                            color: verified
                                ? AppColors.successGreen
                                : AppColors.accentAmber,
                            small: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ProfBadge(
                        label: role[0].toUpperCase() + role.substring(1),
                        color: AppColors.primaryIndigo,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Academic Performance Stats ───────────────
                if (isProf) ...[
                  if (MediaQuery.sizeOf(context).width < 560) ...[
                    _academicStatCard('Courses Taught', '4 Active', Icons.school_outlined, AppColors.primaryIndigo),
                    const SizedBox(height: 14),
                    _academicStatCard('Students Evaluated', '142 Cohort', Icons.people_outline_rounded, AppColors.successGreen),
                    const SizedBox(height: 14),
                    _academicStatCard('HEC Compliance Score', '98.4%', Icons.verified_outlined, AppColors.successGreen),
                    const SizedBox(height: 14),
                    _academicStatCard('AI Evaluation Speed', '1.8 min / submission', Icons.bolt_outlined, AppColors.accentAmber),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: _academicStatCard('Courses Taught', '4 Active', Icons.school_outlined, AppColors.primaryIndigo)),
                        const SizedBox(width: 14),
                        Expanded(child: _academicStatCard('Students Evaluated', '142 Cohort', Icons.people_outline_rounded, AppColors.successGreen)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _academicStatCard('HEC Compliance Score', '98.4%', Icons.verified_outlined, AppColors.successGreen)),
                        const SizedBox(width: 14),
                        Expanded(child: _academicStatCard('AI Evaluation Speed', '1.8 min / submission', Icons.bolt_outlined, AppColors.accentAmber)),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],

                // ── Change Password Card ───────────────
                ProfCard(
                  child: Form(
                    key: _pwFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change Password',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _oldPassCtrl,
                          obscureText: _obscureOld,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureOld
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () =>
                                  setState(() => _obscureOld = !_obscureOld),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Current password is required.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _newPassCtrl,
                          obscureText: _obscureNew,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () =>
                                  setState(() => _obscureNew = !_obscureNew),
                            ),
                          ),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon:
                                const Icon(Icons.check_circle_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppColors.textMuted),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v != _newPassCtrl.text
                              ? 'Passwords do not match.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryButton,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              const BoxShadow(
                                  color: Color(0x304F46E5),
                                  blurRadius: 10,
                                  offset: Offset(0, 4))
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _savingPw ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: GoogleFonts.inter(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            child: _savingPw
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : const Text('Update Password'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Sign Out Multi-device ───────────────
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.dangerRose),
                  label: Text('Sign out from all active sessions',
                      style: GoogleFonts.inter(
                          color: AppColors.dangerRose,
                          fontWeight: FontWeight.w600)),
                  onPressed: () async {
                    final confirmed = await ProfConfirmSheet.show(
                      context,
                      title: 'Sign Out Everywhere',
                      body:
                          'This will invalidate your current authentication token and log out all active sessions on other browsers.',
                      confirmLabel: 'Sign Out Everywhere',
                    );
                    if (confirmed == true && mounted) {
                      await ref.read(authProvider.notifier).logout();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.dangerRose),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _academicStatCard(
      String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(val,
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
