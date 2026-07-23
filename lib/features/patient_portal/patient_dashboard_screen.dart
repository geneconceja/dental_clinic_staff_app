/// patient_dashboard_screen.dart
/// Dental Clinic Staff/Admin App — Patient Portal
///
/// Overview dashboard for patients featuring a welcome hero banner,
/// next upcoming appointment highlight card, quick action cards, and
/// recent appointment history list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/appointment.dart';
import '../../core/theme/app_colors.dart';
import '../../routing/app_router.dart';
import '../auth/auth_providers.dart';
import 'patient_providers.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(staffProfileProvider);
    final profile = profileAsync.asData?.value;
    final patientName = profile != null ? profile.name : 'Patient';

    final upcomingAppt = ref.watch(nextUpcomingAppointmentProvider);
    final allApptsAsync = ref.watch(patientAppointmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------- Welcome Hero Banner ----------
                _buildHeroBanner(patientName),
                const SizedBox(height: 24),

                // ---------- Upcoming Appointment Highlight ----------
                _buildUpcomingCard(context, upcomingAppt),
                const SizedBox(height: 28),

                // ---------- Quick Actions ----------
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQuickActionCards(context),
                const SizedBox(height: 32),

                // ---------- Recent Activity ----------
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecentActivityList(context, allApptsAsync),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Welcome Hero Banner ----------

  Widget _buildHeroBanner(String patientName) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $patientName! 👋',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your dental visits, check upcoming schedule, and book new appointments easily.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.health_and_safety_outlined, size: 64, color: Colors.white24),
        ],
      ),
    );
  }

  // ---------- Upcoming Appointment Card ----------

  Widget _buildUpcomingCard(BuildContext context, Appointment? appt) {
    if (appt == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available, color: AppColors.primary, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No Upcoming Appointments',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Keep your smile healthy! Schedule your next dental checkup today.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.goNamed(AppRoutes.patientBook),
                icon: const Icon(Icons.add),
                label: const Text('Book Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isConfirmed = appt.status == AppointmentStatus.confirmed;
    final statusColor = isConfirmed ? AppColors.statusConfirmed : AppColors.statusPending;
    final statusText = isConfirmed ? 'CONFIRMED' : 'PENDING APPROVAL';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: statusColor, width: 6)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                Text(
                  'Ref ID: ${appt.id}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              appt.serviceName.isNotEmpty ? appt.serviceName : appt.reason,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(appt.date, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(width: 20),
                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('${appt.startTime} - ${appt.endTime}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.goNamed(AppRoutes.patientAppointments),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View All Appointments'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Quick Action Cards ----------

  Widget _buildQuickActionCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return GridView.count(
          crossAxisCount: isCompact ? 1 : 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isCompact ? 3.0 : 1.6,
          children: [
            _QuickActionTile(
              title: 'Book Appointment',
              subtitle: 'Select date & preferred time slot',
              icon: Icons.calendar_month_outlined,
              color: AppColors.primary,
              onTap: () => context.goNamed(AppRoutes.patientBook),
            ),
            _QuickActionTile(
              title: 'My Appointments',
              subtitle: 'View history & cancellation status',
              icon: Icons.event_note_outlined,
              color: AppColors.info,
              onTap: () => context.goNamed(AppRoutes.patientAppointments),
            ),
            _QuickActionTile(
              title: 'My Profile',
              subtitle: 'Update phone number & personal details',
              icon: Icons.person_outline,
              color: AppColors.accent,
              onTap: () => context.goNamed(AppRoutes.patientProfile),
            ),
          ],
        );
      },
    );
  }

  // ---------- Recent Activity List ----------

  Widget _buildRecentActivityList(BuildContext context, AsyncValue<List<Appointment>> apptsAsync) {
    return apptsAsync.when(
      data: (appts) {
        if (appts.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No previous appointment records found.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          );
        }

        final recentList = appts.take(5).toList();

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final appt = recentList[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceVariant,
                  child: Icon(_getIconForStatus(appt.status), color: _getColorForStatus(appt.status), size: 20),
                ),
                title: Text(appt.serviceName.isNotEmpty ? appt.serviceName : appt.reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${appt.date} @ ${appt.startTime}'),
                trailing: Chip(
                  label: Text(appt.status.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  backgroundColor: _getColorForStatus(appt.status).withAlpha(30),
                  side: BorderSide.none,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load appointments: ${err.toString()}', style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  IconData _getIconForStatus(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => Icons.hourglass_empty,
      AppointmentStatus.confirmed => Icons.check_circle_outline,
      AppointmentStatus.cancelled => Icons.cancel_outlined,
      AppointmentStatus.completed => Icons.task_alt,
      AppointmentStatus.noShow => Icons.person_off_outlined,
    };
  }

  Color _getColorForStatus(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.pending => AppColors.statusPending,
      AppointmentStatus.confirmed => AppColors.statusConfirmed,
      AppointmentStatus.cancelled => AppColors.statusCancelled,
      AppointmentStatus.completed => AppColors.statusCompleted,
      AppointmentStatus.noShow => AppColors.statusNoShow,
    };
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}
