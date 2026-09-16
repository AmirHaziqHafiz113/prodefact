import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
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
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'This element is no longer configured.',
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Card(
            child: ListTile(
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
          ),
          if (element.components.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const AppSectionHeader(title: 'Components'),
            for (final component in element.components)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  child: ListTile(
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
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'Findings recorded so far'),
          if (elementFindings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('No findings recorded yet.'),
            )
          else
            for (final finding in elementFindings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FindingCard(element: element, finding: finding),
              ),
        ],
      ),
    );
  }
}

class _FindingCard extends ConsumerWidget {
  const _FindingCard({required this.element, required this.finding});

  final InspectionElement element;
  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final component = element.components.firstWhereOrNull(
      (c) => c.id == finding.componentId,
    );

    return Card(
      child: ListTile(
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
      ),
    );
  }
}
