/// analytics_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Admin Analytics Dashboard Screen
/// Integrates all 6 analytics widgets with responsive layouts, date filtering,
/// and live refresh capabilities.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import 'providers/analytics_provider.dart';
import 'widgets/appointment_trend_chart.dart';
import 'widgets/no_show_rate_card.dart';
import 'widgets/patient_split_card.dart';
import 'widgets/revenue_card.dart';
import 'widgets/today_appointments_card.dart';
import 'widgets/top_treatments_card.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final analyticsAsync = ref.watch(adminAnalyticsProvider);
    final selectedDate = ref.watch(adminAnalyticsDateProvider);
    final isFilteringDate = selectedDate != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Screen Header ──────────────────────────────────────────────
            _buildHeader(context, ref, theme, isFilteringDate, selectedDate),

            const SizedBox(height: 20),

            // ── Main Body Content ──────────────────────────────────────────
            analyticsAsync.when(
              data: (analytics) => _buildAnalyticsGrid(context, analytics),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      SizedBox(height: 16),
                      Text(
                        'Aggregating clinic analytics...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              error: (err, stack) => _buildErrorState(ref, theme, err),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    bool isFilteringDate,
    DateTime? selectedDate,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Title & subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Clinic Analytics',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Admin Exclusive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Performance overview, patient retention, and revenue intelligence.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          // Actions: Date Picker & Refresh
          Row(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (isFilteringDate) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(adminAnalyticsDateProvider.notifier).clearDate();
                  },
                  icon: const Icon(Icons.today, size: 16),
                  label: const Text('Back to Today'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: AppColors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(adminAnalyticsDateProvider.notifier).setDate(picked);
                  }
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 16),
                label: Text(
                  selectedDate != null
                      ? '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'
                      : 'Filter Date',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  ref.invalidate(adminAnalyticsProvider);
                },
                tooltip: 'Refresh analytics',
                icon: const Icon(Icons.refresh, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceVariant,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsGrid(BuildContext context, dynamic analytics) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1100;

    return Column(
      children: [
        // Top Row: 3 Primary Stat Cards
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TodayAppointmentsCard(todayStats: analytics.today),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: RevenueCard(
                  revenueThisMonth: analytics.revenueThisMonth,
                  weeklyRevenue: analytics.weeklyRevenue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: NoShowRateCard(noShowRate: analytics.noShowRate),
              ),
            ],
          )
        else ...[
          TodayAppointmentsCard(todayStats: analytics.today),
          const SizedBox(height: 16),
          RevenueCard(
            revenueThisMonth: analytics.revenueThisMonth,
            weeklyRevenue: analytics.weeklyRevenue,
          ),
          const SizedBox(height: 16),
          NoShowRateCard(noShowRate: analytics.noShowRate),
        ],

        const SizedBox(height: 16),

        // Bottom Row: Trend Chart, Retention Split, Top Treatments
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: AppointmentTrendChart(
                  weeklyTrend: analytics.weeklyTrend,
                  monthTotal: analytics.monthTotal,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: PatientSplitCard(
                  newPatients: analytics.newPatients,
                  returningPatients: analytics.returningPatients,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: TopTreatmentsCard(
                  topTreatments: analytics.topTreatments,
                ),
              ),
            ],
          )
        else ...[
          AppointmentTrendChart(
            weeklyTrend: analytics.weeklyTrend,
            monthTotal: analytics.monthTotal,
          ),
          const SizedBox(height: 16),
          PatientSplitCard(
            newPatients: analytics.newPatients,
            returningPatients: analytics.returningPatients,
          ),
          const SizedBox(height: 16),
          TopTreatmentsCard(
            topTreatments: analytics.topTreatments,
          ),
        ],
      ],
    );
  }

  Widget _buildErrorState(WidgetRef ref, ThemeData theme, Object err) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ref.invalidate(adminAnalyticsProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
