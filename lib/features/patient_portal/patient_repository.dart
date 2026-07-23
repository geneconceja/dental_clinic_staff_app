/// patient_repository.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Repository handling Firestore queries and updates for patient appointments
/// and patient user profiles.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/models/appointment.dart';

class PatientRepository {
  PatientRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ---------- Patient Appointments Stream ----------

  /// Streams all appointments belonging to the specified [patientUid].
  /// Sorted by appointmentDateTime descending (most recent first).
  Stream<List<Appointment>> watchPatientAppointments(String patientUid) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: patientUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return Appointment.fromJson(data, documentId: doc.id);
      }).toList();

      // Sort client-side by appointmentDateTime descending
      list.sort((a, b) => b.appointmentDateTime.compareTo(a.appointmentDateTime));
      return list;
    });
  }

  // ---------- Create Patient Appointment ----------

  /// Creates a new self-service patient appointment request in Firestore.
  Future<String> createPatientAppointment({
    required String patientUid,
    required String patientEmail,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String serviceId,
    required String serviceName,
    required String dateStr,
    required String startTime,
    required String endTime,
    required DateTime appointmentDateTime,
    String? notes,
  }) async {
    final docRef = _firestore.collection('appointments').doc();

    final data = {
      'userId': patientUid,
      'userEmail': patientEmail,
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'serviceId': serviceId,
      'serviceName': serviceName,
      'reason': serviceName,
      'date': dateStr,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'startTime': startTime,
      'endTime': endTime,
      'notes': notes != null && notes.trim().isNotEmpty ? notes.trim() : null,
      'imageUrl': null,
      'analysisResults': null,
      'status': 'pending',
      'bookingSource': 'patient_web',
      'createdBy': null,
      'paid': false,
      'reminderSent': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
    return docRef.id;
  }

  // ---------- Fetch Appointments for Date Slot Calculation ----------

  /// Fetches existing non-cancelled appointments for a specific date (YYYY-MM-DD)
  /// to filter out taken time slots.
  Future<List<Appointment>> fetchAppointmentsForDate(String dateStr) async {
    try {
      final snap = await _firestore
          .collection('appointments')
          .where('date', isEqualTo: dateStr)
          .get();

      return snap.docs
          .map((doc) => Appointment.fromJson(doc.data(), documentId: doc.id))
          .where((a) => a.status == AppointmentStatus.pending || a.status == AppointmentStatus.confirmed)
          .toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Patient users cannot query all appointments on a date due to Firestore security rules.
        // Return empty list so working-hours slots can still be generated.
        return [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ---------- Update Patient Profile ----------

  /// Updates patient name and phone number under users/{patientUid}.
  Future<void> updatePatientProfile({
    required String patientUid,
    required String name,
    required String phone,
  }) async {
    await _firestore.collection('users').doc(patientUid).update({
      'name': name.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Patient Cancellation & Rescheduling ----------

  /// Cancels an existing appointment request owned by the patient.
  Future<void> cancelPatientAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': 'cancelled',
      if (reason != null && reason.trim().isNotEmpty) 'cancellationReason': reason.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reschedules an existing appointment to a new date & time slot.
  /// Resets status to 'pending' for staff re-review.
  Future<void> reschedulePatientAppointment({
    required String appointmentId,
    required String dateStr,
    required String startTime,
    required String endTime,
    required DateTime appointmentDateTime,
  }) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'date': dateStr,
      'startTime': startTime,
      'endTime': endTime,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
