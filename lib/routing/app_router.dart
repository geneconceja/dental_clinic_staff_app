/// app_router.dart
/// Dental Clinic Staff/Admin App
///
/// Central routing configuration using go_router.
/// Contains all named routes, auth guards, and placeholder screens for
/// routes not yet built. Real screen implementations replace the placeholders
/// in later phases.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/services_admin/services_repository.dart';
import '../features/review_queue/appointments_repository.dart';
import '../core/widgets/app_shell.dart';
import '../features/review_queue/review_queue_screen.dart';
import '../features/review_queue/appointment_detail_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/walk_in_booking/walk_in_booking_screen.dart';

// ---------- Route name constants ----------

abstract final class AppRoutes {
  static const login = 'login';
  static const dashboard = 'dashboard';
  static const reviewQueue = 'review-queue';
  static const walkInNew = 'walk-in-new';
  static const appointmentDetail = 'appointment-detail';
  static const services = 'services';
  static const settings = 'settings';
  static const staff = 'staff';
  static const forbidden = 'forbidden';
}

// ---------- Router provider ----------

/// The global [GoRouter] instance, provided via Riverpod so it can read
/// auth providers for redirect guards.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Use a notifier so the router re-evaluates its redirect when auth changes.
  final authNotifier = _AuthRouterNotifier(ref);

  return GoRouter(
    refreshListenable: authNotifier,
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.asData?.value != null;
      final isLoading = authState.isLoading;

      // While auth is loading, don't redirect — stay on current route.
      if (isLoading) return null;

      final onLoginPage = state.matchedLocation == '/login';

      // Not logged in → always go to login
      if (!isLoggedIn) {
        return onLoginPage ? null : '/login';
      }

      // Logged in + on login page → go to dashboard
      if (onLoginPage) return '/dashboard';

      // Admin-only route check
      final role = ref.read(currentRoleProvider);
      const adminOnlyPaths = ['/services', '/settings', '/staff'];
      final isAdminOnly = adminOnlyPaths.contains(state.matchedLocation);
      if (isAdminOnly && role != 'admin') return '/403';

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            name: AppRoutes.dashboard,
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/review-queue',
            name: AppRoutes.reviewQueue,
            builder: (_, __) => const ReviewQueueScreen(),
          ),
          GoRoute(
            path: '/walk-in/new',
            name: AppRoutes.walkInNew,
            builder: (_, __) => const WalkInBookingScreen(),
          ),
          GoRoute(
            path: '/appointment/:id',
            name: AppRoutes.appointmentDetail,
            builder: (context, state) => AppointmentDetailScreen(
              appointmentId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: '/services',
            name: AppRoutes.services,
            builder: (_, __) => const _PlaceholderScreen(
              title: 'Services (Admin)',
              icon: Icons.medical_services_outlined,
            ),
          ),
          GoRoute(
            path: '/settings',
            name: AppRoutes.settings,
            builder: (_, __) => const _PlaceholderScreen(
              title: 'Clinic Settings (Admin)',
              icon: Icons.settings_outlined,
            ),
          ),
          GoRoute(
            path: '/staff',
            name: AppRoutes.staff,
            builder: (_, __) => const _PlaceholderScreen(
              title: 'Staff Management (Admin)',
              icon: Icons.manage_accounts_outlined,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/403',
        name: AppRoutes.forbidden,
        builder: (_, __) => const _ForbiddenScreen(),
      ),
    ],
  );
});

// ---------- Auth change notifier (for router refresh) ----------

/// Listens to [authStateProvider] and notifies the [GoRouter] to re-evaluate
/// its redirects whenever auth state changes.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(staffProfileProvider, (_, __) => notifyListeners());
  }
}

// ---------- Placeholder screen (temporary) ----------

/// Generic placeholder used for routes not yet implemented.
/// Will be replaced screen-by-screen in later phases.
class _PlaceholderScreen extends ConsumerWidget {
  const _PlaceholderScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final servicesAsync = ref.watch(activeServicesProvider);
    final pendingAsync = ref.watch(pendingAppointmentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.border),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This screen is coming soon.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // ---------- Live Data Verification Panel ----------
            Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Phase 3 Data Layer Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  servicesAsync.when(
                    data: (list) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Active Services:'),
                        Text('${list.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Services Error: $err', style: const TextStyle(color: AppColors.error)),
                  ),
                  const SizedBox(height: 8),
                  pendingAsync.when(
                    data: (list) => Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pending Appts:'),
                        Text('${list.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text('Appointments Error: $err', style: const TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            // Quick-nav for development convenience
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (title != 'Dashboard')
                  OutlinedButton.icon(
                    icon: const Icon(Icons.dashboard_outlined, size: 16),
                    label: const Text('Dashboard'),
                    onPressed: () => context.goNamed(AppRoutes.dashboard),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.inbox_outlined, size: 16),
                  label: const Text('Review Queue'),
                  onPressed: () => context.goNamed(AppRoutes.reviewQueue),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('New Walk-In'),
                  onPressed: () => context.goNamed(AppRoutes.walkInNew),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 403 Forbidden screen ----------

class _ForbiddenScreen extends ConsumerWidget {
  const _ForbiddenScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Access Denied', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This page is restricted to admin accounts only.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.goNamed(AppRoutes.dashboard),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}
