import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../config/property_type.dart';
import '../../providers/new_inspection_draft_providers.dart';
import 'property_details_screen.dart';

/// Entry point for Home Inspection: the inspector picks the property type
/// before ProDefact shows the relevant inspection areas — step 1 of the
/// 5-step New Inspection wizard (see `AppWizardStepper`). Tapping a card
/// selects and immediately continues (no separate "Continue" tap) —
/// there are only two, mutually exclusive options, so a confirm step
/// would only add friction.
class PropertyTypeSelectionScreen extends ConsumerWidget {
  const PropertyTypeSelectionScreen({super.key});

  static const routePath = '/home-inspection';

  static const wizardSteps = ['Property', 'Details', 'Areas', 'Review'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Inspection')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppWizardStepper(stepLabels: wizardSteps, currentIndex: 0),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'What type of property are you inspecting?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Select the property type to get the right inspection '
                      'flow and checklist.',
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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Not sure?',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  'You can always change this later before '
                                  'finalising your inspection.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Starts an in-memory setup draft only — see
  /// [NewInspectionDraftNotifier]. Nothing is persisted and no
  /// inspection exists yet, so backing out of the area configuration
  /// screen that follows leaves no trace: this is purely local state
  /// that a future property-type pick (or app restart) simply
  /// overwrites/discards.
  void _selectPropertyType(
    BuildContext context,
    WidgetRef ref,
    PropertyType propertyType,
  ) {
    ref.read(newInspectionDraftProvider.notifier).begin(propertyType);
    context.push(PropertyDetailsScreen.routePath);
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
        'Condominiums, apartments and other multi-storey residential '
            'buildings.',
      ),
      PropertyType.landed => (
        Icons.house_outlined,
        'Houses, terrace, semi-detached and bungalow properties.',
      ),
    };

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      propertyType.label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              AppFallbackThumbnail(icon: icon, size: 84, radius: AppRadius.lg),
            ],
          ),
        ),
      ),
    );
  }
}
