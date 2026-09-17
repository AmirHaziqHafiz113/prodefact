import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../providers/active_session_providers.dart';
import '../../providers/home_inspection_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import 'ai_analysis_approval_dialog.dart';
import 'ai_suggestion_review_dialog.dart';

/// Camera-first physical inspection of a single area: "Take Defect
/// Photo" is the primary, most prominent action — no element/component
/// selection is ever required before capturing evidence. See
/// `docs/ai_provider_architecture.md` ("Camera-first workflow").
///
/// Flow: Take Photo -> Preview -> optional side note -> Save. AI
/// classification is queued the moment a finding is saved and runs in
/// the background — the inspector can immediately take the next photo
/// without waiting for it.
class AreaInspectionScreen extends ConsumerStatefulWidget {
  const AreaInspectionScreen({required this.sectionId, super.key});

  final String sectionId;

  @override
  ConsumerState<AreaInspectionScreen> createState() =>
      _AreaInspectionScreenState();
}

class _AreaInspectionScreenState extends ConsumerState<AreaInspectionScreen> {
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final statuses = ref.read(sectionStatusesProvider.notifier);
      if (statuses.statusOf(widget.sectionId) == SectionStatus.notStarted) {
        statuses.setStatus(widget.sectionId, SectionStatus.inProgress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(configuredAreasProvider);
    final section = sections.firstWhereOrNull((s) => s.id == widget.sectionId);

    if (section == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Area')),
        body: const AppEmptyView(
          icon: Icons.error_outline,
          title: 'This area is no longer configured.',
        ),
      );
    }

    final status =
        ref.watch(sectionStatusesProvider)[section.id] ??
        SectionStatus.notStarted;
    final areaFindings = ref
        .watch(inspectionFindingsProvider)
        .where((f) => f.sectionId == section.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(section.name),
        actions: [
          IconButton(
            tooltip: section.note == null ? 'Add area note' : 'Edit area note',
            icon: Icon(
              section.note == null
                  ? Icons.note_add_outlined
                  : Icons.sticky_note_2,
            ),
            onPressed: () => _editAreaNote(context, ref, section),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          120,
        ),
        children: [
          if (section.isPlumbing)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: StatusPill(
                label: 'Plumbing area — inspect first',
                icon: Icons.plumbing_outlined,
                foreground: AppColors.plumbing,
                background: AppColors.plumbingBg,
              ),
            ),
          if (section.note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Container(
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
                        section.note!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            'Inspection progress',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<SectionStatus>(
            segments: const [
              ButtonSegment(
                value: SectionStatus.notStarted,
                label: Text('Not started'),
              ),
              ButtonSegment(
                value: SectionStatus.inProgress,
                label: Text('In progress'),
              ),
              ButtonSegment(
                value: SectionStatus.completed,
                label: Text('Completed'),
              ),
            ],
            selected: {status},
            onSelectionChanged: (selection) {
              ref
                  .read(sectionStatusesProvider.notifier)
                  .setStatus(section.id, selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(title: 'Saved findings (${areaFindings.length})'),
          if (areaFindings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'No findings recorded yet. Tap "Take Defect Photo" below '
                'whenever you spot a defect.',
              ),
            )
          else
            for (final finding in areaFindings)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _FindingCard(finding: finding),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: FilledButton.icon(
            onPressed: _isCapturing ? null : () => _takePhoto(section.id),
            icon: _isCapturing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera),
            label: const Text('Take Defect Photo'),
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto(String sectionId) async {
    setState(() => _isCapturing = true);
    final notifier = ref.read(activeSessionProvider.notifier);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    if (!mounted) return;
    setState(() => _isCapturing = false);
    if (photo == null) return; // cancelled, or a capture error already shown

    final result = await showModalBottomSheet<_PreviewResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PhotoPreviewSheet(photo: photo),
    );

    if (!mounted) return;
    if (result == null || !result.save) {
      await notifier.discardCapturedFindingPhoto(photo);
      return;
    }
    notifier.saveCameraFinding(
      sectionId: sectionId,
      photo: photo,
      note: result.note,
    );
  }

  Future<void> _editAreaNote(
    BuildContext context,
    WidgetRef ref,
    Section section,
  ) async {
    final controller = TextEditingController(text: section.note ?? '');
    final newNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Area note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'e.g. "Ponding test started at 10:15 AM."',
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
    ref.read(activeSessionProvider.notifier).setAreaNote(section.id, newNote);
  }
}

class _PreviewResult {
  const _PreviewResult({required this.save, this.note});

  final bool save;
  final String? note;
}

/// "Preview Photo -> optional side note -> Save Finding" — deliberately
/// simple: one photo, one optional text field, one primary action.
class _PhotoPreviewSheet extends StatefulWidget {
  const _PhotoPreviewSheet({required this.photo});

  final CapturedFindingPhoto photo;

  @override
  State<_PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends State<_PhotoPreviewSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A fixed (not aspect-ratio-driven) height — keeps the
              // whole sheet, note field, and Save/Discard buttons
              // comfortably within view without scrolling on a small
              // phone, regardless of the photo's own aspect ratio.
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.file(
                    File(widget.photo.filePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Side note (optional)',
                  hintText: 'e.g. "Water leaking when turned on"',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .pop(const _PreviewResult(save: false)),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        _PreviewResult(save: true, note: _noteController.text),
                      ),
                      child: const Text('Save Finding'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FindingCard extends ConsumerWidget {
  const _FindingCard({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstPhoto = finding.evidence.firstOrNull;
    final suggestion = ref
        .watch(activeSessionProvider)
        ?.aiSuggestions
        .firstWhereOrNull((s) => s.findingId == finding.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 64,
                height: 64,
                child: firstPhoto == null
                    ? const ColoredBox(
                        color: AppColors.surfaceAlt,
                        child: Icon(Icons.photo_outlined),
                      )
                    : Image.file(File(firstPhoto.filePath), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AiStatusLine(finding: finding, suggestion: suggestion),
                  if (finding.description?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        finding.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (finding.evidence.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${finding.evidence.length} photos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Add another photo',
              icon: const Icon(Icons.add_a_photo_outlined),
              onPressed: () => ref
                  .read(activeSessionProvider.notifier)
                  .addEvidence(
                    findingId: finding.id,
                    source: EvidenceSource.camera,
                  ),
            ),
            IconButton(
              tooltip: 'Edit note',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editNote(context, ref),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(inspectionFindingsProvider.notifier)
                  .removeFinding(finding.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: finding.description ?? '');
    final newNote = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Side note'),
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
    ref
        .read(inspectionFindingsProvider.notifier)
        .updateFinding(
          findingId: finding.id,
          description: newNote,
          notes: finding.notes,
        );
  }
}

class _AiStatusLine extends ConsumerWidget {
  const _AiStatusLine({required this.finding, required this.suggestion});

  final Finding finding;
  final AiSuggestion? suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (finding.aiStatus) {
      case AiFindingStatus.notQueued:
      case AiFindingStatus.queued:
        return const _StatusText(
          icon: Icons.hourglass_empty,
          color: AppColors.textMuted,
          text: 'Waiting for connection',
        );
      case AiFindingStatus.awaitingApproval:
        return Row(
          children: [
            const Expanded(
              child: _StatusText(
                icon: Icons.smart_toy_outlined,
                color: AppColors.textMuted,
                text: 'Ready to analyse',
              ),
            ),
            TextButton(
              onPressed: () => showAnalyseApprovalDialog(
                context: context,
                ref: ref,
                findingId: finding.id,
              ),
              child: const Text('Analyse'),
            ),
          ],
        );
      case AiFindingStatus.uploading:
        return const _StatusText(
          icon: Icons.cloud_upload_outlined,
          color: AppColors.info,
          text: 'Uploading photo…',
        );
      case AiFindingStatus.analyzing:
        return const _StatusText(
          icon: Icons.smart_toy_outlined,
          color: AppColors.info,
          text: 'AI analysing…',
        );
      case AiFindingStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StatusText(
              icon: Icons.error_outline,
              color: AppColors.danger,
              text: 'AI analysis failed',
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => ref
                      .read(activeSessionProvider.notifier)
                      .retryAiClassification(finding.id),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => showManualClassificationDialog(
                    context: context,
                    ref: ref,
                    findingId: finding.id,
                  ),
                  child: const Text('Classify Manually'),
                ),
              ],
            ),
          ],
        );
      case AiFindingStatus.needsReview:
        return const _StatusText(
          icon: Icons.help_outline,
          color: AppColors.warning,
          text: 'Needs manual review',
        );
      case AiFindingStatus.completed:
        final entryId = suggestion?.finalCatalogueEntryId?.isNotEmpty == true
            ? suggestion!.finalCatalogueEntryId
            : suggestion?.suggestedCatalogueEntryId;
        final entry = entryId == null
            ? null
            : DefectCatalogue.instance.byId(entryId);
        return _StatusText(
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          text: entry?.defectDescription ?? 'Classified',
        );
    }
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
