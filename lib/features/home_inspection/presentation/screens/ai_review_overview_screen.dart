import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import 'ai_suggestion_review_dialog.dart';
import 'area_inspection_screen.dart' show FindingAiStatusLine;
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
    final suggestions = session.aiSuggestions;
    // Findings AI hasn't produced a suggestion for yet (queued,
    // analysing, failed, or waiting for a note/approval). Previously
    // these were not shown here at all, so a failed or stuck analysis
    // left a page with nothing to tap (QA #33).
    final suggestedIds = {for (final s in suggestions) s.findingId};
    final withoutSuggestion = session.findings
        .where((f) => f.isAiEligible && !suggestedIds.contains(f.id))
        .toList();
    final pendingNote = _pendingSummary(processing, review, withoutSuggestion);

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
          if (withoutSuggestion.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: 'Waiting on AI (${withoutSuggestion.length})',
              subtitle: 'Each finding shows what happens next.',
            ),
            for (final finding in withoutSuggestion)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PendingFindingCard(session: session, finding: finding),
              ),
          ],
          if (suggestions.isEmpty && withoutSuggestion.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.lg),
              child: Text(
                'No findings have photos yet, so there is nothing for AI '
                'to review.',
              ),
            )
          else if (suggestions.isNotEmpty) ...[
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
      // Always tappable (QA #32/#33): AI and review gate report
      // *generation*, which the Report screen enforces and explains —
      // never the way forward from this screen.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pendingNote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    pendingNote,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              FilledButton(
                onPressed: () => context.push(ReportScreen.routePath),
                child: const Text('Continue to Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Why the report isn't ready yet, in one line, or null when it is.
String? _pendingSummary(
  AiProcessingProgress processing,
  AiReviewProgress review,
  List<Finding> withoutSuggestion,
) {
  final parts = <String>[];
  if (processing.inFlight > 0) {
    parts.add(
      'AI is still working on ${processing.inFlight} '
      'finding${processing.inFlight == 1 ? '' : 's'}',
    );
  }
  final failed = withoutSuggestion
      .where((f) => f.aiStatus == AiFindingStatus.failed)
      .length;
  if (failed > 0) {
    parts.add(
      '$failed need${failed == 1 ? 's' : ''} a retry or manual classification',
    );
  }
  if (review.pending > 0) {
    parts.add('${review.pending} to review');
  }
  if (parts.isEmpty) return null;
  return '${parts.join(' · ')}. The report can be generated once these are '
      'done.';
}

/// A finding with no AI suggestion yet: its photo, note, and live AI
/// status with the action that moves it on.
class _PendingFindingCard extends StatelessWidget {
  const _PendingFindingCard({required this.session, required this.finding});

  final InspectionSession session;
  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final area = session.sections
        .firstWhereOrNull((s) => s.id == finding.sectionId)
        ?.name;
    final photo = finding.evidence.firstOrNull;
    return Card(
      key: ValueKey('pending-finding-${finding.id}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
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
                    Text(area, style: Theme.of(context).textTheme.labelLarge),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: ColoredBox(
                  color: Colors.black,
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.file(
                      File(finding.evidence.first.displayFilePath),
                      fit: BoxFit.contain,
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
                label: suggestion.isAutoAccepted
                    ? 'Accepted automatically'
                    : 'Your final decision',
                icon: Icons.fact_check_outlined,
                color: AppColors.success,
                child: Text(
                  finalEntry != null
                      ? finalEntry.defectDescription
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
    final (label, icon, fg, bg) = switch (status) {
      AiSuggestionStatus.pending => (
        'Pending',
        Icons.hourglass_empty,
        AppColors.warning,
        AppColors.warningBg,
      ),
      AiSuggestionStatus.accepted => (
        automatic ? 'Auto-accepted' : 'Accepted',
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
