/// auth_providers.dart
/// Dental Clinic Staff/Admin App
///
/// Riverpod providers for authentication state and staff profile.
/// The router and any screen that needs to know "who is logged in" reads
/// from these providers — never from FirebaseAuth.instance directly.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import '../../core/models/staff_user.dart';

// ---------- Repository provider ----------

/// Singleton [AuthRepository]. Override in tests to inject mocks.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

// ---------- Auth state ----------

/// Streams the current [User] from Firebase Auth.
/// Emits null when signed out.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

// ---------- Staff profile ----------

/// Fetches the Firestore `users/{uid}` document for the currently
/// signed-in user. Returns null if:
///   - No user is signed in
///   - The user has no corresponding staff document (e.g. patient account)
final staffProfileProvider = FutureProvider<StaffUser?>(
  (ref) async {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) return null;
    return ref.watch(authRepositoryProvider).fetchStaffProfile(user.uid);
  },
);

/// Convenience provider exposing just the role string, or null.
/// Used by the router guard to distinguish admin, staff, and patient.
final currentRoleProvider = Provider<String?>((ref) {
  return ref.watch(staffProfileProvider).asData?.value?.role.name;
});

/// Convenience provider returning true if the currently logged in user is a patient.
final isPatientProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'patient';
});

/// Convenience provider returning true if the logged in user is staff or admin.
final isStaffOrAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(currentRoleProvider);
  return role == 'staff' || role == 'admin';
});
