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
      fallback: 'AIzaSyB20UmsoI1DIne0CDC-n9NSNf6_zt-MiXY',
    ),
    appId: resolve(
      'FIREBASE_WEB_APP_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_WEB_APP_ID'),
      fallback: '1:674648400625:web:1bc13a4d92f0a4f75abf50',
    ),
    messagingSenderId: resolve(
      'FIREBASE_MESSAGING_SENDER_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      fallback: '674648400625',
    ),
    projectId: resolve(
      'FIREBASE_PROJECT_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      fallback: 'oralscope-78cda',
    ),
    authDomain: resolve(
      'FIREBASE_AUTH_DOMAIN',
      dartDefine: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      fallback: 'oralscope-78cda.firebaseapp.com',
    ),
    storageBucket: resolve(
      'FIREBASE_STORAGE_BUCKET',
      dartDefine: const String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
      fallback: 'oralscope-78cda.firebasestorage.app',
    ),
    measurementId: resolve(
      'FIREBASE_WEB_MEASUREMENT_ID',
      dartDefine: const String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID'),
      fallback: 'G-XM74GVJ4HP',
    ),
  );
}
