/// calendar_day_panel.dart
/// Dental Clinic Staff/Admin App
///
/// A fixed right-side panel that shows all appointments for a selected
/// calendar day. Slides in alongside the monthly calendar grid.
/// Tapping an appointment navigates to the appointment detail screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_formatter.dart';
import '../../routing/app_router.dart';
import '../review_queue/appointments_repository.dart';

class CalendarDayPanel extends ConsumerWidget {
  const CalendarDayPanel({
    super.key,
    required this.selectedDay,
    required this.dateString,
    required this.onClose,
  });

  final DateTime selectedDay;
  final String dateString;   // "YYYY-MM-DD"
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final apptAsync = ref.watch(appointmentsByDateProvider(dateString));

    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final weekday = weekdays[selectedDay.weekday - 1];
    final month = months[selectedDay.month - 1];

    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Panel Header ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$weekday, $month ${selectedDay.day}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      apptAsync.when(
                        data: (appts) => Text(
                          appts.isEmpty
                              ? 'No appointments'
                              : '${appts.length} appointment${appts.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: 'Close panel',
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Appointment List ───────────────────────────────────
          Expanded(
            child: apptAsync.when(
              data: (appts) {
                if (appts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_available_outlined,
                            size: 48,
                            color: AppColors.textDisabled,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No appointments',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This day has no scheduled appointments.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textDisabled,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: appts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _AppointmentPanelTile(appointment: appts[i]),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load appointments.\n$err',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Individual tile inside the panel ----------

class _AppointmentPanelTile extends StatelessWidget {
  const _AppointmentPanelTile({required this.appointment});

  final Appointment appointment;

  Color _statusColor(AppointmentStatus s) => switch (s) {
        AppointmentStatus.pending => AppColors.statusPending,
        AppointmentStatus.confirmed => AppColors.statusConfirmed,
        AppointmentStatus.cancelled => AppColors.statusCancelled,
        AppointmentStatus.completed => AppColors.statusCompleted,
        AppointmentStatus.noShow => AppColors.statusNoShow,
      };

  String _statusLabel(AppointmentStatus s) => switch (s) {
        AppointmentStatus.pending => 'Pending',
        AppointmentStatus.confirmed => 'Confirmed',
        AppointmentStatus.cancelled => 'Cancelled',
        AppointmentStatus.completed => 'Completed',
        AppointmentStatus.noShow => 'No-Show',
      };

  @override
  Widget build(BuildContext context) {
    final appt = appointment;
    final statusColor = _statusColor(appt.status);
    final timeStr =
        '${format12Hour(appt.startTime)} – ${format12Hour(appt.endTime)}';
    final isWalkIn = appt.bookingSource == BookingSource.staffWalkin;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.goNamed(
          AppRoutes.appointmentDetail,
          pathParameters: {'id': appt.id},
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: statusColor, width: 3),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + time
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appt.patientFullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Service name
              Text(
                appt.serviceName.isNotEmpty ? appt.serviceName : appt.reason,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Status + booking source chips
              Row(
                children: [
                  _SmallChip(
                    label: _statusLabel(appt.status),
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  _SmallChip(
                    label: isWalkIn ? 'Walk-In' : 'Patient App',
                    color: isWalkIn
                        ? AppColors.accent
                        : AppColors.info,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
