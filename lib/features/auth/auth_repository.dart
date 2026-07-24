/// auth_repository.dart
/// Dental Clinic Staff/Admin App
///
/// Wraps FirebaseAuth and Firestore to provide typed authentication and
/// staff/patient profile lookups. All auth errors are normalized to [AuthException].
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

  // --- Patient sign up ---

  /// Creates a new Firebase Auth user and a corresponding Firestore `users/{uid}`
  /// document with `role: patient`. Sends the built-in Firebase email verification
  /// link immediately after account creation.
  ///
  /// On Firestore write failure the Firebase Auth user is deleted so the account
  /// does not end up in a half-created state. Throws [AuthException] on failure.
  Future<void> signUpPatient({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String phone = '',
  }) async {
    late UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }

    final user = credential.user!;
    final fullName = '${firstName.trim()} ${lastName.trim()}';
    final now = Timestamp.now();

    // Persist patient profile to Firestore.
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'role': 'patient',
        'name': fullName,
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'active': true,
        'isVerified': false,
        'createdAt': now,
        'updatedAt': now,
      });
    } catch (_) {
      // If Firestore write fails, clean up the Firebase Auth user so the account
      // doesn't end up in a half-created state.
      await user.delete();
      rethrow;
    }

    // Send the built-in Firebase email-verification link.
    await user.sendEmailVerification();
  }

  // --- Email verification ---

  /// Re-sends the Firebase email-verification link to the currently signed-in user.
  /// Throws [AuthException] if there is no signed-in user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No user is currently signed in.');
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  /// Force-refreshes the current user's token from the Firebase backend so that
  /// [User.emailVerified] reflects the latest server-side verification status.
  /// Call this when the patient taps "I've verified my email".
  ///
  /// If [User.reload] fails (e.g. the emulator returns a 400 when verification
  /// was set externally via the emulator UI), we fall back to the locally
  /// cached [emailVerified] value rather than throwing — this keeps the button
  /// working in both emulator and production environments.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {
      // Reload can fail in the emulator when the verification state was updated
      // externally (e.g. via the emulator UI). Fall through and use the cached
      // emailVerified value — it may already be true.
    }
    // Re-fetch the current user object after reload (or the cached one on error).
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Once the patient has verified their email, update the Firestore document
  /// so [StaffUser.isVerified] is reflected across the app.
  Future<void> markPatientVerified(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'isVerified': true,
      'updatedAt': Timestamp.now(),
    });
  }

  // --- Sign out ---

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- Staff / patient profile ---

  /// Fetches the Firestore `users/{uid}` document and returns a [StaffUser],
  /// or null if the document doesn't exist.
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
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'network-request-failed' => 'Network error. Check your connection and try again.',
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      _ => 'An error occurred. Please try again.',
    };
  }
}
