/// patient_providers.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Riverpod state providers for patient appointments and upcoming highlights.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/appointment.dart';
import '../auth/auth_providers.dart';
import 'patient_repository.dart';

/// Singleton [PatientRepository] provider.
final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository();
});

/// Streams the list of appointments belonging to the logged-in patient.
final patientAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(patientRepositoryProvider).watchPatientAppointments(user.uid);
});

/// Computes the next upcoming appointment (status pending or confirmed, future date).
final nextUpcomingAppointmentProvider = Provider<Appointment?>((ref) {
  final apptsAsync = ref.watch(patientAppointmentsProvider);
  final appts = apptsAsync.asData?.value ?? [];
  final now = DateTime.now();

  final upcomingList = appts.where((a) {
    final isUpcomingStatus = a.status == AppointmentStatus.pending ||
        a.status == AppointmentStatus.confirmed;
    final isFuture = a.appointmentDateTime.isAfter(now.subtract(const Duration(hours: 2)));
    return isUpcomingStatus && isFuture;
  }).toList();

  if (upcomingList.isEmpty) return null;

  // Sort ascending by appointmentDateTime (earliest upcoming first)
  upcomingList.sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
  return upcomingList.first;
});
