/// dashboard_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Daily appointment calendar view. Shows all appointments for the selected
/// date in a chronological timeline list. Staff can navigate day-by-day,
/// filter by appointment status, and tap any tile to open the full detail view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../features/review_queue/appointments_repository.dart';
import '../../routing/app_router.dart';
import 'dashboard_appointment_tile.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedDate = _today();
  AppointmentStatus? _statusFilter; // null = show all

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String get _dateString {
    return '${_selectedDate.year}-'
        '${_selectedDate.month.toString().padLeft(2, '0')}-'
        '${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  void _goToPrevDay() =>
      setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));

  void _goToNextDay() =>
      setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));

  void _goToToday() => setState(() => _selectedDate = _today());

  bool get _isToday => _selectedDate == _today();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointmentsAsync = ref.watch(appointmentsByDateProvider(_dateString));

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────
          _buildHeader(theme),

          // ── Status Filter Chips ──────────────────────────────
          _buildFilterChips(theme),

          const Divider(height: 1),

          // ── Appointment List ─────────────────────────────────
          Expanded(
            child: appointmentsAsync.when(
              data: (appointments) {
                final filtered = _statusFilter == null
                    ? appointments
                    : appointments
                        .where((a) => a.status == _statusFilter)
                        .toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(theme, appointments.isEmpty);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final appt = filtered[i];
                    return DashboardAppointmentTile(
                      appointment: appt,
                      onTap: () => context.goNamed(
                        AppRoutes.appointmentDetail,
                        pathParameters: {'id': appt.id},
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 48),
                      const SizedBox(height: 16),
                      Text('Failed to load appointments',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('$err',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Sub-builders ----------

  Widget _buildHeader(ThemeData theme) {
    final weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final weekday = weekdays[_selectedDate.weekday - 1];
    final month = months[_selectedDate.month - 1];
    final day = _selectedDate.day;
    final year = _selectedDate.year;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      color: AppColors.surface,
      child: Row(
        children: [
          // Date display
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$weekday, $month $day, $year',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_isToday)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Today',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Navigation controls
          Row(
            children: [
              if (!_isToday)
                TextButton(
                  onPressed: _goToToday,
                  child: const Text('Today'),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous day',
                onPressed: _goToPrevDay,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next day',
                onPressed: _goToNextDay,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Pick date'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate =
                        DateTime(picked.year, picked.month, picked.day));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    final filters = <(AppointmentStatus?, String, Color)>[
      (null, 'All', AppColors.textSecondary),
      (AppointmentStatus.pending, 'Pending', AppColors.statusPending),
      (AppointmentStatus.confirmed, 'Confirmed', AppColors.statusConfirmed),
      (AppointmentStatus.completed, 'Completed', AppColors.statusCompleted),
      (AppointmentStatus.cancelled, 'Cancelled', AppColors.statusCancelled),
      (AppointmentStatus.noShow, 'No-Show', AppColors.statusNoShow),
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          // Left: Scrollable filters
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) {
                  final isSelected = _statusFilter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _statusFilter = f.$1),
                      selectedColor: f.$3.withAlpha(30),
                      checkmarkColor: f.$3,
                      labelStyle: TextStyle(
                        color: isSelected ? f.$3 : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: isSelected ? f.$3.withAlpha(80) : AppColors.border,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Gap
          const SizedBox(width: 16),

          // Right: Static "New Walk-In" Button
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('New Walk-In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => context.goNamed(AppRoutes.walkInNew),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool noAppointmentsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                noAppointmentsAtAll
                    ? Icons.event_available_outlined
                    : Icons.filter_list_off,
                size: 48,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              noAppointmentsAtAll
                  ? 'No appointments scheduled'
                  : 'No appointments match this filter',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noAppointmentsAtAll
                  ? 'This day is clear. Use the button below to book a walk-in.'
                  : 'Try selecting a different status filter.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
