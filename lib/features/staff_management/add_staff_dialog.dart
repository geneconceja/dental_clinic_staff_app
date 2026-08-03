/// add_staff_dialog.dart
/// Dental Clinic Staff/Admin App
///
/// Modal dialog for creating a new staff or admin user account.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/staff_user.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/functions_client.dart';
import 'staff_functions.dart';

class AddStaffDialog extends ConsumerStatefulWidget {
  const AddStaffDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddStaffDialog(),
    );
  }

  @override
  ConsumerState<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends ConsumerState<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  StaffRole _selectedRole = StaffRole.staff;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(staffFunctionsProvider).createStaffUser(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            role: _selectedRole,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ConflictException {
      setState(() {
        _errorMessage = 'The email address is already registered.';
      });
    } on InvalidArgumentException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } on PermissionDeniedException {
      setState(() {
        _errorMessage = 'You do not have permission to create staff accounts.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create staff account: $e';
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
      title: const Text('Add Staff Member'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
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

                // Full Name
                TextFormField(
                  controller: _nameController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Dr. Sarah Jenkins',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'staff@clinic.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: '09171234567',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Temporary Password *',
                    hintText: 'At least 8 characters',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
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

                // Role Dropdown
                DropdownButtonFormField<StaffRole>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(

                    labelText: 'Account Role *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: StaffRole.staff,
                      child: Text('Staff (Standard Desk / Review Queue Access)'),
                    ),
                    DropdownMenuItem(
                      value: StaffRole.admin,
                      child: Text('Admin (Full Administrative & Settings Access)'),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (newRole) {
                          if (newRole != null) {
                            setState(() {
                              _selectedRole = newRole;
                            });
                          }
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
              : const Icon(Icons.person_add),
          label: const Text('Create Account'),
        ),
      ],
    );
  }
}
