/// forgot_password_dialog.dart
/// Dental Clinic Staff/Admin App
///
/// Modal dialog for sending a password reset email link.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail});

  final String? initialEmail;

  static Future<bool?> show(BuildContext context, {String? initialEmail}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForgotPasswordDialog(initialEmail: initialEmail),
    );
  }

  @override
  ConsumerState<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .sendPasswordResetEmail(_emailController.text.trim());

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to send password reset email: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter your account email address. We will send you an email with a link to reset your password.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withAlpha(50)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'user@clinic.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email address is required';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Send Reset Link'),
        ),
      ],
    );
  }
}
