import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

class JournalScaffold extends ConsumerWidget {
  final String currentPath;
  final Widget workspace;
  final Widget? annotationColumn;
  final bool showAnnotation;

  const JournalScaffold({
    super.key,
    required this.currentPath,
    required this.workspace,
    this.annotationColumn,
    this.showAnnotation = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final canvasBg = isDark ? AppColorsDark.canvas : AppColorsLight.canvas;
    final ruleColor = isDark ? AppColorsDark.rule : AppColorsLight.rule;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 768;
        final bool showAnnotationPanel = showAnnotation &&
            constraints.maxWidth >= 1024 &&
            annotationColumn != null;

        if (isMobile) {
          return Scaffold(
            backgroundColor: canvasBg,
            appBar: AppBar(
              backgroundColor: isDark ? AppColorsDark.surface : AppColorsLight.surface,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ProfessorOS',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColorsDark.inkPrimary : AppColorsLight.inkTitle,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF4F46E5),
                  ),
                  onPressed: () => ref.read(themeStateProvider.notifier).toggleThemeMode(),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: ruleColor),
              ),
            ),
            drawer: _buildMobileDrawer(context, ref, isDark),
            body: workspace,
            bottomNavigationBar: _buildMobileBottomNav(context, ref, isDark),
          );
        }

        final isCollapsed = ref.watch(sidebarCollapsedProvider);

        return Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB):
                const _ToggleSidebarIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyB):
                const _ToggleSidebarIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _ToggleSidebarIntent: CallbackAction<_ToggleSidebarIntent>(
                onInvoke: (intent) => ref
                    .read(sidebarCollapsedProvider.notifier)
                    .update((val) => !val),
              ),
            },
            child: Scaffold(
              backgroundColor: canvasBg,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Navigation Sidebar ─────
                  Builder(
                    builder: (ctx) {
                      final textScale = MediaQuery.textScalerOf(ctx).scale(1.0);
                      final double baseWidth =
                          constraints.maxWidth >= 1280 ? 250.0 : 228.0;
                      final double navWidth =
                          (baseWidth * textScale.clamp(1.0, 1.35))
                              .clamp(220.0, 285.0);
                      final double targetWidth = isCollapsed ? 68.0 : navWidth;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        width: targetWidth,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: isCollapsed ? 68.0 : navWidth,
                            maxWidth: isCollapsed ? 68.0 : navWidth,
                            child: SizedBox(
                              width: isCollapsed ? 68.0 : navWidth,
                              child: _JournalNavColumn(
                                currentPath: currentPath,
                                isCollapsed: isCollapsed,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 1px Vertical Divider
                  Container(width: 1, color: ruleColor),

                  // ── Primary Workspace ────────────────────────────
                  Expanded(
                    child: workspace,
                  ),

                  // ── Annotation / Right Detail Column ─
                  if (showAnnotationPanel) ...[
                    Container(
                      width: 1.0,
                      color: isDark ? AppColorsDark.ruleStrong : AppColorsLight.ruleStrong,
                    ),
                    SizedBox(
                      width: 240,
                      child: Container(
                        color: isDark ? AppColorsDark.surface : AppColorsLight.surface,
                        child: annotationColumn!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDrawer(BuildContext context, WidgetRef ref, bool isDark) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = user?['role'] as String? ?? 'student';
    final name = user?['full_name'] as String? ?? 'User';
    final ruleColor = isDark ? AppColorsDark.rule : AppColorsLight.rule;

    return Drawer(
      backgroundColor: isDark ? AppColorsDark.surface : AppColorsLight.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ProfessorOS',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColorsDark.inkPrimary : AppColorsLight.inkTitle,
                        ),
                      ),
                      Text(
                        name,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? AppColorsDark.inkSecondary : AppColorsLight.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: ruleColor, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (role == 'student')
                    _MobileDrawerItem(
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      path: '/dashboard',
                      currentPath: currentPath,
                    ),
                  if (role == 'ta')
                    _MobileDrawerItem(
                      label: 'Grading Queue',
                      icon: Icons.fact_check_outlined,
                      path: '/ta-dashboard',
                      currentPath: currentPath,
                    ),
                  _MobileDrawerItem(
                    label: 'Courses',
                    icon: Icons.menu_book_outlined,
                    path: '/courses',
                    currentPath: currentPath,
                  ),
                  if (role == 'admin')
                    _MobileDrawerItem(
                      label: 'Admin Panel',
                      icon: Icons.admin_panel_settings_outlined,
                      path: '/admin',
                      currentPath: currentPath,
                    ),
                  _MobileDrawerItem(
                    label: 'Profile & Settings',
                    icon: Icons.account_circle_outlined,
                    path: '/profile',
                    currentPath: currentPath,
                  ),
                ],
              ),
            ),
            Divider(color: ruleColor, height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, size: 20, color: AppColors.feedbackRed),
              title: Text(
                'Sign out',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.feedbackRed,
                ),
              ),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomNav(BuildContext context, WidgetRef ref, bool isDark) {
    final user = ref.watch(authProvider).valueOrNull;
    final role = user?['role'] as String? ?? 'student';

    final items = <_BottomNavItem>[
      if (role == 'student')
        const _BottomNavItem(
          path: '/dashboard',
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
        ),
      if (role == 'ta')
        const _BottomNavItem(
          path: '/ta-dashboard',
          label: 'Grading',
          icon: Icons.fact_check_outlined,
          activeIcon: Icons.fact_check_rounded,
        ),
      if (role == 'admin')
        const _BottomNavItem(
          path: '/admin',
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings_rounded,
        ),
      const _BottomNavItem(
        path: '/courses',
        label: 'Courses',
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
      ),
      const _BottomNavItem(
        path: '/profile',
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    int selectedIndex = items.indexWhere((it) => currentPath.startsWith(it.path));
    if (selectedIndex < 0) selectedIndex = 0;

    final bg = isDark ? AppColorsDark.surface : AppColorsLight.surface;
    final border = isDark ? AppColorsDark.rule : AppColorsLight.rule;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = selectedIndex == idx;
              final color = isSelected
                  ? const Color(0xFF4F46E5)
                  : (isDark ? AppColorsDark.inkSecondary : AppColorsLight.inkSecondary);

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (!isSelected) {
                      context.go(item.path);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isSelected ? item.activeIcon : item.icon, size: 22, color: color),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _BottomNavItem({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class _MobileDrawerItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String path;
  final String currentPath;

  const _MobileDrawerItem({
    required this.label,
    required this.icon,
    required this.path,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath.startsWith(path);
    return ListTile(
      leading: Icon(icon, size: 20, color: isSelected ? const Color(0xFF4F46E5) : null),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? const Color(0xFF4F46E5) : null,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        context.go(path);
      },
    );
  }
}

// ── NAVIGATION SIDEBAR (Desktop) ────────────────────────
class _JournalNavColumn extends ConsumerWidget {
  final String currentPath;
  final bool isCollapsed;

  const _JournalNavColumn({
    required this.currentPath,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeStateProvider);
    final isDark = themeState.themeMode == JournalThemeMode.dark;
    final user = ref.watch(authProvider).valueOrNull;
    final role = user?['role'] as String? ?? 'student';
    final name = user?['full_name'] as String? ?? 'User';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'OS';

    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inkPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inkSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final ruleColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment:
            isCollapsed ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Platform Brand Header
          if (isCollapsed) ...[
            Tooltip(
              message: 'ProfessorOS (Spring 2027 • STMU)',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(height: 12),
            IconButton(
              tooltip: 'Expand Sidebar (Ctrl+B)',
              icon: const Icon(Icons.menu_open_rounded, size: 20),
              color: inkSecondary,
              onPressed: () => ref
                  .read(sidebarCollapsedProvider.notifier)
                  .update((v) => !v),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF0D9488)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ProfessorOS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: inkPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Spring 2027 • STMU',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Collapse Sidebar (Ctrl+B)',
                    icon: const Icon(Icons.menu_rounded, size: 20),
                    color: inkSecondary,
                    onPressed: () => ref
                        .read(sidebarCollapsedProvider.notifier)
                        .update((v) => !v),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Theme Toggle
          if (isCollapsed)
            Tooltip(
              message: isDark ? 'Switch to Light' : 'Switch to Dark',
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF4F46E5),
                ),
                onPressed: () =>
                    ref.read(themeStateProvider.notifier).toggleThemeMode(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: InkWell(
                onTap: () => ref.read(themeStateProvider.notifier).toggleThemeMode(),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: ruleColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isDark ? 'Switch to Light' : 'Switch to Dark',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: inkPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Navigation Section
          if (!isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'ACADEMIC WORKSPACE',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: inkSecondary,
                ),
              ),
            ),
          if (!isCollapsed) const SizedBox(height: 8),

          if (role == 'student')
            _JournalNavItem(
              label: 'Dashboard',
              icon: Icons.dashboard_outlined,
              activeIcon: Icons.dashboard_rounded,
              path: '/dashboard',
              currentPath: currentPath,
              isDark: isDark,
              isCollapsed: isCollapsed,
            ),
          if (role == 'ta')
            _JournalNavItem(
              label: 'Grading Queue',
              icon: Icons.fact_check_outlined,
              activeIcon: Icons.fact_check_rounded,
              path: '/ta-dashboard',
              currentPath: currentPath,
              isDark: isDark,
              isCollapsed: isCollapsed,
            ),
          _JournalNavItem(
            label: 'Courses',
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book_rounded,
            path: '/courses',
            currentPath: currentPath,
            isDark: isDark,
            isCollapsed: isCollapsed,
          ),
          if (role == 'admin')
            _JournalNavItem(
              label: 'Admin Console',
              icon: Icons.admin_panel_settings_outlined,
              activeIcon: Icons.admin_panel_settings_rounded,
              path: '/admin',
              currentPath: currentPath,
              isDark: isDark,
              isCollapsed: isCollapsed,
            ),
          _JournalNavItem(
            label: 'Profile & Security',
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield_rounded,
            path: '/profile',
            currentPath: currentPath,
            isDark: isDark,
            isCollapsed: isCollapsed,
          ),

          const Spacer(),

          // System Status Pill
          if (isCollapsed)
            Tooltip(
              message: 'OBE Engine Online',
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'OBE Engine Online',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),

          // User Profile Card & Sign Out
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 18),
            child: Divider(color: ruleColor, height: 1),
          ),
          const SizedBox(height: 14),

          if (isCollapsed) ...[
            Tooltip(
              message: '$name (${role.toUpperCase()})',
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF4F46E5),
                child: Text(
                  initials,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              tooltip: 'Sign Out',
              icon: Icon(Icons.logout_rounded, size: 18, color: inkSecondary),
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF4F46E5),
                    child: Text(
                      initials,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: inkPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _roleBadgeColor(role).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: _roleBadgeColor(role),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Sign Out',
                    icon: Icon(Icons.logout_rounded, size: 18, color: inkSecondary),
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _roleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'professor':
        return const Color(0xFF4F46E5);
      case 'student':
        return const Color(0xFF10B981);
      case 'admin':
        return const Color(0xFFD97706);
      case 'ta':
        return const Color(0xFF0D9488);
      default:
        return const Color(0xFF64748B);
    }
  }
}

class _JournalNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;
  final String currentPath;
  final bool isDark;
  final bool isCollapsed;

  const _JournalNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
    required this.currentPath,
    required this.isDark,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = currentPath.startsWith(path);
    final activeBg = isDark
        ? const Color(0xFF4F46E5).withOpacity(0.15)
        : const Color(0xFF4F46E5).withOpacity(0.08);
    const activeColor = Color(0xFF4F46E5);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final itemIcon = Icon(
      isSelected ? activeIcon : icon,
      size: 19,
      color: isSelected ? activeColor : inactiveColor,
    );

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Tooltip(
          message: label,
          preferBelow: false,
          child: InkWell(
            onTap: () => context.go(path),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: activeColor.withOpacity(0.3), width: 1)
                    : null,
              ),
              child: itemIcon,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              itemIcon,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? activeColor
                        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
