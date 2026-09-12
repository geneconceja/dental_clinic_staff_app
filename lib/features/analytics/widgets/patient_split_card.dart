/// patient_split_card.dart
/// Dental Clinic Staff/Admin App — Analytics
///
/// Widget 4: New vs Returning Patients
/// Shows the split of first-time clinic visitors versus returning patients
/// among completed appointments with a proportional progress bar and counts.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class PatientSplitCard extends StatelessWidget {
  const PatientSplitCard({
    super.key,
    required this.newPatients,
    required this.returningPatients,
  });

  final int newPatients;
  final int returningPatients;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = newPatients + returningPatients;
    final newPercent = total > 0 ? (newPatients / total * 100).round() : 0;
    final returningPercent = total > 0 ? 100 - newPercent : 0;

    final newFlex = total > 0 ? newPatients : 1;
    final returningFlex = total > 0 ? returningPatients : 1;

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
                        color: AppColors.accent.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.people_outline,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Patient Retention & Growth',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$total completed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Segmented split bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 12,
                child: total == 0
                    ? Container(color: AppColors.surfaceVariant)
                    : Row(
                        children: [
                          if (newPatients > 0)
                            Expanded(
                              flex: newFlex,
                              child: Container(color: AppColors.primary),
                            ),
                          if (returningPatients > 0)
                            Expanded(
                              flex: returningFlex,
                              child: Container(color: AppColors.accent),
                            ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Stat columns
            Row(
              children: [
                Expanded(
                  child: _SegmentStat(
                    label: 'New Patients',
                    count: newPatients,
                    percent: newPercent,
                    color: AppColors.primary,
                    icon: Icons.person_add_alt_1_outlined,
                  ),
                ),
                Container(
                  height: 36,
                  width: 1,
                  color: AppColors.border,
                ),
                Expanded(
                  child: _SegmentStat(
                    label: 'Returning',
                    count: returningPatients,
                    percent: returningPercent,
                    color: AppColors.accent,
                    icon: Icons.repeat_outlined,
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

class _SegmentStat extends StatelessWidget {
  const _SegmentStat({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final int percent;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($percent%)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
