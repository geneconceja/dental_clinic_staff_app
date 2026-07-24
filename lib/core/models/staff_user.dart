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
    this.firstName,
    this.lastName,
    this.isVerified = false,
  });

  final String uid;
  final StaffRole role;
  final String name;
  final String email;
  final String phone;
  final bool active;
  final DateTime createdAt;

  /// Split first name (used for patient profile; null for staff accounts).
  final String? firstName;

  /// Split last name (used for patient profile; null for staff accounts).
  final String? lastName;

  /// True once the patient has clicked the Firebase email-verification link.
  /// Always true for staff/admin (they are provisioned by admin, not self-signup).
  final bool isVerified;

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
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      // Staff/admin accounts are pre-provisioned — treat missing field as verified.
      isVerified: (json['isVerified'] as bool?) ?? true,
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
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      'isVerified': isVerified,
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
    String? firstName,
    String? lastName,
    bool? isVerified,
  }) {
    return StaffUser(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
