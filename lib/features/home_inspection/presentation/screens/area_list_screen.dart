import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_inspection_providers.dart';

/// Read-only preview of the default areas for the selected property type.
///
/// This is a stub proving the config → domain → UI wiring end to end. The
/// full include/exclude/add/remove/rename workflow, and the physical
/// inspection flow itself, are built in a later phase.
class AreaListScreen extends ConsumerWidget {
  const AreaListScreen({super.key});

  static const routePath = '/home-inspection/areas';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyType = ref.watch(selectedPropertyTypeProvider);
    final sections = ref.watch(defaultSectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          propertyType == null
              ? 'Inspection Areas'
              : '${propertyType.label} Areas',
        ),
      ),
      body: sections.isEmpty
          ? const Center(child: Text('No property type selected.'))
          : ListView.builder(
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                return ListTile(
                  title: Text(section.name),
                  subtitle: section.isPlumbing
                      ? const Text('Plumbing area — inspect first')
                      : null,
                );
              },
            ),
    );
  }
}
