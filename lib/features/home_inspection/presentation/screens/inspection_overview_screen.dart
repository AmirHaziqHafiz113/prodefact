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
import '../widgets/app_bottom_sheet.dart';
import '../widgets/session_navigation.dart';
import '../widgets/session_status_presentation.dart';
import 'ai_review_overview_screen.dart';
import 'areas_screen.dart';
import 'photo_guide_screen.dart';
import 'report_screen.dart';

/// The hub for ONE property: who/where it is, where it stands, and one
/// obvious next step. Everything else is a distinct destination:
///
/// - **Continue Inspection** (primary while on site) → the current
///   area's findings (see [continueAreaFor]).
/// - **Areas** → progress by area, filters, add a newly found area.
/// - **Review findings** → AI Review (only findings needing a decision).
/// - **Report** → the existing report flow (unchanged).
/// - **Inspection details** → a sheet with the setup details and note.
///
/// The row matching the current primary action is hidden so no two
/// controls on this screen lead to the same place. See
/// docs/ux_architecture.md.
class InspectionOverviewScreen extends ConsumerWidget {
  const InspectionOverviewScreen({super.key});

  static const routePath = '/home-inspection/inspection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final queue = ref.watch(inspectionQueueProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inspection Overview')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'No inspection open',
          message: 'Open an inspection from the Inspections tab.',
        ),
      );
    }

    final pendingSyncCount = session.findings
        .expand((f) => f.evidence)
        .where((e) => e.syncStatus != SyncStatus.synced)
        .length;
    final isOnline = ref.watch(isOnlineForAiProvider);
    final canComplete = ref.watch(canCompletePhysicalInspectionProvider);
    final readiness = ReportReadiness.of(session);
    final needsAttention =
        readiness.toReview +
        readiness.failed +
        readiness.unresolved +
        readiness.waitingForNote;
    final continueArea = continueAreaFor(session, queue);
    final primary = _primaryActionFor(
      session: session,
      needsAttention: needsAttention,
      continueArea: continueArea,
      canComplete: canComplete,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Overview'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Center(
              child: SyncStatusPill(
                status: session.syncStatus,
                pendingCount: pendingSyncCount,
                dense: true,
              ),
            ),
          ),
          const PhotoGuideAction(),
        ],
      ),
      body: Column(
        children: [
          if (session.status == InspectionStatus.reported)
            const AppInlineWarningBanner(
              message:
                  'This inspection is completed. Changes may require a new '
                  'report version.',
            ),
          _HousePassAllowanceWatcher(inspectionId: session.id),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              children: [
                _OverviewHeader(session: session),
                const SizedBox(height: AppSpacing.md),
                _StatusStrip(
                  session: session,
                  pendingSyncCount: pendingSyncCount,
                  isOnline: isOnline,
                ),
                const _AutoAnalyseNotice(),
                const SizedBox(height: AppSpacing.md),
                _ProgressCard(
                  session: session,
                  queueLength: queue.length,
                  readiness: readiness,
                  needsAttention: needsAttention,
                ),
                if (session.status == InspectionStatus.inProgress &&
                    queue.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _UpNextAreas(session: session, queue: queue),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppGroupedList(
                  children: [
                    if (primary.kind != _PrimaryKind.areas)
                      AppActionRow(
                        key: const ValueKey('overview-areas'),
                        icon: Icons.grid_view_rounded,
                        title: 'Areas',
                        subtitle: _areasSubtitle(session, queue),
                        onTap: () => context.push(AreasScreen.routePath),
                      ),
                    if (primary.kind != _PrimaryKind.review)
                      AppActionRow(
                        key: const ValueKey('overview-review'),
                        icon: Icons.rate_review_outlined,
                        iconColor: needsAttention > 0
                            ? AppColors.warning
                            : AppColors.primary,
                        title: 'Review findings',
                        subtitle: needsAttention > 0
                            ? '$needsAttention need${needsAttention == 1 ? 's' : ''} '
                                  'your decision'
                            : 'Nothing needs your decision',
                        trailing: AppCountBadge(count: needsAttention),
                        onTap: () =>
                            context.push(AiReviewOverviewScreen.routePath),
                      ),
                    if (primary.kind != _PrimaryKind.report)
                      AppActionRow(
                        key: const ValueKey('overview-report'),
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Report',
                        subtitle: _reportSubtitle(session, readiness),
                        onTap: () => context.push(ReportScreen.routePath),
                      ),
                    AppActionRow(
                      key: const ValueKey('overview-details'),
                      icon: Icons.info_outline,
                      title: 'Inspection details',
                      subtitle: session.inspectionNote == null
                          ? 'Property details and inspection note'
                          : 'Note: ${session.inspectionNote}',
                      onTap: () => _showDetailsSheet(context, ref, session),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppPrimaryActionBar(
        hint: primary.hint,
        primary: FilledButton.icon(
          key: const ValueKey('overview-primary'),
          onPressed: primary.onPressed(context, ref, session),
          icon: Icon(primary.icon),
          label: Text(primary.label),
        ),
        secondary:
            primary.kind != _PrimaryKind.complete &&
                session.status == InspectionStatus.inProgress &&
                canComplete
            ? TextButton(
                key: const ValueKey('overview-complete'),
                onPressed: () => completePhysicalInspection(context, ref),
                child: const Text('Complete Physical Inspection'),
              )
            : null,
      ),
    );
  }

  String _areasSubtitle(InspectionSession session, List<Section> queue) {
    final physical = PhysicalProgress.of(session);
    if (physical.totalAreas == 0) {
      return '${queue.length} suggested area${queue.length == 1 ? '' : 's'}'
          ' · none started';
    }
    return '${physical.completed} of ${physical.totalAreas} inspected '
        'area${physical.totalAreas == 1 ? '' : 's'} complete';
  }

  String _reportSubtitle(InspectionSession session, ReportReadiness r) {
    final report = session.report;
    if (report != null) {
      return report.isStaleRelativeTo(session.updatedAt)
          ? 'Report v${report.version} is out of date'
          : 'Report v${report.version} generated';
    }
    if (session.status == InspectionStatus.inProgress) {
      return 'Available after the site visit';
    }
    return r.isReady ? 'Ready to generate' : (r.summary ?? 'Not ready yet');
  }
}

enum _PrimaryKind { continueArea, areas, complete, review, report }

/// The single primary action for the inspection's current stage.
class _PrimaryAction {
  const _PrimaryAction({
    required this.kind,
    required this.label,
    required this.icon,
    this.hint,
    this.area,
  });

  final _PrimaryKind kind;
  final String label;
  final IconData icon;
  final String? hint;
  final Section? area;

  VoidCallback onPressed(
    BuildContext context,
    WidgetRef ref,
    InspectionSession session,
  ) => switch (kind) {
    _PrimaryKind.continueArea => () => context.push(
      areaFindingsLocation(area!.id),
    ),
    _PrimaryKind.areas => () => context.push(AreasScreen.routePath),
    _PrimaryKind.complete => () => completePhysicalInspection(context, ref),
    _PrimaryKind.review => () => context.push(AiReviewOverviewScreen.routePath),
    _PrimaryKind.report => () => context.push(ReportScreen.routePath),
  };
}

_PrimaryAction _primaryActionFor({
  required InspectionSession session,
  required int needsAttention,
  required Section? continueArea,
  required bool canComplete,
}) {
  if (session.status == InspectionStatus.inProgress) {
    if (continueArea != null) {
      return _PrimaryAction(
        kind: _PrimaryKind.continueArea,
        label: 'Continue Inspection',
        icon: Icons.photo_camera_outlined,
        hint: 'Next: ${continueArea.name}',
        area: continueArea,
      );
    }
    if (canComplete) {
      return const _PrimaryAction(
        kind: _PrimaryKind.complete,
        label: 'Complete Physical Inspection',
        icon: Icons.task_alt,
        hint: 'Every area is marked complete.',
      );
    }
    return const _PrimaryAction(
      kind: _PrimaryKind.areas,
      label: 'View Areas',
      icon: Icons.grid_view_rounded,
    );
  }
  if (needsAttention > 0 && session.status != InspectionStatus.reported) {
    return _PrimaryAction(
      kind: _PrimaryKind.review,
      label: 'Review Findings',
      icon: Icons.rate_review_outlined,
      hint:
          '$needsAttention finding${needsAttention == 1 ? '' : 's'} '
          '${needsAttention == 1 ? 'needs' : 'need'} your decision before '
          'the report.',
    );
  }
  return _PrimaryAction(
    kind: _PrimaryKind.report,
    label: session.report == null ? 'Generate Report' : 'View Report',
    icon: Icons.picture_as_pdf_outlined,
  );
}

/// Confirms and completes the physical site visit, then opens AI Review —
/// the same rules as before (at least one area inspected; AI and review
/// never block it).
Future<void> completePhysicalInspection(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(activeSessionProvider);
  if (session == null) return;
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
  if (confirmed != true || !context.mounted) return;
  final completed = await ref
      .read(activeSessionProvider.notifier)
      .markPhysicalInspectionComplete();
  if (!completed || !context.mounted) return;
  context.push(AiReviewOverviewScreen.routePath);
}

/// Property identity: the residence photo (or illustration), title,
/// status, address and date.
class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.session});

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
    final date = details.inspectionDate ?? session.createdAt;
    final meta = [
      if (details.unitNumber?.isNotEmpty == true) 'Unit ${details.unitNumber}',
      propertyType?.label,
    ].whereType<String>().join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => AppPropertyPhoto(
              photoPath: session.reportMetadata?.coverPhotoPath,
              kind: illustrationKindFor(session.assetTypeId),
              width: constraints.maxWidth,
              height: 132,
              radius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SessionLifecyclePill(status: session.status, dense: false),
                  ],
                ),
                if (meta.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      meta,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (details.address?.isNotEmpty == true)
                  _IconLine(icon: Icons.place_outlined, text: details.address!),
                _IconLine(
                  icon: Icons.event_outlined,
                  text:
                      '${formatInspectionDate(date)} · updated '
                      '${formatRelativeTime(session.updatedAt)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Site-visit progress, the three numbers that matter, and whether the
/// report can be generated.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.session,
    required this.queueLength,
    required this.readiness,
    required this.needsAttention,
  });

  final InspectionSession session;
  final int queueLength;
  final ReportReadiness readiness;
  final int needsAttention;

  @override
  Widget build(BuildContext context) {
    final physical = PhysicalProgress.of(session);
    final processing = AiProcessingProgress.of(session);
    final onSite = session.status == InspectionStatus.inProgress;
    final (readyIcon, readyColor, readyText) = !onSite && readiness.isReady
        ? (Icons.check_circle, AppColors.success, 'Report ready to generate')
        : onSite
        ? (
            Icons.schedule,
            AppColors.textSecondary,
            'Report available after the site visit',
          )
        : (
            Icons.pending_outlined,
            AppColors.warning,
            readiness.summary ?? 'Report not ready yet',
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppProgressBar(
              value: physical.fraction,
              label: 'Site visit',
              valueLabel: physical.totalAreas == 0
                  ? '0 of $queueLength areas started'
                  : '${physical.completed} of ${physical.totalAreas} areas '
                        'complete',
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: session.findings.length,
                    label: 'Findings',
                    icon: Icons.photo_camera_outlined,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: needsAttention,
                    label: 'Need review',
                    icon: Icons.help_outline,
                    color: needsAttention > 0
                        ? AppColors.warning
                        : AppColors.textMuted,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    value: processing.inFlight,
                    label: 'Analysing',
                    icon: Icons.auto_awesome,
                    color: processing.inFlight > 0
                        ? AppColors.info
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            Row(
              key: const ValueKey('overview-report-readiness'),
              children: [
                Icon(readyIcon, size: 18, color: readyColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    readyText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: readyColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// The areas the inspector is most likely to open next — started ones
/// first, then the next untouched ones in queue order — each straight
/// to its findings. "All areas" opens the full Areas screen.
class _UpNextAreas extends ConsumerWidget {
  const _UpNextAreas({required this.session, required this.queue});

  final InspectionSession session;
  final List<Section> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = queue
        .where((s) => areaVisitStateOf(session, s) != AreaVisitState.completed)
        .toList();
    final ordered = [
      ...open.where(
        (s) => areaVisitStateOf(session, s) == AreaVisitState.started,
      ),
      ...open.where(
        (s) => areaVisitStateOf(session, s) == AreaVisitState.untouched,
      ),
    ].take(3).toList();
    if (ordered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: 'Up next',
          trailing: TextButton(
            onPressed: () => context.push(AreasScreen.routePath),
            child: Text('All ${queue.length} areas'),
          ),
        ),
        AppGroupedList(
          children: [
            for (final section in ordered)
              _UpNextRow(
                section: section,
                state: areaVisitStateOf(session, section),
                findingCount: session.findings
                    .where((f) => f.sectionId == section.id)
                    .length,
              ),
          ],
        ),
      ],
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.section,
    required this.state,
    required this.findingCount,
  });

  final Section section;
  final AreaVisitState state;
  final int findingCount;

  @override
  Widget build(BuildContext context) {
    return AppActionRow(
      icon: section.isPlumbing ? Icons.plumbing_outlined : Icons.chair_outlined,
      iconColor: section.isPlumbing ? AppColors.plumbing : AppColors.primary,
      title: section.name,
      subtitle: [
        if (section.isPlumbing) 'Plumbing — inspect first',
        if (findingCount > 0)
          '$findingCount finding${findingCount == 1 ? '' : 's'}',
      ].join(' · ').ifEmpty(null),
      trailing: AreaStatusChip(state: state),
      onTap: () => context.push(areaFindingsLocation(section.id)),
    );
  }
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}

/// Property details and the inspection note, in a sheet — reference
/// information, not a separate screen.
Future<void> _showDetailsSheet(
  BuildContext context,
  WidgetRef ref,
  InspectionSession session,
) {
  final details = session.propertyDetails;
  final rows = <(String, String?)>[
    ('Property', details.title.isEmpty ? null : details.title),
    ('Project / Developer', details.resolvedProjectDeveloperName),
    ('Address', details.address),
    ('Block / Tower', details.blockTower),
    ('Unit', details.unitNumber),
    ('Client', details.clientName),
    ('Inspector', details.inspectorName),
    ('Contact', details.contactNumber),
    (
      'Inspection date',
      details.inspectionDate == null
          ? null
          : formatInspectionDate(details.inspectionDate!),
    ),
  ].where((r) => r.$2?.trim().isNotEmpty == true).toList();

  return showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) => AppSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Inspection details',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      label,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value!,
                      style: Theme.of(sheetContext).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: AppSpacing.xl),
          Text(
            'Inspection note',
            style: Theme.of(sheetContext).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            session.inspectionNote ?? 'No note yet.',
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _editInspectionNote(context, ref, session);
            },
            icon: Icon(
              session.inspectionNote == null
                  ? Icons.note_add_outlined
                  : Icons.edit_outlined,
            ),
            label: Text(
              session.inspectionNote == null
                  ? 'Add inspection note'
                  : 'Edit inspection note',
            ),
          ),
        ],
      ),
    ),
  );
}

/// Keeps billing invisible during field work (QA #23): the backend
/// applies this inspection's House Pass automatically while it has
/// allowance, then Flex Credits. When the allowance runs out the
/// inspector is told that analysis continues on Credits, but is never
/// asked to choose a billing mechanism (analysis is always automatic).
class _HousePassAllowanceWatcher extends ConsumerWidget {
  const _HousePassAllowanceWatcher({required this.inspectionId});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref
        .watch(housePassStatusProvider(inspectionId))
        .value
        ?.status;
    if (status != HousePassLifecycleStatus.allowanceReached) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
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
                'House Pass AI allowance used up. New findings are '
                'analysed with your AI Credits.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AI analysis always runs automatically (tester feedback, 2026-10-02:
/// it is the main reason to use the app), so there is no switch — just
/// a passive line saying so.
class _AutoAnalyseNotice extends StatelessWidget {
  const _AutoAnalyseNotice();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('auto-analyse-notice'),
      children: [
        const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'AI analysis runs automatically for every saved finding.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// A compact, one-or-two-line contextual strip surfacing the single
/// highest-priority real state the inspector should know about right
/// now — never more than two at once. Prioritizes review over
/// AI-in-flight over sync, since review is the only one that's actually
/// blocking the inspector.
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
                Icons.auto_awesome,
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
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> _editInspectionNote(
  BuildContext context,
  WidgetRef ref,
  InspectionSession session,
) async {
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
