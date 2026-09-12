/// no_show_rate_card.dart
/// Dental Clinic Staff/Admin App — Analytics
///
/// Widget 3: No-Show Rate Card
/// Visual circular gauge displaying the clinic's monthly no-show percentage,
/// with dynamic color-coding based on clinic threshold benchmarks.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class NoShowRateCard extends StatelessWidget {
  const NoShowRateCard({
    super.key,
    required this.noShowRate,
  });

  final double noShowRate;

  Color _indicatorColor() {
    if (noShowRate <= 5.0) return AppColors.success;
    if (noShowRate <= 15.0) return AppColors.warning;
    return AppColors.error;
  }

  String _ratingLabel() {
    if (noShowRate <= 5.0) return 'Optimal (< 5%)';
    if (noShowRate <= 15.0) return 'Moderate (5%–15%)';
    return 'Attention (> 15%)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _indicatorColor();
    final progress = (noShowRate / 100.0).clamp(0.0, 1.0);

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        color: AppColors.statusNoShow.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person_off_outlined,
                        color: AppColors.statusNoShow,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'No-Show Rate',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withAlpha(50)),
                  ),
                  child: Text(
                    _ratingLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Middle: Circular progress with center percentage text
            Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 76,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.surfaceVariant,
                        color: color,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          '${noShowRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Attendance',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Calculated from finalised visits (completed, no-show, cancelled).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
