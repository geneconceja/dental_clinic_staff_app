/// activity_logger_service.dart
/// Dental Clinic Staff/Admin App
///
/// Service handling audit log creation in activity_logs/{id} and streaming
/// activity records for the audit log dashboard UI.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity_log.dart';

class ActivityLoggerService {
  ActivityLoggerService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Records an audit log entry in the activity_logs collection.
  Future<void> logActivity({
    required String action,
    required String resourceId,
    String? actorRole,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = _auth.currentUser;
      final actorUid = user?.uid ?? 'system';
      final actorEmail = user?.email ?? 'system@clinic.test';

      final docRef = _firestore.collection('activity_logs').doc();

      await docRef.set({
        'actorUid': actorUid,
        'actorEmail': actorEmail,
        'actorRole': actorRole ?? 'staff',
        'action': action,
        'resourceId': resourceId,
        'timestamp': FieldValue.serverTimestamp(),
        if (details != null) 'details': details,
      });
    } catch (e) {
      // Audit logging errors should not crash main feature flows
      debugPrint('[ActivityLoggerService] Exception while logging activity: $e');
    }
  }

  /// Streams all activity logs sorted by timestamp descending.
  Stream<List<ActivityLog>> watchActivityLogs() {
    return _firestore
        .collection('activity_logs')
        .snapshots()
        .map((snapshot) {
      final logs = snapshot.docs.map((doc) {
        return ActivityLog.fromJson(doc.data(), documentId: doc.id);
      }).toList();

      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return logs;
    });
  }
}

// ---------- Riverpod Providers ----------

final activityLoggerServiceProvider = Provider<ActivityLoggerService>((ref) {
  return ActivityLoggerService();
});

final activityLogsStreamProvider = StreamProvider<List<ActivityLog>>((ref) {
  final service = ref.watch(activityLoggerServiceProvider);
  return service.watchActivityLogs();
});
