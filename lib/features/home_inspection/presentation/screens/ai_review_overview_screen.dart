import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'ai_suggestion_review_dialog.dart';
import 'report_screen.dart';

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
            for (final section in session.sections.where((s) => s.isIncluded))
              ..._sectionGroup(context, session, section, suggestions),
            // A suggestion whose finding's area was since excluded/removed
            // from the draft still needs to be reviewable — never
            // silently dropped from this screen just because its area
            // no longer appears in the configured list.
            ..._ungroupedSuggestions(session, suggestions),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton(
            onPressed: canContinue
                ? () => context.push(ReportScreen.routePath)
                : null,
            child: const Text('Continue to Report'),
          ),
        ),
      ),
    );
  }
}

/// One area's worth of suggestion cards, headed by the area name — see
/// `docs/home_inspection_product_flow.md` ("AI Review UX"). Returns an
/// empty list (no header rendered) for an area with no AI-eligible
/// findings yet.
List<Widget> _sectionGroup(
  BuildContext context,
  InspectionSession session,
  Section section,
  List<AiSuggestion> suggestions,
) {
  final sectionSuggestions = suggestions.where((s) {
    final finding = session.findings.firstWhereOrNull(
      (f) => f.id == s.findingId,
    );
    return finding?.sectionId == section.id;
  }).toList();
  if (sectionSuggestions.isEmpty) return const [];

  return [
    Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(section.name, style: Theme.of(context).textTheme.titleMedium),
    ),
    for (final suggestion in sectionSuggestions)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _SuggestionCard(session: session, suggestion: suggestion),
      ),
  ];
}

List<Widget> _ungroupedSuggestions(
  InspectionSession session,
  List<AiSuggestion> suggestions,
) {
  final includedIds = session.sections
      .where((s) => s.isIncluded)
      .map((s) => s.id)
      .toSet();
  final orphaned = suggestions.where((s) {
    final finding = session.findings.firstWhereOrNull(
      (f) => f.id == s.findingId,
    );
    return finding == null || !includedIds.contains(finding.sectionId);
  }).toList();
  if (orphaned.isEmpty) return const [];

  return [
    for (final suggestion in orphaned)
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _SuggestionCard(session: session, suggestion: suggestion),
      ),
  ];
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (finding != null && finding.evidence.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Image.file(
                          File(finding.evidence.first.filePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _AttributedBlock(
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
                        if (finding != null && finding.evidence.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${finding.evidence.length} photos attached.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
                        if (suggestion.suggestedShortReason != null ||
                            suggestion.suggestedConfidence != null)
                          _AiDetailsToggle(suggestion: suggestion),
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

/// A lightweight "AI details" expand/collapse for confidence + reason —
/// deliberately not `ExpansionTile` (it renders a `ListTile` internally,
/// which asserts when placed on a colored `Container` background like
/// `_AttributedBlock`'s without its own `Material` ancestor).
class _AiDetailsToggle extends StatefulWidget {
  const _AiDetailsToggle({required this.suggestion});

  final AiSuggestion suggestion;

  @override
  State<_AiDetailsToggle> createState() => _AiDetailsToggleState();
}

class _AiDetailsToggleState extends State<_AiDetailsToggle> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('AI details', style: Theme.of(context).textTheme.bodySmall),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16),
            ],
          ),
        ),
        if (_expanded) ...[
          if (widget.suggestion.suggestedShortReason != null)
            Text(
              widget.suggestion.suggestedShortReason!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (widget.suggestion.suggestedConfidence != null)
            Text(
              'Confidence: '
              '${(widget.suggestion.suggestedConfidence! * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
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
