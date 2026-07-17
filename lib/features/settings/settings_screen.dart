/// settings_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Administrative interface for clinic settings.
/// Allows admins to update clinic contact info, appointment slot durations,
/// weekly operating hours (open/close times + open days), and holidays.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/clinic_settings.dart';
import '../../core/theme/app_colors.dart';
import 'clinic_settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Clinic metadata controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  // Configuration values
  int _slotDuration = 30;
  int _reminderHours = 24;

  // Local mutable copies of working hours and holidays
  late WorkingHours _workingHours;
  final List<String> _holidays = [];

  bool _isInitialized = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _initialize(ClinicSettings settings) {
    if (_isInitialized) return;
    _nameCtrl.text = settings.clinicName;
    _phoneCtrl.text = settings.clinicPhone;
    _addressCtrl.text = settings.clinicAddress;
    _slotDuration = settings.slotDurationMinutes;
    _reminderHours = settings.reminderHoursBefore;
    _workingHours = settings.workingHours;
    _holidays.clear();
    _holidays.addAll(settings.holidays);
    _holidays.sort();
    _isInitialized = true;
  }

  Future<void> _selectTime(
      BuildContext context, DailyHours current, bool isOpen,
      {required bool isOpenTime, required Function(String) onSelected}) async {
    if (!isOpen) return;

    final initialTimeStr = isOpenTime ? current.open : current.close;
    var initialTime = const TimeOfDay(hour: 9, minute: 0);

    if (initialTimeStr != null) {
      final parts = initialTimeStr.split(':');
      if (parts.length >= 2) {
        initialTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onSelected(formatted);
    }
  }

  Future<void> _addHoliday(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final dateStr =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      if (!_holidays.contains(dateStr)) {
        setState(() {
          _holidays.add(dateStr);
          _holidays.sort();
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final settings = ClinicSettings(
        slotDurationMinutes: _slotDuration,
        workingHours: _workingHours,
        holidays: _holidays,
        reminderHoursBefore: _reminderHours,
        clinicName: _nameCtrl.text.trim(),
        clinicPhone: _phoneCtrl.text.trim(),
        clinicAddress: _addressCtrl.text.trim(),
      );

      await ref
          .read(clinicSettingsRepositoryProvider)
          .updateClinicSettings(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(clinicSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Settings'),
        actions: [
          if (_isInitialized)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaving ? null : _save,
              ),
            ),
        ],
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (settings == null) {
            return const Center(
              child: Text('Clinic settings document not found.',
                  style: TextStyle(color: AppColors.error)),
            );
          }

          _initialize(settings);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // General Card
                      _buildGeneralCard(theme),
                      const SizedBox(height: 20),

                      // Working Hours Card
                      _buildWorkingHoursCard(theme),
                      const SizedBox(height: 20),

                      // Holidays Card
                      _buildHolidaysCard(theme),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading settings: $err',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  // ---------- Section Card Builders ----------

  Widget _buildGeneralCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clinic Metadata & Configurations',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Clinic Name *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Clinic Phone *',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Clinic Address *',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Slot Duration Dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _slotDuration,
                    decoration: const InputDecoration(
                      labelText: 'Slot Duration (Mins) *',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                      DropdownMenuItem(value: 20, child: Text('20 Minutes')),
                      DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                      DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                    ],
                    onChanged: (val) => setState(() => _slotDuration = val ?? 30),
                  ),
                ),
                const SizedBox(width: 20),
                // Reminder Hours Dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _reminderHours,
                    decoration: const InputDecoration(
                      labelText: 'Send Reminders before *',
                      prefixIcon: Icon(Icons.notifications_active_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 12, child: Text('12 Hours Before')),
                      DropdownMenuItem(value: 24, child: Text('24 Hours Before')),
                      DropdownMenuItem(value: 48, child: Text('48 Hours Before')),
                    ],
                    onChanged: (val) => setState(() => _reminderHours = val ?? 24),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weekly Operating Hours',
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(
              'Define clinic open days and appointment slot start/end boundaries.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _buildDayRow('Monday', _workingHours.monday, (dayHours) {
              _workingHours = _workingHours.copyWith(monday: dayHours);
            }),
            _buildDayRow('Tuesday', _workingHours.tuesday, (dayHours) {
              _workingHours = _workingHours.copyWith(tuesday: dayHours);
            }),
            _buildDayRow('Wednesday', _workingHours.wednesday, (dayHours) {
              _workingHours = _workingHours.copyWith(wednesday: dayHours);
            }),
            _buildDayRow('Thursday', _workingHours.thursday, (dayHours) {
              _workingHours = _workingHours.copyWith(thursday: dayHours);
            }),
            _buildDayRow('Friday', _workingHours.friday, (dayHours) {
              _workingHours = _workingHours.copyWith(friday: dayHours);
            }),
            _buildDayRow('Saturday', _workingHours.saturday, (dayHours) {
              _workingHours = _workingHours.copyWith(saturday: dayHours);
            }),
            _buildDayRow('Sunday', _workingHours.sunday, (dayHours) {
              _workingHours = _workingHours.copyWith(sunday: dayHours);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(String label, DailyHours hours, Function(DailyHours) onUpdated) {
    final isOpen = hours.isOpen;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Day name + Open Toggle Switch
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Switch(
                  value: isOpen,
                  activeTrackColor: AppColors.primary.withAlpha(120),
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) {
                    onUpdated(DailyHours(
                      open: val ? '09:00' : null,
                      close: val ? '17:00' : null,
                      isOpen: val,
                    ));
                    setState(() {});
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Working times selector
          if (isOpen) ...[
            TextButton.icon(
              icon: const Icon(Icons.access_time, size: 16),
              label: Text('Open: ${hours.open ?? "09:00"}'),
              onPressed: () => _selectTime(context, hours, isOpen,
                  isOpenTime: true, onSelected: (time) {
                onUpdated(DailyHours(
                  open: time,
                  close: hours.close,
                  isOpen: isOpen,
                ));
                setState(() {});
              }),
            ),
            const SizedBox(width: 12),
            const Text('to'),
            const SizedBox(width: 12),
            TextButton.icon(
              icon: const Icon(Icons.access_time, size: 16),
              label: Text('Close: ${hours.close ?? "17:00"}'),
              onPressed: () => _selectTime(context, hours, isOpen,
                  isOpenTime: false, onSelected: (time) {
                onUpdated(DailyHours(
                  open: hours.open,
                  close: time,
                  isOpen: isOpen,
                ));
                setState(() {});
              }),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'Closed',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHolidaysCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clinic Holidays',
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(
                      'Select days when the clinic is completely closed.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Holiday'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                  ),
                  onPressed: () => _addHoliday(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chips List
            _holidays.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No holidays defined.',
                      style: TextStyle(
                        color: AppColors.textDisabled,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _holidays.map((dateStr) {
                      return Chip(
                        label: Text(dateStr),
                        deleteIconColor: AppColors.error,
                        onDeleted: () {
                          setState(() {
                            _holidays.remove(dateStr);
                          });
                        },
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),
    );
  }
}

// Extension to simplify deep copies of working hours
extension _WorkingHoursCopy on WorkingHours {
  WorkingHours copyWith({
    DailyHours? monday,
    DailyHours? tuesday,
    DailyHours? wednesday,
    DailyHours? thursday,
    DailyHours? friday,
    DailyHours? saturday,
    DailyHours? sunday,
  }) {
    return WorkingHours(
      monday: monday ?? this.monday,
      tuesday: tuesday ?? this.tuesday,
      wednesday: wednesday ?? this.wednesday,
      thursday: thursday ?? this.thursday,
      friday: friday ?? this.friday,
      saturday: saturday ?? this.saturday,
      sunday: sunday ?? this.sunday,
    );
  }
}
