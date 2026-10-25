import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../theme/app_theme.dart';

const double mobileNavigationBreakpoint = 800;

bool shouldUseMobileNavigation(double width) =>
    width < mobileNavigationBreakpoint;

class MobileNavigationShell extends ConsumerWidget {
  final Widget child;
  final String currentPath;

  const MobileNavigationShell({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _destinations(ref);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('ProfessorOS'),
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.inkPrimary,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: AppColors.bgCard,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Text(
                  'ProfessorOS',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              for (final destination in destinations)
                _DrawerDestination(
                  destination: destination,
                  selected: currentPath.startsWith(destination.path),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go(destination.path);
                  },
                ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign Out'),
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: _buildBottomNav(context, ref),
    );
  }

  Widget _buildBottomNav(BuildContext context, WidgetRef ref) {
    final destinations = _destinations(ref);
    int selectedIndex =
        destinations.indexWhere((it) => currentPath.startsWith(it.path));
    if (selectedIndex < 0) selectedIndex = 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.rule, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: destinations.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              final isSelected = selectedIndex == idx;
              final color = isSelected ? AppColors.signal : AppColors.inkSecondary;

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
                      Icon(item.icon, size: 22, color: color),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
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

  List<_NavigationDestination> _destinations(WidgetRef ref) {
    final role =
        ref.watch(authProvider).valueOrNull?['role'] as String? ?? 'student';
    return [
      if (role == 'student')
        const _NavigationDestination(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          path: '/dashboard',
        ),
      if (role == 'ta')
        const _NavigationDestination(
          icon: Icons.grading_rounded,
          label: 'Grading',
          path: '/ta-dashboard',
        ),
      const _NavigationDestination(
        icon: Icons.menu_book_rounded,
        label: 'Courses',
        path: '/courses',
      ),
      if (role == 'admin')
        const _NavigationDestination(
          icon: Icons.admin_panel_settings_rounded,
          label: 'Admin',
          path: '/admin',
        ),
      const _NavigationDestination(
        icon: Icons.person_rounded,
        label: 'Profile',
        path: '/profile',
      ),
    ];
  }
}

class _DrawerDestination extends StatelessWidget {
  final _NavigationDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        destination.icon,
        color: selected ? AppColors.signal : AppColors.inkSecondary,
      ),
      title: Text(destination.label),
      selected: selected,
      selectedColor: AppColors.signal,
      selectedTileColor: AppColors.bgActive,
      onTap: onTap,
    );
  }
}

class _NavigationDestination {
  final IconData icon;
  final String label;
  final String path;

  const _NavigationDestination({
    required this.icon,
    required this.label,
    required this.path,
  });
}
