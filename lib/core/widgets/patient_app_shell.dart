/// patient_app_shell.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Responsive layout shell for all patient-facing routes (/patient/*).
/// Features a top header navigation for desktop/tablet web and a fluid
/// bottom navigation bar for mobile web browsers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/auth/auth_providers.dart';
import '../../routing/app_router.dart';

class PatientAppShell extends ConsumerWidget {
  const PatientAppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    final profileAsync = ref.watch(staffProfileProvider);
    final profile = profileAsync.asData?.value;
    final patientName = profile != null ? profile.name : 'Patient';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isMobile
          ? AppBar(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 1,
              title: Row(
                children: [
                  const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'OralScope',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              actions: [
                _buildProfileAvatarMenu(context, ref, patientName),
                const SizedBox(width: 8),
              ],
            )
          : null,
      body: Column(
        children: [
          if (!isMobile) _buildDesktopHeader(context, ref, patientName),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildMobileBottomBar(context) : null,
    );
  }

  // ---------- Desktop / Tablet Top Header ----------

  Widget _buildDesktopHeader(BuildContext context, WidgetRef ref, String patientName) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Clinic Branding Logo & Title
          InkWell(
            onTap: () => context.goNamed(AppRoutes.patientDashboard),
            borderRadius: BorderRadius.circular(8),
            child: const Row(
              children: [
                Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 28),
                SizedBox(width: 10),
                Text(
                  'OralScope Dental',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 40),

          // Navigation Links
          Expanded(
            child: Row(
              children: [
                _HeaderTabItem(
                  label: 'Dashboard',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  isActive: currentRoute == '/patient/dashboard',
                  onTap: () => context.goNamed(AppRoutes.patientDashboard),
                ),
                const SizedBox(width: 8),
                _HeaderTabItem(
                  label: 'Book Appointment',
                  icon: Icons.calendar_month_outlined,
                  activeIcon: Icons.calendar_month,
                  isActive: currentRoute == '/patient/book',
                  onTap: () => context.goNamed(AppRoutes.patientBook),
                ),
                const SizedBox(width: 8),
                _HeaderTabItem(
                  label: 'My Appointments',
                  icon: Icons.event_note_outlined,
                  activeIcon: Icons.event_note,
                  isActive: currentRoute == '/patient/appointments',
                  onTap: () => context.goNamed(AppRoutes.patientAppointments),
                ),
                const SizedBox(width: 8),
                _HeaderTabItem(
                  label: 'Profile',
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  isActive: currentRoute == '/patient/profile',
                  onTap: () => context.goNamed(AppRoutes.patientProfile),
                ),
              ],
            ),
          ),

          // Patient User Actions & Avatar Menu
          _buildProfileAvatarMenu(context, ref, patientName),
        ],
      ),
    );
  }

  // ---------- Profile Avatar & Logout Popup Menu ----------

  Widget _buildProfileAvatarMenu(BuildContext context, WidgetRef ref, String patientName) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'logout') {
          await ref.read(authRepositoryProvider).signOut();
          if (context.mounted) {
            context.goNamed(AppRoutes.login);
          }
        } else if (value == 'profile') {
          context.goNamed(AppRoutes.patientProfile);
        }
      },
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                patientName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Text(
                'Patient Account',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text('My Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_outlined, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text('Log Out', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              patientName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  // ---------- Mobile Bottom Navigation Bar ----------

  Widget _buildMobileBottomBar(BuildContext context) {
    int currentIndex = 0;
    if (currentRoute == '/patient/book') currentIndex = 1;
    if (currentRoute == '/patient/appointments') currentIndex = 2;
    if (currentRoute == '/patient/profile') currentIndex = 3;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight.withAlpha(50),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.goNamed(AppRoutes.patientDashboard);
              break;
            case 1:
              context.goNamed(AppRoutes.patientBook);
              break;
            case 2:
              context.goNamed(AppRoutes.patientAppointments);
              break;
            case 3:
              context.goNamed(AppRoutes.patientProfile);
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary),
            label: 'Book',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note, color: AppColors.primary),
            label: 'Appointments',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ---------- Desktop Header Tab Widget ----------

class _HeaderTabItem extends StatelessWidget {
  const _HeaderTabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 18,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
