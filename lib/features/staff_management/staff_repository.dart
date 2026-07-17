/// staff_repository.dart
/// Dental Clinic Staff/Admin App
///
/// Handles Firestore streams and updates for staff accounts under users collection.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/staff_user.dart';

class StaffRepository {
  StaffRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users');

  // ---------- Read Streams ----------

  /// Streams all users where `role` is either 'staff' or 'admin'.
  /// Sorted alphabetically by name.
  Stream<List<StaffUser>> watchStaffUsers() {
    return _collection
        .where('role', whereIn: const ['staff', 'admin'])
        .snapshots()
        .map((snap) {
          final users = snap.docs
              .map((doc) => StaffUser.fromJson(doc.data(), documentId: doc.id))
              .toList();
          // Sort alphabetically client-side to avoid Firestore composite index requirement
          users.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          return users;
        });
  }

  /// Streams a single user profile by UID.
  Stream<StaffUser?> watchStaffUserById(String uid) {
    return _collection.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return StaffUser.fromJson(doc.data()!, documentId: doc.id);
    });
  }

  // ---------- CRUD / Write Operations ----------

  /// Seeds or writes a staff user record in Firestore under users/{uid}.
  /// Used during new account setup or syncing credentials.
  Future<void> saveStaffUser(StaffUser user) async {
    await _collection.doc(user.uid).set(user.toJson(), SetOptions(merge: true));
  }

  /// Toggles a staff member's active status.
  Future<void> toggleStaffActive(String uid, bool active) async {
    await _collection.doc(uid).update({
      'active': active,
    });
  }

  /// Updates a staff member's role.
  Future<void> updateStaffRole(String uid, StaffRole role) async {
    await _collection.doc(uid).update({
      'role': role.toJson(),
    });
  }
}

// ---------- Provider ----------

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  return StaffRepository();
});
