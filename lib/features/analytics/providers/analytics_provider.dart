/// analytics_provider.dart
/// Dental Clinic Staff/Admin App
///
/// Riverpod providers for Admin Analytics state management.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/analytics_models.dart';
import '../data/analytics_service.dart';

/// Notifier managing the selected reference date for analytics.
/// Defaults to `null` (evaluates as today / current calendar month).
class AdminAnalyticsDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setDate(DateTime? date) {
    state = date;
  }

  void clearDate() {
    state = null;
  }
}

/// Provider exposing the selected reference date filter for analytics.
final adminAnalyticsDateProvider =
    NotifierProvider<AdminAnalyticsDateNotifier, DateTime?>(
  AdminAnalyticsDateNotifier.new,
);

/// Asynchronously provides [AdminAnalyticsResult] for the admin dashboard.
///
/// Re-evaluates automatically whenever [adminAnalyticsDateProvider] changes.
/// Supports pull-to-refresh / manual reloads via:
/// ```dart
/// ref.refresh(adminAnalyticsProvider);
/// ```
final adminAnalyticsProvider =
    FutureProvider.autoDispose<AdminAnalyticsResult>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final date = ref.watch(adminAnalyticsDateProvider);
  return service.getAdminAnalytics(referenceDate: date);
});
