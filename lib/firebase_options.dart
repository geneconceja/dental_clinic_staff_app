/// firebase_options.dart
/// Dental Clinic Staff/Admin App
///
/// Builds FirebaseOptions from the .env file loaded by flutter_dotenv.
/// API keys and App IDs are loaded exclusively from the .env file — no
/// fallback values are hardcoded here so that production credentials are
/// never committed to source control.
///
/// For local development: copy .env.example → .env and fill in your values.
/// For CI/CD: inject .env values via GitHub Actions secrets.
///
/// Usage:
///   await Firebase.initializeApp(options: firebaseOptionsFromEnv());
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Returns a [FirebaseOptions] configured from `.env`.
/// Throws an assertion error in debug mode if a required key is missing.
FirebaseOptions firebaseOptionsFromEnv() {
  String require(String key) {
    final value = dotenv.env[key];
    assert(
      value != null && value.isNotEmpty,
      'Missing required environment variable: $key — copy .env.example to .env and fill in your Firebase credentials.',
    );
    return value ?? '';
  }

  String optional(String key, String fallback) {
    final value = dotenv.env[key];
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

  return FirebaseOptions(
    apiKey: require('FIREBASE_WEB_API_KEY'),
    appId: require('FIREBASE_WEB_APP_ID'),
    messagingSenderId: require('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: optional('FIREBASE_PROJECT_ID', 'oralscope-78cda'),
    authDomain: optional('FIREBASE_AUTH_DOMAIN', 'oralscope-78cda.firebaseapp.com'),
    storageBucket: optional('FIREBASE_STORAGE_BUCKET', 'oralscope-78cda.firebasestorage.app'),
    measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'] ?? '',
  );
}
