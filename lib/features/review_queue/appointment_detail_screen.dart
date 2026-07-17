/// appointment_detail_screen.dart
/// Dental Clinic Staff/Admin App
///
/// View component displaying all details of an appointment document.
/// Provides status triggers (Confirm, Cancel, Complete, No-Show) and
/// inline metadata edits (payment status toggle, staff notes update).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/functions_client.dart';
import '../../core/utils/time_formatter.dart';
import '../../routing/app_router.dart';
import 'appointments_repository.dart';
import 'status_functions.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointmentId,
  });

  final String appointmentId;

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  bool _isProcessing = false;
  final _notesController = TextEditingController();
  bool _isEditingNotes = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // ---------- Action Callers ----------

  Future<void> _updateStatus(String newStatus, {String? reason}) async {
    setState(() => _isProcessing = true);
    try {
      final functions = ref.read(statusFunctionsProvider);
      await functions.updateStatus(
        appointmentId: widget.appointmentId,
        newStatus: newStatus,
        cancellationReason: reason,
      );

      if (mounted) {
        final displayStatus = switch (newStatus) {
          'confirmed' => 'confirmed',
          'completed' => 'marked as completed',
          'no-show' => 'marked as no-show',
          'cancelled' => 'cancelled',
          _ => 'updated',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment $displayStatus.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ConflictException catch (e) {
      if (mounted) {
        _showErrorDialog('Slot Conflict', e.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Action Failed',
          e.toString().replaceAll('FunctionsException: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _togglePaid(bool paid) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(appointmentsRepositoryProvider);
      await repo.updatePaymentStatus(widget.appointmentId, paid);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Update Failed', 'Failed to update payment status: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(appointmentsRepositoryProvider);
      await repo.updateNotes(
        widget.appointmentId,
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      setState(() => _isEditingNotes = false);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Update Failed', 'Failed to update notes: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ---------- Dialog Helpers ----------

  void _showDeclineDialog() {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Please provide a cancellation reason. The patient will be notified.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Schedule conflict, Doctor unavailable',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              final r = reasonController.text.trim();
              Navigator.of(ctx).pop();
              _updateStatus('cancelled', reason: r.isEmpty ? 'Cancelled by staff' : r);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _confirmAction({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    Color? confirmButtonColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            style: confirmButtonColor != null
                ? ElevatedButton.styleFrom(backgroundColor: confirmButtonColor)
                : null,
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ---------- UI Builder ----------

  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(watchAppointmentByIdProvider(widget.appointmentId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(AppRoutes.dashboard),
        ),
      ),
      body: appointmentAsync.when(
        data: (appt) {
          if (appt == null) {
            return const Center(child: Text('Appointment not found.'));
          }

          // Sync text field only if not editing currently
          if (!_isEditingNotes) {
            _notesController.text = appt.notes ?? '';
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;

                        if (isWide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Area
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _buildInfoCard(appt, theme),
                                    const SizedBox(height: 20),
                                    if (appt.imageUrl != null) ...[
                                      _buildDiagnosticCard(appt, theme),
                                      const SizedBox(height: 20),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Right Area
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    _buildActionCenterCard(appt, theme),
                                    const SizedBox(height: 20),
                                    _buildNotesCard(appt, theme),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Narrow View Stack
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildInfoCard(appt, theme),
                              const SizedBox(height: 20),
                              if (appt.imageUrl != null) ...[
                                _buildDiagnosticCard(appt, theme),
                                const SizedBox(height: 20),
                              ],
                              _buildActionCenterCard(appt, theme),
                              const SizedBox(height: 20),
                              _buildNotesCard(appt, theme),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black12,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading appointment: $err', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  // ---------- Component Cards ----------

  Widget _buildInfoCard(Appointment appt, ThemeData theme) {
    final statusConfig = _getStatusColors(appt.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Source badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    appt.bookingSource == BookingSource.staffWalkin ? 'Walk-In Booking' : 'Patient App Booking',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusConfig.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusConfig.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusConfig.fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Patient Name Header
            Text(appt.patientFullName, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),

            // Contacts
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(appt.phoneNumber, style: theme.textTheme.bodyMedium),
                if (appt.userEmail != null) ...[
                  const SizedBox(width: 24),
                  const Icon(Icons.email_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(appt.userEmail!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Date & Time Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DATE & TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(
                        '${appt.date} • ${format12Hour(appt.startTime)} - ${format12Hour(appt.endTime)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SERVICE REQUESTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Text(
                        appt.serviceName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (appt.cancellationReason != null) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CANCELLATION REASON', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(
                      appt.cancellationReason!,
                      style: const TextStyle(fontSize: 14, color: AppColors.error, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosticCard(Appointment appt, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('Diagnostic Review Image', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            // Diagnostic analysis tags
            if (appt.analysisResults != null && appt.analysisResults!.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: appt.analysisResults!.map((result) {
                  final confidencePct = (result.confidence * 100).toStringAsFixed(0);
                  return Chip(
                    avatar: const Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                    label: Text('${result.tag} ($confidencePct%)'),
                    backgroundColor: AppColors.successLight,
                    side: BorderSide(color: AppColors.success.withAlpha(40)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ] else ...[
              const Text('No diagnostic candidate tags detected.', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
            ],

            // Cloudinary Image Loader
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                appt.imageUrl!,
                height: 380,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 380,
                    color: AppColors.surfaceVariant,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, err, stack) {
                  return Container(
                    height: 180,
                    color: AppColors.errorLight,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 40, color: AppColors.error),
                        SizedBox(height: 8),
                        Text('Failed to load patient uploaded image', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCenterCard(Appointment appt, ThemeData theme) {
    final showConfirmDecline = appt.status == AppointmentStatus.pending;
    final showConfirmedActions = appt.status == AppointmentStatus.confirmed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Action Center', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),

            // Billing Status Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Text(
                      appt.paid ? 'PAID' : 'UNPAID',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: appt.paid ? AppColors.success : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: appt.paid,
                      activeThumbColor: AppColors.success,
                      onChanged: (val) => _togglePaid(val),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Status Actions
            if (showConfirmDecline) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Confirm Appointment'),
                onPressed: () => _updateStatus('confirmed'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, color: AppColors.error),
                label: const Text('Decline Request'),
                onPressed: _showDeclineDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ] else if (showConfirmedActions) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.done_all),
                label: const Text('Mark Completed'),
                onPressed: () {
                  _confirmAction(
                    title: 'Mark Completed',
                    message: 'Are you sure you want to mark this appointment as completed?',
                    onConfirm: () => _updateStatus('completed'),
                    confirmButtonColor: AppColors.success,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_off_outlined),
                label: const Text('Mark No-Show'),
                onPressed: () {
                  _confirmAction(
                    title: 'Mark No-Show',
                    message: 'Are you sure you want to mark this appointment as a no-show?',
                    onConfirm: () => _updateStatus('no-show'),
                    confirmButtonColor: AppColors.warning,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, color: AppColors.error),
                label: const Text('Cancel Appointment'),
                onPressed: _showDeclineDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No status actions available for terminal states.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(Appointment appt, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Staff Notes', style: theme.textTheme.titleMedium),
                if (!_isEditingNotes)
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    onPressed: () => setState(() => _isEditingNotes = true),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditingNotes) ...[
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  hintText: 'Type internal clinical or coordination notes...',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _isEditingNotes = false;
                      _notesController.text = appt.notes ?? '';
                    }),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveNotes,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              Text(
                appt.notes ?? 'No internal staff notes recorded.',
                style: TextStyle(
                  fontStyle: appt.notes == null ? FontStyle.italic : FontStyle.normal,
                  color: appt.notes == null ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- Private Color Getter ----------

  _StatusConfig _getStatusColors(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => _StatusConfig(AppColors.statusPending, AppColors.warningLight, 'Pending Review'),
      AppointmentStatus.confirmed => _StatusConfig(AppColors.statusConfirmed, AppColors.successLight, 'Confirmed'),
      AppointmentStatus.cancelled => _StatusConfig(AppColors.statusCancelled, AppColors.errorLight, 'Cancelled'),
      AppointmentStatus.completed => _StatusConfig(AppColors.statusCompleted, AppColors.infoLight, 'Completed'),
      AppointmentStatus.noShow => _StatusConfig(AppColors.statusNoShow, AppColors.surfaceVariant, 'No-Show'),
    };
  }
}

class _StatusConfig {
  const _StatusConfig(this.fg, this.bg, this.label);
  final Color fg;
  final Color bg;
  final String label;
}

// ---------- Private Family Streams ----------

final watchAppointmentByIdProvider = StreamProvider.family<Appointment?, String>((ref, id) {
  final repo = ref.watch(appointmentsRepositoryProvider);
  return repo.watchAppointmentById(id);
});
