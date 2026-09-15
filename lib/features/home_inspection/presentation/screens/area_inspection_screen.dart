import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/home_inspection_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import 'finding_dialog.dart';

/// Physical inspection of a single area: its elements (opened for
/// component-level findings) plus a running list of findings already
/// recorded directly against the area.
class AreaInspectionScreen extends ConsumerStatefulWidget {
  const AreaInspectionScreen({required this.sectionId, super.key});

  final String sectionId;

  @override
  ConsumerState<AreaInspectionScreen> createState() =>
      _AreaInspectionScreenState();
}

class _AreaInspectionScreenState extends ConsumerState<AreaInspectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final statuses = ref.read(sectionStatusesProvider.notifier);
      if (statuses.statusOf(widget.sectionId) == SectionStatus.notStarted) {
        statuses.setStatus(widget.sectionId, SectionStatus.inProgress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(configuredAreasProvider);
    final section = sections.firstWhereOrNull((s) => s.id == widget.sectionId);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Area')),
        body: const Center(child: Text('This area is no longer configured.')),
      );
    }

    final status =
        ref.watch(sectionStatusesProvider)[section.id] ??
        SectionStatus.notStarted;
    final areaFindings = ref
        .watch(inspectionFindingsProvider)
        .where((f) => f.sectionId == section.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(section.name)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<SectionStatus>(
              segments: const [
                ButtonSegment(
                  value: SectionStatus.notStarted,
                  label: Text('Not started'),
                ),
                ButtonSegment(
                  value: SectionStatus.inProgress,
                  label: Text('In progress'),
                ),
                ButtonSegment(
                  value: SectionStatus.completed,
                  label: Text('Completed'),
                ),
              ],
              selected: {status},
              onSelectionChanged: (selection) {
                ref
                    .read(sectionStatusesProvider.notifier)
                    .setStatus(section.id, selection.first);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Elements',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          for (final element in section.elements)
            ListTile(
              title: Text(element.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(
                '/home-inspection/inspection/${section.id}/${element.id}',
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
          if (areaFindings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No findings recorded yet.'),
            )
          else
            for (final finding in areaFindings)
              _FindingTile(section: section, finding: finding),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FindingTile extends ConsumerWidget {
  const _FindingTile({required this.section, required this.finding});

  final Section section;
  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final element = section.elements.firstWhereOrNull(
      (e) => e.id == finding.elementId,
    );
    final component = element?.components.firstWhereOrNull(
      (c) => c.id == finding.componentId,
    );

    final subtitleParts = <String>[
      if (element != null) element.name,
      if (component != null) component.name,
    ];

    return ListTile(
      title: Text(
        finding.description?.isNotEmpty == true
            ? finding.description!
            : '(No description)',
      ),
      subtitle: Text(
        [
          if (subtitleParts.isNotEmpty) subtitleParts.join(' / '),
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
