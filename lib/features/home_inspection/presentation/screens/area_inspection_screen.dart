import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/home_inspection_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import 'finding_dialog.dart';

/// Icon per common element name — falls back to a generic icon for a
/// custom element name that doesn't match one of these.
IconData _iconForElement(String name) {
  switch (name) {
    case 'Floor':
      return Icons.texture_outlined;
    case 'Wall':
      return Icons.vertical_split_outlined;
    case 'Ceiling':
      return Icons.expand_less_outlined;
    case 'Door':
      return Icons.door_front_door_outlined;
    case 'Window':
      return Icons.window_outlined;
    case 'M&E':
      return Icons.bolt_outlined;
    default:
      return Icons.category_outlined;
  }
}

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
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'This area is no longer configured.',
        ),
      );
    }

    final status =
        ref.watch(sectionStatusesProvider)[section.id] ??
        SectionStatus.notStarted;
    final areaFindings = ref
        .watch(inspectionFindingsProvider)
        .where((f) => f.sectionId == section.id)
        .toList();
    final evidenceCount = areaFindings.fold<int>(
      0,
      (sum, f) => sum + f.evidence.length,
    );

    return Scaffold(
      appBar: AppBar(title: Text(section.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          if (section.isPlumbing)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: StatusPill(
                label: 'Plumbing area — inspect first',
                icon: Icons.plumbing_outlined,
                foreground: AppColors.plumbing,
                background: AppColors.plumbingBg,
              ),
            ),
          Row(
            children: [
              _MiniStat(
                icon: Icons.report_gmailerrorred_outlined,
                value: '${areaFindings.length}',
                label: 'Findings',
              ),
              const SizedBox(width: AppSpacing.lg),
              _MiniStat(
                icon: Icons.photo_camera_outlined,
                value: '$evidenceCount',
                label: 'Photos',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<SectionStatus>(
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
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Elements'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.4,
            ),
            itemCount: section.elements.length,
            itemBuilder: (context, index) {
              final element = section.elements[index];
              final elementFindingCount = areaFindings
                  .where((f) => f.elementId == element.id)
                  .length;
              return _ElementCard(
                name: element.name,
                findingCount: elementFindingCount,
                onTap: () => context.push(
                  '/home-inspection/inspection/${section.id}/${element.id}',
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(title: 'Findings recorded so far'),
          if (areaFindings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text('No findings recorded yet.'),
            )
          else
            for (final finding in areaFindings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FindingCard(section: section, finding: finding),
              ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text('$value $label', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _ElementCard extends StatelessWidget {
  const _ElementCard({
    required this.name,
    required this.findingCount,
    required this.onTap,
  });

  final String name;
  final int findingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _iconForElement(name),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (findingCount > 0)
                      Text(
                        '$findingCount finding${findingCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindingCard extends ConsumerWidget {
  const _FindingCard({required this.section, required this.finding});

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

    return Card(
      child: ListTile(
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
      ),
    );
  }
}
