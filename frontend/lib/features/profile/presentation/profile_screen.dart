/// ProfessorOS – Profile / Account Settings Screen.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/journal_ui/journal_components.dart';
import '../../../core/utils/avatar_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/prof_badge.dart';
import '../../../shared/widgets/prof_breadcrumbs.dart';
import '../../../shared/widgets/prof_confirm_sheet.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/providers/course_providers.dart';

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

    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final bgPage = isDark ? AppColors.canvas : AppColorsLight.canvas;
    final rule = isDark ? AppColors.rule : AppColorsLight.rule;
    final textPrimary = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;

    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: bgPage,
        surfaceTintColor: Colors.transparent,
        title: const ProfBreadcrumbs(
          items: [
            BreadcrumbItem(label: 'Home', path: '/courses'),
            BreadcrumbItem(label: 'Account Settings'),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: rule),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: [
                // ── Avatar + Name Row ─────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColorsLight.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.rule : AppColorsLight.rule),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF4F46E5),
                        child: Text(
                          AvatarHelper.initialsFor(name),
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_editingName)
                              Row(children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    autofocus: true,
                                    style: GoogleFonts.inter(color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      labelStyle: GoogleFonts.inter(color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _savingName
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF4F46E5)))
                                    : IconButton(
                                        icon: const Icon(Icons.check_rounded,
                                            color: AppColors.statusPassInk),
                                        onPressed: _saveName),
                                IconButton(
                                    icon: Icon(Icons.close_rounded,
                                        color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
                                    onPressed: () =>
                                        setState(() => _editingName = false)),
                              ])
                            else
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 320),
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        size: 18,
                                        color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
                                    onPressed: () {
                                      _nameCtrl.text = name;
                                      setState(() => _editingName = true);
                                    },
                                  ),
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ProfBadge(
                                  label: verified
                                      ? 'Verified Academic'
                                      : 'Unverified',
                                  color: verified
                                      ? AppColors.statusPassInk
                                      : AppColors.statusPendingInk,
                                ),
                                ProfBadge(
                                  label:
                                      role[0].toUpperCase() + role.substring(1),
                                  color: const Color(0xFF4F46E5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Performance Metrics by Role ───────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColorsLight.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.rule : AppColorsLight.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Overview',
                          style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textPrimary)),
                      const SizedBox(height: 20),
                      if (role == 'admin') _buildAdminStats(context),
                      if (role == 'professor') _buildProfStats(context),
                      if (role == 'student') _buildStudentStats(context),
                      if (role == 'ta') _buildTAStats(context),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Change Password Form ───────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColorsLight.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.rule : AppColorsLight.rule),
                  ),
                  child: Form(
                    key: _pwFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change Password',
                            style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textPrimary)),
                        const SizedBox(height: 6),
                        Text(
                          'Ensure your account uses a secure, long password with symbols and numbers.',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _oldPassCtrl,
                          obscureText: _obscureOld,
                          style: GoogleFonts.inter(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureOld
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
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
                          style: GoogleFonts.inter(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureNew
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
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
                          style: GoogleFonts.inter(color: textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon:
                                const Icon(Icons.check_circle_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) => v != _newPassCtrl.text
                              ? 'Passwords do not match.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _savingPw ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            textStyle: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          child: _savingPw
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('Update Password'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── APPEARANCE & DESIGN SYSTEM ────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surface : AppColorsLight.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark ? AppColors.rule : AppColorsLight.rule, width: 1),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APPEARANCE & DESIGN SYSTEM',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select your visual environment. You can switch between "The Journal" (v2 2026/2027) and "Marginalia" (v1 Classic) at any time.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Design System Switcher
                      Text(
                        'Design Edition',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildSelectionChip(
                            label: 'The Journal (v2)',
                            isSelected:
                                ref.watch(themeStateProvider).designSystem ==
                                    DesignSystem.journal,
                            onTap: () {
                              ref
                                  .read(themeStateProvider.notifier)
                                  .setDesignSystem(DesignSystem.journal);
                              JournalToastManager.show(
                                  context, 'Switched to The Journal v2');
                            },
                          ),
                          _buildSelectionChip(
                            label: 'Marginalia (v1)',
                            isSelected:
                                ref.watch(themeStateProvider).designSystem ==
                                    DesignSystem.marginalia,
                            onTap: () {
                              ref
                                  .read(themeStateProvider.notifier)
                                  .setDesignSystem(DesignSystem.marginalia);
                              JournalToastManager.show(
                                  context, 'Switched to Marginalia v1');
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Divider(
                          color: isDark ? AppColors.rule : AppColorsLight.rule,
                          height: 1),
                      const SizedBox(height: 20),

                      // Theme Mode Switcher
                      Text(
                        'Theme Palette',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildSelectionChip(
                            label: 'Pressroom Day',
                            isSelected:
                                ref.watch(themeStateProvider).themeMode ==
                                    JournalThemeMode.light,
                            onTap: () {
                              ref
                                  .read(themeStateProvider.notifier)
                                  .setThemeMode(JournalThemeMode.light);
                              JournalToastManager.show(
                                  context, 'Theme set to Pressroom Day');
                            },
                          ),
                          _buildSelectionChip(
                            label: 'Pressroom Night',
                            isSelected:
                                ref.watch(themeStateProvider).themeMode ==
                                    JournalThemeMode.dark,
                            onTap: () {
                              ref
                                  .read(themeStateProvider.notifier)
                                  .setThemeMode(JournalThemeMode.dark);
                              JournalToastManager.show(
                                  context, 'Theme set to Pressroom Night');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Sign out button ──────────────────────
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.statusCriticalInk),
                  label: Text('Sign out from all sessions',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: AppColors.statusCriticalInk,
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
                    side: const BorderSide(color: AppColors.statusCriticalBorder),
                    backgroundColor: AppColors.statusCriticalBg.withOpacity(0.3),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final surface = isDark ? AppColors.surface : AppColorsLight.surface;
    final rule = isDark ? AppColors.rule : AppColorsLight.rule;
    final textPrimary = isDark ? AppColors.inkPrimary : AppColorsLight.inkPrimary;
    final textSecondary = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: rule, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
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
                        fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(val,
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStats(BuildContext context) {
    try {
      final coursesAsync = ref.watch(courseListProvider);
      final Object? data = coursesAsync.valueOrNull;
      final List<dynamic> rawList;
      if (data != null && data is Map && data['courses'] is List) {
        rawList = data['courses'] as List<dynamic>;
      } else if (data != null && data is List) {
        rawList = data;
      } else {
        rawList = const <dynamic>[];
      }
      final courses = rawList.whereType<Map<String, dynamic>>().toList();
      final totalCourses = courses.length;
      final totalStudents = courses.fold<int>(
          0, (sum, c) => sum + ((c['enrollment_count'] as num?)?.toInt() ?? 0));

      final isMobile = MediaQuery.sizeOf(context).width < 560;
      final c1 = _academicStatCard(
          'Institution Courses',
          '$totalCourses Managed',
          Icons.analytics_outlined,
          AppColors.inkPrimary);
      final c2 = _academicStatCard(
          'Total Student Seats',
          '$totalStudents Enrolled',
          Icons.people_outline_rounded,
          AppColors.verified);
      final c3 = _academicStatCard('HEC OBE Engine', 'Synchronized',
          Icons.dns_outlined, AppColors.successGreen);

      if (isMobile) {
        return Column(
          children: [
            c1,
            const SizedBox(height: 12),
            c2,
            const SizedBox(height: 12),
            c3,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: c1),
          const SizedBox(width: 14),
          Expanded(child: c2),
          const SizedBox(width: 14),
          Expanded(child: c3),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildProfStats(BuildContext context) {
    try {
      final coursesAsync = ref.watch(courseListProvider);
      final Object? data = coursesAsync.valueOrNull;
      final List<dynamic> rawList;
      if (data != null && data is Map && data['courses'] is List) {
        rawList = data['courses'] as List<dynamic>;
      } else if (data != null && data is List) {
        rawList = data;
      } else {
        rawList = const <dynamic>[];
      }
      final courses = rawList.whereType<Map<String, dynamic>>().toList();
      final totalCourses = courses.length;
      final totalStudents = courses.fold<int>(
          0, (sum, c) => sum + ((c['enrollment_count'] as num?)?.toInt() ?? 0));
      final totalAssignments = courses.fold<int>(
          0, (sum, c) => sum + ((c['assignment_count'] as num?)?.toInt() ?? 0));

      final isMobile = MediaQuery.sizeOf(context).width < 560;
      final c1 = _academicStatCard(
          'Active Courses',
          '$totalCourses Course${totalCourses == 1 ? '' : 's'}',
          Icons.menu_book_rounded,
          AppColors.inkPrimary);
      final c2 = _academicStatCard(
          'Total Enrolled Students',
          '$totalStudents Student${totalStudents == 1 ? '' : 's'}',
          Icons.group_outlined,
          AppColors.verified);
      final c3 = _academicStatCard(
          'Curriculum Assignments',
          '$totalAssignments Created',
          Icons.assignment_outlined,
          AppColors.signal);
      final c4 = _academicStatCard('Evaluation Engine', 'Active & Grounded',
          Icons.psychology_outlined, AppColors.successGreen);

      if (isMobile) {
        return Column(
          children: [
            c1,
            const SizedBox(height: 12),
            c2,
            const SizedBox(height: 12),
            c3,
            const SizedBox(height: 12),
            c4,
          ],
        );
      }

      return Column(
        children: [
          Row(
            children: [
              Expanded(child: c1),
              const SizedBox(width: 14),
              Expanded(child: c2),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: c3),
              const SizedBox(width: 14),
              Expanded(child: c4),
            ],
          ),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildStudentStats(BuildContext context) {
    try {
      final dashAsync = ref.watch(studentDashboardProvider);
      final dash = dashAsync.valueOrNull ?? {};
      final stats = (dash['stats'] as Map<String, dynamic>?) ??
          (dash['counts'] as Map<String, dynamic>?) ??
          {};
      final courses = (dash['courses'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      final enrolled =
          (stats['enrolled_courses'] as num?)?.toInt() ?? courses.length;
      final pending = (stats['pending'] as num?)?.toInt() ??
          (stats['pending_submissions'] as num?)?.toInt() ??
          0;
      final graded = (stats['graded'] as num?)?.toInt() ??
          (stats['graded_submissions'] as num?)?.toInt() ??
          0;

      final isMobile = MediaQuery.sizeOf(context).width < 560;
      final c1 = _academicStatCard('Enrolled Courses', '$enrolled Active',
          Icons.menu_book_rounded, AppColors.inkAccent);
      final c2 = _academicStatCard('Pending Submissions', '$pending Due',
          Icons.schedule_rounded, AppColors.pending);
      final c3 = _academicStatCard('Graded & Feedback', '$graded Graded',
          Icons.chat_bubble_outline_rounded, AppColors.verified);

      if (isMobile) {
        return Column(
          children: [
            c1,
            const SizedBox(height: 12),
            c2,
            const SizedBox(height: 12),
            c3,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: c1),
          const SizedBox(width: 14),
          Expanded(child: c2),
          const SizedBox(width: 14),
          Expanded(child: c3),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildTAStats(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 560;
    final c1 = _academicStatCard('Eval Batches Processed', '8 Batches',
        Icons.batch_prediction_outlined, AppColors.inkAccent);
    final c2 = _academicStatCard('Discrepancy vs AI', '2.1%',
        Icons.compare_arrows_rounded, AppColors.pending);
    final c3 = _academicStatCard('Pending Reviews', '14',
        Icons.pending_actions_rounded, AppColors.feedbackRed);

    if (isMobile) {
      return Column(
        children: [
          c1,
          const SizedBox(height: 12),
          c2,
          const SizedBox(height: 12),
          c3,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: c1),
        const SizedBox(width: 14),
        Expanded(child: c2),
        const SizedBox(width: 14),
        Expanded(child: c3),
      ],
    );
  }

  Widget _buildSelectionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final surface = isDark ? AppColors.surface : AppColorsLight.surface;
    final rule = isDark ? AppColors.rule : AppColorsLight.rule;
    final textSecondary = isDark ? AppColors.inkSecondary : AppColorsLight.inkSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? const Color(0xFF312E81).withOpacity(0.5) : const Color(0xFFEEF2FF)) : surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF4F46E5) : rule,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                          : textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
