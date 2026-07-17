/// status_functions.dart
/// Dental Clinic Staff/Admin App
///
/// Caller logic for updateAppointmentStatus Cloud Function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/functions_client.dart';

class StatusUpdateResult {
  const StatusUpdateResult({
    required this.success,
    required this.appointmentId,
    required this.newStatus,
  });

  final bool success;
  final String appointmentId;
  final String newStatus;

  factory StatusUpdateResult.fromMap(Map<String, dynamic> map) {
    return StatusUpdateResult(
      success: (map['success'] as bool?) ?? false,
      appointmentId: (map['appointmentId'] as String?) ?? '',
      newStatus: (map['newStatus'] as String?) ?? '',
    );
  }
}

class StatusFunctions {
  const StatusFunctions({required FunctionsClient client}) : _client = client;

  final FunctionsClient _client;

  /// Invokes the updateAppointmentStatus callable Cloud Function.
  /// Throws typed [FunctionsException] subclasses on backend errors.
  Future<StatusUpdateResult> updateStatus({
    required String appointmentId,
    required String newStatus,
    String? cancellationReason,
  }) async {
    final Map<String, dynamic> rawResult = await _client.call(
      functionName: 'updateAppointmentStatus',
      data: {
        'appointmentId': appointmentId,
        'newStatus': newStatus,
        if (cancellationReason != null) 'cancellationReason': cancellationReason,
      },
    );

    return StatusUpdateResult.fromMap(rawResult);
  }
}

// ---------- Provider ----------

final statusFunctionsProvider = Provider<StatusFunctions>((ref) {
  final client = ref.watch(functionsClientProvider);
  return StatusFunctions(client: client);
});
