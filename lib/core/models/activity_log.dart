/// activity_log.dart
/// Dental Clinic Staff/Admin App
///
/// Data model representing an immutable audit trail record in activity_logs/{id}.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.actorUid,
    required this.actorEmail,
    required this.actorRole,
    required this.action,
    required this.resourceId,
    required this.timestamp,
    this.details,
  });

  final String id;
  final String actorUid;
  final String actorEmail;
  final String actorRole;
  final String action;
  final String resourceId;
  final DateTime timestamp;
  final Map<String, dynamic>? details;

  factory ActivityLog.fromJson(Map<String, dynamic> json, {required String documentId}) {
    DateTime parsedTime = DateTime.now();
    final rawTs = json['timestamp'];
    if (rawTs is Timestamp) {
      parsedTime = rawTs.toDate();
    } else if (rawTs is String) {
      parsedTime = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    return ActivityLog(
      id: documentId,
      actorUid: (json['actorUid'] as String?) ?? '',
      actorEmail: (json['actorEmail'] as String?) ?? 'system',
      actorRole: (json['actorRole'] as String?) ?? 'system',
      action: (json['action'] as String?) ?? 'unknown_action',
      resourceId: (json['resourceId'] as String?) ?? '',
      timestamp: parsedTime,
      details: json['details'] != null ? Map<String, dynamic>.from(json['details'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actorUid': actorUid,
      'actorEmail': actorEmail,
      'actorRole': actorRole,
      'action': action,
      'resourceId': resourceId,
      'timestamp': Timestamp.fromDate(timestamp),
      if (details != null) 'details': details,
    };
  }
}
