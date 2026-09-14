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

/// Returns a [FirebaseOptions] configured from `.env`, `--dart-define`,
/// or standard platform fallbacks for the OralScope project.
FirebaseOptions firebaseOptionsFromEnv() {
  String resolve(String key, {String? dartDefine, String fallback = ''}) {
    final value = dotenv.env[key];
    if (value != null && value.isNotEmpty) return value;
    if (dartDefine != null && dartDefine.isNotEmpty) return dartDefine;
    return fallback;
  }

  return FirebaseOptions(
    apiKey: resolve(
      'FIREBASE_WEB_API_KEY',
      dartDefine: const String.fromEnvironment('FIREBASE_WEB_API_KEY'),
      fallback: '',
    ),
    appId: resolve(
      'FIREBASE_WEB_APP_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
      fallback: '1:703472694816:web:49629b64cbffbb6eadae45',
    ),
    messagingSenderId: resolve(
      'FIREBASE_MESSAGING_SENDER_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      fallback: '703472694816',
    ),
    projectId: resolve(
      'FIREBASE_PROJECT_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      fallback: 'dental-clinic-ams',
    ),
    authDomain: resolve(
      'FIREBASE_AUTH_DOMAIN',
      dartDefine: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      fallback: 'dental-clinic-ams.firebaseapp.com',
    ),
    storageBucket: resolve(
      'FIREBASE_STORAGE_BUCKET',
      dartDefine: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      fallback: 'dental-clinic-ams.firebasestorage.app',
    ),
    measurementId: resolve(
      'FIREBASE_WEB_MEASUREMENT_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID'),
      fallback: '',
    ),
  );
}
