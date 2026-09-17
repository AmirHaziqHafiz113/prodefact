import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../config/property_type.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/house_pass_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../widgets/session_status_presentation.dart';
import 'ai_review_overview_screen.dart';
import 'house_pass_screen.dart';

/// A real field-inspection dashboard: overall progress, the ordered
/// queue of included areas (plumbing-related areas first), each area's
/// status/finding/evidence counts, and the final action to complete
/// the physical inspection once every area is done.
class InspectionQueueScreen extends ConsumerWidget {
  const InspectionQueueScreen({super.key});

  static const routePath = '/home-inspection/inspection';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(inspectionQueueProvider);
    final statuses = ref.watch(sectionStatusesProvider);
    final findings = ref.watch(inspectionFindingsProvider);
    final suggestions =
        ref.watch(activeSessionProvider)?.aiSuggestions ?? const [];
    final canComplete = ref.watch(isPhysicalInspectionCompleteProvider);

    final completedCount = queue
        .where(
          (s) =>
              (statuses[s.id] ?? SectionStatus.notStarted) ==
              SectionStatus.completed,
        )
        .length;
    final nextArea = queue.firstWhereOrNullStatus(statuses);
    final remainingCount = queue.length - completedCount;

    final activeSession = ref.watch(activeSessionProvider);
    final pendingSyncCount = activeSession == null
        ? 0
        : activeSession.findings
              .expand((f) => f.evidence)
              .where((e) => e.syncStatus != SyncStatus.synced)
              .length;

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
                if (activeSession?.commercialMode == CommercialMode.housePass)
                  _HousePassBanner(inspectionId: activeSession!.id),
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
                                    '$completedCount of ${queue.length} '
                                    'areas complete',
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
                                  value: queue.isEmpty
                                      ? 0
                                      : completedCount / queue.length,
                                  label:
                                      'Physical\n$completedCount of '
                                      '${queue.length}',
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
                      const SizedBox(height: AppSpacing.md),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  icon: Icons.pending_actions_outlined,
                                  label: '$remainingCount',
                                  caption: 'Remaining',
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
                        title: 'Areas (${queue.length})',
                        subtitle: '$completedCount complete',
                      ),
                      for (final section in queue)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AreaQueueCard(
                            section: section,
                            status:
                                statuses[section.id] ??
                                SectionStatus.notStarted,
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
          child: FilledButton(
            onPressed: canComplete
                ? () => _completeInspection(context, ref)
                : null,
            child: const Text('Complete Physical Inspection'),
          ),
        ),
      ),
    );
  }

  Future<void> _completeInspection(BuildContext context, WidgetRef ref) async {
    await ref
        .read(activeSessionProvider.notifier)
        .markPhysicalInspectionComplete();
    if (!context.mounted) return;
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

/// Re-offers House Pass purchase/confirmation if it was skipped (or a
/// payment attempt failed) right after starting the inspection — never
/// blocks physical inspection either way, so it falls through to
/// nothing once the pass is [HousePassLifecycleStatus.active]. Also
/// owns the "allowance reached" interrupt: the moment a House Pass
/// flips to [HousePassLifecycleStatus.allowanceReached] while Auto
/// Analyse is on, it turns Auto Analyse back off (so no further
/// finding silently starts spending Flex Credits without a fresh,
/// explicit decision) and offers "Continue with AI Credits" to
/// knowingly re-enable it.
class _HousePassBanner extends ConsumerWidget {
  const _HousePassBanner({required this.inspectionId});

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

    final statusAsync = ref.watch(housePassStatusProvider(inspectionId));
    return statusAsync.maybeWhen(
      data: (summary) {
        if (summary.status == HousePassLifecycleStatus.allowanceReached) {
          return const _AllowanceReachedBanner();
        }
        final (message, icon) = switch (summary.status) {
          HousePassLifecycleStatus.purchaseRequired => (
            'This inspection uses House Pass — purchase required to '
                'unlock included AI analysis.',
            Icons.verified_outlined,
          ),
          HousePassLifecycleStatus.paymentPending => (
            'House Pass payment is pending confirmation.',
            Icons.hourglass_top_outlined,
          ),
          HousePassLifecycleStatus.paymentFailed => (
            'House Pass payment failed — tap to try again.',
            Icons.error_outline,
          ),
          _ => (null, null),
        };
        if (message == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: () =>
                context.push('${HousePassScreen.routePath}/$inspectionId'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.warning),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// "House Pass AI allowance reached." — shown once Auto Analyse has
/// already been switched back off by [_HousePassBanner]'s listener;
/// tapping the action is the fresh, explicit consent to keep going on
/// Flex Credits, so it re-enables Auto Analyse rather than just
/// dismissing the banner.
class _AllowanceReachedBanner extends ConsumerWidget {
  const _AllowanceReachedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.data_usage_outlined,
              size: 18,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'House Pass AI allowance reached.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(activeSessionProvider.notifier)
                  .setAutoAnalyseEnabled(true),
              child: const Text('Continue with AI Credits'),
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
    final isHousePass = session.commercialMode == CommercialMode.housePass;
    return Card(
      child: SwitchListTile(
        title: const Text('Auto Analyse'),
        subtitle: Text(
          isHousePass
              ? 'Saved findings will automatically use your House Pass '
                    "allowance, then your AI Credits once it's used up."
              : 'Saved findings will automatically use your AI Credits.',
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
    required this.status,
    required this.isUpNext,
    required this.findingCount,
    required this.evidenceCount,
    required this.aiProcessing,
    required this.review,
    required this.onTap,
  });

  final Section section;
  final SectionStatus status;
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
                    const SizedBox(height: 4),
                    Text(
                      aiProcessing.totalEligible == 0
                          ? 'AI: No findings'
                          : 'AI: ${aiProcessing.processed}/'
                                '${aiProcessing.totalEligible} analysed',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      aiProcessing.totalEligible == 0
                          ? 'Review: Not required'
                          : 'Review: ${review.resolved}/${review.total} '
                                'reviewed',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: _StatusChip(status: status)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SectionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = switch (status) {
      SectionStatus.notStarted => (
        'Not started',
        Icons.circle_outlined,
        AppColors.textSecondary,
        AppColors.neutralBg,
      ),
      SectionStatus.inProgress => (
        'In progress',
        Icons.timelapse,
        AppColors.warning,
        AppColors.warningBg,
      ),
      SectionStatus.completed => (
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
