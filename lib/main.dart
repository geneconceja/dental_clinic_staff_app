/// main.dart
/// Dental Clinic Staff/Admin App
///
/// Entry point. Initializes Firebase from .env, conditionally wires emulators
/// in dev mode, then launches the app under a Riverpod ProviderScope.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/firebase_emulator.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'core/theme/app_theme.dart';

// Dart-define injected at build time:
//   flutter run  --dart-define=ENV=dev
//   flutter build web --dart-define=ENV=prod
const String _env = String.fromEnvironment('ENV', defaultValue: 'prod');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env before any Firebase SDK call (fail silently on web release if asset missing)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[Main] dotenv load skipped or failed: $e');
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: firebaseOptionsFromEnv());

  // Point all SDKs at the local emulator when running in dev mode
  if (_env == 'dev') {
    await configureEmulators();
  }

  runApp(
    const ProviderScope(
      child: _DentalClinicStaffApp(),
    ),
  );
}

class _DentalClinicStaffApp extends ConsumerWidget {
  const _DentalClinicStaffApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'OralScope — Staff Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
