/// sso_exchange_screen.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Single Sign-On (SSO) token exchange view. Handles incoming mobile handoff
/// links (/#/sso?token=sso_code_xyz123&target=/patient/book), consumes the token via
/// Cloud Function, authenticates the patient via custom token, and redirects.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../routing/app_router.dart';
import 'auth_providers.dart';

class SsoExchangeScreen extends ConsumerStatefulWidget {
  const SsoExchangeScreen({
    super.key,
    required this.token,
    required this.targetPath,
  });

  final String token;
  final String targetPath;

  @override
  ConsumerState<SsoExchangeScreen> createState() => _SsoExchangeScreenState();
}

class _SsoExchangeScreenState extends ConsumerState<SsoExchangeScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performSsoExchange();
  }

  Future<void> _performSsoExchange() async {
    if (widget.token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid SSO link: No exchange token provided.';
      });
      return;
    }

    try {
      // 1. Consume SSO token via Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('consumeSsoToken');
      final result = await callable.call<Map<String, dynamic>>({
        'ssoToken': widget.token,
      });

      final customToken = result.data['customToken'] as String?;
      final targetPath = (result.data['targetPath'] as String?) ?? widget.targetPath;

      if (customToken == null || customToken.isEmpty) {
        throw Exception('Server failed to return custom authentication token.');
      }

      // 2. Authenticate patient with Custom Auth Token
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      // 3. Invalidate auth providers so Riverpod updates immediately
      ref.invalidate(authStateProvider);
      ref.invalidate(staffProfileProvider);

      if (mounted) {
        // 4. Redirect to target path
        final destination = targetPath.startsWith('/patient') ? targetPath : '/patient/dashboard';
        context.go(destination);
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e is FirebaseFunctionsException
            ? e.message ?? e.code
            : e.toString().replaceAll('Exception: ', '');

        setState(() {
          _isLoading = false;
          _errorMessage = cleanMsg;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_hospital_outlined, color: AppColors.primary, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Dental Clinic Portal',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),

                    if (_isLoading) ...[
                      const Text(
                        'Authenticating your session from mobile app...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 28),
                      const CircularProgressIndicator(),
                    ] else ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage ?? 'SSO Transfer Failed',
                                style: const TextStyle(fontSize: 13, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => context.goNamed(AppRoutes.login),
                        icon: const Icon(Icons.login),
                        label: const Text('Proceed to Manual Sign-In'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
