/// ProfessorOS – GoRouter Navigation Configuration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';

import '../../features/courses/presentation/course_list_screen.dart';
import '../../features/courses/presentation/student_dashboard_screen.dart';
import '../../features/courses/presentation/create_course_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/assignment_creation_wizard.dart';
import '../../features/courses/presentation/assignment_detail_screen.dart';

import '../../features/analytics/presentation/analytics_dashboard_screen.dart';

import '../../features/profile/presentation/profile_screen.dart';
import '../../features/admin/presentation/user_management_screen.dart';

import '../theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/auth/login',
    refreshListenable: _RouterNotifier(ref),
    redirect: (context, state) {
      // Don't redirect while auth state is still loading (prevents flash to login on refresh)
      if (authState.isLoading) return null;

      final isAuth = authState.valueOrNull != null;
      final isAuthRoute = state.uri.path.startsWith('/auth');

      // Unauthenticated users can only access /auth routes
      if (!isAuth && !isAuthRoute) return '/auth/login';

      // Authenticated users trying to access login get redirected to home
      // but NOT verify-email or reset-password (they should be accessible)
      if (isAuth && isAuthRoute &&
          !state.uri.path.contains('verify-email') &&
          !state.uri.path.contains('reset-password')) return '/courses';

      return null; // no redirect
    },
    routes: [
      // ── Auth ───────────────────────────────────────
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/auth/verify-email',
        builder: (context, state) => VerifyEmailScreen(
          token: state.uri.queryParameters['token'],
          email: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/auth/reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'],
        ),
      ),

      // ── Main Shell (with Sidebar/Navbar) ───────────
      ShellRoute(
        builder: (context, state, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;
              if (isMobile) {
                return Scaffold(
                  backgroundColor: AppColors.bgPage,
                  body: child,
                  bottomNavigationBar: _buildMobileNavigation(
                    context,
                    state.uri.path,
                    ref,
                  ),
                );
              }

              return Scaffold(
                backgroundColor: AppColors.bgPage,
                body: Row(
                  children: [
                    _buildSidebar(context, state.uri.path, ref),
                    Expanded(child: child),
                  ],
                ),
              );
            },
          );
        },
        routes: [
          // Student Dashboard (homepage for students)
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const StudentDashboardScreen(),
          ),
          // Courses
          GoRoute(
            path: '/courses',
            builder: (context, state) => const CourseListScreen(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const CreateCourseScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CourseDetailScreen(courseId: int.parse(state.pathParameters['id']!)),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => CreateCourseScreen(courseId: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'analytics',
                    builder: (context, state) => AnalyticsDashboardScreen(courseId: int.parse(state.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'assignments/new',
                    builder: (context, state) => AssignmentCreationWizard(courseId: int.parse(state.pathParameters['id']!)),
                  ),
                  GoRoute(
                    path: 'assignments/:aid',
                    builder: (context, state) => AssignmentDetailScreen(
                      courseId: int.parse(state.pathParameters['id']!),
                      assignmentId: int.parse(state.pathParameters['aid']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Profile
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),

          // Admin
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UserManagementScreen(),
          ),
        ],
      ),
    ],
  );
});

Widget _buildSidebar(BuildContext context, String currentPath, Ref ref) {
  final user = ref.watch(authProvider).valueOrNull;
  final role = user?['role'] as String? ?? 'student';
  final name = user?['full_name'] as String? ?? 'User';
  final email = user?['email'] as String? ?? '';
  final isAdmin = role == 'admin';
  final isStudent = role == 'student';

  return Container(
    width: 260,
    decoration: const BoxDecoration(
      color: AppColors.bgCard,
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        // App header / Logo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: AppGradients.primaryButton,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [const BoxShadow(color: Color(0x304F46E5), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ProfessorOS', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                  Text('Academic Platform', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 1),
        ),
        const SizedBox(height: 16),

        // Menu Section Label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text('NAVIGATION', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
        ),

        if (isStudent)
          _SideMenuItem(icon: Icons.dashboard_rounded, label: 'Dashboard', path: '/dashboard', currentPath: currentPath),
        _SideMenuItem(icon: Icons.menu_book_rounded, label: 'Courses', path: '/courses', currentPath: currentPath),
        if (isAdmin) _SideMenuItem(icon: Icons.people_alt_rounded, label: 'User Management', path: '/admin/users', currentPath: currentPath),
        _SideMenuItem(icon: Icons.person_rounded, label: 'Account Profile', path: '/profile', currentPath: currentPath),

        const Spacer(),

        // User info footer card
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryIndigo,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.dangerRose),
                  tooltip: 'Sign Out',
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

Widget _buildMobileNavigation(BuildContext context, String currentPath, Ref ref) {
  final user = ref.watch(authProvider).valueOrNull;
  final role = user?['role'] as String? ?? 'student';
  final isAdmin = role == 'admin';
  final destinations = <({IconData icon, String label, String path})>[
    if (role == 'student') (
      icon: Icons.dashboard_rounded,
      label: 'Dashboard',
      path: '/dashboard',
    ),
    (icon: Icons.menu_book_rounded, label: 'Courses', path: '/courses'),
    if (isAdmin)
      (
        icon: Icons.people_alt_rounded,
        label: 'Users',
        path: '/admin/users',
      ),
    (icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
  ];
  var selected = destinations.indexWhere((item) => currentPath.startsWith(item.path));
  if (selected < 0) selected = 0;

  return NavigationBar(
    selectedIndex: selected,
    onDestinationSelected: (index) => context.go(destinations[index].path),
    destinations: [
      for (final item in destinations)
        NavigationDestination(icon: Icon(item.icon), label: item.label),
    ],
  );
}

class _SideMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;

  const _SideMenuItem({required this.icon, required this.label, required this.path, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final selected = currentPath.startsWith(path);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: selected ? AppColors.primaryIndigo.withOpacity(0.3) : Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? AppColors.primaryIndigo : AppColors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.primaryIndigo : AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 6, height: 6,
                    decoration: const BoxDecoration(color: AppColors.primaryIndigo, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
