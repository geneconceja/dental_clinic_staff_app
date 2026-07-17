/// slot_generator.dart
/// Dental Clinic Staff/Admin App
///
/// Pure utility for computing available appointment time slots for a given date.
/// Derives candidate slots from clinic working hours, then removes slots that
/// overlap with already-booked (pending or confirmed) appointments.
///
/// Kept in core/utils/ so it can be reused by both the Walk-In form and any
/// future scheduling/calendar features.
library;

import '../models/appointment.dart';
import '../models/clinic_settings.dart';
import 'time_formatter.dart';

/// Represents a single bookable time slot.
class TimeSlot {
  const TimeSlot({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.appointmentDateTime,
  });

  /// "HH:mm" format
  final String startTime;

  /// "HH:mm" format
  final String endTime;

  /// Human-readable label, e.g. "09:00 – 09:30"
  final String label;

  /// Full DateTime for the slot start (used when calling the Cloud Function).
  final DateTime appointmentDateTime;

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.startTime == startTime;

  @override
  int get hashCode => startTime.hashCode;
}

/// Computes available [TimeSlot]s for a specific [date] given the clinic's
/// [settings] and the [existingAppointments] already booked on that day.
///
/// Slots that overlap with an existing `pending` or `confirmed` appointment
/// are excluded. All other statuses (cancelled, completed, no-show) free the
/// slot back up.
List<TimeSlot> generateAvailableSlots({
  required DateTime date,
  required ClinicSettings settings,
  required List<Appointment> existingAppointments,
}) {
  final dailyHours = _getDailyHours(settings.workingHours, date.weekday);

  // Clinic is closed this day, or hours are not configured.
  if (!dailyHours.isOpen ||
      dailyHours.open == null ||
      dailyHours.close == null) {
    return const [];
  }

  final openTime = _parseTime(dailyHours.open!);
  final closeTime = _parseTime(dailyHours.close!);
  final bookedIntervals = existingAppointments
      .where((a) =>
          a.status == AppointmentStatus.pending ||
          a.status == AppointmentStatus.confirmed)
      .map((a) => (start: _parseTime(a.startTime), end: _parseTime(a.endTime)))
      .toList();

  final slots = <TimeSlot>[];
  var current = openTime;

  while (_addMinutes(current, settings.slotDurationMinutes)
      .compareTo(closeTime) <=
      0) {
    final slotEnd = _addMinutes(current, settings.slotDurationMinutes);

    // Check overlap against any booked interval.
    final isBooked = bookedIntervals.any((interval) =>
        current.isBefore(interval.end) && slotEnd.isAfter(interval.start));

    if (!isBooked) {
      final slotDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        current.hour,
        current.minute,
      );
      slots.add(TimeSlot(
        startTime: _formatTime(current),
        endTime: _formatTime(slotEnd),
        label: '${format12Hour(_formatTime(current))} – ${format12Hour(_formatTime(slotEnd))}',
        appointmentDateTime: slotDateTime,
      ));
    }

    current = _addMinutes(current, settings.slotDurationMinutes);
    if (current.compareTo(closeTime) >= 0) break;
  }

  return slots;
}

/// Returns true if a given [date] is a holiday per the clinic settings.
bool isHoliday(DateTime date, ClinicSettings settings) {
  final dateStr =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  return settings.holidays.contains(dateStr);
}

/// Returns true if the clinic is open on the given [date].
bool isClinicOpen(DateTime date, ClinicSettings settings) {
  if (isHoliday(date, settings)) return false;
  final daily = _getDailyHours(settings.workingHours, date.weekday);
  return daily.isOpen;
}

// ---------- Private helpers ----------

DailyHours _getDailyHours(WorkingHours hours, int weekday) {
  return switch (weekday) {
    DateTime.monday => hours.monday,
    DateTime.tuesday => hours.tuesday,
    DateTime.wednesday => hours.wednesday,
    DateTime.thursday => hours.thursday,
    DateTime.friday => hours.friday,
    DateTime.saturday => hours.saturday,
    DateTime.sunday => hours.sunday,
    _ => const DailyHours(open: null, close: null, isOpen: false),
  };
}

/// Parses "HH:mm" into a [DateTime] (date portion is ignored; only time matters).
DateTime _parseTime(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return DateTime(2000, 1, 1, h, m);
}

DateTime _addMinutes(DateTime dt, int minutes) =>
    dt.add(Duration(minutes: minutes));

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
