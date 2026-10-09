import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'ai_suggestion_review_dialog.dart';
import '../widgets/finding_status_presentation.dart';
import '../widgets/reanalyse_and_candidates.dart';
import '../widgets/related_defect_selector.dart';
import 'area_inspection_screen.dart'
    show AiImageQualityNote, FindingAiStatusLine;
import 'finding_detail_screen.dart';
import 'report_screen.dart';

/// The inspector's review inbox for the open inspection — exceptions
/// only. It shows the findings that need a decision: a pending AI
/// suggestion (low confidence, note/image conflict, several candidates),
/// a failed analysis, a rejected (unresolved) result, or a finding
/// still waiting for its note. Confirmed findings don't clutter it; they
/// sit in a collapsed "Resolved" group where they can still be changed.
/// Findings still being analysed are summarised in one line, and show
/// up here only if they come back needing the inspector. Area Findings
/// remains the place to see everything — see docs/ux_architecture.md.
class AiReviewOverviewScreen extends ConsumerStatefulWidget {
  const AiReviewOverviewScreen({super.key});

  static const routePath = '/home-inspection/complete';

  @override
  ConsumerState<AiReviewOverviewScreen> createState() =>
      _AiReviewOverviewScreenState();
}

class _AiReviewOverviewScreenState
    extends ConsumerState<AiReviewOverviewScreen> {
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
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
    // Only suggestions of findings that still exist — a deleted
    // finding (or any orphan) never shows here or counts.
    final suggestions = activeSuggestionsOf(session);
    final suggestionByFinding = {for (final s in suggestions) s.findingId: s};
    // Ordered by AI progress, newest first within each.
    final ordered = [
      for (final unit in orderFindings(
        session.findings.where((f) => f.isAiEligible).toList(),
      ))
        ...unit.findings,
    ];
    final exceptions = ordered
        .where((f) => findingNeedsAttention(f, suggestionByFinding[f.id]))
        .toList();
    final resolvedSuggestions = suggestions
        .where(
          (s) =>
              !exceptions.any((f) => f.id == s.findingId) &&
              session.findings.any(
                (f) => f.id == s.findingId && resolutionOf(f, s).isResolved,
              ),
        )
        .toList();
    final outstanding = ReportReadiness.of(session).summary;
    final pendingNote = outstanding == null
        ? null
        : '$outstanding. The report can be generated once these are done.';

    return Scaffold(
      appBar: AppBar(title: const Text('AI Review')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _StatusPanel(processing: processing, review: review),
            ),
          ),
          if (processing.inFlight > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              key: const ValueKey('review-in-flight'),
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${processing.inFlight} '
                    'finding${processing.inFlight == 1 ? '' : 's'} still '
                    'being analysed — '
                    '${processing.inFlight == 1 ? 'it appears' : 'they appear'}'
                    ' here only if you need to decide.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (processing.totalEligible == 0)
            const AppEmptyView(
              icon: Icons.photo_camera_outlined,
              title: 'Nothing to review yet',
              message:
                  'No findings have photos yet, so there is nothing for AI '
                  'to review.',
            )
          else if (exceptions.isEmpty)
            AppEmptyView(
              icon: Icons.task_alt,
              title: 'Nothing needs your review',
              message: processing.inFlight > 0
                  ? 'Every analysed finding is settled. Findings still '
                        'being analysed will appear here only if they need '
                        'you.'
                  : 'Every finding has a confirmed defect.',
            )
          else ...[
            AppSectionHeader(
              title: 'Needs your decision (${exceptions.length})',
              subtitle: 'Settle each one before generating the report.',
            ),
            ..._groupedByArea(context, session, exceptions, (finding) {
              final suggestion = suggestionByFinding[finding.id];
              return suggestion == null
                  ? _PendingFindingCard(session: session, finding: finding)
                  : _SuggestionCard(session: session, suggestion: suggestion);
            }),
          ],
          if (resolvedSuggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('review-show-resolved'),
                onTap: () => setState(() => _showResolved = !_showResolved),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Resolved (${resolvedSuggestions.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        _showResolved ? 'Hide' : 'Show',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: AppColors.primary),
                      ),
                      Icon(
                        _showResolved ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showResolved) ...[
              const SizedBox(height: AppSpacing.md),
              for (final suggestion in resolvedSuggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _SuggestionCard(
                    session: session,
                    suggestion: suggestion,
                  ),
                ),
            ],
          ],
        ],
      ),
      // Always tappable (QA #32/#33): AI and review gate report
      // *generation*, which the Report screen enforces and explains —
      // never the way forward from this screen.
      bottomNavigationBar: AppPrimaryActionBar(
        hint: pendingNote,
        primary: FilledButton(
          onPressed: () => context.push(ReportScreen.routePath),
          child: const Text('Continue to Report'),
        ),
      ),
    );
  }
}

/// [findings] as cards under area headings, in configured area order;
/// a finding whose area was since removed is still listed (never
/// silently dropped).
List<Widget> _groupedByArea(
  BuildContext context,
  InspectionSession session,
  List<Finding> findings,
  Widget Function(Finding finding) cardFor,
) {
  final widgets = <Widget>[];
  final shown = <String>{};
  for (final section in session.sections.where((s) => s.isIncluded)) {
    final inArea = findings.where((f) => f.sectionId == section.id).toList();
    if (inArea.isEmpty) continue;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          section.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
    for (final finding in inArea) {
      shown.add(finding.id);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: cardFor(finding),
        ),
      );
    }
  }
  for (final finding in findings.where((f) => !shown.contains(f.id))) {
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: cardFor(finding),
      ),
    );
  }
  return widgets;
}

/// A finding with no AI suggestion yet: its photo, note, and live AI
/// status with the action that moves it on.
class _PendingFindingCard extends ConsumerWidget {
  const _PendingFindingCard({required this.session, required this.finding});

  final InspectionSession session;
  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = session.sections
        .firstWhereOrNull((s) => s.id == finding.sectionId)
        ?.name;
    final photo = finding.evidence.firstOrNull;
    return Card(
      key: ValueKey('pending-finding-${finding.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.file(
                        File(photo.displayFilePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const ColoredBox(color: AppColors.surfaceAlt),
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (area != null)
                        Text(
                          area,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      if (finding.defectNote != null)
                        Text(
                          finding.defectNote!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      FindingAiStatusLine(finding: finding, suggestion: null),
                    ],
                  ),
                ),
              ],
            ),
            // A failed finding has no AiSuggestion yet (the attempt
            // errored before AI answered) — still manually classifiable
            // straight from here, no AI call involved.
            if (finding.aiStatus == AiFindingStatus.failed) ...[
              const SizedBox(height: AppSpacing.sm),
              RelatedDefectSelector(
                keyId: finding.id,
                relatedContext: RelatedDefectContext(note: finding.defectNote),
                onSelected: (entry) => ref
                    .read(activeSessionProvider.notifier)
                    .selectDefectForFinding(finding.id, entry.id),
              ),
            ],
          ],
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
            label: review.autoAccepted > 0
                ? 'Report-ready (${review.autoAccepted} accepted '
                      'automatically)'
                : 'Reviewed by you',
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
                _StatusChip(
                  status: suggestion.status,
                  automatic: suggestion.isAutoAccepted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Evidence first (mission "AI REVIEW" hierarchy) — the
            // photo the AI match and the inspector's decision are both
            // actually about, given real visual weight rather than a
            // small thumbnail bundled into the note row.
            if (finding != null && finding.evidence.isNotEmpty) ...[
              // Whole photo, own orientation (QA #18): letterboxed, never
              // cropped. Shows the inspector's markup when there is one.
              InkWell(
                key: ValueKey('review-open-finding-${finding.id}'),
                onTap: () => context.push(findingDetailLocation(finding.id)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: ColoredBox(
                    color: Colors.black,
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: Image.file(
                        File(finding.evidence.first.displayFilePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
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
                        Text(
                          'Finding: ${concreteDefectText(componentName: suggestedEntry.componentName, defectDescription: suggestedEntry.defectDescription, term: suggestion.suggestedDefectTerm)}',
                        ),
                        if (suggestedEntry.correctiveAction != null)
                          Text(
                            'Recommendation: '
                            '${suggestedEntry.correctiveAction}',
                          ),
                        if (aiImageQualityNote(suggestion) case final note?)
                          AiImageQualityNote(text: note),
                        if (suggestion.suggestedShortReason != null ||
                            suggestion.suggestedConfidence != null)
                          _AiDetailsToggle(suggestion: suggestion),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Always available — passed, needs review, or already
            // manually corrected — never only while unresolved: the
            // inspector's own search, never another AI call.
            RelatedDefectSelector(
              keyId: suggestion.id,
              relatedContext: RelatedDefectContext(
                note: finding?.defectNote,
                detectedComponent: suggestion.detectedComponent,
                candidateEntryIds: suggestion.suggestedCandidateEntryIds,
                excludeEntryId: finalEntry?.id ?? suggestedEntry?.id,
              ),
              onSelected: (entry) => ref
                  .read(activeSessionProvider.notifier)
                  .selectDefectForFinding(suggestion.findingId, entry.id),
            ),
            if (suggestion.isResolved) ...[
              const SizedBox(height: AppSpacing.sm),
              _AttributedBlock(
                label: suggestion.isAutoAccepted
                    ? 'Accepted automatically'
                    : 'Your final decision',
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                child: Text(
                  finalEntry != null
                      ? concreteDefectText(
                          componentName: finalEntry.componentName,
                          defectDescription: finalEntry.defectDescription,
                          term: suggestion.finalDefectTerm,
                        )
                      : 'Unresolved — pending manual classification',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // A decision — automatic or the inspector's — is never
              // final: it can still be changed or rejected.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton(
                    key: ValueKey('change-${suggestion.id}'),
                    onPressed: () => showAiSuggestionReviewDialog(
                      context: context,
                      ref: ref,
                      suggestion: suggestion,
                    ),
                    child: const Text('Change'),
                  ),
                  if (finding != null)
                    TextButton(
                      key: ValueKey('reanalyse-${suggestion.id}'),
                      onPressed: () => showReanalyseDialog(
                        context: context,
                        ref: ref,
                        finding: finding,
                      ),
                      child: const Text('Reanalyse'),
                    ),
                  if (suggestion.status != AiSuggestionStatus.rejected)
                    TextButton(
                      key: ValueKey('reject-${suggestion.id}'),
                      onPressed: () => ref
                          .read(activeSessionProvider.notifier)
                          .rejectSuggestion(suggestion.id),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Reject / Unresolved'),
                    ),
                ],
              ),
            ],
            if (!suggestion.isResolved) ...[
              if (needsReviewReasonText(suggestion.needsReviewReason)
                  case final reason?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    reason,
                    key: ValueKey('review-reason-${suggestion.id}'),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.warning),
                  ),
                ),
              PossibleDefectsList(
                suggestion: suggestion,
                excludeEntryId: suggestedEntry?.id,
              ),
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
                  // Tertiary — real but never the same visual weight as
                  // Accept (positive) or Change (strong secondary), so
                  // it doesn't compete for attention (§21).
                  TextButton(
                    onPressed: () => ref
                        .read(activeSessionProvider.notifier)
                        .rejectSuggestion(suggestion.id),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text('Reject / Unresolved'),
                  ),
                  if (finding != null)
                    TextButton(
                      key: ValueKey('reanalyse-${suggestion.id}'),
                      onPressed: () => showReanalyseDialog(
                        context: context,
                        ref: ref,
                        finding: finding,
                      ),
                      child: const Text('Reanalyse'),
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.2,
                  ),
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
  const _StatusChip({required this.status, this.automatic = false});

  final AiSuggestionStatus status;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final (appStatus, label) = switch (status) {
      AiSuggestionStatus.pending => (AppStatus.needsReview, 'Pending'),
      AiSuggestionStatus.accepted => (
        AppStatus.confirmed,
        automatic ? 'Auto-accepted' : 'Accepted',
      ),
      AiSuggestionStatus.edited => (AppStatus.confirmed, 'Changed'),
      AiSuggestionStatus.rejected => (AppStatus.rejected, 'Unresolved'),
    };
    return AppStatusChip(status: appStatus, label: label, dense: false);
  }
}
