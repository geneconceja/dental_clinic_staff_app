/// email_verification_gate_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Shown immediately after patient sign-up. Blocks portal access until the
/// patient clicks the Firebase email-verification link.
///
/// Flow:
///   1. Screen loads → auto-checks Firebase Auth. If already verified (e.g.
///      emulator UI shortcut, or returning from email link), syncs Firestore
///      and redirects immediately with no user action required.
///   2. Otherwise patient sees their email address + instructions.
///   3. "Resend Email" → re-sends verification link (60-second cooldown).
///   4. "I've Verified My Email" → calls reloadAndCheckVerified():
///      • Verified  → markPatientVerified() → GoRouter guard redirects.
///      • Not yet   → shows a friendly inline message.
///   5. "Use a different account" → signs out → back to /login.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

// ---------- Screen ----------

class EmailVerificationGateScreen extends ConsumerStatefulWidget {
  const EmailVerificationGateScreen({super.key});

  @override
  ConsumerState<EmailVerificationGateScreen> createState() =>
      _EmailVerificationGateScreenState();
}

class _EmailVerificationGateScreenState
    extends ConsumerState<EmailVerificationGateScreen>
    with TickerProviderStateMixin {
  // Resend cooldown
  static const _cooldownSeconds = 60;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  bool _isChecking = false;
  bool _isResending = false;
  String? _statusMessage;
  bool _statusIsError = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Auto-check on mount: if Firebase Auth already shows emailVerified=true
    // (e.g. user verified via emulator UI, or returned from the email link
    // in another tab), sync Firestore and redirect without any button tap.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckOnLoad());
  }

  Future<void> _autoCheckOnLoad() async {
    // Reload token from server first so we get the latest emailVerified state.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await user.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!verified) return; // not yet verified — show the gate normally
    // Already verified — sync Firestore and redirect silently.
    await _completeVerification(showLoader: false);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ---------- Resend ----------

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _statusMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      _startCooldown();
      _showStatus('Verification email sent! Check your inbox.', isError: false);
    } on AuthException catch (e) {
      _showStatus(e.message, isError: true);
    } catch (_) {
      _showStatus('Could not resend email. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = _cooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  // ---------- Check verification ----------

  /// Called by the "I've Verified My Email" button.
  Future<void> _checkVerified() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      final verified = await repo.reloadAndCheckVerified();

      if (!verified) {
        _showStatus(
          'Email not verified yet. Please check your inbox and click the link.',
          isError: true,
        );
        return;
      }

      await _completeVerification(showLoader: false);
    } catch (_) {
      _showStatus('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Shared completion path: update Firestore, invalidate the profile cache,
  /// and navigate to the patient dashboard.
  ///
  /// [showLoader] controls whether we set _isChecking (not needed when called
  /// from _autoCheckOnLoad since the screen may not be fully built yet).
  Future<void> _completeVerification({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _isChecking = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await repo.markPatientVerified(uid);
      }
      // Invalidate the cached staff/patient profile so the router re-evaluates.
      ref.invalidate(staffProfileProvider);
      if (mounted) context.go('/patient/dashboard');
    } catch (_) {
      if (mounted) {
        _showStatus('Something went wrong. Please try again.', isError: true);
      }
    } finally {
      if (mounted && showLoader) setState(() => _isChecking = false);
    }
  }

  void _showStatus(String msg, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = msg;
      _statusIsError = isError;
    });
  }

  // ---------- Sign out ----------

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/login');
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Decorative gradient circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight.withValues(alpha: 0.07),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? (screenWidth - 480) / 2 : 24,
                  vertical: 48,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Animated envelope icon
                    Center(
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Heading
                    Text(
                      'Check your inbox',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'We sent a verification link to\n'),
                          TextSpan(
                            text: email,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const TextSpan(
                            text:
                                '\n\nClick the link in the email, then come back here.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Card with action buttons
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Steps hint
                          _StepRow(
                            number: '1',
                            text: 'Open the email from OralScope Dental.',
                          ),
                          const SizedBox(height: 10),
                          _StepRow(
                            number: '2',
                            text: 'Click "Verify email address" in the email.',
                          ),
                          const SizedBox(height: 10),
                          _StepRow(
                            number: '3',
                            text: 'Come back and tap the button below.',
                          ),
                          const SizedBox(height: 24),

                          // Status message
                          if (_statusMessage != null) ...[
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _statusIsError
                                    ? AppColors.errorLight
                                    : AppColors.successLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _statusIsError
                                      ? AppColors.error.withValues(alpha: 0.3)
                                      : AppColors.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _statusIsError
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    color: _statusIsError
                                        ? AppColors.error
                                        : AppColors.success,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _statusMessage!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _statusIsError
                                            ? AppColors.error
                                            : AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // "I've verified" primary button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _isChecking ? null : _checkVerified,
                              icon: _isChecking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.verified_outlined, size: 20),
                              label: Text(
                                _isChecking
                                    ? 'Checking…'
                                    : "I've Verified My Email",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.primary.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Resend button
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: (_isResending || _resendCooldown > 0)
                                  ? null
                                  : _resendEmail,
                              icon: _isResending
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            AppColors.primary),
                                      ),
                                    )
                                  : const Icon(Icons.send_outlined, size: 18),
                              label: Text(
                                _resendCooldown > 0
                                    ? 'Resend in ${_resendCooldown}s'
                                    : _isResending
                                        ? 'Sending…'
                                        : 'Resend Verification Email',
                                style: const TextStyle(fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign out link
                    Center(
                      child: TextButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Use a different account'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Step row widget ----------

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
