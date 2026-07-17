/// auth_repository.dart
/// Dental Clinic Staff/Admin App
///
/// Wraps FirebaseAuth and Firestore to provide typed authentication and
/// staff profile lookups. All auth errors are normalized to [AuthException].
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/models/staff_user.dart';

// ---------- Exceptions ----------

/// Normalized auth error surfaced to UI layers.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

// ---------- Repository ----------

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // --- Auth state stream ---

  /// Emits the current [User] whenever auth state changes, or null when
  /// signed out. Use this to drive the [authStateProvider].
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in [User], or null.
  User? get currentUser => _auth.currentUser;

  // --- Sign in ---

  /// Signs in with [email] and [password].
  /// Throws [AuthException] with a user-friendly message on failure.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  // --- Sign out ---

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- Staff profile ---

  /// Fetches the Firestore `users/{uid}` document and returns a
  /// [StaffUser], or null if the document doesn't exist
  /// (e.g. a patient Firebase Auth user who somehow accessed this app).
  Future<StaffUser?> fetchStaffProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return StaffUser.fromJson(doc.data()!, documentId: uid);
  }

  // --- Error mapping ---

  String _mapFirebaseError(String code) {
    return switch (code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Invalid email or password.',
      'user-disabled' => 'This account has been disabled. Contact your administrator.',
      'too-many-requests' => 'Too many login attempts. Please try again later.',
      'network-request-failed' => 'Network error. Check your connection and try again.',
      _ => 'Sign-in failed. Please try again.',
    };
  }
}
