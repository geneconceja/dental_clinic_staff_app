/// app_router.dart
/// Dental Clinic Staff/Admin App
///
/// Central routing configuration using go_router.
/// Contains all named routes, auth guards, and placeholder screens for
/// routes not yet built. Real screen implementations replace the placeholders
/// in later phases.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_shell.dart';
import '../core/widgets/patient_app_shell.dart';
import '../features/auth/auth_providers.dart';
import '../features/activity_logs/activity_logs_screen.dart';
import '../features/auth/email_verification_gate_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/patient_signup_screen.dart';
import '../features/auth/sso_exchange_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/patient_portal/patient_appointments_screen.dart';
import '../features/patient_portal/patient_booking_wizard_screen.dart';
import '../features/patient_portal/patient_dashboard_screen.dart';
import '../features/patient_portal/patient_profile_screen.dart';
import '../features/review_queue/review_queue_screen.dart';
import '../features/review_queue/appointment_detail_screen.dart';
import '../features/walk_in_booking/walk_in_booking_screen.dart';
import '../features/services_admin/services_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/staff_management/staff_screen.dart';
import '../features/calendar/calendar_screen.dart';

// ---------- Route name constants ----------

abstract final class AppRoutes {
  static const login = 'login';
  static const signUp = 'signUp';
  static const emailVerification = 'emailVerification';
  static const dashboard = 'dashboard';
  static const patientDashboard = 'patient-dashboard';
  static const patientBook = 'patient-book';
  static const patientAppointments = 'patient-appointments';
  static const patientProfile = 'patient-profile';
  static const reviewQueue = 'review-queue';
  static const walkInNew = 'walk-in-new';
  static const appointmentDetail = 'appointment-detail';
  static const calendar = 'calendar';
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

      final location = state.matchedLocation;
      final onLoginPage = location == '/login';
      final onSsoPage = location == '/sso';
      final onSignUpPage = location == '/signup';
      final onVerificationPage = location == '/email-verification';

      // Public routes — always accessible, even signed out.
      if (onSsoPage || onSignUpPage) return null;

      // Not logged in → always go to login (except public routes above)
      if (!isLoggedIn) {
        return (onLoginPage) ? null : '/login';
      }

      final profileState = ref.read(staffProfileProvider);

      // While the staff/patient profile is loading/resolving, stay on current route.
      if (profileState.isLoading || profileState.isRefreshing || !profileState.hasValue) {
        return null;
      }

      final profile = profileState.asData?.value;

      // A patient is considered verified if EITHER:
      //   (a) Firestore profile.isVerified is true (the normal production state), OR
      //   (b) FirebaseAuth.currentUser.emailVerified is true but Firestore hasn't been
      //       synced yet (e.g. emulator UI shortcut, or returning from email link).
      // The gate screen's _autoCheckOnLoad will sync Firestore in case (b).
      final firebaseVerified =
          FirebaseAuth.instance.currentUser?.emailVerified ?? false;

      bool effectivelyVerified(bool firestoreVerified) =>
          firestoreVerified || firebaseVerified;

      // Logged in + on login page → redirect to the right home for the role.
      if (onLoginPage) {
        if (profile != null && profile.active) {
          if (profile.role.name == 'patient') {
            return effectivelyVerified(profile.isVerified)
                ? '/patient/dashboard'
                : '/email-verification';
          }
          return '/dashboard';
        }
        return null; // stay on login page
      }

      if (profile == null || !profile.active) {
        return '/login';
      }

      // Unverified patient (neither Firestore nor Firebase Auth says verified)
      // trying to access anything other than the gate → send to gate.
      if (profile.role.name == 'patient' &&
          !effectivelyVerified(profile.isVerified) &&
          !onVerificationPage) {
        return '/email-verification';
      }

      // Patient is effectively verified and is on the gate → move them along.
      if (profile.role.name == 'patient' &&
          effectivelyVerified(profile.isVerified) &&
          onVerificationPage) {
        return '/patient/dashboard';
      }

      // Role-based route protection
      final role = profile.role.name;
      const adminOnlyPaths = ['/services', '/settings', '/staff'];
      const staffPaths = ['/dashboard', '/calendar', '/review-queue', '/walk-in/new'];

      final isStaffPath = staffPaths.contains(state.matchedLocation) ||
          state.matchedLocation.startsWith('/appointment/');
      final isAdminPath = adminOnlyPaths.contains(state.matchedLocation);

      // Patient attempting to visit staff or admin routes ➔ redirect to patient dashboard
      if (role == 'patient' && (isStaffPath || isAdminPath)) {
        return '/patient/dashboard';
      }

      // Non-admin staff attempting to visit admin-only routes ➔ 403
      if (role != 'admin' && isAdminPath) {
        return '/403';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: AppRoutes.signUp,
        builder: (_, __) => const PatientSignUpScreen(),
      ),
      GoRoute(
        path: '/email-verification',
        name: AppRoutes.emailVerification,
        builder: (_, __) => const EmailVerificationGateScreen(),
      ),
      GoRoute(
        path: '/sso',
        name: 'sso',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'] ?? '';
          final target = state.uri.queryParameters['target'] ?? '/patient/dashboard';
          return SsoExchangeScreen(token: token, targetPath: target);
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return PatientAppShell(
            currentRoute: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/patient/dashboard',
            name: AppRoutes.patientDashboard,
            builder: (_, __) => const PatientDashboardScreen(),
          ),
          GoRoute(
            path: '/patient/book',
            name: AppRoutes.patientBook,
            builder: (_, __) => const PatientBookingWizardScreen(),
          ),
          GoRoute(
            path: '/patient/appointments',
            name: AppRoutes.patientAppointments,
            builder: (_, __) => const PatientAppointmentsScreen(),
          ),
          GoRoute(
            path: '/patient/profile',
            name: AppRoutes.patientProfile,
            builder: (_, __) => const PatientProfileScreen(),
          ),
        ],
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
            path: '/calendar',
            name: AppRoutes.calendar,
            builder: (_, __) => const CalendarScreen(),
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
          GoRoute(
            path: '/activity-logs',
            name: 'activityLogs',
            builder: (_, __) => const ActivityLogsScreen(),
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
