/// time_formatter.dart
/// Dental Clinic Staff/Admin App
///
/// Utility function to format 24-hour time strings ("HH:mm") into 12-hour format ("h:mm AM/PM").
library;

String format12Hour(String hhmm) {
  try {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    var h = hour % 12;
    if (h == 0) h = 12;
    return '$h:$minute $period';
  } catch (_) {
    return hhmm;
  }
}
