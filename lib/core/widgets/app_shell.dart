/// app_shell.dart
/// Dental Clinic Staff/Admin App
///
/// Shared layout shell containing the clinic branding, sidebar navigation
/// drawer, current staff member info, and responsive content area.
/// Automatically handles hiding admin-only navigation links based on user role.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/review_queue/appointments_repository.dart';
import '../../routing/app_router.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final profileAsync = ref.watch(staffProfileProvider);
    final pendingAsync = ref.watch(pendingAppointmentsProvider);
    final theme = Theme.of(context);

    final isAdmin = role == 'admin';
    final pendingCount = pendingAsync.asData?.value.length ?? 0;

    return Scaffold(
      body: Row(
        children: [
          // ---------- Left Sidebar (Desktop/Tablet) ----------
          Container(
            width: 260,
            color: AppColors.sidebarBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Branding header
                _buildSidebarHeader(theme),
                const Divider(color: Colors.white24, height: 1),

                // Navigation links
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _SidebarItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard',
                        active: currentRoute == '/dashboard',
                        onTap: () => context.goNamed(AppRoutes.dashboard),
                      ),
                      _SidebarItem(
                        icon: Icons.calendar_month_outlined,
                        label: 'Calendar',
                        active: currentRoute == '/calendar',
                        onTap: () => context.goNamed(AppRoutes.calendar),
                      ),
                      _SidebarItem(
                        icon: Icons.inbox_outlined,
                        label: 'Review Queue',
                        active: currentRoute == '/review-queue',
                        onTap: () => context.goNamed(AppRoutes.reviewQueue),
                        badgeCount: pendingCount,
                      ),
                      _SidebarItem(
                        icon: Icons.person_add_outlined,
                        label: 'New Walk-In',
                        active: currentRoute == '/walk-in/new',
                        onTap: () => context.goNamed(AppRoutes.walkInNew),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          child: Text(
                            'ADMIN TOOLS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.sidebarText.withAlpha(127),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _SidebarItem(
                          icon: Icons.medical_services_outlined,
                          label: 'Services',
                          active: currentRoute == '/services',
                          onTap: () => context.goNamed(AppRoutes.services),
                        ),
                        _SidebarItem(
                          icon: Icons.manage_accounts_outlined,
                          label: 'Staff Directory',
                          active: currentRoute == '/staff',
                          onTap: () => context.goNamed(AppRoutes.staff),
                        ),
                        _SidebarItem(
                          icon: Icons.settings_outlined,
                          label: 'Clinic Settings',
                          active: currentRoute == '/settings',
                          onTap: () => context.goNamed(AppRoutes.settings),
                        ),
                      ],
                    ],
                  ),
                ),

                // User profile info + log out button
                const Divider(color: Colors.white24, height: 1),
                profileAsync.when(
                  data: (profile) => _buildUserProfileFooter(context, ref, profile),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.sidebarText)),
                  ),
                  error: (_, __) => _buildUserProfileFooter(context, ref, null),
                ),
              ],
            ),
          ),

          // ---------- Right Content Window ----------
          Expanded(
            child: Container(
              color: AppColors.background,
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_hospital,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'OralScope',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Staff Management Portal',
                  style: TextStyle(
                    color: AppColors.sidebarText.withAlpha(178),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileFooter(BuildContext context, WidgetRef ref, dynamic profile) {
    final name = profile?.name ?? 'Staff User';
    final roleName = profile?.role == 'admin' ? 'Administrator' : 'Clinic Staff';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  roleName,
                  style: TextStyle(
                    color: AppColors.sidebarText.withAlpha(153),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.sidebarText, size: 20),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}

// ---------- Private Sidebar Item Widget ----------

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: active ? AppColors.sidebarItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: active ? AppColors.sidebarTextActive : AppColors.sidebarText,
                  size: 20,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? AppColors.sidebarTextActive : AppColors.sidebarText,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount! > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
