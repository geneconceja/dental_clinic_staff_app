/// staff_functions.dart
/// Dental Clinic Staff/Admin App
///
/// Client caller wrapper for createStaffUser Cloud Function.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/staff_user.dart';
import '../../core/utils/functions_client.dart';

class CreateStaffResult {
  const CreateStaffResult({
    required this.uid,
    required this.status,
  });

  final String uid;
  final String status;

  factory CreateStaffResult.fromMap(Map<String, dynamic> map) {
    return CreateStaffResult(
      uid: (map['uid'] as String?) ?? '',
      status: (map['status'] as String?) ?? '',
    );
  }
}

class StaffFunctions {
  const StaffFunctions({required FunctionsClient client}) : _client = client;

  final FunctionsClient _client;

  /// Calls createStaffUser Cloud Function to create a new staff Auth + Firestore record.
  Future<CreateStaffResult> createStaffUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required StaffRole role,
  }) async {
    final Map<String, dynamic> rawResult = await _client.call(
      functionName: 'createStaffUser',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
        'role': role.toJson(),
      },
    );

    return CreateStaffResult.fromMap(Map<String, dynamic>.from(rawResult));
  }
}

final staffFunctionsProvider = Provider<StaffFunctions>((ref) {
  final client = ref.watch(functionsClientProvider);
  return StaffFunctions(client: client);
});
