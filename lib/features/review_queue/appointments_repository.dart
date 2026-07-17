/// appointments_repository.dart
/// Dental Clinic Staff/Admin App
///
/// Handles Firestore streams and updates for the appointments collection.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';

class AppointmentsRepository {
  AppointmentsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('appointments');

  // ---------- Read Streams ----------

  /// Streams all appointments with `status == "pending"`, sorted by
  /// `appointmentDateTime` ascending. Useful for the Review Queue page.
  Stream<List<Appointment>> watchPendingAppointments() {
    return _collection
        .where('status', isEqualTo: 'pending')
        .orderBy('appointmentDateTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), documentId: doc.id))
            .toList());
  }

  /// Streams all appointments scheduled for a specific date (YYYY-MM-DD),
  /// sorted by start time. Useful for the Dashboard.
  Stream<List<Appointment>> watchAppointmentsByDate(String dateString) {
    return _collection
        .where('date', isEqualTo: dateString)
        .orderBy('startTime', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Appointment.fromJson(doc.data(), documentId: doc.id))
            .toList());
  }

  /// Streams a single appointment by its document ID.
  Stream<Appointment?> watchAppointmentById(String id) {
    return _collection.doc(id).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Appointment.fromJson(doc.data()!, documentId: doc.id);
    });
  }

  // ---------- Direct Writes ----------
  // Note: Status transitions go through updateAppointmentStatus Cloud Function.
  // Direct writes are limited to fields allowed by firestore.rules for staff.

  /// Marks an appointment as paid or unpaid.
  Future<void> updatePaymentStatus(String id, bool paid) async {
    await _collection.doc(id).update({
      'paid': paid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the staff notes of an appointment.
  Future<void> updateNotes(String id, String? notes) async {
    await _collection.doc(id).update({
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ---------- Providers ----------

final appointmentsRepositoryProvider = Provider<AppointmentsRepository>((ref) {
  return AppointmentsRepository();
});

final pendingAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  return ref.watch(appointmentsRepositoryProvider).watchPendingAppointments();
});

/// Streams all appointments for a specific date string ("YYYY-MM-DD").
/// Used by the Dashboard screen to show the day's schedule.
final appointmentsByDateProvider =
    StreamProvider.family<List<Appointment>, String>((ref, dateStr) {
  return ref
      .watch(appointmentsRepositoryProvider)
      .watchAppointmentsByDate(dateStr);
});
