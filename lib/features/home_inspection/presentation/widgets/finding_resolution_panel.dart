import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../screens/area_inspection_screen.dart' show FindingAiStatusLine;
import 'reanalyse_and_candidates.dart';
import 'related_defect_selector.dart';

Color _toneColor(FindingTone tone) => switch (tone) {
  FindingTone.green => AppColors.success,
  FindingTone.orange => AppColors.warning,
  FindingTone.red => AppColors.danger,
};

String _toneLabel(FindingResolution resolution) => switch (resolution.state) {
  FindingResolutionState.autoAccepted => 'Accepted by AI',
  FindingResolutionState.confirmedByInspector => 'Confirmed',
  FindingResolutionState.processing => 'In progress',
  FindingResolutionState.needsReview => 'Needs your choice',
  FindingResolutionState.unresolved => 'Unresolved',
  FindingResolutionState.failed => 'Needs attention',
};

/// Asks before deleting a finding (photo + classification). Returns
/// whether it was deleted.
Future<bool> confirmAndDeleteFinding(
  BuildContext context,
  WidgetRef ref,
  Finding finding,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete this defect finding?'),
      content: const Text(
        'This removes the photo and its classification from this '
        'inspection.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-delete-finding'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  ref.read(activeSessionProvider.notifier).removeFinding(finding.id);
  return true;
}

/// Everything an inspector needs to settle one finding without leaving
/// the Area page: its colour/state, the current result, the AI's reason,
/// up to 4 Recommended defects, the searchable full catalogue, and
/// Reanalyse / Reject / Delete. Derived from [resolutionOf] — the same
/// rule AI Review and report readiness use — so every screen agrees.
class FindingResolutionPanel extends ConsumerWidget {
  const FindingResolutionPanel({
    super.key,
    required this.finding,
    required this.suggestion,
  });

  final Finding finding;
  final AiSuggestion? suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = resolutionOf(finding, suggestion);
    final tone = resolution.tone;
    final catalogue = DefectCatalogue.instance;
    final finalEntry = suggestion?.hasFinalEntry == true
        ? catalogue.byId(suggestion!.finalCatalogueEntryId!)
        : null;
    final suggestedEntry = suggestion?.suggestedCatalogueEntryId == null
        ? null
        : catalogue.byId(suggestion!.suggestedCatalogueEntryId!);
    final shownEntry = finalEntry ?? suggestedEntry;
    final canPick = FindingResolution.canPickManually(finding);
    final inFlight = aiFindingStatusIsInFlight(finding.aiStatus);
    final needsChoice =
        resolution.state == FindingResolutionState.needsReview ||
        resolution.state == FindingResolutionState.unresolved ||
        resolution.state == FindingResolutionState.failed;
    final failureReason = resolution.state == FindingResolutionState.failed
        ? ref.read(activeSessionProvider.notifier).aiFailureReason(finding.id)
        : null;

    final relatedContext = RelatedDefectContext(
      note: finding.defectNote,
      detectedComponent: suggestion?.detectedComponent,
      candidateEntryIds: suggestion?.suggestedCandidateEntryIds ?? const [],
      excludeEntryId: resolution.isResolved ? shownEntry?.id : null,
    );

    return Column(
      key: ValueKey('finding-panel-${finding.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              key: ValueKey('finding-tone-${finding.id}-${tone.name}'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _toneColor(tone),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _toneLabel(resolution),
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: _toneColor(tone)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (resolution.isResolved && shownEntry != null)
          _ResultBlock(
            entry: shownEntry,
            term: suggestion?.finalDefectTerm,
            findingId: finding.id,
          )
        else
          FindingAiStatusLine(finding: finding, suggestion: suggestion),
        if (failureReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              failureReason,
              key: ValueKey('failure-reason-${finding.id}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (needsChoice &&
            needsReviewReasonText(suggestion?.needsReviewReason) != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              needsReviewReasonText(suggestion?.needsReviewReason)!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.warning),
            ),
          ),
        if (needsChoice && canPick)
          _Recommended(
            finding: finding,
            relatedContext: relatedContext,
            onSelected: (entry) => ref
                .read(activeSessionProvider.notifier)
                .selectDefectForFinding(finding.id, entry.id),
          ),
        if (canPick)
          RelatedDefectSelector(
            keyId: finding.id,
            relatedContext: relatedContext,
            onSelected: (entry) => ref
                .read(activeSessionProvider.notifier)
                .selectDefectForFinding(finding.id, entry.id),
          ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: 0,
          children: [
            TextButton.icon(
              key: ValueKey('reanalyse-finding-${finding.id}'),
              onPressed: finding.isAiEligible && !inFlight
                  ? () => showReanalyseDialog(
                      context: context,
                      ref: ref,
                      finding: finding,
                    )
                  : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reanalyse'),
            ),
            if (suggestion != null && !suggestion!.isRejected && canPick)
              TextButton.icon(
                key: ValueKey('reject-finding-${finding.id}'),
                onPressed: () => ref
                    .read(activeSessionProvider.notifier)
                    .rejectSuggestion(suggestion!.id),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Reject'),
              ),
            TextButton.icon(
              key: ValueKey('delete-finding-${finding.id}'),
              onPressed: () => confirmAndDeleteFinding(context, ref, finding),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.entry,
    required this.term,
    required this.findingId,
  });

  final DefectCatalogueEntry entry;
  final String? term;
  final String findingId;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('finding-result-$findingId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          concreteDefectText(
            componentName: entry.componentName,
            defectDescription: entry.defectDescription,
            term: term,
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          '${entry.mainElementName} · ${entry.componentName}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Up to 4 best catalogue matches, one tap each (never an AI call).
class _Recommended extends StatelessWidget {
  const _Recommended({
    required this.finding,
    required this.relatedContext,
    required this.onSelected,
  });

  final Finding finding;
  final RelatedDefectContext relatedContext;
  final void Function(DefectCatalogueEntry entry) onSelected;

  @override
  Widget build(BuildContext context) {
    final noteMissing = (finding.defectNote ?? '').trim().isEmpty;
    final ranked = rankRelatedDefects(relatedContext);
    // With neither a note nor an AI hint there is nothing to rank by —
    // an arbitrary "recommendation" would be noise.
    if (noteMissing &&
        relatedContext.candidateEntryIds.isEmpty &&
        relatedContext.detectedComponent == null) {
      return const SizedBox.shrink();
    }
    final top = ranked.take(4).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return Column(
      key: ValueKey('recommended-${finding.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Recommended defects',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final entry in top)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            child: ListTile(
              key: ValueKey('recommended-${finding.id}-${entry.id}'),
              dense: true,
              title: Text(entry.defectDescription),
              subtitle: Text(
                '${entry.mainElementName} · ${entry.componentName}',
              ),
              trailing: const Icon(Icons.check_circle_outline),
              onTap: () => onSelected(entry),
            ),
          ),
      ],
    );
  }
}
