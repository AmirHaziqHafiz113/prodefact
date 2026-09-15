import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        body: const Center(child: Text('No active inspection.')),
      );
    }

    final suggestions = session.aiSuggestions;
    final pendingCount = suggestions
        .where((s) => s.status == AiSuggestionStatus.pending)
        .length;
    final reviewedCount = suggestions.length - pendingCount;
    final canContinue = session.aiReviewState == AiReviewState.completed;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Review')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _StatusPanel(session: session),
          ),
          if (suggestions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${suggestions.length} suggestion(s) · $pendingCount pending · '
                    '$reviewedCount reviewed',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: suggestions.isEmpty
                        ? 0
                        : reviewedCount / suggestions.length,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final suggestion in suggestions)
              _SuggestionCard(session: session, suggestion: suggestion),
          ],
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
            const Text(
              'Physical inspection is complete. Findings and photos can '
              'now be analyzed — AI never looks at photos before this '
              'point.',
            ),
            const SizedBox(height: 12),
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
            SizedBox(width: 12),
            Text('Analyzing findings…'),
          ],
        );
      case AiReviewState.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'AI analysis failed. Your physical inspection data is safe '
              'and unaffected — you can retry.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _runAnalysis(context, ref),
              child: const Text('Retry AI Analysis'),
            ),
          ],
        );
      case AiReviewState.readyForReview:
        return const Text('Review each AI suggestion below.');
      case AiReviewState.completed:
        return const Text(
          'AI review is complete. You may continue to the report.',
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: suggestion.status),
              ],
            ),
            if (finding?.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                'Inspector finding: ${finding!.description}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (finding != null && finding.evidence.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${finding.evidence.length} photo(s) attached.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Divider(),
            Text(
              'AI suggests: ${suggestion.suggestedDefectType ?? '(no defect type)'}',
            ),
            if (suggestion.suggestedRecommendation != null)
              Text(suggestion.suggestedRecommendation!),
            if (suggestion.suggestedNotes != null)
              Text(
                suggestion.suggestedNotes!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (suggestion.isResolved) ...[
              const SizedBox(height: 8),
              Text(
                'Final: ${suggestion.finalDefectType?.isNotEmpty == true ? suggestion.finalDefectType : '(none)'}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            const SizedBox(height: 8),
            if (!suggestion.isResolved)
              Wrap(
                spacing: 8,
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
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AiSuggestionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AiSuggestionStatus.pending => ('Pending', Colors.orange),
      AiSuggestionStatus.accepted => ('Accepted', Colors.green),
      AiSuggestionStatus.edited => ('Edited', Colors.blue),
      AiSuggestionStatus.rejected => ('Rejected', Colors.red),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}
