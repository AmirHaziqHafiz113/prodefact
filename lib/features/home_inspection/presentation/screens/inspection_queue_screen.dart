import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/remote/remote_providers.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/house_pass_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../widgets/session_status_presentation.dart';
import 'ai_review_overview_screen.dart';

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

/// A real field-inspection dashboard: overall progress, the ordered
/// queue of suggested areas (plumbing-related areas first), each area's
/// status/finding/evidence counts, and the action to complete the
/// physical site visit.
///
/// Suggested areas are optional: the inspector inspects only the areas
/// the unit actually has, and can complete the physical inspection as
/// soon as one area has been inspected — untouched suggestions never
/// block it, and neither does AI still processing (see
/// `canCompletePhysicalInspection`).
class InspectionQueueScreen extends ConsumerStatefulWidget {
  const InspectionQueueScreen({super.key});

  static const routePath = '/home-inspection/inspection';

  @override
  ConsumerState<InspectionQueueScreen> createState() =>
      _InspectionQueueScreenState();
}

class _InspectionQueueScreenState extends ConsumerState<InspectionQueueScreen> {
  AreaListFilter _filter = AreaListFilter.all;

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(inspectionQueueProvider);
    final statuses = ref.watch(sectionStatusesProvider);
    final findings = ref.watch(inspectionFindingsProvider);
    final suggestions =
        ref.watch(activeSessionProvider)?.aiSuggestions ?? const [];
    final canComplete = ref.watch(canCompletePhysicalInspectionProvider);

    final activeSession = ref.watch(activeSessionProvider);
    AreaVisitState visitStateOf(Section section) => activeSession == null
        ? AreaVisitState.untouched
        : areaVisitStateOf(activeSession, section);
    final physical = activeSession == null
        ? const PhysicalProgress(totalAreas: 0, completed: 0)
        : PhysicalProgress.of(activeSession);
    final completedCount = physical.completed;
    final nextArea = queue.firstWhereOrNullStatus(statuses);
    final filterCounts = {
      for (final filter in AreaListFilter.values)
        filter: queue
            .where((s) => _matchesAreaFilter(filter, visitStateOf(s)))
            .length,
    };
    final visibleAreas = queue
        .where((s) => _matchesAreaFilter(_filter, visitStateOf(s)))
        .toList();

    final pendingSyncCount = activeSession == null
        ? 0
        : activeSession.findings
              .expand((f) => f.evidence)
              .where((e) => e.syncStatus != SyncStatus.synced)
              .length;
    final isOnline = ref.watch(isOnlineForAiProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Physical Inspection'),
        actions: [
          if (activeSession != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Center(
                child: SyncStatusPill(
                  status: activeSession.syncStatus,
                  pendingCount: pendingSyncCount,
                  dense: true,
                ),
              ),
            ),
          // No billing controls here (QA #23): the backend applies an
          // active House Pass automatically, otherwise Flex Credits.
          // House Pass is bought from the Wallet, outside field work.
          IconButton(
            tooltip: activeSession?.inspectionNote == null
                ? 'Add inspection note'
                : 'Edit inspection note',
            icon: Icon(
              activeSession?.inspectionNote == null
                  ? Icons.note_add_outlined
                  : Icons.sticky_note_2,
            ),
            onPressed: () => _editInspectionNote(context, ref, activeSession),
          ),
        ],
      ),
      body: queue.isEmpty
          ? const AppEmptyView(
              icon: Icons.checklist_outlined,
              title: 'No areas to inspect.',
              message: 'Go back and include at least one area.',
            )
          : Column(
              children: [
                if (activeSession?.status == InspectionStatus.reported)
                  const AppInlineWarningBanner(
                    message:
                        'This inspection is completed. Changes may require '
                        'a new report version.',
                  ),
                if (activeSession != null)
                  _HousePassAllowanceWatcher(inspectionId: activeSession.id),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      96,
                    ),
                    children: [
                      if (activeSession != null)
                        _PropertyHeader(session: activeSession),
                      if (activeSession != null)
                        const SizedBox(height: AppSpacing.lg),
                      AppHeroCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.home_outlined,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                const Expanded(
                                  child: Text(
                                    'Inspection Progress',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Text(
                                    '${physical.totalAreas} of '
                                    '${queue.length} suggested areas '
                                    'inspected',
                                    textAlign: TextAlign.right,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                AppRingProgress(
                                  value: physical.fraction,
                                  label:
                                      'Physical\n$completedCount of '
                                      '${physical.totalAreas}',
                                  color: Colors.white,
                                  size: 76,
                                ),
                                if (activeSession != null) ...[
                                  AppRingProgress(
                                    value: AiProcessingProgress.of(
                                      activeSession,
                                    ).fraction,
                                    label:
                                        'AI Analysed\n'
                                        '${AiProcessingProgress.of(activeSession).processed} of '
                                        '${AiProcessingProgress.of(activeSession).totalEligible}',
                                    color: Colors.white70,
                                    size: 76,
                                  ),
                                  AppRingProgress(
                                    value: AiReviewProgress.of(activeSession)
                                        .fraction,
                                    label:
                                        'Reviewed\n'
                                        '${AiReviewProgress.of(activeSession).resolved} of '
                                        '${AiReviewProgress.of(activeSession).total}',
                                    color: Colors.white70,
                                    size: 76,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (activeSession != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _StatusStrip(
                          session: activeSession,
                          pendingSyncCount: pendingSyncCount,
                          isOnline: isOnline,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.map_outlined,
                                  label: '${physical.totalAreas}',
                                  caption: 'Areas inspected',
                                ),
                              ),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.report_gmailerrorred_outlined,
                                  label: '${findings.length}',
                                  caption: 'Findings',
                                ),
                              ),
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.photo_camera_outlined,
                                  label:
                                      '${findings.fold<int>(0, (sum, f) => sum + f.evidence.length)}',
                                  caption: 'Photos',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (activeSession?.inspectionNote != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.sticky_note_2_outlined,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  activeSession!.inspectionNote!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (activeSession != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _AutoAnalyseToggle(session: activeSession),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      AppSectionHeader(
                        title: 'Suggested areas (${queue.length})',
                        subtitle:
                            'Inspect only the areas this unit has. '
                            'Untouched areas are left out of the report.',
                      ),
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
                                onSelected: (_) =>
                                    setState(() => _filter = filter),
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
                              'Mark an area complete once you have '
                                  'finished inspecting it.',
                            AreaListFilter.inProgress =>
                              'An area moves here once you record a '
                                  'finding in it.',
                            _ => 'Every suggested area has been started.',
                          },
                        ),
                      for (final section in visibleAreas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AreaQueueCard(
                            section: section,
                            visitState: visitStateOf(section),
                            isUpNext: section.id == nextArea?.id,
                            findingCount: findings
                                .where((f) => f.sectionId == section.id)
                                .length,
                            evidenceCount: findings
                                .where((f) => f.sectionId == section.id)
                                .fold<int>(
                                  0,
                                  (sum, f) => sum + f.evidence.length,
                                ),
                            aiProcessing: AiProcessingProgress.forFindings(
                              findings
                                  .where((f) => f.sectionId == section.id)
                                  .toList(),
                            ),
                            review: AiReviewProgress.forSuggestions(
                              suggestions
                                  .where(
                                    (s) => findings.any(
                                      (f) =>
                                          f.id == s.findingId &&
                                          f.sectionId == section.id,
                                    ),
                                  )
                                  .toList(),
                            ),
                            onTap: () => context.push(
                              '${InspectionQueueScreen.routePath}/${section.id}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canComplete && queue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Inspect at least one area to complete the site visit.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              FilledButton(
                onPressed: canComplete && activeSession != null
                    ? () => _completeInspection(activeSession)
                    : null,
                child: const Text('Complete Physical Inspection'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeInspection(InspectionSession session) async {
    final physical = PhysicalProgress.of(session);
    final inFlight = AiProcessingProgress.of(session).inFlight;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete physical inspection?'),
        content: Text(
          [
            '${physical.totalAreas} area${physical.totalAreas == 1 ? '' : 's'} '
                'inspected.',
            if (physical.untouchedSuggested > 0)
              '${physical.untouchedSuggested} suggested '
                  'area${physical.untouchedSuggested == 1 ? '' : 's'} not '
                  'visited will be left out of the report.',
            if (inFlight > 0)
              'AI keeps analysing $inFlight '
                  'finding${inFlight == 1 ? '' : 's'} in the background. '
                  'You can leave the property.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Inspecting'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final completed = await ref
        .read(activeSessionProvider.notifier)
        .markPhysicalInspectionComplete();
    if (!completed || !mounted) return;
    context.push(AiReviewOverviewScreen.routePath);
  }
}

extension on List<Section> {
  Section? firstWhereOrNullStatus(Map<String, SectionStatus> statuses) {
    for (final section in this) {
      if ((statuses[section.id] ?? SectionStatus.notStarted) !=
          SectionStatus.completed) {
        return section;
      }
    }
    return null;
  }
}

/// Keeps billing invisible during field work (QA #23) while preserving
/// the existing spend-consent rule: the backend applies this
/// inspection's House Pass automatically while it has allowance, then
/// Flex Credits. The moment the allowance runs out, Auto Analyse is
/// switched off, so no further finding silently starts spending
/// Credits; new findings then ask before analysing. The inspector is
/// told what happened but is never asked to choose a billing mechanism.
class _HousePassAllowanceWatcher extends ConsumerWidget {
  const _HousePassAllowanceWatcher({required this.inspectionId});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(housePassStatusProvider(inspectionId), (previous, next) {
      final becameAllowanceReached =
          next.value?.status == HousePassLifecycleStatus.allowanceReached &&
          previous?.value?.status != HousePassLifecycleStatus.allowanceReached;
      if (!becameAllowanceReached) return;
      final session = ref.read(activeSessionProvider);
      if (session?.autoAnalyseEnabled == true) {
        ref.read(activeSessionProvider.notifier).setAutoAnalyseEnabled(false);
      }
    });

    final status = ref
        .watch(housePassStatusProvider(inspectionId))
        .value
        ?.status;
    if (status != HousePassLifecycleStatus.allowanceReached) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Row(
          children: [
            Icon(Icons.data_usage_outlined, size: 18, color: AppColors.warning),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'House Pass AI allowance used up. New findings will ask '
                'before using AI Credits.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A per-inspection Auto Analyse switch — explicit opt-in for Flex
/// Credits (never defaults on for a Flex inspection), so a saved
/// finding never silently starts spending Credits without the
/// inspector having turned this on themselves. See
/// `InspectionSession.autoAnalyseEnabled` and
/// `HousePassScreen._confirmSandbox`/`_purchase`, which turn this on
/// automatically the moment a House Pass becomes active (its allowance
/// makes auto-analysing safe by default) — see docs/commercial_model.md.
class _AutoAnalyseToggle extends ConsumerWidget {
  const _AutoAnalyseToggle({required this.session});

  final InspectionSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: SwitchListTile(
        title: const Text('Auto Analyse'),
        subtitle: const Text(
          'Saved findings are analysed with Smart AI automatically, '
          'without asking each time.',
        ),
        value: session.autoAnalyseEnabled,
        onChanged: (enabled) => ref
            .read(activeSessionProvider.notifier)
            .setAutoAnalyseEnabled(enabled),
      ),
    );
  }
}

/// The property identity strip above the progress hero — real
/// `PropertyDetails` plus the session's own lifecycle status, mirroring
/// the same card shape the Inspections list already uses so the two
/// screens read as one product.
class _PropertyHeader extends StatelessWidget {
  const _PropertyHeader({required this.session});

  final InspectionSession session;

  @override
  Widget build(BuildContext context) {
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == session.assetTypeId,
    );
    final details = session.propertyDetails;
    final title = details.title.isNotEmpty
        ? details.title
        : (propertyType?.label ?? session.assetTypeId);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFallbackThumbnail(
          icon: propertyType == PropertyType.highRise
              ? Icons.apartment_outlined
              : Icons.house_outlined,
          size: 64,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SessionLifecyclePill(status: session.status),
                ],
              ),
              Text(
                [
                  details.unitNumber,
                  propertyType?.label,
                ].whereType<String>().join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (details.address != null)
                Text(
                  details.address!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              Text(
                'Last updated ${_formatUpdatedAt(session.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatUpdatedAt(DateTime dateTime) {
    final local = dateTime.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

/// A compact, one-or-two-line contextual strip surfacing the single
/// highest-priority real state the inspector should know about right
/// now — never more than two at once (see mission §7 "SYNC / AI
/// STATE"). Prioritizes review over AI-in-flight over sync, since
/// review is the only one that's actually blocking the inspector.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.session,
    required this.pendingSyncCount,
    required this.isOnline,
  });

  final InspectionSession session;
  final int pendingSyncCount;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final summary = AiCardSummary.of(session, isOnline: isOnline);
    final review = summary.review;
    final processing = summary.processing;

    final items = <(String, IconData, Color)>[];
    if (review.pending > 0) {
      items.add((
        '${review.pending} finding${review.pending == 1 ? '' : 's'} '
            '${review.pending == 1 ? 'needs' : 'need'} review',
        Icons.help_outline,
        AppColors.warning,
      ));
    } else if (processing.failed > 0) {
      items.add((
        '${processing.failed} finding${processing.failed == 1 ? '' : 's'} '
            'could not be analysed',
        Icons.error_outline,
        AppColors.danger,
      ));
    } else if (processing.inFlight > 0) {
      items.add(
        isOnline
            ? (
                '${processing.inFlight} finding${processing.inFlight == 1 ? '' : 's'} '
                    'waiting for AI',
                Icons.smart_toy_outlined,
                AppColors.info,
              )
            : (
                '${processing.inFlight} finding${processing.inFlight == 1 ? '' : 's'} '
                    'waiting for connection',
                Icons.cloud_off_outlined,
                AppColors.textSecondary,
              ),
      );
    }
    if (pendingSyncCount > 0 && items.length < 2) {
      items.add((
        '$pendingSyncCount item${pendingSyncCount == 1 ? '' : 's'} waiting '
            'to sync',
        Icons.cloud_sync_outlined,
        AppColors.warning,
      ));
    }
    if (items.isEmpty) {
      items.add(('Synced', Icons.cloud_done_outlined, AppColors.success));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, icon, color) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AreaQueueCard extends StatelessWidget {
  const _AreaQueueCard({
    required this.section,
    required this.visitState,
    required this.isUpNext,
    required this.findingCount,
    required this.evidenceCount,
    required this.aiProcessing,
    required this.review,
    required this.onTap,
  });

  final Section section;
  final AreaVisitState visitState;
  final bool isUpNext;
  final int findingCount;
  final int evidenceCount;

  /// Per-area AI processing progress — see `AiProcessingProgress`.
  /// Distinct from [status] (physical) and [review] (inspector review):
  /// the three axes are never combined into one misleading number.
  final AiProcessingProgress aiProcessing;
  final AiReviewProgress review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isUpNext ? AppColors.primary.withValues(alpha: 0.05) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              AppFallbackThumbnail(
                icon: section.isPlumbing
                    ? Icons.plumbing_outlined
                    : Icons.chair_outlined,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUpNext)
                          const Padding(
                            padding: EdgeInsets.only(right: AppSpacing.sm),
                            child: Icon(
                              Icons.flag,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            section.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (section.isPlumbing)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.sm),
                            child: Icon(
                              Icons.plumbing_outlined,
                              size: 16,
                              color: AppColors.plumbing,
                            ),
                          ),
                      ],
                    ),
                    if (section.isPlumbing)
                      const Text(
                        'Plumbing area — inspect first',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.plumbing,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (findingCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.report_gmailerrorred_outlined,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$findingCount finding${findingCount == 1 ? '' : 's'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        if (evidenceCount > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_camera_outlined,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$evidenceCount photo${evidenceCount == 1 ? '' : 's'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (aiProcessing.totalEligible == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'AI: No findings · Review: Not required',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      )
                    else ...[
                      const SizedBox(height: 4),
                      AppMiniProgressLine(
                        label: 'AI',
                        value: aiProcessing.fraction,
                        fractionLabel:
                            '${aiProcessing.processed}/'
                            '${aiProcessing.totalEligible}',
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
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: _StatusChip(state: visitState)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final AreaVisitState state;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = switch (state) {
      AreaVisitState.untouched => (
        'Not started',
        Icons.circle_outlined,
        AppColors.textSecondary,
        AppColors.neutralBg,
      ),
      AreaVisitState.started => (
        'In progress',
        Icons.timelapse,
        AppColors.warning,
        AppColors.warningBg,
      ),
      AreaVisitState.completed => (
        'Completed',
        Icons.check_circle_outline,
        AppColors.success,
        AppColors.successBg,
      ),
    };
    return StatusPill(label: label, icon: icon, foreground: fg, background: bg);
  }
}

Future<void> _editInspectionNote(
  BuildContext context,
  WidgetRef ref,
  InspectionSession? session,
) async {
  if (session == null) return;
  final controller = TextEditingController(text: session.inspectionNote ?? '');
  final newNote = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Inspection note'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Note',
          hintText: 'e.g. "Unit occupied during inspection."',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (newNote == null) return;
  ref.read(activeSessionProvider.notifier).setInspectionNote(newNote);
}
