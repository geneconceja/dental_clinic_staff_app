/// patient_booking_wizard_screen.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Multi-step appointment request wizard for patients to select a service,
/// choose an available date & time slot, add visit notes, and submit a request.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/clinic_settings.dart';
import '../../core/models/service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/slot_generator.dart';
import '../../core/utils/time_formatter.dart';
import '../../routing/app_router.dart';
import '../auth/auth_providers.dart';
import '../services_admin/services_repository.dart';
import '../settings/clinic_settings_repository.dart';
import 'patient_providers.dart';

class PatientBookingWizardScreen extends ConsumerStatefulWidget {
  const PatientBookingWizardScreen({super.key});

  @override
  ConsumerState<PatientBookingWizardScreen> createState() => _PatientBookingWizardScreenState();
}

class _PatientBookingWizardScreenState extends ConsumerState<PatientBookingWizardScreen> {
  int _currentStep = 0;

  Service? _selectedService;
  DateTime? _selectedDate;
  String? _selectedStartTime;
  String? _selectedEndTime;
  final _notesController = TextEditingController();

  bool _isLoadingSlots = false;
  List<_TimeSlotOption> _availableSlots = [];
  bool _isSubmitting = false;
  String? _submissionError;
  String? _createdAppointmentId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  DateTime _findFirstOpenDate(DateTime start, ClinicSettings settings) {
    var candidate = start;
    for (int i = 0; i < 60; i++) {
      if (isClinicOpen(candidate, settings)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return start;
  }

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

  Future<void> _fetchAndComputeSlots(DateTime date) async {
    setState(() {
      _isLoadingSlots = true;
      _selectedStartTime = null;
      _selectedEndTime = null;
    });

    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Non-blocking synchronous settings resolution
      final settings = ref.read(clinicSettingsProvider).asData?.value ?? _fallbackClinicSettings;

      if (!isClinicOpen(date, settings)) {
        if (mounted) {
          setState(() {
            _availableSlots = [];
            _isLoadingSlots = false;
          });
        }
        return;
      }

      // Fetch existing appointments for date with 3s timeout
      final existingAppts = await ref
          .read(patientRepositoryProvider)
          .fetchAppointmentsForDate(dateStr)
          .timeout(const Duration(seconds: 3), onTimeout: () => []);

      final generatedSlots = generateAvailableSlots(
        date: date,
        settings: settings,
        existingAppointments: existingAppts,
      );

      final options = generatedSlots.map((s) => _TimeSlotOption(
        startTime: s.startTime,
        endTime: s.endTime,
        label: s.label,
        isAvailable: true,
      )).toList();

      if (mounted) {
        setState(() {
          _availableSlots = options;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableSlots = [];
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  // ---------- Submission ----------

  Future<void> _submitBooking() async {
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final profile = ref.read(staffProfileProvider).asData?.value;
      if (profile == null) throw Exception('Patient profile not loaded.');

      final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
      final startParts = _selectedStartTime!.split(':');
      final apptDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        int.parse(startParts[0]),
        int.parse(startParts[1]),
      );

      // Split name into first and last
      final nameParts = profile.name.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : 'Patient';

      final apptId = await ref.read(patientRepositoryProvider).createPatientAppointment(
            patientUid: profile.uid,
            patientEmail: profile.email,
            firstName: firstName,
            lastName: lastName,
            phoneNumber: profile.phone.isNotEmpty ? profile.phone : '09170000000',
            serviceId: _selectedService!.id,
            serviceName: _selectedService!.name,
            dateStr: dateStr,
            startTime: _selectedStartTime!,
            endTime: _selectedEndTime!,
            appointmentDateTime: apptDateTime,
            notes: _notesController.text,
          );

      // Refresh appointments provider
      ref.invalidate(patientAppointmentsProvider);

      setState(() {
        _createdAppointmentId = apptId;
        _currentStep = 3; // Advance to confirmation step
      });
    } catch (e) {
      setState(() => _submissionError = 'Failed to submit request: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Book an Appointment',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select your preferred service, date, and time slot to request a visit.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                // Step Progress Indicator
                _buildStepIndicator(),
                const SizedBox(height: 28),

                // Step Content
                if (_currentStep == 0) _buildStep1ServiceSelection(),
                if (_currentStep == 1) _buildStep2DateTimeSelection(),
                if (_currentStep == 2) _buildStep3ReviewAndNotes(),
                if (_currentStep == 3) _buildStep4Confirmation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Progress Bar Indicator ----------

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepBadge(0, '1. Select Service'),
        const Expanded(child: Divider(thickness: 2)),
        _buildStepBadge(1, '2. Date & Time'),
        const Expanded(child: Divider(thickness: 2)),
        _buildStepBadge(2, '3. Review'),
        const Expanded(child: Divider(thickness: 2)),
        _buildStepBadge(3, '4. Confirmed'),
      ],
    );
  }

  Widget _buildStepBadge(int step, String label) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    final bgColor = isDone
        ? AppColors.success
        : (isActive ? AppColors.primary : AppColors.surfaceVariant);
    final textColor = (isDone || isActive) ? Colors.white : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  // ---------- Step 1: Service Selection ----------

  Widget _buildStep1ServiceSelection() {
    final activeServicesAsync = ref.watch(activeServicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose a Dental Treatment',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        activeServicesAsync.when(
          data: (services) {
            if (services.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No active dental services available at this time.'),
                ),
              );
            }

            return Column(
              children: services.map((svc) {
                final isSelected = _selectedService?.id == svc.id;

                return Card(
                  elevation: isSelected ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedService = svc;
                      });
                      _fetchAndComputeSlots(_selectedDate!);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  svc.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  svc.description,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₱${svc.price.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Chip(
                                label: Text('${svc.durationMinutes} mins', style: const TextStyle(fontSize: 11)),
                                backgroundColor: AppColors.surfaceVariant,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading services: ${e.toString()}', style: const TextStyle(color: AppColors.error)),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: _selectedService == null
                  ? null
                  : () {
                      setState(() => _currentStep = 1);
                      final settings = ref.read(clinicSettingsProvider).asData?.value ?? _fallbackClinicSettings;

                      if (!isClinicOpen(_selectedDate!, settings)) {
                        final firstOpen = _findFirstOpenDate(_selectedDate!, settings);
                        setState(() => _selectedDate = firstOpen);
                      }
                      _fetchAndComputeSlots(_selectedDate!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Next: Choose Date & Time'),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Step 2: Date & Time Selection ----------

  Widget _buildStep2DateTimeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentStep = 0),
            ),
            const Text(
              'Select Date & Time',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Date Selection Button
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.primary, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selected Date', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final settings = ref.read(clinicSettingsProvider).asData?.value ?? _fallbackClinicSettings;

                    final today = DateTime.now();
                    final cleanToday = DateTime(today.year, today.month, today.day);

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate!,
                      firstDate: cleanToday.add(const Duration(days: 1)),
                      lastDate: cleanToday.add(const Duration(days: 90)),
                      selectableDayPredicate: (day) => isClinicOpen(day, settings),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      await _fetchAndComputeSlots(picked);
                    }
                  },
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Change Date'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Time Slot Grid
        const Text(
          'Available Time Slots',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),

        if (_isLoadingSlots)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_availableSlots.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('Clinic is closed or fully booked on this date. Please pick another date.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableSlots.map((slot) {
              final isSelected = _selectedStartTime == slot.startTime;
              final isAvail = slot.isAvailable;

              return ChoiceChip(
                label: Text(slot.label),
                selected: isSelected,
                disabledColor: AppColors.surfaceVariant,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isAvail ? AppColors.textPrimary : AppColors.textDisabled),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: isAvail
                    ? (val) {
                        setState(() {
                          _selectedStartTime = slot.startTime;
                          _selectedEndTime = slot.endTime;
                        });
                      }
                    : null,
              );
            }).toList(),
          ),

        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 0),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: _selectedStartTime == null
                  ? null
                  : () => setState(() => _currentStep = 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Next: Review & Submit'),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Step 3: Review & Visit Notes ----------

  Widget _buildStep3ReviewAndNotes() {
    final dateStr = '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _currentStep = 1),
            ),
            const Text(
              'Review Your Booking Request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_submissionError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 10),
                Expanded(child: Text(_submissionError!, style: const TextStyle(color: AppColors.error))),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Summary Card
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedService!.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      '₱${_selectedService!.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                _buildSummaryRow(Icons.calendar_today, 'Date', dateStr),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.access_time, 'Time Slot', '${format12Hour(_selectedStartTime!)} - ${format12Hour(_selectedEndTime!)}'),
                const SizedBox(height: 8),
                _buildSummaryRow(Icons.timer_outlined, 'Est. Duration', '${_selectedService!.durationMinutes} mins'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Optional Notes
        const Text(
          'Reason for Visit / Optional Notes',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'e.g. Tooth sensitivity on upper left side, routine cleaning request...',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Back'),
            ),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitBooking,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Appointment Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  // ---------- Step 4: Confirmation Screen ----------

  Widget _buildStep4Confirmation() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Booking Request Submitted!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Reference ID: ${_createdAppointmentId ?? 'Pending'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your request has been sent to our clinic staff. You will receive a notification as soon as your appointment is confirmed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => context.goNamed(AppRoutes.patientDashboard),
                  icon: const Icon(Icons.home),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class _TimeSlotOption {
  _TimeSlotOption({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.isAvailable,
  });

  final String startTime;
  final String endTime;
  final String label;
  final bool isAvailable;
}
