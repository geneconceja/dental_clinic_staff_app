/// dashboard_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Daily and range-based appointment calendar view. Shows appointments for
/// the selected date or range in a chronological timeline list. Staff can navigate
/// range-by-range (day, week, month), filter by appointment status, and tap any
/// tile to open the full detail view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../features/review_queue/appointments_repository.dart';
import '../../routing/app_router.dart';
import 'dashboard_appointment_tile.dart';

enum _DateRangeMode { today, thisWeek, thisMonth, custom }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedDate = _today();
  _DateRangeMode _dateRangeMode = _DateRangeMode.today;
  DateTimeRange? _customRange;
  AppointmentStatus? _statusFilter; // null = show all

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDate(DateTime d) {
    return '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime get _startDateTime {
    switch (_dateRangeMode) {
      case _DateRangeMode.today:
        return _selectedDate;
      case _DateRangeMode.thisWeek:
        return _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      case _DateRangeMode.thisMonth:
        return DateTime(_selectedDate.year, _selectedDate.month, 1);
      case _DateRangeMode.custom:
        return _customRange?.start ?? _selectedDate;
    }
  }

  DateTime get _endDateTime {
    switch (_dateRangeMode) {
      case _DateRangeMode.today:
        return _selectedDate;
      case _DateRangeMode.thisWeek:
        final monday = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
        return monday.add(const Duration(days: 6));
      case _DateRangeMode.thisMonth:
        return DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
      case _DateRangeMode.custom:
        return _customRange?.end ?? _selectedDate;
    }
  }

  void _goToPrev() {
    setState(() {
      switch (_dateRangeMode) {
        case _DateRangeMode.today:
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
          break;
        case _DateRangeMode.thisWeek:
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
          break;
        case _DateRangeMode.thisMonth:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
          break;
        case _DateRangeMode.custom:
          break;
      }
    });
  }

  void _goToNext() {
    setState(() {
      switch (_dateRangeMode) {
        case _DateRangeMode.today:
          _selectedDate = _selectedDate.add(const Duration(days: 1));
          break;
        case _DateRangeMode.thisWeek:
          _selectedDate = _selectedDate.add(const Duration(days: 7));
          break;
        case _DateRangeMode.thisMonth:
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
          break;
        case _DateRangeMode.custom:
          break;
      }
    });
  }

  void _goToToday() {
    setState(() {
      _selectedDate = _today();
      _dateRangeMode = _DateRangeMode.today;
    });
  }

  bool get _isToday =>
      _dateRangeMode == _DateRangeMode.today && _selectedDate == _today();

  Future<void> _pickCustomRange() async {
    final initialRange = _customRange ??
        DateTimeRange(
          start: _selectedDate,
          end: _selectedDate.add(const Duration(days: 7)),
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: initialRange,
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
      setState(() {
        _customRange = picked;
        _dateRangeMode = _DateRangeMode.custom;
      });
    }
  }

  String _getHeaderTitle() {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    if (_dateRangeMode == _DateRangeMode.today) {
      final weekday = weekdays[_selectedDate.weekday - 1];
      final month = months[_selectedDate.month - 1];
      final day = _selectedDate.day;
      final year = _selectedDate.year;
      return '$weekday, $month $day, $year';
    } else if (_dateRangeMode == _DateRangeMode.thisWeek) {
      final start = _startDateTime;
      final end = _endDateTime;
      return 'Week of ${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${start.year}';
    } else if (_dateRangeMode == _DateRangeMode.thisMonth) {
      return '${months[_selectedDate.month - 1]} ${_selectedDate.year}';
    } else {
      if (_customRange == null) return 'Custom Range';
      final start = _customRange!.start;
      final end = _customRange!.end;
      return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${start.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final startStr = _formatDate(_startDateTime);
    final endStr = _formatDate(_endDateTime);

    final appointmentsAsync = ref.watch(
      appointmentsByDateRangeProvider((start: startStr, end: endStr)),
    );

    final appointmentsCount = appointmentsAsync.asData?.value.length ?? 0;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────
          _buildHeader(theme, appointmentsCount),

          // ── Date Range Choice Chips ────────────────────────
          _buildDateRangeChips(theme),

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

                final showDate = _dateRangeMode != _DateRangeMode.today;

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final appt = filtered[i];
                    return DashboardAppointmentTile(
                      appointment: appt,
                      showDate: showDate,
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

  Widget _buildHeader(ThemeData theme, int totalCount) {
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
                  _getHeaderTitle(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_isToday) ...[
                      Text(
                        'Today',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.textDisabled,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (totalCount > 0)
                      Text(
                        '$totalCount appointment${totalCount == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
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
              if (_dateRangeMode != _DateRangeMode.custom) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: _dateRangeMode == _DateRangeMode.today
                      ? 'Previous day'
                      : _dateRangeMode == _DateRangeMode.thisWeek
                          ? 'Previous week'
                          : 'Previous month',
                  onPressed: _goToPrev,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: _dateRangeMode == _DateRangeMode.today
                      ? 'Next day'
                      : _dateRangeMode == _DateRangeMode.thisWeek
                          ? 'Next week'
                          : 'Next month',
                  onPressed: _goToNext,
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(_dateRangeMode == _DateRangeMode.custom
                    ? 'Change Range'
                    : 'Pick Date'),
                onPressed: () async {
                  if (_dateRangeMode == _DateRangeMode.custom) {
                    await _pickCustomRange();
                  } else {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate =
                            DateTime(picked.year, picked.month, picked.day);
                        _dateRangeMode = _DateRangeMode.today;
                      });
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChips(ThemeData theme) {
    final modes = <(_DateRangeMode, String)>[
      (_DateRangeMode.today, 'Today'),
      (_DateRangeMode.thisWeek, 'This Week'),
      (_DateRangeMode.thisMonth, 'This Month'),
      (_DateRangeMode.custom, 'Custom Range'),
    ];

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: modes.map((m) {
            final isSelected = _dateRangeMode == m.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(m.$2),
                selected: isSelected,
                onSelected: (selected) async {
                  if (selected) {
                    if (m.$1 == _DateRangeMode.custom) {
                      await _pickCustomRange();
                    } else {
                      setState(() {
                        _dateRangeMode = m.$1;
                      });
                    }
                  }
                },
                selectedColor: AppColors.primary.withAlpha(30),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
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
              decoration: const BoxDecoration(
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
                  ? 'This range is clear. Use the button below to book a walk-in.'
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
