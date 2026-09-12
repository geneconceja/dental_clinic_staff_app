/// analytics_service.dart
/// Dental Clinic Staff/Admin App
///
/// Service layer for calling the getAdminAnalytics Cloud Function.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/functions_client.dart';
import 'analytics_models.dart';

class AnalyticsService {
  const AnalyticsService({required FunctionsClient client}) : _client = client;

  final FunctionsClient _client;

  /// Calls the `getAdminAnalytics` callable Cloud Function.
  ///
  /// [referenceDate] optionally overrides the reference date (e.g. for testing
  /// or historic dashboard views). Must be passed as YYYY-MM-DD.
  ///
  /// Throws typed [FunctionsException] subclasses on backend failures (such as
  /// [PermissionDeniedException] if caller is not an admin).
  Future<AdminAnalyticsResult> getAdminAnalytics({DateTime? referenceDate}) async {
    final Map<String, dynamic> payload = {};

    if (referenceDate != null) {
      final year = referenceDate.year.toString().padLeft(4, '0');
      final month = referenceDate.month.toString().padLeft(2, '0');
      final day = referenceDate.day.toString().padLeft(2, '0');
      payload['referenceDate'] = '$year-$month-$day';
    }

    debugPrint('[AnalyticsService] Invoking getAdminAnalytics (payload: $payload)');

    final dynamic rawResult = await _client.call(
      functionName: 'getAdminAnalytics',
      data: payload.isEmpty ? null : payload,
    );

    if (rawResult is Map) {
      return AdminAnalyticsResult.fromMap(Map<String, dynamic>.from(rawResult));
    }

    debugPrint('[AnalyticsService] Unexpected response format: $rawResult');
    return AdminAnalyticsResult.fromMap(null);
  }
}

// ---------- Riverpod Provider ----------

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final client = ref.watch(functionsClientProvider);
  return AnalyticsService(client: client);
});
