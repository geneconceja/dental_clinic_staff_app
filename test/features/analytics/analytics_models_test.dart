import 'package:flutter_test/flutter_test.dart';
import 'package:dental_clinic_staff_app/features/analytics/data/analytics_models.dart';

void main() {
  group('TodayStats.fromMap', () {
    test('handles null safely with zero defaults', () {
      final stats = TodayStats.fromMap(null);
      expect(stats.total, 0);
      expect(stats.upcoming, 0);
      expect(stats.completed, 0);
      expect(stats.noShow, 0);
      expect(stats.cancelled, 0);
    });

    test('deserializes valid numbers correctly', () {
      final stats = TodayStats.fromMap({
        'total': 10,
        'upcoming': 4,
        'completed': 3,
        'noShow': 2,
        'cancelled': 1,
      });
      expect(stats.total, 10);
      expect(stats.upcoming, 4);
      expect(stats.completed, 3);
      expect(stats.noShow, 2);
      expect(stats.cancelled, 1);
    });
  });

  group('DailyCount.fromMap', () {
    test('handles null safely', () {
      final daily = DailyCount.fromMap(null);
      expect(daily.date, '');
      expect(daily.count, 0);
    });

    test('deserializes fields correctly', () {
      final daily = DailyCount.fromMap({'date': '2026-09-12', 'count': 5});
      expect(daily.date, '2026-09-12');
      expect(daily.count, 5);
    });
  });

  group('WeeklyRevenue.fromMap', () {
    test('handles null safely', () {
      final rev = WeeklyRevenue.fromMap(null);
      expect(rev.weekLabel, '');
      expect(rev.revenue, 0.0);
    });

    test('coerces int to double revenue', () {
      final rev = WeeklyRevenue.fromMap({'weekLabel': 'Week 1', 'revenue': 1500});
      expect(rev.weekLabel, 'Week 1');
      expect(rev.revenue, 1500.0);
    });
  });

  group('TreatmentCount.fromMap', () {
    test('handles null safely', () {
      final treat = TreatmentCount.fromMap(null);
      expect(treat.serviceName, '');
      expect(treat.count, 0);
    });

    test('deserializes correctly', () {
      final treat = TreatmentCount.fromMap({'serviceName': 'Cleaning', 'count': 8});
      expect(treat.serviceName, 'Cleaning');
      expect(treat.count, 8);
    });
  });

  group('AdminAnalyticsResult.fromMap', () {
    test('handles null map with safe defaults', () {
      final result = AdminAnalyticsResult.fromMap(null);
      expect(result.today.total, 0);
      expect(result.weeklyTrend, isEmpty);
      expect(result.monthTotal, 0);
      expect(result.noShowRate, 0.0);
      expect(result.newPatients, 0);
      expect(result.returningPatients, 0);
      expect(result.revenueThisMonth, 0.0);
      expect(result.weeklyRevenue, isEmpty);
      expect(result.topTreatments, isEmpty);
    });

    test('deserializes full payload from Cloud Function accurately', () {
      final payload = {
        'today': {
          'total': 12,
          'upcoming': 6,
          'completed': 4,
          'noShow': 1,
          'cancelled': 1,
        },
        'weeklyTrend': [
          {'date': '2026-09-07', 'count': 2},
          {'date': '2026-09-08', 'count': 3},
          {'date': '2026-09-09', 'count': 1},
          {'date': '2026-09-10', 'count': 4},
          {'date': '2026-09-11', 'count': 5},
          {'date': '2026-09-12', 'count': 2},
          {'date': '2026-09-13', 'count': 0},
        ],
        'monthTotal': 45,
        'noShowRate': 8.5,
        'newPatients': 14,
        'returningPatients': 21,
        'revenueThisMonth': 35000,
        'weeklyRevenue': [
          {'weekLabel': 'Week 1', 'revenue': 12000},
          {'weekLabel': 'Week 2', 'revenue': 23000},
        ],
        'topTreatments': [
          {'serviceName': 'Dental Cleaning', 'count': 20},
          {'serviceName': 'Tooth Extraction', 'count': 15},
        ],
        'computedAt': '2026-09-12T10:30:00.000Z',
      };

      final result = AdminAnalyticsResult.fromMap(payload);

      expect(result.today.total, 12);
      expect(result.today.upcoming, 6);
      expect(result.weeklyTrend.length, 7);
      expect(result.weeklyTrend[0].date, '2026-09-07');
      expect(result.weeklyTrend[0].count, 2);
      expect(result.monthTotal, 45);
      expect(result.noShowRate, 8.5);
      expect(result.newPatients, 14);
      expect(result.returningPatients, 21);
      expect(result.revenueThisMonth, 35000.0);
      expect(result.weeklyRevenue.length, 2);
      expect(result.weeklyRevenue[0].weekLabel, 'Week 1');
      expect(result.weeklyRevenue[0].revenue, 12000.0);
      expect(result.topTreatments.length, 2);
      expect(result.topTreatments[0].serviceName, 'Dental Cleaning');
      expect(result.topTreatments[0].count, 20);
      expect(result.computedAt.year, 2026);
      expect(result.computedAt.month, 9);
      expect(result.computedAt.day, 12);
    });
  });
}
