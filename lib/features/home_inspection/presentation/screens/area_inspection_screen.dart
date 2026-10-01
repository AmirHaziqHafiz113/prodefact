import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/remote/remote_providers.dart'
    show isOnlineForAiProvider;
import '../../providers/active_session_providers.dart';
import '../../providers/home_inspection_providers.dart';
import '../../providers/house_pass_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/app_bottom_sheet.dart';
import 'ai_analysis_approval_dialog.dart';
import 'ai_suggestion_review_dialog.dart';
import 'photo_annotation_screen.dart';
import 'photo_viewer_screen.dart';
import 'top_up_screen.dart';

/// Lets the inspector pick where a piece of evidence comes from —
/// Camera or Gallery/Photos — before it enters the *exact same*
/// capture pipeline either way (`EvidenceCaptureService.captureImage`,
/// which already treats [EvidenceSource.camera] and
/// [EvidenceSource.gallery] identically: same normalization, same
/// local persistence, same evidence id, same upload/AI/report path).
/// Returns null if the inspector dismisses the sheet without choosing
/// either — callers must treat that exactly like the camera picker
/// itself being cancelled, i.e. a silent no-op, never an error.
Future<EvidenceSource?> chooseEvidenceSource(BuildContext context) {
  return showAppBottomSheet<EvidenceSource>(
    context: context,
    builder: (sheetContext) => AppSheetFrame(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () => Navigator.of(sheetContext).pop(EvidenceSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.of(sheetContext).pop(EvidenceSource.gallery),
          ),
        ],
      ),
    ),
  );
}

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

  // Opening an area deliberately does NOT mark it started (QA #13/#21):
  // a stray tap into a suggested area the unit doesn't have must not
  // make it count, or appear in the report as "No defects recorded". An
  // area becomes started when a finding or area note is recorded, and
  // completed only through "Mark Area Complete".

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
          _AreaHeader(section: section, findings: areaFindings),
          const SizedBox(height: AppSpacing.lg),
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
          // One clear action instead of the old Not started / In
          // progress / Completed selector, which looked like a filter
          // but only relabelled the area (QA #25). "In progress" now
          // follows from recording a finding; "Completed" is this
          // explicit action, which also covers an area inspected and
          // found to have no defects.
          _AreaCompletionControl(
            status: status,
            hasFindings: areaFindings.isNotEmpty,
            onMarkComplete: () => ref
                .read(sectionStatusesProvider.notifier)
                .setStatus(section.id, SectionStatus.completed),
            onReopen: () => ref
                .read(sectionStatusesProvider.notifier)
                .setStatus(section.id, SectionStatus.inProgress),
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
            label: Text(
              areaFindings.isEmpty
                  ? 'Take Defect Photo'
                  : 'Take Another Defect Photo',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto(String sectionId) async {
    final source = await chooseEvidenceSource(context);
    if (source == null || !mounted) return; // cancelled the source picker

    setState(() => _isCapturing = true);
    final notifier = ref.read(activeSessionProvider.notifier);
    // Gallery: up to 3 photos of this defect in one pick. Camera: one.
    final photos = await notifier.captureFindingPhotos(source: source);
    if (!mounted) return;
    setState(() => _isCapturing = false);
    if (photos.isEmpty) return; // cancelled, or a capture error was shown

    final result = await showAppBottomSheet<_PreviewResult>(
      context: context,
      builder: (context) => _PhotoPreviewSheet(photos: photos),
    );

    if (!mounted) return;
    // The sheet may have marked photos up (separate annotated copies; the
    // originals are untouched) or removed some.
    final kept = result?.photos ?? photos;
    // File cleanup only; nothing waits on it.
    for (final removed in result?.removed ?? const <CapturedFindingPhoto>[]) {
      unawaited(notifier.discardCapturedFindingPhoto(removed));
    }
    if (result == null || !result.save) {
      for (final photo in kept) {
        unawaited(notifier.discardCapturedFindingPhoto(photo));
      }
      return;
    }
    notifier.saveCameraFinding(
      sectionId: sectionId,
      photo: kept.first,
      additionalPhotos: kept.skip(1).toList(),
      note: result.note,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Finding saved'),
        duration: Duration(seconds: 2),
      ),
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

/// This area's physical status plus the one action that changes it.
class _AreaCompletionControl extends StatelessWidget {
  const _AreaCompletionControl({
    required this.status,
    required this.hasFindings,
    required this.onMarkComplete,
    required this.onReopen,
  });

  final SectionStatus status;
  final bool hasFindings;
  final VoidCallback onMarkComplete;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final isComplete = status == SectionStatus.completed;
    final isStarted = hasFindings || status == SectionStatus.inProgress;
    final (label, icon, color) = isComplete
        ? ('Area completed', Icons.check_circle, AppColors.success)
        : isStarted
        ? ('Area in progress', Icons.timelapse, AppColors.warning)
        : (
            'Not started · optional if this unit has no such area',
            Icons.circle_outlined,
            AppColors.textSecondary,
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (isComplete)
              OutlinedButton.icon(
                onPressed: onReopen,
                icon: const Icon(Icons.undo),
                label: const Text('Reopen Area'),
              )
            else
              OutlinedButton.icon(
                onPressed: onMarkComplete,
                icon: const Icon(Icons.check),
                label: Text(
                  hasFindings
                      ? 'Mark Area Complete'
                      : 'No Defects · Mark Area Complete',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The area identity strip — real finding/pending-review counts plus
/// the plumbing-first and needs-attention badges, matching the same
/// card language used on the Inspection Overview's own area cards.
class _AreaHeader extends StatelessWidget {
  const _AreaHeader({required this.section, required this.findings});

  final Section section;
  final List<Finding> findings;

  @override
  Widget build(BuildContext context) {
    final pendingReview = findings
        .where((f) => f.aiStatus == AiFindingStatus.needsReview)
        .length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFallbackThumbnail(
          icon: section.isPlumbing
              ? Icons.plumbing_outlined
              : Icons.chair_outlined,
          size: 64,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                pendingReview == 0
                    ? '${findings.length} finding${findings.length == 1 ? '' : 's'}'
                    : '${findings.length} finding${findings.length == 1 ? '' : 's'} '
                          '· $pendingReview pending review',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (section.isPlumbing)
                    const StatusPill(
                      label: 'Plumbing First',
                      icon: Icons.plumbing_outlined,
                      foreground: AppColors.plumbing,
                      background: AppColors.plumbingBg,
                      dense: true,
                    ),
                  if (pendingReview > 0)
                    StatusPill(
                      label: 'Needs Attention',
                      icon: Icons.priority_high,
                      foreground: AppColors.danger,
                      background: AppColors.dangerBg,
                      dense: true,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewResult {
  const _PreviewResult({
    required this.save,
    required this.photos,
    this.removed = const [],
    this.note,
  });

  final bool save;

  /// The photos kept for this finding, possibly with markup copies.
  final List<CapturedFindingPhoto> photos;

  /// Photos the inspector removed in the sheet (their files are deleted).
  final List<CapturedFindingPhoto> removed;
  final String? note;
}

/// Quick defect note field wording (QA #16), shared by capture and edit.
const _quickNoteLabel = 'Quick defect note';
const _quickNoteHint =
    'e.g. wall tile hollow · poor skim finish · '
    'window frame gap';
const _quickNoteHelper =
    'Needed before AI analysis. Shorthand, BM or English is fine.';

/// "Preview photos -> mark up (optional) -> quick defect note -> Save
/// Finding". All photos here belong to ONE finding (several angles of the
/// same defect). Saving never needs the note; AI analysis does (QA #16),
/// so a finding saved without one simply waits for it.
class _PhotoPreviewSheet extends ConsumerStatefulWidget {
  const _PhotoPreviewSheet({required this.photos});

  final List<CapturedFindingPhoto> photos;

  @override
  ConsumerState<_PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends ConsumerState<_PhotoPreviewSheet> {
  final _noteController = TextEditingController();
  late final List<CapturedFindingPhoto> _photos = [...widget.photos];
  final List<CapturedFindingPhoto> _removed = [];
  int _selected = 0;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _markUp() async {
    final photo = _photos[_selected];
    final bytes = await showPhotoAnnotation(context, filePath: photo.filePath);
    if (bytes == null || !mounted) return;
    final annotated = await ref
        .read(activeSessionProvider.notifier)
        .annotateCapturedPhoto(photo, bytes);
    if (mounted) setState(() => _photos[_selected] = annotated);
  }

  void _remove(int index) {
    // A finding keeps at least one photo.
    if (_photos.length < 2) return;
    setState(() {
      _removed.add(_photos.removeAt(index));
      if (_selected >= _photos.length) _selected = _photos.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Image-first: the selected photo gets most of the viewport, shown
    // whole in its own orientation (QA #18) — never cropped to fit.
    // Save/Discard are pinned (QA #15), so they stay visible with the
    // keyboard open, on short screens, and at large text sizes.
    final imageHeight = (MediaQuery.sizeOf(context).height * 0.38).clamp(
      150.0,
      400.0,
    );
    final current = _photos[_selected];
    return AppSheetFrame(
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(
                _PreviewResult(save: false, photos: _photos, removed: _removed),
              ),
              child: const Text('Discard'),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _PreviewResult(
                  save: true,
                  photos: _photos,
                  removed: _removed,
                  note: _noteController.text,
                ),
              ),
              child: const Text('Save Finding'),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Image.file(
                  File(current.displayFilePath),
                  key: ValueKey(current.displayFilePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          if (_photos.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${_photos.length} photos of this defect',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, i) => _PreviewThumb(
                  key: ValueKey('preview-thumb-$i'),
                  photo: _photos[i],
                  selected: i == _selected,
                  onTap: () => setState(() => _selected = i),
                  onRemove: () => _remove(i),
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _markUp,
              icon: const Icon(Icons.draw_outlined),
              label: Text(
                current.annotatedFilePath == null ? 'Mark Up' : 'Redo Markup',
              ),
            ),
          ),
          TextField(
            controller: _noteController,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: _quickNoteLabel,
              hintText: _quickNoteHint,
              helperText: _quickNoteHelper,
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// One selectable thumbnail in the capture preview, with a remove
/// button (removal is refused for the last remaining photo).
class _PreviewThumb extends StatelessWidget {
  const _PreviewThumb({
    super.key,
    required this.photo,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final CapturedFindingPhoto photo;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(
              File(photo.displayFilePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const ColoredBox(color: AppColors.surfaceAlt),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
                semanticLabel: 'Remove photo',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _FindingAction { editNote, remove }

class _FindingCard extends ConsumerWidget {
  const _FindingCard({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref
        .watch(activeSessionProvider)
        ?.aiSuggestions
        .firstWhereOrNull((s) => s.findingId == finding.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FindingPhotoStrip(finding: finding),
                  const SizedBox(height: AppSpacing.sm),
                  FindingAiStatusLine(finding: finding, suggestion: suggestion),
                  if (finding.defectNote != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        finding.defectNote!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        final source = await chooseEvidenceSource(context);
                        if (source == null) return; // cancelled the picker
                        await ref
                            .read(activeSessionProvider.notifier)
                            .addEvidence(findingId: finding.id, source: source);
                      },
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('Add angle'),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_FindingAction>(
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => switch (action) {
                _FindingAction.editNote => _editNote(context, ref),
                _FindingAction.remove =>
                  ref
                      .read(inspectionFindingsProvider.notifier)
                      .removeFinding(finding.id),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _FindingAction.editNote,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit note'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _FindingAction.remove,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Remove'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(BuildContext context, WidgetRef ref) =>
      editFindingNote(context, ref, finding);
}

/// Edits a finding's quick defect note (QA #16). With Auto Analyse on,
/// adding a note to a finding that was waiting for one starts AI.
Future<void> editFindingNote(
  BuildContext context,
  WidgetRef ref,
  Finding finding,
) async {
  final controller = TextEditingController(text: finding.description ?? '');
  final newNote = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(_quickNoteLabel),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: _quickNoteLabel,
          hintText: _quickNoteHint,
          helperText: _quickNoteHelper,
          helperMaxLines: 2,
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
  ref
      .read(inspectionFindingsProvider.notifier)
      .updateFinding(
        findingId: finding.id,
        description: newNote,
        notes: finding.notes,
      );
}

/// Every photo of one defect ticket as a strip of thumbnails (QA #20).
/// Thumbnails are small square crops for scanning; tapping one opens
/// the full, uncropped photos (QA #18/#19).
class _FindingPhotoStrip extends StatelessWidget {
  const _FindingPhotoStrip({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final photos = finding.evidence;
    if (photos.isEmpty) {
      return const SizedBox(
        width: 72,
        height: 72,
        child: ColoredBox(
          color: AppColors.surfaceAlt,
          child: Icon(Icons.photo_outlined),
        ),
      );
    }
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final photo = photos[i];
          return InkWell(
            key: ValueKey('finding-photo-${photo.id}'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => showFindingPhotos(
              context,
              findingId: finding.id,
              initialIndex: i,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.file(
                      File(photo.displayFilePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const ColoredBox(
                            color: AppColors.surfaceAlt,
                            child: Icon(Icons.photo_outlined),
                          ),
                    ),
                  ),
                  if (photo.isAnnotated)
                    const Positioned(
                      right: 4,
                      bottom: 4,
                      child: Icon(Icons.draw, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A finding's live AI state with the one action that moves it on
/// (Analyse, Add Note, Retry, Classify Manually). Shared by the area
/// screen and AI Review, so a finding never shows without a way forward.
class FindingAiStatusLine extends ConsumerWidget {
  const FindingAiStatusLine({
    super.key,
    required this.finding,
    required this.suggestion,
  });

  final Finding finding;
  final AiSuggestion? suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (finding.aiStatus) {
      case AiFindingStatus.notQueued:
        return const _StatusText(
          icon: Icons.hourglass_empty,
          color: AppColors.textMuted,
          text: 'Not started',
        );
      case AiFindingStatus.queued:
        // `queued` covers two very different reasons nothing is
        // happening yet: genuinely offline/signed-out (in which case
        // "Waiting for connection" is accurate), or simply not picked
        // up by the classification queue for a moment while fully
        // online (the common case right after Save, before the
        // background enqueue's uploading/analyzing transition lands).
        // Previously this branch showed "Waiting for connection"
        // unconditionally, which is the reported false-connection-
        // state bug: the device had working internet the whole time.
        // `isOnlineForAiProvider` is the same connectivity+auth signal
        // `AiCardSummary` already uses at the session-card level — see
        // `lib/data/remote/remote_providers.dart`.
        final isOnline = ref.watch(isOnlineForAiProvider);
        return _StatusText(
          icon: Icons.hourglass_empty,
          color: AppColors.textMuted,
          text: isOnline ? 'Queued for AI' : 'Waiting for connection',
        );
      case AiFindingStatus.awaitingApproval:
        if (!finding.hasDefectNote) {
          return Row(
            children: [
              const Expanded(
                child: _StatusText(
                  icon: Icons.edit_note,
                  color: AppColors.textMuted,
                  text: 'Add a quick defect note to start AI',
                ),
              ),
              TextButton(
                onPressed: () => editFindingNote(context, ref, finding),
                child: const Text('Add Note'),
              ),
            ],
          );
        }
        // A zero-balance, Flex-only finding can never actually be
        // analysed yet — surfaced up front on the card itself, rather
        // than only after the inspector taps "Analyse" and hits the
        // insufficient-credit dialog. Never shown for a House Pass
        // inspection: its included allowance may well cover this
        // finding for 0 Credits, which only the real estimate call
        // knows for sure. Physical inspection (the card existing at
        // all) is never affected either way.
        final resolvedBalance =
            ref.watch(walletBalanceProvider).value ??
            ref.watch(walletCacheProvider).value?.balanceCredits;
        // The backend decides House Pass vs Flex from the pass itself
        // (QA #23); mirror that here rather than a local setting. While
        // the pass status is still loading, don't claim Credits are
        // missing.
        final sessionId = ref.watch(activeSessionProvider)?.id;
        final passStatus = sessionId == null
            ? null
            : ref.watch(housePassStatusProvider(sessionId)).value?.status;
        final isFlexOnly =
            passStatus != null && passStatus != HousePassLifecycleStatus.active;
        if (isFlexOnly && resolvedBalance == 0) {
          return Row(
            children: [
              const Expanded(
                child: _StatusText(
                  icon: Icons.smart_toy_outlined,
                  color: AppColors.textMuted,
                  text: 'AI: Waiting for Credits',
                ),
              ),
              TextButton(
                onPressed: () => context.push(TopUpScreen.routePath),
                child: const Text('Top Up'),
              ),
            ],
          );
        }
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
          text: 'Preparing photo…',
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
            // Wrap, not Row: on a narrow card both actions must stay
            // visible (a Row overflowed and clipped them).
            Wrap(
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
