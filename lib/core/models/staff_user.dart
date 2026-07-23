/// staff_user.dart
/// Dental Clinic Staff/Admin App
///
/// Mirrors the StaffUser model defined in schema-types.ts.
/// Keep manually in sync if schema-types.ts updates.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum StaffRole {
  patient,
  staff,
  admin;

  static StaffRole fromString(String? role) {
    if (role == 'admin') return StaffRole.admin;
    if (role == 'patient') return StaffRole.patient;
    return StaffRole.staff;
  }

  String toJson() => name;
}

class StaffUser {
  const StaffUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    required this.active,
    required this.createdAt,
  });

  final String uid;
  final StaffRole role;
  final String name;
  final String email;
  final String phone;
  final bool active;
  final DateTime createdAt;

  bool get isAdmin => role == StaffRole.admin;

  factory StaffUser.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return StaffUser(
      uid: documentId ?? (json['uid'] as String?) ?? '',
      role: StaffRole.fromString(json['role'] as String?),
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      active: (json['active'] as bool?) ?? false,
      createdAt: parseDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'role': role.toJson(),
      'name': name,
      'email': email,
      'phone': phone,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  StaffUser copyWith({
    String? uid,
    StaffRole? role,
    String? name,
    String? email,
    String? phone,
    bool? active,
    DateTime? createdAt,
  }) {
    return StaffUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
