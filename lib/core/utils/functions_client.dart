/// functions_client.dart
/// Dental Clinic Staff/Admin App
///
/// Dual-mode wrapper around Cloud Functions calls.
///
/// ## Modes
///
/// **Emulator / Firebase Callable mode** (default — local development):
///   - Active when the `BACKEND_URL` dart-define is empty or not provided.
///   - Uses `FirebaseFunctions.httpsCallable()` — emulator-safe, zero config.
///   - Local run: `flutter run -d chrome --dart-define=ENV=dev`
///
/// **HTTP / Render mode** (production):
///   - Active when `BACKEND_URL` is provided at build time.
///   - Uses `http.post()` to `$BACKEND_URL/api/$functionName`.
///   - Attaches the signed-in user's Firebase ID token as `Authorization: Bearer <token>`.
///   - CI/CD injects the Render URL via `--dart-define=BACKEND_URL=https://...`.
///
/// All callers (providers, repositories, dialogs) use `functionsClientProvider`
/// and call `client.call(functionName: ..., data: ...)` — identical in both modes.
library;

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

// ---------- Build-time configuration ----------

/// The base URL of the Render backend.
/// Injected at build time via `--dart-define=BACKEND_URL=https://...`.
/// When empty, the client falls back to Firebase Callable Functions (emulator mode).
const String _backendUrl = String.fromEnvironment('BACKEND_URL');

/// True when the app was built with a Render backend URL.
bool get _useHttpBackend => _backendUrl.isNotEmpty;

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
  FunctionsClient({
    FirebaseFunctions? functions,
    http.Client? httpClient,
    FirebaseAuth? auth,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
        _httpClient = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final http.Client _httpClient;
  final FirebaseAuth _auth;

  /// Calls a Cloud Function named [functionName] with [data].
  ///
  /// Routes to the Render HTTP backend when `BACKEND_URL` is set at build time,
  /// otherwise falls back to Firebase Callable Functions (emulator-safe).
  Future<T> call<T>({
    required String functionName,
    dynamic data,
  }) async {
    if (_useHttpBackend) {
      return _callHttp<T>(functionName: functionName, data: data);
    } else {
      return _callFirebase<T>(functionName: functionName, data: data);
    }
  }

  // ── Firebase Callable path (emulator / local dev) ──────────────────────────

  Future<T> _callFirebase<T>({
    required String functionName,
    dynamic data,
  }) async {
    try {
      debugPrint('[FunctionsClient:firebase] Calling $functionName');
      final callable = _functions.httpsCallable(functionName);
      final result = await callable.call(data);
      debugPrint('[FunctionsClient:firebase] Response from $functionName: ${result.data}');
      return result.data as T;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        '[FunctionsClient:firebase] Error [$functionName]: code=${e.code}, msg=${e.message}',
      );
      throw _mapFirebaseException(e);
    } catch (e, stack) {
      debugPrint('[FunctionsClient:firebase] Unknown error [$functionName]: $e\n$stack');
      throw UnknownFunctionsException(e.toString());
    }
  }

  // ── HTTP / Render path (production) ────────────────────────────────────────

  Future<T> _callHttp<T>({
    required String functionName,
    dynamic data,
  }) async {
    try {
      // 1. Get the current user's Firebase ID token.
      final user = _auth.currentUser;
      String? idToken;
      if (user != null) {
        idToken = await user.getIdToken();
      }

      // 2. Build the request.
      final uri = Uri.parse('$_backendUrl/api/$functionName');
      debugPrint('[FunctionsClient:http] POST $uri');

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (idToken != null) 'Authorization': 'Bearer $idToken',
      };

      // Mirror the Firebase Callable wire format: body is {"data": <payload>}.
      final body = jsonEncode({'data': data});

      // 3. Send request.
      final response = await _httpClient.post(uri, headers: headers, body: body);

      debugPrint('[FunctionsClient:http] Response ${response.statusCode} from $functionName');

      // 4. Parse response.
      final Map<String, dynamic> responseJson =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Success: body is {"result": <data>} (mirrors Firebase Callable response).
        final result = responseJson['result'];
        return result as T;
      } else {
        // Error: body is {"error": {"status": "...", "message": "..."}}.
        final error = responseJson['error'] as Map<String, dynamic>?;
        final status = error?['status'] as String? ?? 'unknown';
        final message = error?['message'] as String? ?? 'An error occurred.';
        debugPrint('[FunctionsClient:http] Error [$functionName]: status=$status, msg=$message');
        throw _mapHttpError(status, message);
      }
    } on FunctionsException {
      rethrow;
    } catch (e, stack) {
      debugPrint('[FunctionsClient:http] Unknown error [$functionName]: $e\n$stack');
      throw UnknownFunctionsException(e.toString());
    }
  }

  // ── Error mapping ───────────────────────────────────────────────────────────

  FunctionsException _mapFirebaseException(FirebaseFunctionsException e) {
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

  FunctionsException _mapHttpError(String status, String message) {
    return switch (status) {
      'permission-denied' || 'unauthenticated' => PermissionDeniedException(message),
      'invalid-argument' => InvalidArgumentException(message),
      'not-found' => NotFoundException(message),
      'failed-precondition' => PreconditionException(message),
      'already-exists' => ConflictException(message),
      _ => UnknownFunctionsException(message),
    };
  }
}

// ---------- Provider ----------

final functionsClientProvider = Provider<FunctionsClient>((ref) {
  return FunctionsClient();
});
