/// dashboard_appointment_tile.dart
/// Dental Clinic Staff/Admin App
///
/// Premium timeline-style tile for displaying a single appointment on the
/// Dashboard. Shows time slot, patient name, service, booking source badge,
/// and a color-coded status indicator bar on the leading edge.
library;

import 'package:flutter/material.dart';
import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_formatter.dart';

class DashboardAppointmentTile extends StatelessWidget {
  const DashboardAppointmentTile({
    super.key,
    required this.appointment,
    required this.onTap,
    this.showDate = false,
  });

  final Appointment appointment;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(appointment.status);
    final statusLabel = _statusLabel(appointment.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left status color bar
                Container(
                  width: 5,
                  color: statusColor,
                ),

                // Time column
                Container(
                  width: 76,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  color: AppColors.surfaceVariant,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (showDate) ...[
                        Text(
                          '${_monthAbbr(appointment.appointmentDateTime.month)} ${appointment.appointmentDateTime.day}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        format12Hour(appointment.startTime),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 11, // adjust size to fit AM/PM nicely
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        format12Hour(appointment.endTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                appointment.patientFullName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                appointment.serviceName.isNotEmpty
                                    ? appointment.serviceName
                                    : appointment.reason,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _SourceBadge(
                                      source: appointment.bookingSource),
                                  if (appointment.paid) ...[
                                    const SizedBox(width: 6),
                                    _PaidBadge(),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Status chip
                        _StatusPill(
                          label: statusLabel,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors.textDisabled,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => AppColors.statusPending,
      AppointmentStatus.confirmed => AppColors.statusConfirmed,
      AppointmentStatus.cancelled => AppColors.statusCancelled,
      AppointmentStatus.completed => AppColors.statusCompleted,
      AppointmentStatus.noShow => AppColors.statusNoShow,
    };
  }

  String _statusLabel(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => 'Pending',
      AppointmentStatus.confirmed => 'Confirmed',
      AppointmentStatus.cancelled => 'Cancelled',
      AppointmentStatus.completed => 'Completed',
      AppointmentStatus.noShow => 'No-Show',
    };
  }

  String _monthAbbr(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month < 1 || month > 12) return '';
    return months[month];
  }
}

// ---------- Private sub-widgets ----------

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});
  final BookingSource source;

  @override
  Widget build(BuildContext context) {
    final isWalkIn = source == BookingSource.staffWalkin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isWalkIn
            ? AppColors.accent.withAlpha(25)
            : AppColors.info.withAlpha(18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isWalkIn ? 'Walk-In' : 'Patient App',
        style: TextStyle(
          color: isWalkIn ? AppColors.accent : AppColors.info,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Paid',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
