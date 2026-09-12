/// appointment_trend_chart.dart
/// Dental Clinic Staff/Admin App — Analytics
///
/// Widget 2: Weekly Appointments Trend & Month Total
/// Bar visualizer showing daily booking counts for the current week (Monday–Sunday)
/// with the current day highlighted, plus month total in the card header.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/analytics_models.dart';

class AppointmentTrendChart extends StatelessWidget {
  const AppointmentTrendChart({
    super.key,
    required this.weeklyTrend,
    required this.monthTotal,
  });

  final List<DailyCount> weeklyTrend;
  final int monthTotal;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final todayStr = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final maxCount = weeklyTrend.isEmpty
        ? 1
        : weeklyTrend.map((d) => d.count).fold<int>(0, math.max);
    final chartCeiling = math.max(maxCount, 5);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.info.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bar_chart_outlined,
                        color: AppColors.info,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Weekly Appointment Trend',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$monthTotal this month',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bar chart area
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final daily = index < weeklyTrend.length
                      ? weeklyTrend[index]
                      : DailyCount(date: '', count: 0);

                  final isToday = daily.date == todayStr;
                  final dayLabel = index < _dayLabels.length ? _dayLabels[index] : '';
                  final count = daily.count;
                  final barFactor = (count / chartCeiling).clamp(0.0, 1.0);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Count badge above bar
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isToday ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // The bar
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutCubic,
                                height: math.max(6.0, barFactor * 90),
                                width: 28,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppColors.primary
                                      : (count > 0
                                          ? AppColors.primaryLight.withAlpha(160)
                                          : AppColors.surfaceVariant),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Day label
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                              color: isToday ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
