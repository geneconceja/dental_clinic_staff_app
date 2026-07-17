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
        // The Cloud Function extracts startTime via getUTCHours()/getUTCMinutes(),
        // so we must send the local wall-clock time as if it were UTC (no offset shift).
        // Sending .toUtc() would subtract the local offset (e.g. +08:00 → -8 hours),
        // causing the stored startTime to be 8 hours behind the selected slot.
        'appointmentDateTime': _localAsUtcIso(appointmentDateTime),
        if (notes != null) 'notes': notes,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );

    return WalkInAppointmentResult.fromMap(rawResult);
  }

  /// Formats [dt] as a UTC-style ISO 8601 string using the local wall-clock
  /// hours and minutes — WITHOUT converting to UTC.
  ///
  /// The Cloud Function reads startTime via `getUTCHours()`/`getUTCMinutes()`,
  /// so the payload must represent local time in the Z/UTC slot. Using
  /// [DateTime.toUtc] would subtract the local offset (e.g. 15:00 +08:00
  /// becomes 07:00Z), causing the stored startTime to be 8 hours wrong.
  static String _localAsUtcIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-${d}T$h:$mi:00.000Z';
  }
}

// ---------- Provider ----------

final walkInFunctionsProvider = Provider<WalkInFunctions>((ref) {
  final client = ref.watch(functionsClientProvider);
  return WalkInFunctions(client: client);
});
