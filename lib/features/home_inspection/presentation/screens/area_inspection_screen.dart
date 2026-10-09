import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/design_system.dart';
import '../../../../core/inspection/inspection_domain.dart';
import '../../../../data/quality/basic_image_quality_service.dart';
import '../../../../data/remote/remote_providers.dart'
    show isOnlineForAiProvider;
import '../../providers/active_session_providers.dart';
import '../../providers/home_inspection_providers.dart';
import '../../providers/house_pass_providers.dart';
import '../../providers/physical_inspection_providers.dart';
import '../../providers/wallet_providers.dart';
import '../widgets/app_bottom_sheet.dart';
import 'ai_suggestion_review_dialog.dart';
import 'photo_annotation_screen.dart';
import 'photo_viewer_screen.dart';
import 'top_up_screen.dart';
import 'photo_guide_screen.dart';
import '../widgets/finding_resolution_panel.dart';
import '../widgets/finding_status_presentation.dart';
import '../widgets/reanalyse_and_candidates.dart';
import 'finding_detail_screen.dart';

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
  const AreaInspectionScreen({
    required this.sectionId,
    this.autoCapture = false,
    super.key,
  });

  /// `/home-inspection/inspection/:sectionId` — see `areaFindingsLocation`.
  static const routePathPrefix = '/home-inspection/inspection';

  final String sectionId;

  /// Opens the camera as soon as the screen appears — the "+" quick
  /// capture path (inspection and area already chosen).
  final bool autoCapture;

  @override
  ConsumerState<AreaInspectionScreen> createState() =>
      _AreaInspectionScreenState();
}

class _AreaInspectionScreenState extends ConsumerState<AreaInspectionScreen> {
  bool _isCapturing = false;

  /// Display order only — never changes the findings.
  FindingSort _sort = FindingSort.status;

  // Opening an area deliberately does NOT mark it started (QA #13/#21):
  // a stray tap into a suggested area the unit doesn't have must not
  // make it count, or appear in the report as "No defects recorded". An
  // area becomes started when a finding or area note is recorded, and
  // completed only through "Mark Area Complete".

  @override
  void initState() {
    super.initState();
    if (widget.autoCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _takePhoto(widget.sectionId, source: EvidenceSource.camera);
      });
    }
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
          const PhotoGuideAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          _AreaHeader(section: section, findings: areaFindings),
          if (section.note != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      section.note!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
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
          AppSectionHeader(title: 'Findings (${areaFindings.length})'),
          if (areaFindings.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _FindingSortControl(
                value: _sort,
                onChanged: (sort) => setState(() => _sort = sort),
              ),
            ),
          if (areaFindings.isEmpty)
            const AppEmptyView(
              icon: Icons.add_a_photo_outlined,
              title: 'No findings in this area yet',
              message:
                  'Tap "Take Defect Photo" whenever you spot a defect. '
                  'Each photo becomes its own finding.',
            )
          else
            for (final unit in orderFindings(areaFindings, sort: _sort))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: unit.isGroup
                    ? _CaptureBatchGroup(
                        unit: unit,
                        cardFor: (finding) => _FindingCard(finding: finding),
                      )
                    : _FindingCard(finding: unit.findings.single),
              ),
        ],
      ),
      bottomNavigationBar: AppPrimaryActionBar(
        primary: FilledButton.icon(
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
    );
  }

  /// [source] skips the Camera/Gallery choice (quick capture).
  Future<void> _takePhoto(String sectionId, {EvidenceSource? source}) async {
    source ??= await chooseEvidenceSource(context);
    if (source == null || !mounted) return; // cancelled the source picker

    final notifier = ref.read(activeSessionProvider.notifier);
    List<CapturedFindingPhoto> photos;
    Map<String, ImageQualityAssessment> quality;
    while (true) {
      setState(() => _isCapturing = true);
      // Gallery: up to 3 photos in one pick. Camera: one. Either way,
      // each photo becomes its own finding.
      photos = await notifier.captureFindingPhotos(source: source);
      if (!mounted) return;
      if (photos.isEmpty) {
        setState(() => _isCapturing = false);
        return; // cancelled, or a capture error was shown
      }
      // A cheap, local quality hint (never an AI request). Advisory
      // only: "Use Anyway" always continues with the photo as it is.
      final checker = ref.read(imageQualityServiceProvider);
      quality = {
        for (final photo in photos)
          photo.filePath: await checker.assess(photo.filePath),
      };
      if (!mounted) return;
      setState(() => _isCapturing = false);
      if (quality.values.every((q) => q.looksClear)) break;
      final choice = await showDialog<_QualityChoice>(
        context: context,
        builder: (context) =>
            _QualityWarningDialog(photos: photos, quality: quality),
      );
      if (!mounted) return;
      if (choice == _QualityChoice.retake) {
        for (final photo in photos) {
          unawaited(notifier.discardCapturedFindingPhoto(photo));
        }
        continue;
      }
      // "Use Anyway" — or the dialog dismissed — keeps the photo.
      break;
    }

    final result = await showAppBottomSheet<_PreviewResult>(
      context: context,
      builder: (context) =>
          _PhotoPreviewSheet(photos: photos, quality: quality),
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
    // One photo = one finding: each kept photo is saved as its own
    // finding with its own note (and its own AI job and report entry).
    final saved = notifier.saveCameraFindings(
      sectionId: sectionId,
      photos: kept,
      notes: result.notes,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved.length == 1
              ? '✓ Finding saved'
              : '✓ ${saved.length} findings saved',
        ),
        duration: const Duration(seconds: 2),
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
    final (label, appStatus) = isComplete
        ? ('Area completed', AppStatus.completed)
        : isStarted
        ? ('Area in progress', AppStatus.inProgress)
        : (
            'Not started · optional if this unit has no such area',
            AppStatus.notStarted,
          );
    final style = appStatusStyle(appStatus);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(style.icon, size: 20, color: style.foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: style.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isComplete)
            TextButton.icon(
              onPressed: onReopen,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Reopen Area'),
            )
          else
            Flexible(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  backgroundColor: AppColors.surface,
                ),
                onPressed: onMarkComplete,
                icon: const Icon(Icons.check, size: 18),
                label: Text(
                  hasFindings
                      ? 'Mark Area Complete'
                      : 'No Defects · Mark Area Complete',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The area identity strip — finding count, open review count and the
/// plumbing-first badge.
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
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: (section.isPlumbing ? AppColors.plumbing : AppColors.primary)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            section.isPlumbing ? Icons.plumbing_outlined : Icons.chair_outlined,
            size: 26,
            color: section.isPlumbing ? AppColors.plumbing : AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pendingReview == 0
                    ? '${findings.length} finding${findings.length == 1 ? '' : 's'}'
                    : '${findings.length} finding${findings.length == 1 ? '' : 's'} '
                          '· $pendingReview pending review',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
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
                    const AppStatusChip(
                      status: AppStatus.needsReview,
                      label: 'Needs Attention',
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
    this.notes = const [],
  });

  final bool save;

  /// The photos kept — one new finding each — possibly with markup
  /// copies.
  final List<CapturedFindingPhoto> photos;

  /// Photos the inspector removed in the sheet (their files are deleted).
  final List<CapturedFindingPhoto> removed;

  /// Each kept photo's own quick note, in the same order as [photos].
  final List<String> notes;
}

/// Quick defect note field wording (QA #16), shared by capture and edit.
const _quickNoteLabel = 'Quick defect note';
const _quickNoteHint =
    'e.g. wall tile hollow · poor skim finish · '
    'window frame gap';
const _quickNoteHelper =
    'Needed before AI analysis. Shorthand, BM or English is fine.';

/// "Preview photos -> mark up (optional) -> quick defect note -> Save".
/// One photo = one finding: every photo here is saved as its OWN finding
/// with its own note, even when it shows the same defect from another
/// angle. Saving never needs a note; AI analysis does (QA #16), so a
/// finding saved without one simply waits for it.
enum _QualityChoice { retake, useAnyway }

/// The soft quality warning: lists the possible issues and lets the
/// inspector Retake or Use Anyway. Never blocks: "Use Anyway" (or simply
/// dismissing) always continues with the photo.
class _QualityWarningDialog extends StatelessWidget {
  const _QualityWarningDialog({required this.photos, required this.quality});

  final List<CapturedFindingPhoto> photos;
  final Map<String, ImageQualityAssessment> quality;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      for (final (i, photo) in photos.indexed)
        for (final issue
            in quality[photo.filePath]?.issues ?? const <LocalImageIssue>[])
          photos.length == 1
              ? issue.label
              : 'Photo ${i + 1}: ${issue.label.toLowerCase()}',
    ];
    return AlertDialog(
      title: const Text('Photo may be difficult to analyse'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Possible issues:'),
          const SizedBox(height: AppSpacing.xs),
          for (final line in lines) Text('• $line'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This is only a suggestion — you can still use the photo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_QualityChoice.retake),
          child: const Text('Retake'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_QualityChoice.useAnyway),
          child: const Text('Use Anyway'),
        ),
      ],
    );
  }
}

class _PhotoPreviewSheet extends ConsumerStatefulWidget {
  const _PhotoPreviewSheet({required this.photos, this.quality = const {}});

  final List<CapturedFindingPhoto> photos;

  /// Local quality hints by original file path (advisory only).
  final Map<String, ImageQualityAssessment> quality;

  @override
  ConsumerState<_PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends ConsumerState<_PhotoPreviewSheet> {
  late final List<CapturedFindingPhoto> _photos = [...widget.photos];
  // One note per photo, since each photo is its own finding.
  late final List<TextEditingController> _notes = [
    for (final _ in widget.photos) TextEditingController(),
  ];
  final List<CapturedFindingPhoto> _removed = [];
  final List<TextEditingController> _removedNotes = [];
  int _selected = 0;

  @override
  void dispose() {
    for (final c in [..._notes, ..._removedNotes]) {
      c.dispose();
    }
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
    // The last photo isn't removed here — Discard drops it.
    if (_photos.length < 2) return;
    setState(() {
      _removed.add(_photos.removeAt(index));
      _removedNotes.add(_notes.removeAt(index));
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
                  notes: [for (final c in _notes) c.text],
                ),
              ),
              child: Text(
                _photos.length == 1
                    ? 'Save Finding'
                    : 'Save ${_photos.length} Findings',
              ),
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
          _QualityHint(assessment: widget.quality[current.filePath]),
          if (_photos.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Photo ${_selected + 1} of ${_photos.length}. Each photo is '
              'saved as its own finding, with its own note.',
              key: const ValueKey('preview-photo-count'),
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
            // Rebuilt per photo so each finding keeps its own note.
            key: ValueKey('preview-note-$_selected-${_photos.length}'),
            controller: _notes[_selected],
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

/// Status / Newest / Oldest for the area's findings (default Status).
class _FindingSortControl extends StatelessWidget {
  const _FindingSortControl({required this.value, required this.onChanged});

  final FindingSort value;
  final ValueChanged<FindingSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Sort', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<FindingSort>(
              key: const ValueKey('finding-sort'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: FindingSort.status, label: Text('Status')),
                ButtonSegment(value: FindingSort.newest, label: Text('Newest')),
                ButtonSegment(value: FindingSort.oldest, label: Text('Oldest')),
              ],
              selected: {value},
              onSelectionChanged: (selection) => onChanged(selection.single),
            ),
          ),
        ),
      ],
    );
  }
}

/// The findings saved from one multi-photo gallery pick, inside one
/// bordered group. Visual only: each card is still its own finding with
/// its own note, AI status, review and report entry.
class _CaptureBatchGroup extends StatelessWidget {
  const _CaptureBatchGroup({required this.unit, required this.cardFor});

  final FindingDisplayUnit unit;
  final Widget Function(Finding finding) cardFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('capture-batch-${unit.captureBatchId}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              'Uploaded together · ${unit.findings.length} findings',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          for (final (i, finding) in unit.findings.indexed) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            cardFor(finding),
          ],
        ],
      ),
    );
  }
}

/// One line under the preview: "Photo looks clear", or the possible
/// issues the inspector chose to accept. Advisory only.
class _QualityHint extends StatelessWidget {
  const _QualityHint({required this.assessment});

  final ImageQualityAssessment? assessment;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    if (a == null) return const SizedBox.shrink();
    final clear = a.looksClear;
    return Padding(
      key: const ValueKey('photo-quality-hint'),
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            clear ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: clear ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              clear
                  ? 'Photo looks clear'
                  : 'Possible issues: '
                        '${a.issues.map((i) => i.label.toLowerCase()).join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The AI's own remark about a photo (blurry, unrelated, ...), shown
/// under a finding. Informational only — nothing is forced.
class AiImageQualityNote extends StatelessWidget {
  const AiImageQualityNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.photo_camera_outlined,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('ai-image-quality-note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

enum _FindingAction { editNote, reanalyse, remove }

/// One finding in the area list: its photo large enough to judge, the
/// inspector's note, and the shared resolution panel (result, defect
/// choice, Reanalyse / Reject / Delete). The header opens Finding
/// Detail; the photo opens the full-screen viewer.
class _FindingCard extends ConsumerWidget {
  const _FindingCard({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref
        .watch(activeSessionProvider)
        ?.aiSuggestions
        .firstWhereOrNull((s) => s.findingId == finding.id);
    final (status, label) = findingStatusOf(finding, suggestion);
    void openDetail() => context.push(findingDetailLocation(finding.id));

    return Card(
      key: ValueKey('finding-card-${finding.id}'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FindingPhoto(finding: finding),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppStatusChip(status: status, label: label),
                      ),
                    ),
                    TextButton(
                      key: ValueKey('finding-details-${finding.id}'),
                      onPressed: openDetail,
                      child: const Text('Details'),
                    ),
                    PopupMenuButton<_FindingAction>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'More actions',
                      onSelected: (action) => switch (action) {
                        _FindingAction.editNote => editFindingNote(
                          context,
                          ref,
                          finding,
                        ),
                        _FindingAction.reanalyse => showReanalyseDialog(
                          context: context,
                          ref: ref,
                          finding: finding,
                        ),
                        _FindingAction.remove => confirmAndDeleteFinding(
                          context,
                          ref,
                          finding,
                        ),
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: _FindingAction.editNote,
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Edit note'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        // Any finding with a photo can be analysed again
                        // on request — passed, needs review, failed or
                        // corrected — except while AI is already working
                        // on it.
                        PopupMenuItem(
                          value: _FindingAction.reanalyse,
                          enabled:
                              finding.isAiEligible &&
                              !aiFindingStatusIsInFlight(finding.aiStatus),
                          child: const ListTile(
                            leading: Icon(Icons.refresh),
                            title: Text('Reanalyse'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem(
                          value: _FindingAction.remove,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Delete finding'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (finding.defectNote != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            finding.defectNote!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      FindingResolutionPanel(
                        finding: finding,
                        suggestion: suggestion,
                        showStatus: false,
                      ),
                      if (aiImageQualityNote(suggestion) case final note?)
                        AiImageQualityNote(text: note),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

/// A finding's photo, full card width and tall enough to judge on site
/// (cropped to fill; tapping opens the full, uncropped photo — QA
/// #18/#19). A legacy finding with several photos shows a "+N" badge.
class _FindingPhoto extends StatelessWidget {
  const _FindingPhoto({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final photos = finding.evidence;
    if (photos.isEmpty) {
      return const SizedBox(
        height: 120,
        child: ColoredBox(
          color: AppColors.surfaceMuted,
          child: Icon(Icons.photo_outlined, color: AppColors.textMuted),
        ),
      );
    }
    final photo = photos.first;
    return InkWell(
      key: ValueKey('finding-photo-${photo.id}'),
      onTap: () =>
          showFindingPhotos(context, findingId: finding.id, initialIndex: 0),
      child: SizedBox(
        height: 180,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(photo.displayFilePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const ColoredBox(
                color: AppColors.surfaceMuted,
                child: Icon(Icons.photo_outlined, color: AppColors.textMuted),
              ),
            ),
            Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: Row(
                children: [
                  if (photo.isAnnotated) const _PhotoBadge(icon: Icons.draw),
                  if (photos.length > 1) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _PhotoBadge(
                      icon: Icons.photo_library_outlined,
                      label: '+${photos.length - 1}',
                    ),
                  ],
                  const SizedBox(width: AppSpacing.xs),
                  const _PhotoBadge(icon: Icons.open_in_full),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A finding's live AI state with the one action that moves it on
/// (Add Note, Retry, Top Up, Classify Manually) — analysis itself is
/// always automatic, so there is no Analyse button. Shared by the area
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
        // AI analysis is always automatic: with its note, this finding
        // is about to be picked up by the queue (no Analyse step).
        return _StatusText(
          icon: Icons.hourglass_empty,
          color: AppColors.textMuted,
          text: ref.watch(isOnlineForAiProvider)
              ? 'Queued for AI'
              : 'Waiting for connection',
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
        // A zero-balance, Flex-only inspection can't analyse anything
        // until Credits are added — say so, with Top Up, rather than a
        // bare failure. Never claimed while the House Pass status is
        // still loading, or while a pass is active.
        final resolvedBalance =
            ref.watch(walletBalanceProvider).value ??
            ref.watch(walletCacheProvider).value?.balanceCredits;
        final sessionId = ref.watch(activeSessionProvider)?.id;
        final passStatus = sessionId == null
            ? null
            : ref.watch(housePassStatusProvider(sessionId)).value?.status;
        final waitingForCredits =
            passStatus != null &&
            passStatus != HousePassLifecycleStatus.active &&
            resolvedBalance == 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusText(
              icon: waitingForCredits
                  ? Icons.smart_toy_outlined
                  : Icons.error_outline,
              color: waitingForCredits ? AppColors.textMuted : AppColors.danger,
              text: waitingForCredits
                  ? 'AI: Waiting for Credits'
                  : 'AI analysis failed',
            ),
            // Wrap, not Row: on a narrow card both actions must stay
            // visible (a Row overflowed and clipped them).
            Wrap(
              children: [
                if (waitingForCredits)
                  TextButton(
                    onPressed: () => context.push(TopUpScreen.routePath),
                    child: const Text('Top Up'),
                  ),
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
