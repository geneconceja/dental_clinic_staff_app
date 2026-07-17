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
import '../core/widgets/app_shell.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/review_queue/review_queue_screen.dart';
import '../features/review_queue/appointment_detail_screen.dart';
import '../features/walk_in_booking/walk_in_booking_screen.dart';
import '../features/services_admin/services_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/staff_management/staff_screen.dart';

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

      // Logged in + on login page → wait for profile to resolve before redirecting to dashboard
      if (onLoginPage) {
        final profileState = ref.read(staffProfileProvider);
        if (profileState.isLoading) return null;

        final profile = profileState.asData?.value;
        if (profile != null && profile.active) {
          return '/dashboard';
        }
        return null; // stay on login page (login screen's _submit handles the signout and error display)
      }

      // While the staff profile is loading, stay on the current route.
      // The router notifier will trigger a redirect re-evaluation when the profile resolves.
      final profileState = ref.read(staffProfileProvider);
      if (profileState.isLoading) return null;

      final profile = profileState.asData?.value;
      if (profile == null || !profile.active) {
        // Deactivated or invalid profile → sign out and boot to login
        ref.read(authRepositoryProvider).signOut();
        return '/login';
      }

      // Admin-only route check
      final role = profile.role.name;
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
            builder: (_, __) => const ServicesScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: AppRoutes.settings,
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/staff',
            name: AppRoutes.staff,
            builder: (_, __) => const StaffScreen(),
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
