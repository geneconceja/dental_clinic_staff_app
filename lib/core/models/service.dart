/// service.dart
/// Dental Clinic Staff/Admin App
///
/// Mirrors the Service model defined in schema-types.ts.
/// Keep manually in sync if schema-types.ts updates.
library;

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    required this.description,
    required this.active,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final double price;
  final String description;
  final bool active;

  factory Service.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return Service(
      id: documentId ?? (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: (json['description'] as String?) ?? '',
      active: (json['active'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'durationMinutes': durationMinutes,
      'price': price,
      'description': description,
      'active': active,
    };
  }

  Service copyWith({
    String? id,
    String? name,
    int? durationMinutes,
    double? price,
    String? description,
    bool? active,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      price: price ?? this.price,
      description: description ?? this.description,
      active: active ?? this.active,
    );
  }
}
