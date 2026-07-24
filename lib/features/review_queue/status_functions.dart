/// status_functions.dart
/// Dental Clinic Staff/Admin App
///
/// Caller logic for updateAppointmentStatus Cloud Function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/activity_logger_service.dart';
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
  const StatusFunctions({
    required FunctionsClient client,
    required ActivityLoggerService logger,
  })  : _client = client,
        _logger = logger;

  final FunctionsClient _client;
  final ActivityLoggerService _logger;

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

    final res = StatusUpdateResult.fromMap(rawResult);

    if (res.success) {
      final actionName = newStatus == 'confirmed'
          ? 'appointment_confirmed'
          : newStatus == 'cancelled'
              ? 'appointment_cancelled'
              : 'appointment_updated';

      await _logger.logActivity(
        action: actionName,
        resourceId: appointmentId,
        actorRole: 'staff',
        details: {
          'newStatus': newStatus,
          if (cancellationReason != null) 'cancellationReason': cancellationReason,
        },
      );
    }

    return res;
  }
}

// ---------- Provider ----------

final statusFunctionsProvider = Provider<StatusFunctions>((ref) {
  final client = ref.watch(functionsClientProvider);
  final logger = ref.watch(activityLoggerServiceProvider);
  return StatusFunctions(client: client, logger: logger);
});
