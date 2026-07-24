/// firebase_options.dart
/// Dental Clinic Staff/Admin App
///
/// Builds FirebaseOptions from the .env file loaded by flutter_dotenv.
/// This keeps Firebase API keys out of source control while still allowing
/// the app to be configured per environment.
///
/// Usage:
///   await Firebase.initializeApp(options: firebaseOptionsFromEnv());
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Returns a [FirebaseOptions] configured from `.env` or production fallbacks.
FirebaseOptions firebaseOptionsFromEnv() {
  String getValue(String key, String fallback) {
    final value = dotenv.env[key];
    if (value != null && value.isNotEmpty) return value;
    return fallback;
  }

  return FirebaseOptions(
    apiKey: getValue('FIREBASE_WEB_API_KEY', 'AIzaSyB20UmsoI1DIne0CDC-n9NSNf6_zt-MiXY'),
    appId: getValue('FIREBASE_WEB_APP_ID', '1:674648400625:web:1bc13a4d92f0a4f75abf50'),
    messagingSenderId: getValue('FIREBASE_MESSAGING_SENDER_ID', '674648400625'),
    projectId: getValue('FIREBASE_PROJECT_ID', 'oralscope-78cda'),
    authDomain: getValue('FIREBASE_AUTH_DOMAIN', 'oralscope-78cda.firebaseapp.com'),
    storageBucket: getValue('FIREBASE_STORAGE_BUCKET', 'oralscope-78cda.firebasestorage.app'),
    measurementId: dotenv.env['FIREBASE_WEB_MEASUREMENT_ID'] ?? 'G-XM74GVJ4HP',
  );
}
