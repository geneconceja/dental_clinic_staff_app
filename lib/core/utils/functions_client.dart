/// functions_client.dart
/// Dental Clinic Staff/Admin App
///
/// Wrapper around FirebaseFunctions to invoke Callable Functions.
/// Maps generic FirebaseFunctionsExceptions to specialized, typed Dart
/// exceptions so that the UI can catch and react to specific business failures.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------- Custom Exceptions ----------

sealed class FunctionsException implements Exception {
  const FunctionsException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class PermissionDeniedException extends FunctionsException {
  const PermissionDeniedException(super.message);
}

class InvalidArgumentException extends FunctionsException {
  const InvalidArgumentException(super.message);
}

class NotFoundException extends FunctionsException {
  const NotFoundException(super.message);
}

class PreconditionException extends FunctionsException {
  const PreconditionException(super.message);
}

class ConflictException extends FunctionsException {
  const ConflictException(super.message);
}

class UnknownFunctionsException extends FunctionsException {
  const UnknownFunctionsException(super.message);
}

// ---------- Client ----------

class FunctionsClient {
  FunctionsClient({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  /// Calls a Callable Cloud Function named [functionName] with [data] payload.
  /// Converts generic [FirebaseFunctionsException] into a typed [FunctionsException].
  Future<T> call<T>({
    required String functionName,
    dynamic data,
  }) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(data);
      return result.data as T;
    } on FirebaseFunctionsException catch (e) {
      throw _mapException(e);
    } catch (e) {
      throw UnknownFunctionsException(e.toString());
    }
  }

  FunctionsException _mapException(FirebaseFunctionsException e) {
    final msg = e.message ?? 'An error occurred while executing operation.';
    return switch (e.code) {
      'permission-denied' || 'unauthenticated' => PermissionDeniedException(msg),
      'invalid-argument' => InvalidArgumentException(msg),
      'not-found' => NotFoundException(msg),
      'failed-precondition' => PreconditionException(msg),
      'already-exists' => ConflictException(msg),
      _ => UnknownFunctionsException(msg),
    };
  }
}

// ---------- Provider ----------

final functionsClientProvider = Provider<FunctionsClient>((ref) {
  return FunctionsClient();
});
