/// analytics_models.dart
/// Dental Clinic Staff/Admin App
///
/// Data models representing metrics computed by the getAdminAnalytics Cloud Function.
library;

import 'package:flutter/foundation.dart';

@immutable
class TodayStats {
  const TodayStats({
    required this.total,
    required this.upcoming,
    required this.completed,
    required this.noShow,
    required this.cancelled,
  });

  final int total;
  final int upcoming;
  final int completed;
  final int noShow;
  final int cancelled;

  factory TodayStats.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const TodayStats(
        total: 0,
        upcoming: 0,
        completed: 0,
        noShow: 0,
        cancelled: 0,
      );
    }
    return TodayStats(
      total: (map['total'] as num?)?.toInt() ?? 0,
      upcoming: (map['upcoming'] as num?)?.toInt() ?? 0,
      completed: (map['completed'] as num?)?.toInt() ?? 0,
      noShow: (map['noShow'] as num?)?.toInt() ?? 0,
      cancelled: (map['cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'total': total,
        'upcoming': upcoming,
        'completed': completed,
        'noShow': noShow,
        'cancelled': cancelled,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodayStats &&
          runtimeType == other.runtimeType &&
          total == other.total &&
          upcoming == other.upcoming &&
          completed == other.completed &&
          noShow == other.noShow &&
          cancelled == other.cancelled;

  @override
  int get hashCode => Object.hash(total, upcoming, completed, noShow, cancelled);
}

@immutable
class DailyCount {
  const DailyCount({
    required this.date,
    required this.count,
  });

  final String date;
  final int count;

  factory DailyCount.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DailyCount(date: '', count: 0);
    }
    return DailyCount(
      date: (map['date'] as String?) ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'count': count,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCount &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          count == other.count;

  @override
  int get hashCode => Object.hash(date, count);
}

@immutable
class WeeklyRevenue {
  const WeeklyRevenue({
    required this.weekLabel,
    required this.revenue,
  });

  final String weekLabel;
  final double revenue;

  factory WeeklyRevenue.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const WeeklyRevenue(weekLabel: '', revenue: 0.0);
    }
    return WeeklyRevenue(
      weekLabel: (map['weekLabel'] as String?) ?? '',
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'weekLabel': weekLabel,
        'revenue': revenue,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklyRevenue &&
          runtimeType == other.runtimeType &&
          weekLabel == other.weekLabel &&
          revenue == other.revenue;

  @override
  int get hashCode => Object.hash(weekLabel, revenue);
}

@immutable
class TreatmentCount {
  const TreatmentCount({
    required this.serviceName,
    required this.count,
  });

  final String serviceName;
  final int count;

  factory TreatmentCount.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const TreatmentCount(serviceName: '', count: 0);
    }
    return TreatmentCount(
      serviceName: (map['serviceName'] as String?) ?? '',
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'serviceName': serviceName,
        'count': count,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreatmentCount &&
          runtimeType == other.runtimeType &&
          serviceName == other.serviceName &&
          count == other.count;

  @override
  int get hashCode => Object.hash(serviceName, count);
}

@immutable
class AdminAnalyticsResult {
  const AdminAnalyticsResult({
    required this.today,
    required this.weeklyTrend,
    required this.monthTotal,
    required this.noShowRate,
    required this.newPatients,
    required this.returningPatients,
    required this.revenueThisMonth,
    required this.weeklyRevenue,
    required this.topTreatments,
    required this.computedAt,
  });

  /// Metric 1: Today's appointment counts and status breakdown
  final TodayStats today;

  /// Metric 2: Daily counts for the current week (Monday–Sunday)
  final List<DailyCount> weeklyTrend;

  /// Metric 2: Total appointments booked for the current month
  final int monthTotal;

  /// Metric 3: Percentage (0–100) of finalised appointments marked as no-show
  final double noShowRate;

  /// Metric 4: Count of first-time visits completed this month
  final int newPatients;

  /// Metric 4: Count of returning patient visits completed this month
  final int returningPatients;

  /// Metric 5: Total clinic revenue generated this month (PHP)
  final double revenueThisMonth;

  /// Metric 5: Breakdown of revenue by week
  final List<WeeklyRevenue> weeklyRevenue;

  /// Metric 6: Top services sorted by booking count
  final List<TreatmentCount> topTreatments;

  /// Timestamp when analytics were computed
  final DateTime computedAt;

  factory AdminAnalyticsResult.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return AdminAnalyticsResult(
        today: const TodayStats(total: 0, upcoming: 0, completed: 0, noShow: 0, cancelled: 0),
        weeklyTrend: const [],
        monthTotal: 0,
        noShowRate: 0.0,
        newPatients: 0,
        returningPatients: 0,
        revenueThisMonth: 0.0,
        weeklyRevenue: const [],
        topTreatments: const [],
        computedAt: DateTime.now(),
      );
    }

    final rawToday = map['today'];
    final rawWeeklyTrend = map['weeklyTrend'] as List<dynamic>? ?? [];
    final rawWeeklyRevenue = map['weeklyRevenue'] as List<dynamic>? ?? [];
    final rawTopTreatments = map['topTreatments'] as List<dynamic>? ?? [];

    DateTime parsedComputedAt;
    if (map['computedAt'] is String) {
      parsedComputedAt = DateTime.tryParse(map['computedAt'] as String) ?? DateTime.now();
    } else {
      parsedComputedAt = DateTime.now();
    }

    return AdminAnalyticsResult(
      today: TodayStats.fromMap(
        rawToday is Map ? Map<String, dynamic>.from(rawToday) : null,
      ),
      weeklyTrend: rawWeeklyTrend
          .whereType<Map>()
          .map((item) => DailyCount.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      monthTotal: (map['monthTotal'] as num?)?.toInt() ?? 0,
      noShowRate: (map['noShowRate'] as num?)?.toDouble() ?? 0.0,
      newPatients: (map['newPatients'] as num?)?.toInt() ?? 0,
      returningPatients: (map['returningPatients'] as num?)?.toInt() ?? 0,
      revenueThisMonth: (map['revenueThisMonth'] as num?)?.toDouble() ?? 0.0,
      weeklyRevenue: rawWeeklyRevenue
          .whereType<Map>()
          .map((item) => WeeklyRevenue.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      topTreatments: rawTopTreatments
          .whereType<Map>()
          .map((item) => TreatmentCount.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      computedAt: parsedComputedAt,
    );
  }
}
