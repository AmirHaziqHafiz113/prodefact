import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'ai_suggestion_review_dialog.dart';

/// Reached once the inspector completes the physical inspection. Runs
/// (or retries) AI analysis, then lets the inspector accept/edit/reject
/// every suggestion before "Continue to Report" unlocks — see
/// `docs/ai_review.md` for the full lifecycle this screen drives.
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

    final suggestions = session.aiSuggestions;
    final pendingCount = suggestions
        .where((s) => s.status == AiSuggestionStatus.pending)
        .length;
    final acceptedCount = suggestions
        .where((s) => s.status == AiSuggestionStatus.accepted)
        .length;
    final editedCount = suggestions
        .where((s) => s.status == AiSuggestionStatus.edited)
        .length;
    final rejectedCount = suggestions
        .where((s) => s.status == AiSuggestionStatus.rejected)
        .length;
    final reviewedCount = suggestions.length - pendingCount;
    final canContinue = session.aiReviewState == AiReviewState.completed;

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
              child: _StatusPanel(session: session),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppProgressBar(
                      value: suggestions.isEmpty
                          ? 0
                          : reviewedCount / suggestions.length,
                      label: 'Review progress',
                      valueLabel: '$reviewedCount of ${suggestions.length}',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        StatusPill(
                          label: '$pendingCount pending',
                          icon: Icons.hourglass_empty,
                          foreground: AppColors.warning,
                          background: AppColors.warningBg,
                          dense: true,
                        ),
                        StatusPill(
                          label: '$acceptedCount accepted',
                          icon: Icons.check_circle_outline,
                          foreground: AppColors.success,
                          background: AppColors.successBg,
                          dense: true,
                        ),
                        StatusPill(
                          label: '$editedCount edited',
                          icon: Icons.edit_outlined,
                          foreground: AppColors.info,
                          background: AppColors.infoBg,
                          dense: true,
                        ),
                        StatusPill(
                          label: '$rejectedCount rejected',
                          icon: Icons.cancel_outlined,
                          foreground: AppColors.danger,
                          background: AppColors.dangerBg,
                          dense: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.session});

  final InspectionSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (session.aiReviewState) {
      case AiReviewState.notStarted:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.smart_toy_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Physical inspection is complete. Findings and photos '
                    'can now be analyzed — AI never looks at photos before '
                    'this point.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => _runAnalysis(context, ref),
              child: const Text('Start AI Analysis'),
            ),
          ],
        );
      case AiReviewState.analyzing:
        return const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Text('Analyzing findings…'),
          ],
        );
      case AiReviewState.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI analysis failed. Your physical inspection data is '
                    'safe and unaffected — you can retry.',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => _runAnalysis(context, ref),
              child: const Text('Retry AI Analysis'),
            ),
          ],
        );
      case AiReviewState.readyForReview:
        return const Text('Review each AI suggestion below.');
      case AiReviewState.completed:
        return Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'AI review is complete. You may continue to the report.',
              ),
            ),
          ],
        );
    }
  }

  Future<void> _runAnalysis(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(activeSessionProvider.notifier)
        .startAiAnalysis();
    if (!context.mounted || result.isSuccess) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              'AI analysis could not run (${result.outcome.name}).',
        ),
      ),
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
    final element = (finding == null || section == null)
        ? null
        : section.elements.firstWhereOrNull((e) => e.id == finding.elementId);
    final component = element?.components.firstWhereOrNull(
      (c) => c.id == finding?.componentId,
    );

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
                    [
                      section?.name,
                      element?.name,
                      component?.name,
                    ].whereType<String>().join(' / '),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(status: suggestion.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AttributedBlock(
              label: 'Inspector finding',
              icon: Icons.person_outline,
              color: AppColors.textSecondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finding?.description?.isNotEmpty == true
                        ? finding!.description!
                        : '(No description)',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(suggestion.suggestedDefectType ?? '(no defect type)'),
                  if (suggestion.suggestedRecommendation != null)
                    Text(suggestion.suggestedRecommendation!),
                  if (suggestion.suggestedNotes != null)
                    Text(
                      suggestion.suggestedNotes!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (suggestion.isResolved) ...[
              const SizedBox(height: AppSpacing.sm),
              _AttributedBlock(
                label: 'Inspector final decision',
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                child: Text(
                  suggestion.finalDefectType?.isNotEmpty == true
                      ? suggestion.finalDefectType!
                      : '(none)',
                ),
              ),
            ],
            if (!suggestion.isResolved) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton(
                    onPressed: () => ref
                        .read(activeSessionProvider.notifier)
                        .acceptSuggestion(suggestion.id),
                    child: const Text('Accept'),
                  ),
                  OutlinedButton(
                    onPressed: section == null
                        ? null
                        : () => showAiSuggestionReviewDialog(
                            context: context,
                            ref: ref,
                            section: section,
                            suggestion: suggestion,
                            isReject: false,
                          ),
                    child: const Text('Edit'),
                  ),
                  OutlinedButton(
                    onPressed: section == null
                        ? null
                        : () => showAiSuggestionReviewDialog(
                            context: context,
                            ref: ref,
                            section: section,
                            suggestion: suggestion,
                            isReject: true,
                          ),
                    child: const Text('Reject / Correct'),
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
        'Edited',
        Icons.edit_outlined,
        AppColors.info,
        AppColors.infoBg,
      ),
      AiSuggestionStatus.rejected => (
        'Rejected',
        Icons.cancel_outlined,
        AppColors.danger,
        AppColors.dangerBg,
      ),
    };
    return StatusPill(label: label, icon: icon, foreground: fg, background: bg);
  }
}
