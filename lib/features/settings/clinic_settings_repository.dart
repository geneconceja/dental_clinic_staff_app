/// clinic_settings_repository.dart
/// Dental Clinic Staff/Admin App
///
/// Handles Firestore read and update operations for the clinic settings.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/clinic_settings.dart';

class ClinicSettingsRepository {
  ClinicSettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _document =>
      _firestore.collection('clinicSettings').doc('main');

  // ---------- Read Streams ----------

  /// Streams the primary clinic configurations from clinicSettings/main.
  /// If the document doesn't exist yet, it returns null.
  Stream<ClinicSettings?> watchClinicSettings() {
    return _document.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ClinicSettings.fromJson(doc.data()!);
    });
  }

  // ---------- Writes ----------

  /// Updates or creates the clinicSettings/main configurations.
  Future<void> updateClinicSettings(ClinicSettings settings) async {
    await _document.set(settings.toJson(), SetOptions(merge: true));
  }
}

// ---------- Provider ----------

final clinicSettingsRepositoryProvider = Provider<ClinicSettingsRepository>((ref) {
  return ClinicSettingsRepository();
});
