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
    await dotenv.load(fileName: 'assets/.env');
  } catch (_) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('[Main] dotenv load skipped or failed: $e');
    }
  }

  final options = firebaseOptionsFromEnv();

  // Guard against missing API key in web builds (e.g. if GitHub secret is not yet set)
  if (options.apiKey.isEmpty) {
    debugPrint(
      '[Bootstrap Error] Firebase Web API Key is missing!\n'
      'For CI/CD: Ensure FIREBASE_WEB_API_KEY is configured in GitHub repository secrets.\n'
      'For local dev: Pass --dart-define=FIREBASE_WEB_API_KEY=<key> or configure assets/.env.',
    );
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 54, color: Colors.amber),
                      const SizedBox(height: 16),
                      const Text(
                        'Firebase Configuration Required',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The Firebase Web API Key has not been configured. '
                        'Please add FIREBASE_WEB_API_KEY to your GitHub Repository Secrets '
                        '(Settings → Secrets and variables → Actions) and re-trigger the workflow.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: options);

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
