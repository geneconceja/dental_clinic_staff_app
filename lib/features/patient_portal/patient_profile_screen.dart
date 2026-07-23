/// patient_profile_screen.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Patient profile management screen allowing patients to inspect their account
/// details and edit their name & phone number.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../auth/auth_providers.dart';
import 'patient_providers.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _isSaving = false;
  String? _successMessage;
  String? _errorMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populateFormOnce() {
    if (_initialized) return;
    final profile = ref.read(staffProfileProvider).asData?.value;
    if (profile != null) {
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _initialized = true;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final profile = ref.read(staffProfileProvider).asData?.value;
    if (profile == null) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(patientRepositoryProvider).updatePatientProfile(
            patientUid: profile.uid,
            name: _nameController.text,
            phone: _phoneController.text,
          );

      // Invalidate profile provider so UI updates
      ref.invalidate(staffProfileProvider);

      setState(() => _successMessage = 'Profile updated successfully!');
    } catch (e) {
      setState(() => _errorMessage = 'Failed to update profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _populateFormOnce();
    final profile = ref.watch(staffProfileProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'My Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage your account information and contact preferences.',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),

                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_successMessage != null) ...[
                            _buildBanner(_successMessage!, isError: false),
                            const SizedBox(height: 16),
                          ],
                          if (_errorMessage != null) ...[
                            _buildBanner(_errorMessage!, isError: true),
                            const SizedBox(height: 16),
                          ],

                          // Read-only email
                          TextFormField(
                            initialValue: profile?.email ?? '',
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Email Address (Account Identifier)',
                              prefixIcon: Icon(Icons.email_outlined),
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name field
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Full name is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone field
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                              hintText: '09171234567',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Phone number is required.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),

                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(_isSaving ? 'Saving...' : 'Save Profile Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(String message, {required bool isError}) {
    final bgColor = isError ? AppColors.errorLight : AppColors.successLight;
    final fgColor = isError ? AppColors.error : AppColors.success;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fgColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: fgColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fgColor, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
