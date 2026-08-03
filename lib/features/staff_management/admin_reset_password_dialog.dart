/// admin_reset_password_dialog.dart
/// Dental Clinic Staff/Admin App
///
/// Modal dialog allowing Admins to force-reset a staff member's password directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/staff_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/functions_client.dart';

class AdminResetPasswordDialog extends ConsumerStatefulWidget {
  const AdminResetPasswordDialog({super.key, required this.staffUser});

  final StaffUser staffUser;

  static Future<bool?> show(BuildContext context, StaffUser staffUser) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminResetPasswordDialog(staffUser: staffUser),
    );
  }

  @override
  ConsumerState<AdminResetPasswordDialog> createState() =>
      _AdminResetPasswordDialogState();
}

class _AdminResetPasswordDialogState
    extends ConsumerState<AdminResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();

  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
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
      final client = ref.read(functionsClientProvider);
      await client.call(
        functionName: 'adminResetPassword',
        data: {
          'targetUid': widget.staffUser.uid,
          'newPassword': _newPasswordController.text,
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on InvalidArgumentException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } on PermissionDeniedException {
      setState(() {
        _errorMessage = 'Only administrators can reset staff passwords.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to reset password: $e';
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
      title: Text('Reset Password for ${widget.staffUser.name}'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set a new password for account (${widget.staffUser.email}).',
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.textSecondary),
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

                // New Password
                TextFormField(
                  controller: _newPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Temporary Password *',
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
                      return 'Password is required';
                    }
                    if (val.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !_isLoading,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
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
                      return 'Please confirm the password';
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
              : const Icon(Icons.vpn_key),
          label: const Text('Reset Password'),
        ),
      ],
    );
  }
}
