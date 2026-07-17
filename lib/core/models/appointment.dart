/// appointment.dart
/// Dental Clinic Staff/Admin App
///
/// Mirrors the Appointment model defined in schema-types.ts.
/// Keep manually in sync if schema-types.ts updates.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  cancelled,
  completed,
  noShow;

  static AppointmentStatus fromString(String? val) {
    return switch (val) {
      'pending' => AppointmentStatus.pending,
      'confirmed' => AppointmentStatus.confirmed,
      'cancelled' => AppointmentStatus.cancelled,
      'completed' => AppointmentStatus.completed,
      'no-show' || 'noShow' => AppointmentStatus.noShow,
      _ => AppointmentStatus.pending,
    };
  }

  String toJson() {
    return switch (this) {
      AppointmentStatus.pending => 'pending',
      AppointmentStatus.confirmed => 'confirmed',
      AppointmentStatus.cancelled => 'cancelled',
      AppointmentStatus.completed => 'completed',
      AppointmentStatus.noShow => 'no-show',
    };
  }
}

enum BookingSource {
  patientApp,
  staffWalkin;

  static BookingSource fromString(String? val) {
    return switch (val) {
      'patient_app' || 'patientApp' => BookingSource.patientApp,
      'staff_walkin' || 'staffWalkin' => BookingSource.staffWalkin,
      _ => BookingSource.patientApp, // fallback default for legacy documents
    };
  }

  String toJson() {
    return switch (this) {
      BookingSource.patientApp => 'patient_app',
      BookingSource.staffWalkin => 'staff_walkin',
    };
  }
}

class AnalysisTag {
  const AnalysisTag({
    required this.tag,
    required this.confidence,
  });

  final String tag;
  final double confidence; // 0.0 - 1.0

  factory AnalysisTag.fromJson(Map<String, dynamic> json) {
    return AnalysisTag(
      tag: (json['tag'] as String?) ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'confidence': confidence,
    };
  }
}

class Appointment {
  const Appointment({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.serviceId,
    required this.serviceName,
    required this.reason,
    required this.appointmentDateTime,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.notes,
    required this.imageUrl,
    required this.analysisResults,
    required this.status,
    required this.bookingSource,
    required this.createdBy,
    required this.paid,
    required this.reminderSent,
    this.cancellationReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? userId;
  final String? userEmail;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String serviceId;
  final String serviceName;
  final String reason; // Keep for legacy read-compat
  final DateTime appointmentDateTime;
  final String date; // "YYYY-MM-DD"
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String? notes;
  final String? imageUrl;
  final List<AnalysisTag>? analysisResults;
  final AppointmentStatus status;
  final BookingSource bookingSource;
  final String createdBy;
  final bool paid;
  final bool reminderSent;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get patientFullName => '$firstName $lastName';

  factory Appointment.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final rawAnalysis = json['analysisResults'] as List<dynamic>?;
    final parsedAnalysis = rawAnalysis
        ?.whereType<Map<String, dynamic>>()
        .map(AnalysisTag.fromJson)
        .toList();

    return Appointment(
      id: documentId ?? (json['id'] as String?) ?? '',
      userId: json['userId'] as String?,
      userEmail: json['userEmail'] as String?,
      firstName: (json['firstName'] as String?) ?? '',
      lastName: (json['lastName'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      serviceId: (json['serviceId'] as String?) ?? '',
      serviceName: (json['serviceName'] as String?) ?? '',
      reason: (json['reason'] as String?) ?? (json['serviceName'] as String?) ?? '',
      appointmentDateTime: parseDateTime(json['appointmentDateTime']),
      date: (json['date'] as String?) ?? '',
      startTime: (json['startTime'] as String?) ?? '',
      endTime: (json['endTime'] as String?) ?? '',
      notes: json['notes'] as String?,
      imageUrl: json['imageUrl'] as String?,
      analysisResults: parsedAnalysis,
      status: AppointmentStatus.fromString(json['status'] as String?),
      // Schema Backfill fallback: default to patient_app if bookingSource is missing or null
      bookingSource: BookingSource.fromString(json['bookingSource'] as String?),
      createdBy: (json['createdBy'] as String?) ?? '',
      paid: (json['paid'] as bool?) ?? false,
      reminderSent: (json['reminderSent'] as bool?) ?? false,
      cancellationReason: json['cancellationReason'] as String?,
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'reason': reason,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'notes': notes,
      'imageUrl': imageUrl,
      'analysisResults': analysisResults?.map((e) => e.toJson()).toList(),
      'status': status.toJson(),
      'bookingSource': bookingSource.toJson(),
      'createdBy': createdBy,
      'paid': paid,
      'reminderSent': reminderSent,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Appointment copyWith({
    String? id,
    String? userId,
    String? userEmail,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? serviceId,
    String? serviceName,
    String? reason,
    DateTime? appointmentDateTime,
    String? date,
    String? startTime,
    String? endTime,
    String? notes,
    String? imageUrl,
    List<AnalysisTag>? analysisResults,
    AppointmentStatus? status,
    BookingSource? bookingSource,
    String? createdBy,
    bool? paid,
    bool? reminderSent,
    String? cancellationReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      reason: reason ?? this.reason,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      analysisResults: analysisResults ?? this.analysisResults,
      status: status ?? this.status,
      bookingSource: bookingSource ?? this.bookingSource,
      createdBy: createdBy ?? this.createdBy,
      paid: paid ?? this.paid,
      reminderSent: reminderSent ?? this.reminderSent,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
