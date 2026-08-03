/// staff_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Administrative interface for staff account management.
/// Allows admins to view staff profile details, promote/demote user roles,
/// and activate/deactivate accounts. Toggles are guarded to prevent
/// self-lockout/self-demotion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/staff_user.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_providers.dart';
import '../auth/change_password_dialog.dart';
import 'add_staff_dialog.dart';
import 'admin_reset_password_dialog.dart';
import 'staff_repository.dart';


/// StreamProvider for active and inactive staff users
final allStaffProvider = StreamProvider<List<StaffUser>>((ref) {
  return ref.watch(staffRepositoryProvider).watchStaffUsers();
});

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  @override
  Widget build(BuildContext context) {
    final allStaffAsync = ref.watch(allStaffProvider);
    final currentAuthUser = ref.watch(authStateProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            tooltip: 'Change My Password',
            icon: const Icon(Icons.lock_reset),
            onPressed: () async {
              final changed = await ChangePasswordDialog.show(context);
              if (changed == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your password has been updated successfully.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                final created = await AddStaffDialog.show(context);
                if (created == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Staff member account created successfully.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff Member'),
            ),
          ),
        ],
      ),

      body: allStaffAsync.when(

        data: (staffList) {
          if (staffList.isEmpty) {
            return const Center(child: Text('No staff members registered.'));
          }

          final screenWidth = MediaQuery.of(context).size.width;
          final crossAxisCount = screenWidth > 1200
              ? 3
              : screenWidth > 800
                  ? 2
                  : 1;

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              mainAxisExtent: screenWidth < 600 ? 230 : 220,
            ),
            itemCount: staffList.length,
            itemBuilder: (_, index) {
              final staff = staffList[index];
              final isCurrentUser = currentAuthUser?.uid == staff.uid;

              return _StaffCard(
                staff: staff,
                isCurrentUser: isCurrentUser,
                onToggleActive: (active) async {
                  if (isCurrentUser) return; // Guard
                  try {
                    await ref
                        .read(staffRepositoryProvider)
                        .toggleStaffActive(staff.uid, active);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to toggle status: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                onRoleChanged: (newRole) async {
                  if (isCurrentUser) return; // Guard
                  if (newRole == null) return;
                  try {
                    await ref
                        .read(staffRepositoryProvider)
                        .updateStaffRole(staff.uid, newRole);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update role: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading staff list: $err',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }
}

// ── Staff Member Card Widget ───────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.staff,
    required this.isCurrentUser,
    required this.onToggleActive,
    required this.onRoleChanged,
  });

  final StaffUser staff;
  final bool isCurrentUser;
  final ValueChanged<bool> onToggleActive;
  final ValueChanged<StaffRole?> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row 1: Name + Role Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    staff.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: staff.active
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _RoleBadge(role: staff.role),
              ],
            ),
            const SizedBox(height: 6),

            // Contact info
            Text(
              staff.email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              staff.phone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),

            // Row 3: Admin Toggles & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Role picker (demoted/promoted)
                isCurrentUser
                    ? Text(
                        'Self (Role: ${staff.role.name})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<StaffRole>(
                          initialValue: staff.role,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                            labelText: 'Role',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: StaffRole.staff,
                              child: Text('Staff'),
                            ),
                            DropdownMenuItem(
                              value: StaffRole.admin,
                              child: Text('Admin'),
                            ),
                          ],
                          onChanged: onRoleChanged,
                        ),
                      ),

                Row(
                  children: [
                    // Reset Password Button (Admin override)
                    IconButton(
                      tooltip: 'Reset Password',
                      icon: const Icon(Icons.vpn_key_outlined, size: 20),
                      onPressed: () async {
                        final reset = await AdminResetPasswordDialog.show(
                          context,
                          staff,
                        );
                        if (reset == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Password reset for ${staff.name} successfully.',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                    ),

                    // Active Switch
                    Text(
                      staff.active ? 'Active' : 'Inactive',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: staff.active
                            ? AppColors.success
                            : AppColors.textDisabled,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      value: staff.active,
                      activeTrackColor: AppColors.primary.withAlpha(120),
                      activeThumbColor: AppColors.primary,
                      onChanged: isCurrentUser ? null : onToggleActive,
                    ),
                  ],
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}

// ── Role Badge Sub-widget ───────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final StaffRole role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == StaffRole.admin;
    final color = isAdmin ? AppColors.primary : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'STAFF',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
