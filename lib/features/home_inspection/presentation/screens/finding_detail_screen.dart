import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../widgets/finding_resolution_panel.dart';
import '../widgets/finding_status_presentation.dart';
import '../widgets/session_status_presentation.dart';
import 'area_inspection_screen.dart' show AiImageQualityNote, editFindingNote;
import 'photo_viewer_screen.dart';

/// The location of [findingId]'s detail screen.
String findingDetailLocation(String findingId) =>
    '${FindingDetailScreen.routePathPrefix}/$findingId';

/// A deep view of ONE finding: the photo at full width, the inspector's
/// original note, the current result (component, defect, corrective
/// action), what AI said and why, and the actions that change it —
/// Edit Note, Reanalyse, Change Defect (the shared searchable selector),
/// Reject and Delete. All actions are the same ones the Area card uses
/// (`FindingResolutionPanel`); nothing here has its own rules.
class FindingDetailScreen extends ConsumerWidget {
  const FindingDetailScreen({super.key, required this.findingId});

  static const routePathPrefix = '/home-inspection/finding';

  final String findingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final finding = session?.findings.firstWhereOrNull(
      (f) => f.id == findingId,
    );

    if (session == null || finding == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finding')),
        body: AppEmptyView(
          icon: Icons.delete_outline,
          title: 'This finding is no longer here',
          message: 'It may have been deleted.',
          actionLabel: 'Back',
          onAction: () => context.pop(),
        ),
      );
    }

    final suggestion = suggestionFor(session, finding);
    final area = session.sections
        .firstWhereOrNull((s) => s.id == finding.sectionId)
        ?.name;
    final (status, statusLabel) = findingStatusOf(finding, suggestion);
    final catalogue = DefectCatalogue.instance;
    final entryId = suggestion?.hasFinalEntry == true
        ? suggestion!.finalCatalogueEntryId
        : suggestion?.suggestedCatalogueEntryId;
    final entry = entryId == null ? null : catalogue.byId(entryId);
    final resolved = resolutionOf(finding, suggestion).isResolved;

    return Scaffold(
      appBar: AppBar(
        title: Text(area ?? 'Finding'),
        actions: [
          IconButton(
            tooltip: 'Edit note',
            icon: const Icon(Icons.edit_note),
            onPressed: () => editFindingNote(context, ref, finding),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          _LargePhoto(finding: finding),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AppStatusChip(
                      status: status,
                      label: statusLabel,
                      dense: false,
                    ),
                    const Spacer(),
                    Text(
                      'Recorded ${formatRelativeTime(finding.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Inspector note',
                  icon: Icons.person_outline,
                  child: Text(
                    finding.defectNote ?? 'No note yet — AI waits for one.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: resolved ? 'Result' : 'Current AI suggestion',
                  icon: Icons.fact_check_outlined,
                  child: entry == null
                      ? Text(
                          'No defect selected yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Field(
                              label: 'Component',
                              value:
                                  '${entry.mainElementName} · '
                                  '${entry.componentName}',
                            ),
                            _Field(
                              label: 'Defect',
                              value: concreteDefectText(
                                componentName: entry.componentName,
                                defectDescription: entry.defectDescription,
                                term: suggestion?.hasFinalEntry == true
                                    ? suggestion?.finalDefectTerm
                                    : suggestion?.suggestedDefectTerm,
                              ),
                            ),
                            if (entry.correctiveAction != null)
                              _Field(
                                label: 'Corrective action',
                                value: entry.correctiveAction!,
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                _Section(
                  title: 'AI analysis',
                  icon: Icons.auto_awesome,
                  child: _AiAnalysis(finding: finding, suggestion: suggestion),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  resolved ? 'Change defect' : 'Choose a defect',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                FindingResolutionPanel(
                  finding: finding,
                  suggestion: suggestion,
                  showStatus: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LargePhoto extends StatelessWidget {
  const _LargePhoto({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final photo = finding.evidence.firstOrNull;
    final height = (MediaQuery.sizeOf(context).height * 0.38).clamp(
      200.0,
      420.0,
    );
    if (photo == null) {
      return SizedBox(
        height: 160,
        child: const ColoredBox(
          color: AppColors.surfaceMuted,
          child: Icon(Icons.photo_outlined, color: AppColors.textMuted),
        ),
      );
    }
    return InkWell(
      key: const ValueKey('finding-detail-photo'),
      onTap: () => showFindingPhotos(context, findingId: finding.id),
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Whole photo, own orientation (QA #18) — never cropped.
              Image.file(
                File(photo.displayFilePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                ),
              ),
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        finding.evidence.length > 1
                            ? 'View ${finding.evidence.length} photos'
                            : 'View & mark up',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiAnalysis extends StatelessWidget {
  const _AiAnalysis({required this.finding, required this.suggestion});

  final Finding finding;
  final AiSuggestion? suggestion;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final textTheme = Theme.of(context).textTheme;
    final attempt = finding.aiAttempt;
    final lines = <Widget>[
      if (s == null)
        Text(switch (finding.aiStatus) {
          AiFindingStatus.failed => 'The last analysis failed.',
          AiFindingStatus.queued ||
          AiFindingStatus.uploading ||
          AiFindingStatus.analyzing => 'AI is working on this photo.',
          _ =>
            finding.hasDefectNote
                ? 'Waiting to be analysed.'
                : 'Add a note to start analysis.',
        }, style: textTheme.bodyMedium)
      else ...[
        if (s.isAutoAccepted)
          Text('Accepted automatically.', style: textTheme.bodyMedium)
        else if (s.isRejected)
          Text('You rejected this result.', style: textTheme.bodyMedium),
        if (s.detectedComponent != null)
          _Field(label: 'Detected component', value: s.detectedComponent!),
        if (s.suggestedShortReason != null)
          _Field(label: 'Why', value: s.suggestedShortReason!),
        if (s.suggestedConfidence != null)
          _Field(
            label: 'Confidence',
            value: '${(s.suggestedConfidence! * 100).round()}%',
          ),
        if (needsReviewReasonText(s.needsReviewReason) case final reason?)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              reason,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.warning),
            ),
          ),
        if (aiImageQualityNote(s) case final note?)
          AiImageQualityNote(text: note),
      ],
      if (attempt != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            'Last sent to AI ${formatRelativeTime(attempt.submittedAt)} · '
            '${_levelLabel(attempt.aiLevel)}',
            style: textTheme.bodySmall,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
    );
  }

  String _levelLabel(AiLevel level) => switch (level) {
    AiLevel.fast => 'Fast',
    AiLevel.smart => 'Smart',
    AiLevel.expert => 'Expert',
  };
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
