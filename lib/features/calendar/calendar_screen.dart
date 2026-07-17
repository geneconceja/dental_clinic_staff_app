/// calendar_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Monthly calendar view showing appointment count badges per day.
/// Tapping a day opens a slide-in right panel with that day's appointment list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../review_queue/appointments_repository.dart';
import 'calendar_day_panel.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late int _displayYear;
  late int _displayMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
  }

  void _prevMonth() {
    setState(() {
      if (_displayMonth == 1) {
        _displayMonth = 12;
        _displayYear--;
      } else {
        _displayMonth--;
      }
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      if (_displayMonth == 12) {
        _displayMonth = 1;
        _displayYear++;
      } else {
        _displayMonth++;
      }
      _selectedDay = null;
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _displayYear = now.year;
      _displayMonth = now.month;
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  String get _selectedDayStr {
    if (_selectedDay == null) return '';
    final d = _selectedDay!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthAsync = ref.watch(
      appointmentsByMonthProvider((year: _displayYear, month: _displayMonth)),
    );

    // Build a count map: { "2026-08-05": 3, ... }
    final countMap = monthAsync.when(
      data: (appts) {
        final map = <String, int>{};
        for (final a in appts) {
          map[a.date] = (map[a.date] ?? 0) + 1;
        }
        return map;
      },
      loading: () => <String, int>{},
      error: (_, __) => <String, int>{},
    );

    return Scaffold(
      body: Row(
        children: [
          // ── Calendar Grid ───────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme),
                _buildWeekdayLabels(theme),
                const Divider(height: 1),
                Expanded(
                  child: _buildCalendarGrid(theme, countMap),
                ),
              ],
            ),
          ),

          // ── Day Panel (slide in from right when a day is selected) ──
          if (_selectedDay != null) ...[
            const VerticalDivider(width: 1),
            CalendarDayPanel(
              selectedDay: _selectedDay!,
              dateString: _selectedDayStr,
              onClose: () => setState(() => _selectedDay = null),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Sub-builders ----------

  Widget _buildHeader(ThemeData theme) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      color: AppColors.surface,
      child: Row(
        children: [
          Text(
            '${monthNames[_displayMonth - 1]} $_displayYear',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _goToToday,
            child: const Text('Today'),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            onPressed: _prevMonth,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            onPressed: _nextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: labels.map((label) {
          return Expanded(
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, Map<String, int> countMap) {
    final today = DateTime.now();
    // First day of the month
    final firstDay = DateTime(_displayYear, _displayMonth, 1);
    // Weekday: 1=Mon..7=Sun → offset for Mon-start grid
    final startOffset = firstDay.weekday - 1;
    final daysInMonth = DateTime(_displayYear, _displayMonth + 1, 0).day;
    final totalCells = startOffset + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.4,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: rowCount * 7,
      itemBuilder: (context, index) {
        final dayNum = index - startOffset + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          return const SizedBox.shrink();
        }

        final thisDay = DateTime(_displayYear, _displayMonth, dayNum);
        String pad(int n) => n.toString().padLeft(2, '0');
        final dateStr =
            '$_displayYear-${pad(_displayMonth)}-${pad(dayNum)}';

        final count = countMap[dateStr] ?? 0;
        final isToday = thisDay.year == today.year &&
            thisDay.month == today.month &&
            thisDay.day == today.day;
        final isSelected = _selectedDay?.day == dayNum &&
            _selectedDay?.month == _displayMonth &&
            _selectedDay?.year == _displayYear;

        return _CalendarDayCell(
          day: dayNum,
          appointmentCount: count,
          isToday: isToday,
          isSelected: isSelected,
          onTap: () => setState(() => _selectedDay = thisDay),
        );
      },
    );
  }
}

// ---------- Day Cell Widget ----------

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.appointmentCount,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final int appointmentCount;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.transparent;
    Color dayNumColor = AppColors.textPrimary;
    Border? border;

    if (isSelected) {
      bgColor = AppColors.primary;
      dayNumColor = Colors.white;
    } else if (isToday) {
      border = Border.all(color: AppColors.primary, width: 2);
      dayNumColor = AppColors.primary;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: dayNumColor,
              ),
            ),
            if (appointmentCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$appointmentCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
