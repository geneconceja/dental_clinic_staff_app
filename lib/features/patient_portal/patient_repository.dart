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
}
