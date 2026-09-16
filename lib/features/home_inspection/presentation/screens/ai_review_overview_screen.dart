import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'ai_suggestion_review_dialog.dart';

/// Overview of AI's progressive classification work across every
/// finding in the inspection, and where the inspector reviews each
/// result (Accept / Change / Reject). AI has already been running in
/// the background per finding — see `docs/ai_provider_architecture.md`
/// — so there is no "Start AI Analysis" button here any more; this
/// screen only surfaces progress and review actions.
class AiReviewOverviewScreen extends ConsumerWidget {
  const AiReviewOverviewScreen({super.key});

  static const routePath = '/home-inspection/complete';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI Review')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'No active inspection.',
        ),
      );
    }

    final processing = AiProcessingProgress.of(session);
    final review = AiReviewProgress.of(session);
    final canContinue = processing.inFlight == 0 && review.pending == 0;
    final suggestions = session.aiSuggestions;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Review')),
      body: ListView(
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
              child: _StatusPanel(processing: processing, review: review),
            ),
          ),
          if (suggestions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                'No findings have photos yet, so there is nothing for AI '
                'to review.',
              ),
            )
          else ...[
            const SizedBox(height: AppSpacing.lg),
            for (final suggestion in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _SuggestionCard(
                  session: session,
                  suggestion: suggestion,
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: canContinue
                ? () => context.push('/home-inspection/report')
                : null,
            child: const Text('Continue to Report'),
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.processing, required this.review});

  final AiProcessingProgress processing;
  final AiReviewProgress review;

  @override
  Widget build(BuildContext context) {
    if (processing.totalEligible == 0) {
      return const Row(
        children: [
          Icon(Icons.smart_toy_outlined, color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Take a photo of a defect in any area to start getting AI '
              'suggestions.',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppProgressBar(
          value: processing.fraction,
          label: 'AI analysing findings',
          valueLabel:
              '${processing.processed} of ${processing.totalEligible} '
              '(${processing.percent}%)',
        ),
        if (review.total > 0) ...[
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: review.fraction,
            label: 'Reviewed by you',
            valueLabel: '${review.resolved} of ${review.total}',
          ),
        ],
        if (processing.failed > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${processing.failed} finding(s) could not be analyzed. '
                  'Your photos and notes are safe — retry from the area '
                  'screen.',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.session, required this.suggestion});

  final InspectionSession session;
  final AiSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finding = session.findings.firstWhereOrNull(
      (f) => f.id == suggestion.findingId,
    );
    final section = finding == null
        ? null
        : session.sections.firstWhereOrNull((s) => s.id == finding.sectionId);
    final catalogue = DefectCatalogue.instance;
    final suggestedEntry = suggestion.suggestedCatalogueEntryId == null
        ? null
        : catalogue.byId(suggestion.suggestedCatalogueEntryId!);
    final finalEntry = suggestion.hasFinalEntry
        ? catalogue.byId(suggestion.finalCatalogueEntryId!)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section?.name ?? 'Area',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: suggestion.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AttributedBlock(
              label: 'Your note',
              icon: Icons.person_outline,
              color: AppColors.textSecondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finding?.description?.isNotEmpty == true
                        ? finding!.description!
                        : '(No note)',
                  ),
                  if (finding != null && finding.evidence.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${finding.evidence.length} photo(s) attached.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _AttributedBlock(
              label: 'AI suggestion (advisory)',
              icon: Icons.smart_toy_outlined,
              color: AppColors.info,
              child: suggestedEntry == null
                  ? const Text(
                      'Not confident enough to suggest a match — please '
                      'classify this one yourself.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Finding: ${suggestedEntry.defectDescription}'),
                        if (suggestedEntry.correctiveAction != null)
                          Text(
                            'Recommendation: '
                            '${suggestedEntry.correctiveAction}',
                          ),
                        if (suggestion.suggestedShortReason != null)
                          Text(
                            suggestion.suggestedShortReason!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
            ),
            if (suggestion.isResolved) ...[
              const SizedBox(height: AppSpacing.sm),
              _AttributedBlock(
                label: 'Your final decision',
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                child: Text(
                  finalEntry != null
                      ? finalEntry.defectDescription
                      : 'Unresolved — pending manual classification',
                ),
              ),
            ],
            if (!suggestion.isResolved) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (suggestedEntry != null)
                    FilledButton(
                      onPressed: () => ref
                          .read(activeSessionProvider.notifier)
                          .acceptSuggestion(suggestion.id),
                      child: const Text('Accept'),
                    ),
                  OutlinedButton(
                    onPressed: () => showAiSuggestionReviewDialog(
                      context: context,
                      ref: ref,
                      suggestion: suggestion,
                    ),
                    child: const Text('Change'),
                  ),
                  OutlinedButton(
                    onPressed: () => ref
                        .read(activeSessionProvider.notifier)
                        .rejectSuggestion(suggestion.id),
                    child: const Text('Reject / Unresolved'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Visually attributes a block of text to who/what produced it —
/// inspector, AI, or the inspector's final decision — so the three
/// never blur together.
class _AttributedBlock extends StatelessWidget {
  const _AttributedBlock({
    required this.label,
    required this.icon,
    required this.color,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AiSuggestionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, fg, bg) = switch (status) {
      AiSuggestionStatus.pending => (
        'Pending',
        Icons.hourglass_empty,
        AppColors.warning,
        AppColors.warningBg,
      ),
      AiSuggestionStatus.accepted => (
        'Accepted',
        Icons.check_circle_outline,
        AppColors.success,
        AppColors.successBg,
      ),
      AiSuggestionStatus.edited => (
        'Changed',
        Icons.edit_outlined,
        AppColors.info,
        AppColors.infoBg,
      ),
      AiSuggestionStatus.rejected => (
        'Unresolved',
        Icons.cancel_outlined,
        AppColors.danger,
        AppColors.dangerBg,
      ),
    };
    return StatusPill(label: label, icon: icon, foreground: fg, background: bg);
  }
}
