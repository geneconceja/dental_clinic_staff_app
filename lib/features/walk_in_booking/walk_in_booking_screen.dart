/// walk_in_booking_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Multi-step form for booking a walk-in appointment directly.
/// Step 1: Patient Details (name, phone, optional notes)
/// Step 2: Appointment Details (service, date, time slot)
///
/// Calls the createWalkInAppointment callable Cloud Function on submit.
/// Slot availability is computed client-side from clinicSettings + existing
/// appointments for the selected date — the server does a final transaction
/// check, so conflicts are handled gracefully inline.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/slot_generator.dart';
import '../../features/review_queue/appointments_repository.dart';
import '../../features/services_admin/services_repository.dart';
import '../../features/settings/clinic_settings_repository.dart';
import '../../features/walk_in_booking/walk_in_functions.dart';
import '../../core/utils/functions_client.dart';
import '../../routing/app_router.dart';

class WalkInBookingScreen extends ConsumerStatefulWidget {
  const WalkInBookingScreen({super.key});

  @override
  ConsumerState<WalkInBookingScreen> createState() =>
      _WalkInBookingScreenState();
}

class _WalkInBookingScreenState extends ConsumerState<WalkInBookingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step index
  int _currentStep = 0;

  // Step 1 controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Step 2 selections
  Service? _selectedService;
  DateTime? _selectedDate;
  TimeSlot? _selectedSlot;

  bool _isSubmitting = false;
  String? _slotConflictError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedService == null ||
        _selectedDate == null ||
        _selectedSlot == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _slotConflictError = null;
    });

    try {
      final functions = ref.read(walkInFunctionsProvider);
      await functions.createWalkIn(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        serviceId: _selectedService!.id,
        appointmentDateTime: _selectedSlot!.appointmentDateTime,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Walk-in appointment booked for '
              '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.goNamed(AppRoutes.dashboard);
      }
    } on ConflictException {
      setState(() {
        _slotConflictError =
            'This slot was just booked by someone else. Please pick another time.';
      });
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: AppColors.error),
                SizedBox(width: 12),
                Text('Booking Failed'),
              ],
            ),
            content: Text(
              e.toString().replaceAll('FunctionsException: ', ''),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Walk-In Appointment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoutes.dashboard),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Form(
                key: _formKey,
                child: Stepper(
                  currentStep: _currentStep,
                  onStepCancel: _currentStep == 0
                      ? null
                      : () => setState(() => _currentStep--),
                  onStepContinue: () {
                    if (_currentStep == 0) {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _currentStep = 1);
                      }
                    } else {
                      _submit();
                    }
                  },
                  controlsBuilder: (context, details) =>
                      _buildStepControls(context, details),
                  steps: [
                    _buildPatientStep(theme),
                    _buildAppointmentStep(theme),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ── Step Controls ──────────────────────────────────────────────────────────

  Widget _buildStepControls(BuildContext context, ControlsDetails details) {
    final isLastStep = _currentStep == 1;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          ElevatedButton(
            onPressed: _isSubmitting ? null : details.onStepContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            ),
            child: Text(isLastStep ? 'Book Appointment' : 'Continue'),
          ),
          if (_currentStep > 0) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : details.onStepCancel,
              child: const Text('Back'),
            ),
          ],
        ],
      ),
    );
  }

  // ── Step 1: Patient Details ───────────────────────────────────────────────

  Step _buildPatientStep(ThemeData theme) {
    return Step(
      title: const Text('Patient Details'),
      subtitle: const Text('Name, phone number, and optional notes'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'First Name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last Name *',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone Number *',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: 'e.g. 09171234567',
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.trim().length < 7) return 'Enter a valid phone number';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
              hintText: 'Chief complaint, special requests…',
              alignLabelWithHint: true,
            ),
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  // ── Step 2: Appointment Details ────────────────────────────────────────────

  Step _buildAppointmentStep(ThemeData theme) {
    return Step(
      title: const Text('Appointment Details'),
      subtitle: const Text('Service, date, and time slot'),
      isActive: _currentStep >= 1,
      state: StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Service dropdown
          _ServiceDropdown(
            selectedService: _selectedService,
            onChanged: (service) => setState(() {
              _selectedService = service;
              _selectedSlot = null; // reset slot when service changes
            }),
          ),
          const SizedBox(height: 16),

          // Date picker
          _DatePickerField(
            selectedDate: _selectedDate,
            onDatePicked: (date) => setState(() {
              _selectedDate = date;
              _selectedSlot = null; // reset slot when date changes
            }),
          ),
          const SizedBox(height: 16),

          // Time slot dropdown (depends on date + settings + existing bookings)
          if (_selectedDate != null)
            _SlotDropdown(
              date: _selectedDate!,
              selectedSlot: _selectedSlot,
              conflictError: _slotConflictError,
              onChanged: (slot) => setState(() {
                _selectedSlot = slot;
                _slotConflictError = null;
              }),
            ),

          if (_slotConflictError != null) ...[
            const SizedBox(height: 8),
            Text(
              _slotConflictError!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],

          if (_selectedService != null) ...[
            const SizedBox(height: 16),
            _ServiceInfoCard(service: _selectedService!),
          ],
        ],
      ),
    );
  }
}

// ── Service Dropdown ──────────────────────────────────────────────────────────

class _ServiceDropdown extends ConsumerWidget {
  const _ServiceDropdown({
    required this.selectedService,
    required this.onChanged,
  });

  final Service? selectedService;
  final ValueChanged<Service?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(activeServicesProvider);

    return servicesAsync.when(
      data: (services) => DropdownButtonFormField<Service>(
        initialValue: selectedService,
        decoration: const InputDecoration(
          labelText: 'Service *',
          prefixIcon: Icon(Icons.medical_services_outlined),
        ),
        hint: const Text('Select a service'),
        items: services
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name),
                ))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Please select a service' : null,
      ),
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Failed to load services'),
    );
  }
}

// ── Date Picker Field ─────────────────────────────────────────────────────────

class _DatePickerField extends ConsumerWidget {
  const _DatePickerField({
    required this.selectedDate,
    required this.onDatePicked,
  });

  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDatePicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(clinicSettingsProvider);

    final label = selectedDate == null
        ? 'Select date'
        : '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';

    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        alignment: Alignment.centerLeft,
        foregroundColor: selectedDate == null
            ? AppColors.textSecondary
            : AppColors.textPrimary,
      ),
      onPressed: () async {
        final settings = settingsAsync.asData?.value;
        final today = DateTime.now();
        final cleanToday = DateTime(today.year, today.month, today.day);
        var initial = selectedDate ?? cleanToday;

        if (settings != null && !isClinicOpen(initial, settings)) {
          for (int i = 0; i < 30; i++) {
            final candidate = cleanToday.add(Duration(days: i));
            if (isClinicOpen(candidate, settings)) {
              initial = candidate;
              break;
            }
          }
        }

        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: cleanToday,
          lastDate: cleanToday.add(const Duration(days: 180)),
          selectableDayPredicate: settings == null
              ? null
              : (day) => isClinicOpen(day, settings),
        );
        if (picked != null) {
          onDatePicked(DateTime(picked.year, picked.month, picked.day));
        }
      },
    );
  }
}

// ── Slot Dropdown ─────────────────────────────────────────────────────────────

class _SlotDropdown extends ConsumerWidget {
  const _SlotDropdown({
    required this.date,
    required this.selectedSlot,
    required this.onChanged,
    this.conflictError,
  });

  final DateTime date;
  final TimeSlot? selectedSlot;
  final ValueChanged<TimeSlot?> onChanged;
  final String? conflictError;

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(clinicSettingsProvider);
    final appointmentsAsync =
        ref.watch(appointmentsByDateProvider(_dateStr(date)));

    return settingsAsync.when(
      data: (settings) {
        if (settings == null) {
          return const Text('Clinic settings not found.',
              style: TextStyle(color: AppColors.error));
        }
        return appointmentsAsync.when(
          data: (appointments) {
            final slots = generateAvailableSlots(
              date: date,
              settings: settings,
              existingAppointments: appointments,
            );

            if (slots.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'No available slots for this date.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ],
                ),
              );
            }

            TimeSlot? dropdownValue;
            if (selectedSlot != null) {
              if (slots.contains(selectedSlot)) {
                dropdownValue = slots.firstWhere((s) => s == selectedSlot);
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onChanged(null);
                });
              }
            }

            return DropdownButtonFormField<TimeSlot>(
              initialValue: dropdownValue,
              decoration: InputDecoration(
                labelText: 'Time Slot *',
                prefixIcon: const Icon(Icons.access_time_outlined),
                errorText: conflictError,
              ),
              hint: const Text('Select a time slot'),
              items: slots
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.label),
                      ))
                  .toList(),
              onChanged: onChanged,
              validator: (v) => v == null ? 'Please select a time slot' : null,
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, __) =>
              const Text('Failed to load appointments for this date'),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('Failed to load clinic settings'),
    );
  }
}

// ── Service Info Card ─────────────────────────────────────────────────────────

class _ServiceInfoCard extends StatelessWidget {
  const _ServiceInfoCard({required this.service});
  final Service service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${service.name} · ${service.durationMinutes} min · '
              '₱${service.price.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.info, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
