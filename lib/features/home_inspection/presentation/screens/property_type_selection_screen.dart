import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../config/property_type.dart';
import '../../providers/home_inspection_providers.dart';

/// Entry point for Home Inspection: the inspector picks the property type
/// before ProDefact shows the relevant inspection areas.
class PropertyTypeSelectionScreen extends ConsumerWidget {
  const PropertyTypeSelectionScreen({super.key});

  static const routePath = '/home-inspection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Inspection')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select property type',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ProDefact tailors inspection areas to the property type.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              for (final propertyType in PropertyType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _PropertyTypeCard(
                    propertyType: propertyType,
                    onTap: () =>
                        _selectPropertyType(context, ref, propertyType),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectPropertyType(
    BuildContext context,
    WidgetRef ref,
    PropertyType propertyType,
  ) async {
    final started = await ref
        .read(selectedPropertyTypeProvider.notifier)
        .select(propertyType);
    if (!context.mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start a new inspection. Please try again.'),
        ),
      );
      return;
    }
    context.push('/home-inspection/areas');
  }
}

class _PropertyTypeCard extends StatelessWidget {
  const _PropertyTypeCard({required this.propertyType, required this.onTap});

  final PropertyType propertyType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, description) = switch (propertyType) {
      PropertyType.highRise => (
        Icons.apartment_outlined,
        'Condos, apartments, and strata high-rise units.',
      ),
      PropertyType.landed => (
        Icons.house_outlined,
        'Terrace, semi-detached, and bungalow landed homes.',
      ),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyType.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
