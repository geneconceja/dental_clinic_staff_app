/// review_queue_screen.dart
/// Dental Clinic Staff/Admin App
///
/// View component displaying all patient-submitted appointment requests.
/// Allows staff to instantly confirm or navigate to the detailed review view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/functions_client.dart';
import '../../routing/app_router.dart';
import 'appointments_repository.dart';
import 'appointment_card.dart';
import 'status_functions.dart';

class ReviewQueueScreen extends ConsumerStatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  ConsumerState<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends ConsumerState<ReviewQueueScreen> {
  bool _isProcessing = false;

  Future<void> _confirmAppointment(String id, String patientName) async {
    setState(() => _isProcessing = true);
    try {
      final functions = ref.read(statusFunctionsProvider);
      await functions.updateStatus(
        appointmentId: id,
        newStatus: 'confirmed',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appointment for $patientName has been confirmed.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on ConflictException catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Slot Conflict',
          '${e.message}\n\nPlease review the details page to reschedule or resolve the conflict.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Confirmation Failed',
          e.toString().replaceAll('FunctionsException: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingAppointmentsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
      ),
      body: Stack(
        children: [
          pendingAsync.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return _buildEmptyState(theme);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth <= 600;

                  if (isMobile) {
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: appointments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final appt = appointments[index];
                        return AppointmentCard(
                          appointment: appt,
                          onConfirm: () => _confirmAppointment(appt.id, appt.patientFullName),
                          onReview: () => context.goNamed(
                            AppRoutes.appointmentDetail,
                            pathParameters: {'id': appt.id},
                          ),
                        );
                      },
                    );
                  }

                  final crossAxisCount = constraints.maxWidth > 900 ? 2 : 1;

                  return GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      mainAxisExtent: 260,
                    ),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final appt = appointments[index];
                      return AppointmentCard(
                        appointment: appt,
                        onConfirm: () => _confirmAppointment(appt.id, appt.patientFullName),
                        onReview: () => context.goNamed(
                          AppRoutes.appointmentDetail,
                          pathParameters: {'id': appt.id},
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load pending queue.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$err',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black12,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Queue Clean!',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All patient-submitted booking requests have been reviewed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
