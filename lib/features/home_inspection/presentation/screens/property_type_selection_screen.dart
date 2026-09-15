import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      appBar: AppBar(title: const Text('Home Inspection')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select property type',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              for (final propertyType in PropertyType.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton(
                    onPressed: () =>
                        _selectPropertyType(context, ref, propertyType),
                    child: SizedBox(
                      width: 200,
                      child: Text(
                        propertyType.label,
                        textAlign: TextAlign.center,
                      ),
                    ),
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
    await ref.read(selectedPropertyTypeProvider.notifier).select(propertyType);
    if (!context.mounted) return;
    context.push('/home-inspection/areas');
  }
}
