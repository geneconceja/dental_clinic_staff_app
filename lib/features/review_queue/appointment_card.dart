/// appointment_card.dart
/// Dental Clinic Staff/Admin App
///
/// Premium card component representing a pending appointment request.
/// Displays patient metadata, requested times, and key action buttons.
library;

import 'package:flutter/material.dart';
import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_formatter.dart';

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onConfirm,
    required this.onReview,
  });

  final Appointment appointment;
  final VoidCallback onConfirm;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = appointment.imageUrl != null;

    // Formatting date helper: "Tuesday, Sep 1"
    final dateFormatted = _formatFriendlyDate(appointment.appointmentDateTime);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onReview,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top row: Date & Time + Status Chip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$dateFormatted • ${format12Hour(appointment.startTime)} - ${format12Hour(appointment.endTime)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    _StatusChip(status: appointment.status),
                  ],
                ),
                const SizedBox(height: 16),

                // Patient Name & Service Type
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.patientFullName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            appointment.phoneNumber,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Service tag chip
                    Chip(
                      label: Text(appointment.serviceName),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Attached image thumbnail indicator if present
                if (hasImage) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.info.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_outlined, size: 16, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Patient attached an image for diagnostic review',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: onReview,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Review'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFriendlyDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

    final weekday = weekdays[dt.weekday % 7];
    final month = months[dt.month - 1];
    return '$weekday, $month ${dt.day}';
  }
}

// ---------- Private Status Chip ----------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      AppointmentStatus.pending => (AppColors.statusPending, AppColors.warningLight, 'Pending'),
      AppointmentStatus.confirmed => (AppColors.statusConfirmed, AppColors.successLight, 'Confirmed'),
      AppointmentStatus.cancelled => (AppColors.statusCancelled, AppColors.errorLight, 'Cancelled'),
      AppointmentStatus.completed => (AppColors.statusCompleted, AppColors.infoLight, 'Completed'),
      AppointmentStatus.noShow => (AppColors.statusNoShow, AppColors.surfaceVariant, 'No-Show'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.$2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.$1.withAlpha(40)),
      ),
      child: Text(
        config.$3,
        style: TextStyle(
          color: config.$1,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
