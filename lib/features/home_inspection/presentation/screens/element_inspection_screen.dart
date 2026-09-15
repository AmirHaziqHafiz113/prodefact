import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/home_inspection_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import 'finding_dialog.dart';

/// Physical inspection of a single element within an area: its
/// components (each with an "add finding" action) plus an "add finding"
/// action for the element as a whole, and the findings recorded so far.
class ElementInspectionScreen extends ConsumerWidget {
  const ElementInspectionScreen({
    required this.sectionId,
    required this.elementId,
    super.key,
  });

  final String sectionId;
  final String elementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref
        .watch(configuredAreasProvider)
        .firstWhereOrNull((s) => s.id == sectionId);
    final element = section?.elements.firstWhereOrNull(
      (e) => e.id == elementId,
    );

    if (section == null || element == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Element')),
        body: const Center(
          child: Text('This element is no longer configured.'),
        ),
      );
    }

    final elementFindings = ref
        .watch(inspectionFindingsProvider)
        .where((f) => f.sectionId == sectionId && f.elementId == elementId)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('${section.name} · ${element.name}')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Finding for this element'),
            subtitle: const Text('Not tied to a specific component'),
            trailing: FilledButton(
              onPressed: () => showFindingDialog(
                context: context,
                ref: ref,
                sectionId: sectionId,
                elementId: elementId,
              ),
              child: const Text('Add'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Components',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          for (final component in element.components)
            ListTile(
              title: Text(component.name),
              trailing: OutlinedButton(
                onPressed: () => showFindingDialog(
                  context: context,
                  ref: ref,
                  sectionId: sectionId,
                  elementId: elementId,
                  componentId: component.id,
                ),
                child: const Text('Add finding'),
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Findings recorded so far',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (elementFindings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No findings recorded yet.'),
            )
          else
            for (final finding in elementFindings)
              _FindingTile(element: element, finding: finding),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FindingTile extends ConsumerWidget {
  const _FindingTile({required this.element, required this.finding});

  final InspectionElement element;
  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final component = element.components.firstWhereOrNull(
      (c) => c.id == finding.componentId,
    );

    return ListTile(
      title: Text(
        finding.description?.isNotEmpty == true
            ? finding.description!
            : '(No description)',
      ),
      subtitle: Text(
        [
          component?.name ?? 'Element only',
          '${finding.evidence.length} photo(s)',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
            onPressed: () => showFindingDialog(
              context: context,
              ref: ref,
              existing: finding,
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref
                .read(inspectionFindingsProvider.notifier)
                .removeFinding(finding.id),
          ),
        ],
      ),
    );
  }
}
