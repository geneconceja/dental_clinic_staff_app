/// services_screen.dart
/// Dental Clinic Staff/Admin App
///
/// Administrative interface for CRUD operations on clinic services.
/// Allows admins to create new services, update durations, prices,
/// descriptions, and toggle active status.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/service.dart';
import '../../core/theme/app_colors.dart';
import 'services_repository.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allServicesAsync = ref.watch(allServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Service'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => _showServiceDialog(context),
            ),
          ),
        ],
      ),
      body: allServicesAsync.when(
        data: (services) {
          if (services.isEmpty) {
            return _buildEmptyState(theme);
          }

          // Responsive grid layout (columns scale by available screen width)
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
              mainAxisExtent: 180,
            ),
            itemCount: services.length,
            itemBuilder: (_, index) {
              final service = services[index];
              return _ServiceCard(
                service: service,
                onEdit: () => _showServiceDialog(context, service: service),
                onToggleActive: (active) async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(servicesRepositoryProvider)
                        .toggleServiceActive(service.id, active);
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to update service state: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading services: $err',
              style: const TextStyle(color: AppColors.error)),
        ),
      ),
    );
  }

  // ---------- Dialog Form Helper ----------

  void _showServiceDialog(BuildContext context, {Service? service}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ServiceDialogForm(service: service),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medical_services_outlined,
              size: 64, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text('No Services Defined', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create your first dental treatment service by clicking the button above.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Service Card Widget ──────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Service service;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title + Active Switch
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      service.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: service.active
                            ? AppColors.textPrimary
                            : AppColors.textDisabled,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: service.active,
                      activeTrackColor: AppColors.primary.withAlpha(120),
                      activeThumbColor: AppColors.primary,
                      onChanged: onToggleActive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              Expanded(
                child: Text(
                  service.description.isNotEmpty
                      ? service.description
                      : 'No description provided.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),

              // Duration & Price row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        '${service.durationMinutes} mins',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₱${service.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Service Dialog Form ──────────────────────────────────────────────────────

class _ServiceDialogForm extends ConsumerStatefulWidget {
  const _ServiceDialogForm({this.service});
  final Service? service;

  @override
  ConsumerState<_ServiceDialogForm> createState() => _ServiceDialogFormState();
}

class _ServiceDialogFormState extends ConsumerState<_ServiceDialogForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _priceCtrl;
  late bool _active;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.service?.name ?? '');
    _descCtrl = TextEditingController(text: widget.service?.description ?? '');
    _durationCtrl = TextEditingController(
        text: widget.service?.durationMinutes.toString() ?? '30');
    _priceCtrl = TextEditingController(
        text: widget.service?.price.toStringAsFixed(0) ?? '500');
    _active = widget.service?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(servicesRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final duration = int.parse(_durationCtrl.text.trim());
      final price = double.parse(_priceCtrl.text.trim());

      if (widget.service == null) {
        // Create new
        await repo.createService(
          name: name,
          durationMinutes: duration,
          price: price,
          description: desc,
          active: _active,
        );
      } else {
        // Edit existing
        final updated = widget.service!.copyWith(
          name: name,
          durationMinutes: duration,
          price: price,
          description: desc,
          active: _active,
        );
        await repo.updateService(updated);
      }

      navigator.pop();
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save service: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.service != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Service' : 'Add New Service'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Container(
            width: 460,
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Service Name *',
                    hintText: 'e.g. Teeth Whitening',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe details or treatment notes...',
                    alignLabelWithHint: true,
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // Duration & Price
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _durationCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Duration (Mins) *',
                          suffixText: 'min',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final mins = int.tryParse(v);
                          if (mins == null || mins <= 0) return 'Invalid duration';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Price (₱) *',
                          prefixText: '₱',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final price = double.tryParse(v);
                          if (price == null || price < 0) return 'Invalid price';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Active Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Service is Active (Available for bookings)'),
                    Switch(
                      value: _active,
                      activeTrackColor: AppColors.primary.withAlpha(120),
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setState(() => _active = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ---------- Extra Stream Provider for All Services (Admin View) ----------

final allServicesProvider = StreamProvider<List<Service>>((ref) {
  return ref.watch(servicesRepositoryProvider).watchAllServices();
});
