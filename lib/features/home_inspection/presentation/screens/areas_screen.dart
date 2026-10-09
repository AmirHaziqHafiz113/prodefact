import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../widgets/discovered_area_dialog.dart';
import '../widgets/session_navigation.dart';

/// Which areas the area list shows — real [AreaVisitState]s, so each
/// chip filters actual data and shows a true count.
enum AreaListFilter { all, notStarted, inProgress, completed }

String areaListFilterLabel(AreaListFilter filter) => switch (filter) {
  AreaListFilter.all => 'All',
  AreaListFilter.notStarted => 'Not started',
  AreaListFilter.inProgress => 'In progress',
  AreaListFilter.completed => 'Completed',
};

bool _matchesAreaFilter(AreaListFilter filter, AreaVisitState state) =>
    switch (filter) {
      AreaListFilter.all => true,
      AreaListFilter.notStarted => state == AreaVisitState.untouched,
      AreaListFilter.inProgress => state == AreaVisitState.started,
      AreaListFilter.completed => state == AreaVisitState.completed,
    };

/// Inspection progress by area: the ordered queue of suggested areas
/// (plumbing first), each with its finding count, open-review count and
/// status, plus adding an area found on site. Tapping an area opens its
/// findings. Suggested areas are optional — untouched ones are left out
/// of the report and never block completing the site visit.
class AreasScreen extends ConsumerStatefulWidget {
  const AreasScreen({super.key});

  static const routePath = '/home-inspection/inspection-areas';

  @override
  ConsumerState<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends ConsumerState<AreasScreen> {
  AreaListFilter _filter = AreaListFilter.all;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(inspectionQueueProvider);
    final findings = ref.watch(inspectionFindingsProvider);
    final session = ref.watch(activeSessionProvider);
    final suggestions = session?.aiSuggestions ?? const <AiSuggestion>[];

    AreaVisitState visitStateOf(Section section) => session == null
        ? AreaVisitState.untouched
        : areaVisitStateOf(session, section);
    final upNext = session == null ? null : continueAreaFor(session, queue);
    final filterCounts = {
      for (final filter in AreaListFilter.values)
        filter: queue
            .where((s) => _matchesAreaFilter(filter, visitStateOf(s)))
            .length,
    };
    final visibleAreas = queue
        .where((s) => _matchesAreaFilter(_filter, visitStateOf(s)))
        .toList();
    final physical = session == null
        ? const PhysicalProgress(totalAreas: 0, completed: 0)
        : PhysicalProgress.of(session);

    return Scaffold(
      appBar: AppBar(title: const Text('Areas')),
      body: queue.isEmpty
          ? const AppEmptyView(
              icon: Icons.checklist_outlined,
              title: 'No areas to inspect',
              message: 'Add the first area you find on site.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  '${physical.completed} of ${physical.totalAreas} inspected '
                  'areas complete · ${queue.length} suggested',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Inspect only the areas this unit has. Untouched areas are '
                  'left out of the report.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in AreaListFilter.values) ...[
                        ChoiceChip(
                          key: ValueKey('area-filter-${filter.name}'),
                          label: Text(
                            '${areaListFilterLabel(filter)} '
                            '(${filterCounts[filter]})',
                          ),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (visibleAreas.isEmpty)
                  AppEmptyView(
                    icon: Icons.filter_alt_off_outlined,
                    title:
                        'No ${areaListFilterLabel(_filter).toLowerCase()} '
                        'areas',
                    message: switch (_filter) {
                      AreaListFilter.completed =>
                        'Mark an area complete once you have finished '
                            'inspecting it.',
                      AreaListFilter.inProgress =>
                        'An area moves here once you record a finding in it.',
                      _ => 'Every suggested area has been started.',
                    },
                  ),
                for (final section in visibleAreas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _AreaCard(
                      section: section,
                      visitState: visitStateOf(section),
                      isUpNext: section.id == upNext?.id,
                      findings: findings
                          .where((f) => f.sectionId == section.id)
                          .toList(),
                      suggestions: suggestions,
                      onTap: () =>
                          context.push(areaFindingsLocation(section.id)),
                    ),
                  ),
                if (session != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _addDiscoveredArea(session),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add Newly Discovered Area'),
                  ),
                ],
              ],
            ),
    );
  }

  /// QA #12: an area found on site joins this inspection immediately;
  /// it is queued separately as a candidate for future suggestions.
  Future<void> _addDiscoveredArea(InspectionSession session) async {
    final result = await showDiscoveredAreaDialog(
      context,
      propertyType: session.assetTypeId,
      existingNames: {for (final s in session.sections) s.name},
    );
    if (result == null || !mounted) return;
    final section = ref
        .read(activeSessionProvider.notifier)
        .addDiscoveredArea(result.name, isPlumbing: result.isPlumbing);
    if (section == null) return;
    setState(() => _filter = AreaListFilter.all);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${section.name} added to this inspection')),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.section,
    required this.visitState,
    required this.isUpNext,
    required this.findings,
    required this.suggestions,
    required this.onTap,
  });

  final Section section;
  final AreaVisitState visitState;
  final bool isUpNext;
  final List<Finding> findings;
  final List<AiSuggestion> suggestions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final findingIds = {for (final f in findings) f.id};
    // Per-area AI processing and inspector review — two distinct axes,
    // never combined into one misleading number.
    final aiProcessing = AiProcessingProgress.forFindings(findings);
    final review = AiReviewProgress.forSuggestions(
      suggestions.where((s) => findingIds.contains(s.findingId)).toList(),
    );
    final openReview = review.pending;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          (section.isPlumbing
                                  ? AppColors.plumbing
                                  : AppColors.primary)
                              .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      section.isPlumbing
                          ? Icons.plumbing_outlined
                          : Icons.chair_outlined,
                      color: section.isPlumbing
                          ? AppColors.plumbing
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (isUpNext)
                          const Text(
                            'Up next',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        else if (section.isPlumbing)
                          const Text(
                            'Plumbing area — inspect first',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.plumbing,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(flex: 0, child: AreaStatusChip(state: visitState)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: 4,
                children: [
                  _Count(
                    icon: Icons.photo_camera_outlined,
                    text:
                        '${findings.length} finding'
                        '${findings.length == 1 ? '' : 's'}',
                  ),
                  if (openReview > 0)
                    _Count(
                      icon: Icons.help_outline,
                      text: '$openReview to review',
                      color: AppColors.warning,
                    ),
                ],
              ),
              if (aiProcessing.totalEligible == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'AI: No findings · Review: Not required',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else ...[
                const SizedBox(height: AppSpacing.sm),
                AppMiniProgressLine(
                  label: 'AI',
                  value: aiProcessing.fraction,
                  fractionLabel:
                      '${aiProcessing.processed}/${aiProcessing.totalEligible}',
                  color: AppColors.info,
                ),
                const SizedBox(height: 4),
                AppMiniProgressLine(
                  label: 'Review',
                  value: review.fraction,
                  fractionLabel: '${review.resolved}/${review.total}',
                  color: AppColors.plumbing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.text,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// An area's [AreaVisitState] as a shared status chip.
class AreaStatusChip extends StatelessWidget {
  const AreaStatusChip({super.key, required this.state});

  final AreaVisitState state;

  @override
  Widget build(BuildContext context) {
    final (status, label) = switch (state) {
      AreaVisitState.untouched => (AppStatus.notStarted, 'Not started'),
      AreaVisitState.started => (AppStatus.inProgress, 'In progress'),
      AreaVisitState.completed => (AppStatus.completed, 'Completed'),
    };
    return AppStatusChip(status: status, label: label, dense: false);
  }
}
