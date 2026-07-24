/// firebase_emulator.dart
/// Dental Clinic Staff/Admin App
///
/// Configures all Firebase SDKs to point to the local emulator suite when
/// running in dev mode (i.e. --dart-define=ENV=dev).
///
/// Call [configureEmulators] once from main(), before any Firebase SDK calls.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// Emulator ports — must match firebase.json / emulator startup config.
final String _emulatorHost = kIsWeb ? 'localhost' : '127.0.0.1';
const int _authPort = 9099;
const int _firestorePort = 8080;
const int _functionsPort = 5001;

/// Points all Firebase SDKs at the local emulator suite.
///
/// Only call this when [ENV] dart-define is "dev". The emulator host is
/// always localhost — this is not intended for use on physical devices
/// or in production builds.
Future<void> configureEmulators() async {
  // Auth emulator
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);

  // Firestore emulator
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);

  // Functions emulator
  FirebaseFunctions.instance.useFunctionsEmulator(_emulatorHost, _functionsPort);
  FirebaseFunctions.instanceFor(region: 'asia-southeast1').useFunctionsEmulator(_emulatorHost, _functionsPort);
}
