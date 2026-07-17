/// clinic_settings.dart
/// Dental Clinic Staff/Admin App
///
/// Mirrors the ClinicSettings model defined in schema-types.ts.
/// Keep manually in sync if schema-types.ts updates.
library;

class DailyHours {
  const DailyHours({
    required this.open,
    required this.close,
    required this.isOpen,
  });

  /// "HH:mm" local time
  final String? open;

  /// "HH:mm" local time
  final String? close;
  final bool isOpen;

  factory DailyHours.fromJson(Map<String, dynamic> json) {
    return DailyHours(
      open: json['open'] as String?,
      close: json['close'] as String?,
      isOpen: (json['isOpen'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open': open,
      'close': close,
      'isOpen': isOpen,
    };
  }
}

class WorkingHours {
  const WorkingHours({
    required this.monday,
    required this.tuesday,
    required this.wednesday,
    required this.thursday,
    required this.friday,
    required this.saturday,
    required this.sunday,
  });

  final DailyHours monday;
  final DailyHours tuesday;
  final DailyHours wednesday;
  final DailyHours thursday;
  final DailyHours friday;
  final DailyHours saturday;
  final DailyHours sunday;

  factory WorkingHours.fromJson(Map<String, dynamic> json) {
    DailyHours parseDay(String key) {
      final val = json[key];
      if (val is Map<String, dynamic>) {
        return DailyHours.fromJson(val);
      }
      return const DailyHours(open: null, close: null, isOpen: false);
    }

    return WorkingHours(
      monday: parseDay('monday'),
      tuesday: parseDay('tuesday'),
      wednesday: parseDay('wednesday'),
      thursday: parseDay('thursday'),
      friday: parseDay('friday'),
      saturday: parseDay('saturday'),
      sunday: parseDay('sunday'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monday': monday.toJson(),
      'tuesday': tuesday.toJson(),
      'wednesday': wednesday.toJson(),
      'thursday': thursday.toJson(),
      'friday': friday.toJson(),
      'saturday': saturday.toJson(),
      'sunday': sunday.toJson(),
    };
  }
}

class ClinicSettings {
  const ClinicSettings({
    required this.slotDurationMinutes,
    required this.workingHours,
    required this.holidays,
    required this.reminderHoursBefore,
    required this.clinicName,
    required this.clinicPhone,
    required this.clinicAddress,
  });

  final int slotDurationMinutes;
  final WorkingHours workingHours;

  /// ISO Date strings, e.g. "YYYY-MM-DD"
  final List<String> holidays;
  final int reminderHoursBefore;
  final String clinicName;
  final String clinicPhone;
  final String clinicAddress;

  factory ClinicSettings.fromJson(Map<String, dynamic> json) {
    final workingJson = json['workingHours'];
    final parsedWorking = workingJson is Map<String, dynamic>
        ? WorkingHours.fromJson(workingJson)
        : WorkingHours(
            monday: const DailyHours(open: '09:00', close: '17:00', isOpen: true),
            tuesday: const DailyHours(open: '09:00', close: '17:00', isOpen: true),
            wednesday: const DailyHours(open: '09:00', close: '17:00', isOpen: true),
            thursday: const DailyHours(open: '09:00', close: '17:00', isOpen: true),
            friday: const DailyHours(open: '09:00', close: '17:00', isOpen: true),
            saturday: const DailyHours(open: null, close: null, isOpen: false),
            sunday: const DailyHours(open: null, close: null, isOpen: false),
          );

    final holidaysList = json['holidays'] as List<dynamic>?;

    return ClinicSettings(
      slotDurationMinutes: (json['slotDurationMinutes'] as num?)?.toInt() ?? 30,
      workingHours: parsedWorking,
      holidays: holidaysList?.map((e) => e.toString()).toList() ?? const [],
      reminderHoursBefore: (json['reminderHoursBefore'] as num?)?.toInt() ?? 24,
      clinicName: (json['clinicName'] as String?) ?? 'Clinic',
      clinicPhone: (json['clinicPhone'] as String?) ?? '',
      clinicAddress: (json['clinicAddress'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slotDurationMinutes': slotDurationMinutes,
      'workingHours': workingHours.toJson(),
      'holidays': holidays,
      'reminderHoursBefore': reminderHoursBefore,
      'clinicName': clinicName,
      'clinicPhone': clinicPhone,
      'clinicAddress': clinicAddress,
    };
  }

  ClinicSettings copyWith({
    int? slotDurationMinutes,
    WorkingHours? workingHours,
    List<String>? holidays,
    int? reminderHoursBefore,
    String? clinicName,
    String? clinicPhone,
    String? clinicAddress,
  }) {
    return ClinicSettings(
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      workingHours: workingHours ?? this.workingHours,
      holidays: holidays ?? this.holidays,
      reminderHoursBefore: reminderHoursBefore ?? this.reminderHoursBefore,
      clinicName: clinicName ?? this.clinicName,
      clinicPhone: clinicPhone ?? this.clinicPhone,
      clinicAddress: clinicAddress ?? this.clinicAddress,
    );
  }
}
