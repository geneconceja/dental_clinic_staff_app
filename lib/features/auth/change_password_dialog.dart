/// change_password_dialog.dart
/// Dental Clinic Staff/Admin App
///
/// Modal dialog for logged-in users (Patient, Staff, Admin) to change their password.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
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
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                // Current Password
                TextFormField(
                  controller: _currentPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrent
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureCurrent = !_obscureCurrent;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Current password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // New Password
                TextFormField(
                  controller: _newPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password *',
                    hintText: 'At least 8 characters',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureNew = !_obscureNew;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'New password is required';
                    }
                    if (val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    if (val == _currentPasswordController.text) {
                      return 'New password must be different from current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm New Password
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_reset),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please confirm your new password';
                    }
                    if (val != _newPasswordController.text) {
                      return 'Passwords do not match';
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
              : const Icon(Icons.check_circle_outline),
          label: const Text('Update Password'),
        ),
      ],
    );
  }
}
