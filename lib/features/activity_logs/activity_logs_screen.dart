/// activity_logs_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Audit logs UI allowing staff/admin to inspect system activities:
/// appointment approvals, cancellations, walk-ins, and settings edits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/activity_log.dart';
import '../../core/services/activity_logger_service.dart';

class ActivityLogsScreen extends ConsumerStatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  ConsumerState<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends ConsumerState<ActivityLogsScreen> {
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(activityLogsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Activity Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(activityLogsStreamProvider),
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header
          Container(
            padding: const EdgeInsets.all(16.0),
            color: theme.colorScheme.surfaceContainerLowest,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by actor email, action, or resource ID...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All Activity'),
                      const SizedBox(width: 8),
                      _buildFilterChip('appointment_confirmed', 'Confirmed'),
                      const SizedBox(width: 8),
                      _buildFilterChip('appointment_cancelled', 'Cancelled'),
                      const SizedBox(width: 8),
                      _buildFilterChip('walkin_created', 'Walk-in Created'),
                      const SizedBox(width: 8),
                      _buildFilterChip('patient_rescheduled', 'Rescheduled'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Log List View
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final filtered = logs.where((log) {
                  // Filter by category
                  if (_selectedFilter != 'all' && log.action != _selectedFilter) {
                    return false;
                  }
                  // Filter by search query
                  if (_searchQuery.isNotEmpty) {
                    final matchEmail = log.actorEmail.toLowerCase().contains(_searchQuery);
                    final matchAction = log.action.toLowerCase().contains(_searchQuery);
                    final matchResource = log.resourceId.toLowerCase().contains(_searchQuery);
                    return matchEmail || matchAction || matchResource;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No audit logs found',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'System actions like appointment approvals and walk-ins will appear here.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return _buildLogCard(context, log);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Error loading activity logs: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedFilter = key;
        });
      },
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[dt.month - 1];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$monthStr ${dt.day}, ${dt.year} • $hour12:$minuteStr $ampm';
  }

  Widget _buildLogCard(BuildContext context, ActivityLog log) {
    final theme = Theme.of(context);
    final formattedTime = _formatDate(log.timestamp);

    Color badgeColor;
    IconData badgeIcon;

    switch (log.action) {
      case 'appointment_confirmed':
        badgeColor = Colors.green;
        badgeIcon = Icons.check_circle_outline;
        break;
      case 'appointment_cancelled':
        badgeColor = Colors.red;
        badgeIcon = Icons.cancel_outlined;
        break;
      case 'walkin_created':
        badgeColor = Colors.blue;
        badgeIcon = Icons.directions_walk;
        break;
      case 'patient_rescheduled':
        badgeColor = Colors.orange;
        badgeIcon = Icons.edit_calendar;
        break;
      default:
        badgeColor = theme.colorScheme.primary;
        badgeIcon = Icons.info_outline;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(badgeIcon, color: badgeColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatActionTitle(log.action),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formattedTime,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text(
                          log.actorRole.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.actorEmail,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (log.resourceId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Target Resource: ${log.resourceId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (log.details != null && log.details!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        log.details.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatActionTitle(String action) {
    switch (action) {
      case 'appointment_confirmed':
        return 'Appointment Confirmed';
      case 'appointment_cancelled':
        return 'Appointment Cancelled';
      case 'walkin_created':
        return 'Walk-in Appointment Created';
      case 'patient_rescheduled':
        return 'Appointment Rescheduled';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }
}
