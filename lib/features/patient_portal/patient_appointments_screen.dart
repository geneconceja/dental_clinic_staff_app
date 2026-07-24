/// patient_appointments_screen.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Patient appointment history manager allowing patients to view upcoming,
/// past, and cancelled visits, inspect appointment details, cancel appointments
/// with an optional reason, and reschedule appointments.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/appointment.dart';
import '../../core/models/clinic_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/slot_generator.dart';
import '../../core/utils/time_formatter.dart';
import '../../routing/app_router.dart';
import '../settings/clinic_settings_repository.dart';
import 'patient_providers.dart';

class PatientAppointmentsScreen extends ConsumerWidget {
  const PatientAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(patientAppointmentsProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final headerText = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'My Appointments',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        SizedBox(height: 4),
        Text(
          'Manage your upcoming visits, past treatments, and cancellation history.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );

    final bookButton = ElevatedButton.icon(
      onPressed: () => context.goNamed(AppRoutes.patientBook),
      icon: const Icon(Icons.add),
      label: const Text('Book New Appointment'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                headerText,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: bookButton),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: headerText),
                    const SizedBox(width: 16),
                    bookButton,
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // TabBar Navigation
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Past Treatments'),
                    Tab(text: 'Cancelled'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // TabBar Views
              Expanded(
                child: appointmentsAsync.when(
                  data: (appointments) {
                    final upcoming = appointments.where((a) =>
                        a.status == AppointmentStatus.pending ||
                        a.status == AppointmentStatus.confirmed).toList();

                    final past = appointments.where((a) =>
                        a.status == AppointmentStatus.completed ||
                        a.status == AppointmentStatus.noShow).toList();

                    final cancelled = appointments.where((a) =>
                        a.status == AppointmentStatus.cancelled).toList();

                    return TabBarView(
                      children: [
                        _AppointmentListView(appointments: upcoming, emptyMessage: 'No upcoming appointments scheduled.'),
                        _AppointmentListView(appointments: past, emptyMessage: 'No completed past treatments recorded yet.'),
                        _AppointmentListView(appointments: cancelled, emptyMessage: 'No cancelled appointments.'),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error loading appointments: ${e.toString()}', style: const TextStyle(color: AppColors.error))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Appointment List View ----------

class _AppointmentListView extends ConsumerWidget {
  const _AppointmentListView({
    required this.appointments,
    required this.emptyMessage,
  });

  final List<Appointment> appointments;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_busy, size: 48, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appt = appointments[index];
        return _AppointmentCard(appointment: appt);
      },
    );
  }
}

// ---------- Appointment Card Component ----------

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  Color _getColorForStatus(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => AppColors.warning,
      AppointmentStatus.confirmed => AppColors.success,
      AppointmentStatus.completed => AppColors.info,
      AppointmentStatus.cancelled => AppColors.error,
      AppointmentStatus.noShow => AppColors.textDisabled,
    };
  }

  String _getBadgeText(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => 'PENDING APPROVAL',
      AppointmentStatus.confirmed => 'CONFIRMED',
      AppointmentStatus.completed => 'COMPLETED',
      AppointmentStatus.cancelled => 'CANCELLED',
      AppointmentStatus.noShow => 'NO SHOW',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = appointment.status == AppointmentStatus.pending ||
        appointment.status == AppointmentStatus.confirmed;
    final isMobile = MediaQuery.of(context).size.width < 500;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Ref ID & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ref ID: ${appointment.id}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getColorForStatus(appointment.status).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getColorForStatus(appointment.status)),
                  ),
                  child: Text(
                    _getBadgeText(appointment.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getColorForStatus(appointment.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Service Title & Time Details
            Text(
              appointment.serviceName.isNotEmpty ? appointment.serviceName : appointment.reason,
              style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            if (isMobile) ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Date: ${appointment.date}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Time: ${format12Hour(appointment.startTime)} – ${format12Hour(appointment.endTime)}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Date: ${appointment.date}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 20),
                  const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Time: ${format12Hour(appointment.startTime)} – ${format12Hour(appointment.endTime)}',
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],

            if (appointment.cancellationReason != null && appointment.cancellationReason!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${appointment.cancellationReason}',
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Action Buttons
            Wrap(
              alignment: isMobile ? WrapAlignment.spaceBetween : WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _showDetailsSheet(context, appointment),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Details'),
                ),
                if (canManage)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showRescheduleDialog(context, ref, appointment),
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: const Text('Reschedule'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showCancelDialog(context, ref, appointment),
                        icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                        label: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Modal Sheet: View Full Metadata ----------

  void _showDetailsSheet(BuildContext context, Appointment appt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appt.serviceName.isNotEmpty ? appt.serviceName : appt.reason,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _detailItem('Reference ID', appt.id),
            _detailItem('Patient Name', appt.patientFullName),
            _detailItem('Contact Phone', appt.phoneNumber),
            _detailItem('Date & Time', '${appt.date} @ ${format12Hour(appt.startTime)} – ${format12Hour(appt.endTime)}'),
            _detailItem('Booking Channel', appt.bookingSource.name.toUpperCase()),
            _detailItem('Payment Status', appt.paid ? 'PAID' : 'UNPAID'),
            if (appt.notes != null && appt.notes!.isNotEmpty)
              _detailItem('Patient Notes', appt.notes!),
            if (appt.cancellationReason != null && appt.cancellationReason!.isNotEmpty)
              _detailItem('Cancellation Reason', appt.cancellationReason!),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ---------- Dialog: Cancel Appointment ----------

  void _showCancelDialog(BuildContext context, WidgetRef ref, Appointment appt) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 10),
            Text('Cancel Appointment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel your appointment for ${appt.serviceName} on ${appt.date}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason for Cancellation (optional)',
                hintText: 'e.g. Schedule conflict, feeling unwell...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              try {
                await ref.read(patientRepositoryProvider).cancelPatientAppointment(
                      appointmentId: appt.id,
                      reason: reasonCtrl.text,
                    );
                ref.invalidate(patientAppointmentsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Appointment request cancelled successfully.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel appointment: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  // ---------- Dialog: Reschedule Appointment ----------

  void _showRescheduleDialog(BuildContext context, WidgetRef ref, Appointment appt) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _RescheduleDialog(appointment: appt),
    );
  }
}

// ---------- Dialog Stateful Component: Reschedule Appointment ----------

class _RescheduleDialog extends ConsumerStatefulWidget {
  const _RescheduleDialog({required this.appointment});

  final Appointment appointment;

  @override
  ConsumerState<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<_RescheduleDialog> {
  late DateTime _selectedDate;
  String? _selectedStartTime;
  String? _selectedEndTime;
  bool _isLoadingSlots = false;
  List<TimeSlot> _availableSlots = [];
  bool _isSubmitting = false;
  String? _error;

  static const _fallbackClinicSettings = ClinicSettings(
    slotDurationMinutes: 30,
    workingHours: WorkingHours(
      monday: DailyHours(open: '09:00', close: '17:00', isOpen: true),
      tuesday: DailyHours(open: '09:00', close: '17:00', isOpen: true),
      wednesday: DailyHours(open: '09:00', close: '17:00', isOpen: true),
      thursday: DailyHours(open: '09:00', close: '17:00', isOpen: true),
      friday: DailyHours(open: '09:00', close: '17:00', isOpen: true),
      saturday: DailyHours(open: '09:00', close: '12:00', isOpen: true),
      sunday: DailyHours(open: null, close: null, isOpen: false),
    ),
    holidays: [],
    reminderHoursBefore: 24,
    clinicName: 'Dental Clinic',
    clinicPhone: '',
    clinicAddress: '',
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _loadSlots(_selectedDate);
  }

  Future<void> _loadSlots(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _selectedStartTime = null;
      _selectedEndTime = null;
      _error = null;
    });

    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final settings = ref.read(clinicSettingsProvider).asData?.value ?? _fallbackClinicSettings;

      if (!isClinicOpen(date, settings)) {
        if (mounted) setState(() => _isLoadingSlots = false);
        return;
      }

      final existingAppts = await ref.read(patientRepositoryProvider).fetchAppointmentsForDate(dateStr);
      final slots = generateAvailableSlots(
        date: date,
        settings: settings,
        existingAppointments: existingAppts,
      );

      if (mounted) {
        setState(() {
          _availableSlots = slots;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _submitReschedule() async {
    if (_selectedStartTime == null || _selectedEndTime == null) return;

    setState(() => _isSubmitting = true);

    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final startParts = _selectedStartTime!.split(':');
      final apptDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      await ref.read(patientRepositoryProvider).reschedulePatientAppointment(
            appointmentId: widget.appointment.id,
            dateStr: dateStr,
            startTime: _selectedStartTime!,
            endTime: _selectedEndTime!,
            appointmentDateTime: apptDateTime,
          );

      ref.invalidate(patientAppointmentsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment rescheduled successfully! Reset to pending staff review.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to reschedule: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(clinicSettingsProvider).asData?.value ?? _fallbackClinicSettings;

    return AlertDialog(
      title: const Text('Reschedule Appointment'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rescheduling visit for ${widget.appointment.serviceName}'),
              const SizedBox(height: 16),

              // Date Picker Button
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date: ${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final today = DateTime.now();
                          final cleanToday = DateTime(today.year, today.month, today.day);

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: cleanToday.add(const Duration(days: 1)),
                            lastDate: cleanToday.add(const Duration(days: 90)),
                            selectableDayPredicate: (day) => isClinicOpen(day, settings),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                            await _loadSlots(picked);
                          }
                        },
                        icon: const Icon(Icons.edit_calendar, size: 16),
                        label: const Text('Pick Date'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time Slot Chips
              const Text('Select New Time Slot:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (_isLoadingSlots)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (_availableSlots.isEmpty)
                const Text('Clinic is closed or fully booked on this date.', style: TextStyle(color: AppColors.error))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSlots.map((slot) {
                    final isSelected = _selectedStartTime == slot.startTime;

                    return ChoiceChip(
                      label: Text(slot.label),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
                      onSelected: (_) {
                        setState(() {
                          _selectedStartTime = slot.startTime;
                          _selectedEndTime = slot.endTime;
                        });
                      },
                    );
                  }).toList(),
                ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_selectedStartTime == null || _isSubmitting) ? null : _submitReschedule,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(_isSubmitting ? 'Rescheduling...' : 'Confirm Reschedule'),
        ),
      ],
    );
  }
}
