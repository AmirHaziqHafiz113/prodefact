import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/physical_inspection_providers.dart';

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
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      96,
                    ),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppProgressBar(
                                value: queue.isEmpty
                                    ? 0
                                    : completedCount / queue.length,
                                label: 'Inspection progress',
                                valueLabel:
                                    '$completedCount of ${queue.length} '
                                    'areas',
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
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
                      const SizedBox(height: AppSpacing.lg),
                      const AppSectionHeader(title: 'Areas'),
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
                              '/home-inspection/inspection/${section.id}',
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
    context.push('/home-inspection/complete');
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
                    Row(
                      children: [
                        if (findingCount > 0) ...[
                          const Icon(
                            Icons.report_gmailerrorred_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$findingCount finding${findingCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: AppSpacing.md),
                        ],
                        if (evidenceCount > 0) ...[
                          const Icon(
                            Icons.photo_camera_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$evidenceCount photo${evidenceCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
              _StatusChip(status: status),
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
