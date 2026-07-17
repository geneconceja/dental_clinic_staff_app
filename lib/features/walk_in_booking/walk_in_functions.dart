/// walk_in_functions.dart
/// Dental Clinic Staff/Admin App
///
/// Caller logic for createWalkInAppointment Cloud Function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/functions_client.dart';

class WalkInAppointmentResult {
  const WalkInAppointmentResult({
    required this.appointmentId,
    required this.status,
  });

  final String appointmentId;
  final String status;

  factory WalkInAppointmentResult.fromMap(Map<String, dynamic> map) {
    return WalkInAppointmentResult(
      appointmentId: (map['appointmentId'] as String?) ?? '',
      status: (map['status'] as String?) ?? '',
    );
  }
}

class WalkInFunctions {
  const WalkInFunctions({required FunctionsClient client}) : _client = client;

  final FunctionsClient _client;

  /// Invokes the createWalkInAppointment callable Cloud Function.
  /// Throws typed [FunctionsException] subclasses on backend errors.
  Future<WalkInAppointmentResult> createWalkIn({
    required String firstName,
    required String lastName,
    required String phoneNumber,
    required String serviceId,
    required DateTime appointmentDateTime,
    String? notes,
    String? imageUrl,
  }) async {
    final Map<String, dynamic> rawResult = await _client.call(
      functionName: 'createWalkInAppointment',
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'serviceId': serviceId,
        'appointmentDateTime': appointmentDateTime.toUtc().toIso8601String(),
        if (notes != null) 'notes': notes,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );

    return WalkInAppointmentResult.fromMap(rawResult);
  }
}

// ---------- Provider ----------

final walkInFunctionsProvider = Provider<WalkInFunctions>((ref) {
  final client = ref.watch(functionsClientProvider);
  return WalkInFunctions(client: client);
});
