/// services_repository.dart
/// Dental Clinic Staff/Admin App
///
/// Handles Firestore streams and updates for the services collection.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/service.dart';

class ServicesRepository {
  ServicesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('services');

  // ---------- Read Streams ----------

  /// Streams all services in the clinic. Sorted alphabetically by name.
  /// Useful for admin services page.
  Stream<List<Service>> watchAllServices() {
    return _collection.orderBy('name').snapshots().map((snap) => snap.docs
        .map((doc) => Service.fromJson(doc.data(), documentId: doc.id))
        .toList());
  }

  /// Streams only active services. Sorted alphabetically by name.
  /// Useful for booking forms and dropdown menus.
  Stream<List<Service>> watchActiveServices() {
    return _collection
        .where('active', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Service.fromJson(doc.data(), documentId: doc.id))
            .toList());
  }

  // ---------- CRUD Operations ----------

  /// Creates a new service. Generates a Firestore document ID automatically.
  Future<String> createService({
    required String name,
    required int durationMinutes,
    required double price,
    required String description,
    required bool active,
  }) async {
    final docRef = _collection.doc();
    final service = Service(
      id: docRef.id,
      name: name.trim(),
      durationMinutes: durationMinutes,
      price: price,
      description: description.trim(),
      active: active,
    );
    await docRef.set(service.toJson());
    return docRef.id;
  }

  /// Updates an existing service profile.
  Future<void> updateService(Service service) async {
    await _collection.doc(service.id).update(service.toJson());
  }

  /// Toggles a service active or inactive.
  Future<void> toggleServiceActive(String id, bool active) async {
    await _collection.doc(id).update({
      'active': active,
    });
  }
}

// ---------- Providers ----------

final servicesRepositoryProvider = Provider<ServicesRepository>((ref) {
  return ServicesRepository();
});

final activeServicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesRepositoryProvider).watchActiveServices();
});
